import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:universal_ble/universal_ble.dart';

import '../cits/cits_application_processor.dart';
import '../cits/cits_interpreter.dart';
import '../cits/cits_security_validator.dart';
import '../models/data_record.dart';
import '../models/obu_snapshot.dart';
import '../protocol/obu_protocol.dart';
import 'obu_repository.dart';

abstract final class ObuGattProfile {
  static const service = '7e570001-6f62-752d-6275-000000000001';
  static const telemetry = '7e570002-6f62-752d-6275-000000000001';
  static const command = '7e570003-6f62-752d-6275-000000000001';
  static const response = '7e570004-6f62-752d-6275-000000000001';
}

class UniversalBleObuRepository implements ObuRepository {
  UniversalBleObuRepository({
    CitsSecurityValidator securityValidator = const NoCitsSecurityValidator(),
  }) : _securityValidator = securityValidator;

  final _snapshotController = StreamController<ObuSnapshot>.broadcast(sync: true);
  final _diagnosticsController =
      StreamController<TransportDiagnostics>.broadcast(sync: true);
  final _recordController =
      StreamController<ObuDataRecord>.broadcast(sync: true);
  final _reassembler = ObuMessageReassembler();
  final _pendingCommands = <int, Completer<ObuCommandResult>>{};
  final _citsProcessor = CitsApplicationProcessor();
  final CitsSecurityValidator _securityValidator;

  StreamSubscription<BleDevice>? _scanSubscription;
  StreamSubscription<bool>? _connectionSubscription;
  StreamSubscription<Uint8List>? _telemetrySubscription;
  StreamSubscription<Uint8List>? _responseSubscription;
  Timer? _scanTimeout;
  Timer? _freshnessTimer;
  BleDevice? _device;
  BleCharacteristic? _commandCharacteristic;
  ObuSnapshot _snapshot = ObuSnapshot.initial();
  TransportDiagnostics _diagnostics =
      TransportDiagnostics.initial(transportName: 'Universal BLE');
  bool _connecting = false;
  int _maxFragmentPayload = 4;
  int _sequence = 0;
  int _requestId = 1;
  double _comfortableMaximumSpeedKmh = 30;

  @override
  Stream<ObuSnapshot> get snapshots => _snapshotController.stream;

  @override
  Stream<TransportDiagnostics> get diagnostics => _diagnosticsController.stream;

  @override
  Stream<ObuDataRecord> get records => _recordController.stream;

  @override
  void setComfortableMaximumSpeed(double speedKmh) {
    _comfortableMaximumSpeedKmh = speedKmh.clamp(1, 80).toDouble();
    _citsProcessor.setComfortableMaximumSpeed(_comfortableMaximumSpeedKmh);
  }

  @override
  Future<void> start() async {
    _setPhase(ConnectionPhase.scanning);
    try {
      await UniversalBle.requestPermissions(withAndroidFineLocation: false);
      final systemDevices = await UniversalBle.getSystemDevices(
        withServices: const <String>[ObuGattProfile.service],
      );
      if (systemDevices.isNotEmpty) {
        await _handleScanResult(systemDevices.first);
        return;
      }
      _scanSubscription = UniversalBle.scanStream.listen(_handleScanResult);
      await UniversalBle.startScan(
        scanFilter: ScanFilter(
          withServices: const <String>[ObuGattProfile.service],
          withNamePrefix: const <String>['Bicycle OBU'],
        ),
        platformConfig: PlatformConfig(
          android: AndroidOptions(
            legacy: true,
            scanMode: AndroidScanMode.lowLatency,
            callbackType: const <AndroidScanCallbackType>[
              AndroidScanCallbackType.allMatches,
            ],
            requestLocationPermission: false,
          ),
        ),
      );
      _scanTimeout = Timer(const Duration(seconds: 15), () async {
        if (_device == null) {
          await UniversalBle.stopScan();
          _setError('No Bicycle OBU advertising the expected service was found.');
        }
      });
    } catch (error) {
      _setError('BLE startup failed: $error');
    }
  }

