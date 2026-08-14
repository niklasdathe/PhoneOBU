import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import '../cits/glosa_service.dart';
import '../models/data_record.dart';
import '../models/obu_snapshot.dart';
import 'obu_repository.dart';

class DemoObuRepository implements ObuRepository {
  final _snapshotController =
      StreamController<ObuSnapshot>.broadcast(sync: true);
  final _diagnosticsController =
      StreamController<TransportDiagnostics>.broadcast(sync: true);
  final _recordController =
      StreamController<ObuDataRecord>.broadcast(sync: true);
  final _glosaService = const GlosaService();

  Timer? _timer;
  double _time = 0;
  bool _collisionRisk = false;
  bool _glosaTimingAvailable = true;
  int _frames = 0;
  int _sequence = 0;
  double _comfortableMaximumSpeedKmh = 30;
  NavigationInstruction _navigation = const NavigationInstruction(
    action: 'Turn right',
    street: 'Jungfernstieg',
    distanceMeters: 180,
    etaMinutes: 12,
  );

  @override
  Stream<ObuSnapshot> get snapshots => _snapshotController.stream;

  @override
  Stream<TransportDiagnostics> get diagnostics => _diagnosticsController.stream;

  @override
  Stream<ObuDataRecord> get records => _recordController.stream;

  @override
  void setComfortableMaximumSpeed(double speedKmh) {
    _comfortableMaximumSpeedKmh = speedKmh.clamp(1, 80).toDouble();
    _emit();
  }

  @override
  Future<void> start() async {
    _emit();
    _timer ??= Timer.periodic(const Duration(milliseconds: 500), (_) {
      _time += 0.5;
      _emit();
    });
  }

  void _emit() {
    final now = DateTime.now();
    final speed = 21.6 + math.sin(_time / 3) * 1.7;
    final cadence = 89 + (math.sin(_time / 2) * 7).round();
    final v2xNearby = (_time % 28) < 11;
    final secondsIntoCycle = _time % 50;
    final secondsToGreen = math.max(0, 18 - secondsIntoCycle);
    final glosa = _glosaTimingAvailable
        ? _glosaService.evaluate(
            input: GlosaInput(
              distanceMeters: 180,
              intersectionId: 42017,
              intersectionName: 'Jungfernstieg / Neuer Jungfernstieg',
              signalGroup: 7,
              signalState: secondsToGreen > 0 ? 'red' : 'green',
              mapemTimestamp: now.subtract(const Duration(milliseconds: 900)),
              spatemTimestamp: now,
              validUntil: now.add(const Duration(seconds: 20)),
              routeMatched: true,
              associationUnambiguous: true,
              greenIntervals: <GreenInterval>[
                GreenInterval(
                  startsInSeconds: secondsToGreen,
                  endsInSeconds: secondsToGreen + 17,
                ),
                GreenInterval(
                  startsInSeconds: secondsToGreen + 45,
                  endsInSeconds: secondsToGreen + 62,
                ),
              ],
            ),
            comfortableMaximumSpeedKmh: _comfortableMaximumSpeedKmh,
            now: now,
          )
        : GlosaRecommendation.unavailable(GlosaAvailability.noSpatem);
    _frames += 3;

    final snapshot = ObuSnapshot(
      receivedAt: now,
      freshness: DataFreshness.live,
      speedKmh: speed,
      glosa: glosa,
      headingDegrees: 42,
      headingCardinal: 'NE',
      heartRateBpm: 148 + (math.sin(_time / 4) * 3).round(),
      cadenceRpm: cadence,
      shiftRecommendation: cadence > 91
          ? ShiftRecommendation.shiftUp
          : ShiftRecommendation.none,
      v2xVehicleNearby: v2xNearby,
      v2xVehicleDistanceMeters:
          v2xNearby ? 38 + (math.sin(_time) * 6).round() : null,
      collisionRisk: _collisionRisk,
      collisionTimeSeconds: _collisionRisk ? 1.8 : null,
      collisionProvenance:
          _collisionRisk ? WarningProvenance.inferredExperimental : null,
      collisionEventId: _collisionRisk ? 'demo-inferred-collision' : null,
      collisionExpiresAt:
          _collisionRisk ? now.add(const Duration(minutes: 2)) : null,
      roadHazard: RoadHazard(
        eventId: 'demo-denm-roadworks-1',
        title: 'Road work',
        detail: 'Narrow lane ahead',
        distanceMeters: 320,
        severity: HazardSeverity.advisory,
        provenance: WarningProvenance.standardizedDenm,
        sourceTimestamp: now.subtract(const Duration(seconds: 1)),
        expiresAt: now.add(const Duration(minutes: 2)),
      ),
      navigation: _navigation,
      obuConnected: true,
      subsystems: const <SubsystemStatus>[
        SubsystemStatus(
          name: 'C5 V2X radio',
          health: SubsystemHealth.online,
          detail: 'ITS-G5 · 5.9 GHz',
        ),
        SubsystemStatus(
          name: 'GNSS',
          health: SubsystemHealth.online,
          detail: '3D fix · 14 satellites',
        ),
        SubsystemStatus(
          name: 'CAN',
          health: SubsystemHealth.online,
          detail: '500 kbit/s · 4 nodes',
        ),
        SubsystemStatus(
          name: 'BLE sensors',
          health: SubsystemHealth.degraded,
          detail: 'Heart rate connected · cadence via CAN',
        ),
        SubsystemStatus(
          name: 'OBU BLE',
          health: SubsystemHealth.online,
          detail: 'Demo link · notifications active',
        ),
        SubsystemStatus(
          name: 'Storage',
          health: SubsystemHealth.online,
          detail: 'Phone session store ready',
        ),
        SubsystemStatus(
          name: 'Internet / OTM',
          health: SubsystemHealth.degraded,
          detail: 'OTM disabled by default',
        ),
      ],
    );
    _snapshotController.add(snapshot);

    _diagnosticsController.add(
      TransportDiagnostics(
        phase: ConnectionPhase.demo,
        transportName: 'Demo',
        protocolVersion: 1,
        negotiatedMtu: 247,
        receivedFrames: _frames,
        transmittedFrames: 4,
        lostSequences: 0,
        recoveredRecords: 0,
        overflowDrops: 0,
        authenticated: true,
        sessionContinuity: 'continuous',
        s3FirmwareVersion: 'demo-s3-1.0',
        c5FirmwareVersion: 'demo-c5-1.0',
        clockSyncState: 'simulated_locked',
        clockSyncQuality: '±1 ms simulated',
        lastMessageType:
            _collisionRisk ? 'experimental collision scenario' : 'telemetry',
        lastError: null,
      ),
    );

    if (_frames % 12 == 0) {
      _recordController.add(
        ObuDataRecord(
          channel: 'v2x/raw',
          source: 'c5',
          acquisitionTime: now.subtract(const Duration(milliseconds: 15)),
          arrivalTime: now,
          sequence: _sequence++,
          origin: RecordOrigin.simulation,
          provenance: RecordProvenance.raw,
          payload: const <String, Object?>{
            'messageSet': 'DENM',
            'scenario': 'roadWorks',
          },
          rawBytes: Uint8List.fromList(
            <int>[0xD3, 0x91, 0x01, _sequence & 0xff, 0x00, 0x7F],
          ),
          isRawV2x: true,
        ),
      );
    }
  }