  Future<void> _handleScanResult(BleDevice device) async {
    if (_connecting || _device != null) {
      return;
    }
    _connecting = true;
    _device = device;
    _scanTimeout?.cancel();
    await UniversalBle.stopScan();
    _setPhase(ConnectionPhase.connecting);

    try {
      _connectionSubscription = device.connectionStream.listen((connected) {
        if (connected) {
          _snapshot = _snapshot.copyWith(
            receivedAt: DateTime.now(),
            freshness: DataFreshness.live,
            obuConnected: true,
          );
          _snapshotController.add(_snapshot);
          _setPhase(ConnectionPhase.connected);
        } else {
          _snapshot = _snapshot.copyWith(
            freshness: DataFreshness.stale,
            obuConnected: false,
          );
          _snapshotController.add(_snapshot);
          _setPhase(ConnectionPhase.disconnected);
        }
      });
      await device.connect(
        autoConnect: true,
        platformConfig: ConnectionPlatformConfig(
          apple: AppleConnectionOptions(
            notifyOnConnection: true,
            notifyOnDisconnection: true,
            notifyOnNotification: true,
          ),
        ),
      );
      _setPhase(ConnectionPhase.connected);

      int? mtu;
      try {
        mtu = await device.requestMtu(247);
      } catch (_) {
        // iOS and some stacks manage MTU entirely at OS level.
      }
      _maxFragmentPayload = _fragmentPayloadForMtu(mtu);

      await device.discoverServices();
      final telemetry = await device.getCharacteristic(
        ObuGattProfile.service,
        ObuGattProfile.telemetry,
      );
      final response = await device.getCharacteristic(
        ObuGattProfile.service,
        ObuGattProfile.response,
      );
      _commandCharacteristic = await device.getCharacteristic(
        ObuGattProfile.service,
        ObuGattProfile.command,
      );

      _telemetrySubscription = telemetry.onValueReceived.listen(_handleFrame);
      _responseSubscription = response.onValueReceived.listen(_handleFrame);
      await telemetry.notifications.subscribe();
      await response.indications.subscribe();

      _diagnostics = _diagnostics.copyWith(
        phase: ConnectionPhase.connected,
        negotiatedMtu: mtu,
        clearError: true,
      );
      _diagnosticsController.add(_diagnostics);
      _snapshot = _snapshot.copyWith(
        receivedAt: DateTime.now(),
        freshness: DataFreshness.live,
        obuConnected: true,
      );
      _snapshotController.add(_snapshot);
      _startFreshnessMonitor();
    } catch (error) {
      _setError('BLE connection setup failed: $error');
      _device = null;
      _connecting = false;
    }
  }

  void _handleFrame(Uint8List frameBytes) {
    try {
      final message = _reassembler.add(frameBytes);
      _diagnostics = _diagnostics.copyWith(
        receivedFrames: _diagnostics.receivedFrames + 1,
        lostSequences: _reassembler.lostSequences,
        outOfOrderSequences: _reassembler.outOfOrderSequences,
      );
      if (message == null) {
        _diagnosticsController.add(_diagnostics);
        return;
      }
      _diagnostics = _diagnostics.copyWith(lastMessageType: message.type.name);
      _diagnosticsController.add(_diagnostics);
      _handleMessage(message);
    } catch (error) {
      _setError('Rejected BLE frame: $error');
    }
  }

  void _handleMessage(ObuMessage message) {
    var json = message.decodeJson();
    if (message.type == MessageType.cits) {
      final encoded = json['rawFrameBase64']?.toString();
      if (encoded != null && encoded.isNotEmpty) {
        try {
          final rawFrame = base64Decode(encoded);
          final verification = _securityValidator.validate(rawFrame, json);
          json = <String, Object?>{
            ...json,
            'securityVerification': verification.toJson(),
          };
        } catch (error) {
          json = <String, Object?>{
            ...json,
            'securityVerification': <String, String>{
              'state': CitsVerificationState.error.name,
              'validatorId': 'transport',
              'detail': error.toString(),
            },
          };
        }
      }
    }
    _emitRecord(message, json);
    switch (message.type) {
      case MessageType.telemetry:
        _applyTelemetry(json);
        break;
      case MessageType.cits:
        _applyCits(json);
        break;
      case MessageType.diagnostics:
        _applySubsystems(json);
        break;
      case MessageType.response:
        _completeCommand(json);
        break;
      case MessageType.command:
        break;
    }
    if (json['recovered'] == true) {
      _snapshot = _snapshot.copyWith(
        receivedAt: DateTime.now(),
        freshness: DataFreshness.bufferedRecovered,
      );
      _snapshotController.add(_snapshot);
    }
  }

  void _applyTelemetry(Map<String, Object?> json) {
    final heading = _asDouble(json['headingDeg'], _snapshot.headingDegrees);
    _snapshot = _snapshot.copyWith(
      receivedAt: DateTime.now(),
      freshness: DataFreshness.live,
      obuConnected: true,
      speedKmh: _asDouble(json['speedKmh'], _snapshot.speedKmh),
      headingDegrees: heading,
      headingCardinal: _cardinal(heading),
      heartRateBpm: _asInt(json['heartRateBpm'], _snapshot.heartRateBpm),
      cadenceRpm: _asInt(json['cadenceRpm'], _snapshot.cadenceRpm),
      shiftRecommendation: _shift(json['shiftRecommendation']),
    );
    _snapshotController.add(_snapshot);
  }

  void _applyCits(Map<String, Object?> json) {
    final event = json['event']?.toString();
    if (json.containsKey('messageSet') || json.containsKey('type')) {
      _applyStandardCits(CitsInterpreter.interpret(json));
      return;
    }
    if (event == 'collisionRisk') {
      final active = json['active'] == true;
      _snapshot = _snapshot.copyWith(
        receivedAt: DateTime.now(),
        freshness: DataFreshness.live,
        collisionRisk: active,
        collisionTimeSeconds: _asNullableDouble(json['timeToCollisionS']),
        clearCollisionTime: !active,
        collisionProvenance:
            active ? WarningProvenance.inferredExperimental : null,
        clearCollisionProvenance: !active,
        collisionEventId: active
            ? json['eventId']?.toString() ?? 'inferred-collision'
            : null,
        clearCollisionEventId: !active,
        collisionExpiresAt: active
            ? _timestamp(
                json['expiresAt'],
                fallback: DateTime.now().add(const Duration(seconds: 5)),
              )
            : null,
        clearCollisionExpiry: !active,
      );
    } else if (event == 'nearbyVehicle') {
      final active = json['active'] == true;
      _snapshot = _snapshot.copyWith(
        receivedAt: DateTime.now(),
        v2xVehicleNearby: active,
        v2xVehicleDistanceMeters: _asNullableInt(json['distanceM']),
        clearV2xDistance: !active,
      );
    } else if (event == 'roadWork') {
      final active = json['active'] == true;
      _snapshot = _snapshot.copyWith(
        receivedAt: DateTime.now(),
        roadHazard: active
            ? RoadHazard(
                eventId: json['eventId']?.toString() ?? 'legacy-road-work',
                title: json['title']?.toString() ?? 'Road work',
                detail: json['detail']?.toString() ?? 'Caution ahead',
                distanceMeters: _asInt(json['distanceM'], 0),
                severity: HazardSeverity.advisory,
                provenance: WarningProvenance.standardizedDenm,
                sourceTimestamp: _timestamp(json['sourceTimestamp']),
                expiresAt: _timestamp(
                  json['expiresAt'],
                  fallback: DateTime.now().add(const Duration(minutes: 2)),
                ),
              )
            : null,
        clearRoadHazard: !active,
      );
    }
    _snapshotController.add(_snapshot);
  }

  void _applyStandardCits(CitsMessage message) {
    _snapshot = _citsProcessor.processMessage(message, _snapshot);
    _snapshotController.add(_snapshot);
  }

  void _applySubsystems(Map<String, Object?> json) {
    _diagnostics = _diagnostics.copyWith(
      recoveredRecords: _asInt(
        json['recoveredRecords'],
        _diagnostics.recoveredRecords,
      ),
      overflowDrops: _asInt(
        json['overflowDrops'],
        _diagnostics.overflowDrops,
      ),
      authenticated: json['authenticated'] is bool
          ? json['authenticated'] as bool
          : _diagnostics.authenticated,
      sessionContinuity: json['sessionContinuity']?.toString() ??
          _diagnostics.sessionContinuity,
      s3FirmwareVersion: json['s3FirmwareVersion']?.toString() ??
          _diagnostics.s3FirmwareVersion,
      c5FirmwareVersion: json['c5FirmwareVersion']?.toString() ??
          _diagnostics.c5FirmwareVersion,
      clockSyncState: json['clockSyncState']?.toString() ??
          _diagnostics.clockSyncState,
      clockSyncQuality: json['clockSyncQuality']?.toString() ??
          _diagnostics.clockSyncQuality,
    );
    _diagnosticsController.add(_diagnostics);
    final raw = json['subsystems'];
    if (raw is! List) {
      return;
    }
    final statuses = raw.whereType<Map>().map((entry) {
      final map = entry.cast<Object?, Object?>();
      return SubsystemStatus(
        name: map['name']?.toString() ?? 'Unknown',
        health: _health(map['state']?.toString()),
        detail: map['detail']?.toString() ?? 'No detail',
      );
    }).toList(growable: false);
    _snapshot = _snapshot.copyWith(
      receivedAt: DateTime.now(),
      subsystems: statuses,
    );
    _snapshotController.add(_snapshot);
  }