  @override
  Future<ObuCommandResult> sendCommand(
    String command, [
    Map<String, Object?> arguments = const <String, Object?>{},
  ]) async {
    switch (command) {
      case 'simulate_collision':
        _collisionRisk = true;
        _emit();
        return const ObuCommandResult(
          success: true,
          code: 'OK',
          message: 'Experimental collision scenario enabled.',
          state: <String, Object?>{'collisionRisk': true},
        );
      case 'clear_collision':
        _collisionRisk = false;
        _emit();
        return const ObuCommandResult(
          success: true,
          code: 'OK',
          message: 'Collision scenario cleared.',
          state: <String, Object?>{'collisionRisk': false},
        );
      case 'simulate_missing_spatem':
        _glosaTimingAvailable = false;
        _emit();
        return const ObuCommandResult(
          success: true,
          code: 'OK',
          message: 'SPATEM removed; GLOSA recommendation unavailable.',
          state: <String, Object?>{'spatemAvailable': false},
        );
      case 'restore_spatem':
        _glosaTimingAvailable = true;
        _emit();
        return const ObuCommandResult(
          success: true,
          code: 'OK',
          message: 'Valid MAPEM/SPATEM restored.',
          state: <String, Object?>{'spatemAvailable': true},
        );
      case 'reconnect':
        _emit();
        return const ObuCommandResult(
          success: true,
          code: 'OK',
          message: 'Demo connection refreshed.',
          state: <String, Object?>{'connected': true},
        );
      case 'configure_sensor':
      case 'configure_can':
      case 'configure_v2x':
        return ObuCommandResult(
          success: true,
          code: 'APPLIED',
          message: 'Demo OBU applied ' + command + '.',
          state: arguments,
        );
      default:
        return ObuCommandResult(
          success: false,
          code: 'UNSUPPORTED',
          message: 'Demo transport does not implement ' + command + '.',
        );
    }
  }

  @override
  Future<void> dispose() async {
    _timer?.cancel();
    await _snapshotController.close();
    await _diagnosticsController.close();
    await _recordController.close();
  }
}