  void _completeCommand(Map<String, Object?> json) {
    final requestId = _asNullableInt(json['requestId']);
    if (requestId == null) {
      return;
    }
    final completer = _pendingCommands.remove(requestId);
    if (completer == null || completer.isCompleted) {
      return;
    }
    completer.complete(
      ObuCommandResult(
        success: json['ok'] == true,
        code: json['code']?.toString() ?? 'UNKNOWN',
        message: json['message']?.toString() ?? 'No response detail.',
        state: json['state'] is Map<Object?, Object?>
            ? (json['state']! as Map<Object?, Object?>)
                .map((key, value) => MapEntry(key.toString(), value))
            : const <String, Object?>{},
      ),
    );
  }

  @override
  Future<ObuCommandResult> sendCommand(
    String command, [
    Map<String, Object?> arguments = const <String, Object?>{},
  ]) async {
    if (command == 'reconnect') {
      return _requestReconnect();
    }
    if (!_diagnostics.authenticated) {
      return const ObuCommandResult(
        success: false,
        code: 'UNAUTHENTICATED_LINK',
        message: 'Protected OBU commands require an authenticated BLE link.',
      );
    }
    final characteristic = _commandCharacteristic;
    if (characteristic == null) {
      return const ObuCommandResult(
        success: false,
        code: 'NOT_CONNECTED',
        message: 'The ESP32-S3 command characteristic is not available.',
      );
    }
    final requestId = _requestId++ & 0xffff;
    final payload = Uint8List.fromList(
      utf8.encode(
        jsonEncode(<String, Object?>{
          'requestId': requestId,
          'command': command,
          'arguments': arguments,
        }),
      ),
    );
    final frames = ObuFrameCodec.encodeMessage(
      source: MessageSource.phone,
      type: MessageType.command,
      messageId: requestId,
      startSequence: _sequence,
      payload: payload,
      maxFragmentPayload: _maxFragmentPayload,
    );
    _sequence = (_sequence + frames.length) & 0xffff;
    final completer = Completer<ObuCommandResult>();
    _pendingCommands[requestId] = completer;
    try {
      for (final frame in frames) {
        await characteristic.write(frame, withResponse: true);
        _diagnostics = _diagnostics.copyWith(
          transmittedFrames: _diagnostics.transmittedFrames + 1,
        );
      }
      _diagnosticsController.add(_diagnostics);
      return await completer.future.timeout(const Duration(seconds: 4));
    } on TimeoutException {
      _pendingCommands.remove(requestId);
      return const ObuCommandResult(
        success: false,
        code: 'TIMEOUT',
        message: 'The OBU did not acknowledge the command in time.',
      );
    } catch (error) {
      _pendingCommands.remove(requestId);
      return ObuCommandResult(
        success: false,
        code: 'WRITE_FAILED',
        message: '$error',
      );
    }
  }

  Future<ObuCommandResult> _requestReconnect() async {
    final device = _device;
    try {
      if (device != null) {
        if (!await device.isConnected) {
          await device.connect(autoConnect: true);
        }
        return const ObuCommandResult(
          success: true,
          code: 'RECONNECT_ACTIVE',
          message: 'The OS is reconnecting to the previously discovered OBU.',
        );
      }
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      _connecting = false;
      await start();
      return const ObuCommandResult(
        success: true,
        code: 'DISCOVERY_STARTED',
        message: 'OBU discovery restarted.',
      );
    } catch (error) {
      return ObuCommandResult(
        success: false,
        code: 'RECONNECT_FAILED',
        message: '$error',
      );
    }
  }

  void _setPhase(ConnectionPhase phase) {
    _diagnostics = _diagnostics.copyWith(phase: phase, clearError: true);
    _diagnosticsController.add(_diagnostics);
  }

  void _setError(String message) {
    _diagnostics = _diagnostics.copyWith(
      phase: ConnectionPhase.error,
      lastError: message,
    );
    _diagnosticsController.add(_diagnostics);
  }

  double _asDouble(Object? value, double fallback) {
    return value is num ? value.toDouble() : fallback;
  }

  int _asInt(Object? value, int fallback) {
    return value is num ? value.round() : fallback;
  }

  double? _asNullableDouble(Object? value) {
    return value is num ? value.toDouble() : null;
  }

  int? _asNullableInt(Object? value) {
    return value is num ? value.round() : null;
  }

  ShiftRecommendation _shift(Object? value) {
    return switch (value?.toString()) {
      'up' => ShiftRecommendation.shiftUp,
      'down' => ShiftRecommendation.shiftDown,
      _ => ShiftRecommendation.none,
    };
  }

  SubsystemHealth _health(String? value) {
    return switch (value) {
      'online' => SubsystemHealth.online,
      'degraded' => SubsystemHealth.degraded,
      'offline' => SubsystemHealth.offline,
      _ => SubsystemHealth.unavailable,
    };
  }

  String _cardinal(double degrees) {
    const labels = <String>['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return labels[((degrees % 360) / 45).round() % labels.length];
  }

  int _fragmentPayloadForMtu(int? mtu) {
    const attHeaderLength = 3;
    const protocolOverhead =
        ObuFrameCodec.headerLength + ObuFrameCodec.crcLength;
    const minimumAttMtu = 23;
    final effectiveMtu = mtu == null || mtu < minimumAttMtu
        ? minimumAttMtu
        : mtu;
    return effectiveMtu - attHeaderLength - protocolOverhead;
  }

  void _emitRecord(ObuMessage message, Map<String, Object?> json) {
    final arrival = DateTime.now();
    final acquisition = _timestamp(json['acquisitionTimestamp']);
    Uint8List? rawBytes;
    final encoded = json['rawFrameBase64']?.toString();
    if (encoded != null && encoded.isNotEmpty) {
      try {
        rawBytes = base64Decode(encoded);
      } catch (_) {
        rawBytes = null;
      }
    }
    _recordController.add(
      ObuDataRecord(
        channel:
            message.type == MessageType.cits ? 'v2x/raw' : message.type.name,
        source: message.source.name,
        acquisitionTime: acquisition,
        arrivalTime: arrival,
        sequence: message.messageId,
        origin: json['recovered'] == true
            ? RecordOrigin.bufferedRecovered
            : RecordOrigin.live,
        provenance: rawBytes == null
            ? RecordProvenance.measured
            : RecordProvenance.raw,
        payload: json,
        rawBytes: rawBytes,
        isRawV2x: message.type == MessageType.cits && rawBytes != null,
      ),
    );
  }

  DateTime _timestamp(Object? value, {DateTime? fallback}) {
    return DateTime.tryParse(value?.toString() ?? '') ??
        fallback ??
        DateTime.now();
  }

  void _startFreshnessMonitor() {
    _freshnessTimer?.cancel();
    _freshnessTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      var changed = false;
      final collisionExpiry = _snapshot.collisionExpiresAt;
      if (_snapshot.collisionRisk &&
          collisionExpiry != null &&
          now.isAfter(collisionExpiry)) {
        _snapshot = _snapshot.copyWith(
          collisionRisk: false,
          clearCollisionTime: true,
          clearCollisionProvenance: true,
          clearCollisionEventId: true,
          clearCollisionExpiry: true,
        );
        changed = true;
      }
      final hazard = _snapshot.roadHazard;
      if (hazard != null && now.isAfter(hazard.expiresAt)) {
        _snapshot = _snapshot.copyWith(clearRoadHazard: true);
        changed = true;
      }
      final glosaExpiry = _snapshot.glosa.validUntil;
      if (_snapshot.glosa.hasRecommendation &&
          glosaExpiry != null &&
          now.isAfter(glosaExpiry)) {
        _snapshot = _snapshot.copyWith(
          glosa: GlosaRecommendation.unavailable(GlosaAvailability.stale),
        );
        changed = true;
      }
      if (!_snapshot.obuConnected ||
          _snapshot.freshness != DataFreshness.live ||
          now.difference(_snapshot.receivedAt) <=
              const Duration(seconds: 3)) {
        if (changed) _snapshotController.add(_snapshot);
        return;
      }
      _snapshot = _snapshot.copyWith(freshness: DataFreshness.stale);
      _snapshotController.add(_snapshot);
    });
  }

  @override
  Future<void> dispose() async {
    _scanTimeout?.cancel();
    _freshnessTimer?.cancel();
    await _scanSubscription?.cancel();
    await _connectionSubscription?.cancel();
    await _telemetrySubscription?.cancel();
    await _responseSubscription?.cancel();
    try {
      await UniversalBle.stopScan();
      await _device?.disconnect();
    } catch (_) {
      // Teardown should remain best-effort when the adapter is already gone.
    }
    for (final completer in _pendingCommands.values) {
      if (!completer.isCompleted) {
        completer.complete(
          const ObuCommandResult(
            success: false,
            code: 'DISPOSED',
            message: 'The BLE transport was closed.',
          ),
        );
      }
    }
    _pendingCommands.clear();
    await _snapshotController.close();
    await _diagnosticsController.close();
    await _recordController.close();
  }
}
