import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../cits/cits_application_processor.dart';
import '../data/background/ride_background_service.dart';
import '../data/dbc/dbc_catalog.dart';
import '../data/navigation/navigation_service.dart';
import '../data/obu_repository.dart';
import '../data/otm/otm_publisher.dart';
import '../data/phone_sensors/phone_sensors_repository.dart';
import '../data/session/ride_session_manager.dart';
import '../data/settings_repository.dart';
import '../models/app_settings.dart';
import '../models/data_record.dart';
import '../models/navigation_route.dart';
import '../models/obu_snapshot.dart';
import '../models/phone_sensor_snapshot.dart';

class ObuController extends ChangeNotifier with WidgetsBindingObserver {
  ObuController(
    this._repository,
    this._phoneSensors,
    this._navigationService, {
    SettingsRepository? settingsRepository,
    DbcCatalog? dbcCatalog,
    RideSessionManager? sessionManager,
    OtmPublisher? otmPublisher,
    RideBackgroundService? backgroundService,
  }) : _settingsRepository =
           settingsRepository ?? PersistentSettingsRepository(),
       _dbcCatalog = dbcCatalog ?? DbcCatalog(),
       _sessionManager = sessionManager ?? RideSessionManager(),
       _otmPublisher = otmPublisher ?? MqttOtmPublisher(),
       _backgroundService = backgroundService ?? RideBackgroundService();

  final ObuRepository _repository;
  final PhoneSensorsRepository _phoneSensors;
  final NavigationService _navigationService;
  final SettingsRepository _settingsRepository;
  final DbcCatalog _dbcCatalog;
  final RideSessionManager _sessionManager;
  final OtmPublisher _otmPublisher;
  final RideBackgroundService _backgroundService;
  final CitsApplicationProcessor _replayCitsProcessor =
      CitsApplicationProcessor();

  StreamSubscription<ObuSnapshot>? _snapshotSubscription;
  StreamSubscription<TransportDiagnostics>? _diagnosticSubscription;
  StreamSubscription<ObuDataRecord>? _recordSubscription;
  StreamSubscription<PhoneSensorSnapshot>? _phoneSensorSubscription;
  StreamSubscription<OtmStatus>? _otmSubscription;
  StreamSubscription<List<RideSessionSummary>>? _sessionSubscription;
  StreamSubscription<ReplayStatus>? _replayStatusSubscription;
  StreamSubscription<ReplayFrame>? _replayFrameSubscription;

  ObuSnapshot snapshot = ObuSnapshot.initial();
  TransportDiagnostics diagnostics = TransportDiagnostics.initial(
    transportName: 'Starting',
  );
  late PhoneSensorSnapshot phoneSensors = PhoneSensorSnapshot.initial(
    _phoneSensors.mode,
  );
  NavigationState navigation = NavigationState.initial();
  AppSettings settings = AppSettings.defaults();
  OtmStatus otmStatus = OtmStatus.disabled();
  List<RideSessionSummary> rideSessions = const <RideSessionSummary>[];
  ReplayStatus replayStatus = ReplayStatus.idle();
  String backgroundCapability = 'checking';
  String backgroundState = 'foreground';
  Duration? lastDetectedSuspension;
  String? appError;
  bool initialized = false;
  DateTime? _backgroundedAt;
  DateTime _lastPipelineActivity = DateTime.now();

  List<DbcDefinition> get dbcDefinitions => _dbcCatalog.definitions;
  bool get isRecording => _sessionManager.isRecording;

  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);
    _wireStreams();
    try {
      settings = await _settingsRepository.load();
      _repository.setComfortableMaximumSpeed(
        settings.comfortableMaximumSpeedKmh,
      );
      _replayCitsProcessor.setComfortableMaximumSpeed(
        settings.comfortableMaximumSpeedKmh,
      );
    } catch (error) {
      appError = 'Settings could not be loaded: ' + error.toString();
    }
    await _initializeOptionalServices();
    unawaited(_configureOtmFromSettings());
    try {
      await Future.wait(<Future<void>>[
        _repository.start(),
        _phoneSensors.start(),
      ]);
    } catch (error) {
      appError = 'Ride pipeline startup failed: ' + error.toString();
    } finally {
      initialized = true;
      notifyListeners();
    }
  }

  Future<void> _configureOtmFromSettings() async {
    try {
      await _otmPublisher.configure(settings.otm);
    } catch (error) {
      appError = 'OTM configuration failed: ' + error.toString();
      notifyListeners();
    }
  }

  void _wireStreams() {
    _snapshotSubscription = _repository.snapshots.listen((value) {
      _lastPipelineActivity = DateTime.now();
      if (!replayStatus.active) {
        snapshot = _applyComfortableMaximum(value);
        _sessionManager.recordObuSnapshot(snapshot);
      }
      notifyListeners();
    });
    _diagnosticSubscription = _repository.diagnostics.listen((value) {
      diagnostics = value;
      _sessionManager.recordSystemEvent(
        'transport_diagnostics',
        <String, Object?>{
          'phase': value.phase.name,
          'receivedFrames': value.receivedFrames,
          'lostSequences': value.lostSequences,
          'outOfOrderSequences': value.outOfOrderSequences,
          'overflowDrops': value.overflowDrops,
          'sessionContinuity': value.sessionContinuity,
          's3FirmwareVersion': value.s3FirmwareVersion,
          'c5FirmwareVersion': value.c5FirmwareVersion,
          'clockSyncState': value.clockSyncState,
          'clockSyncQuality': value.clockSyncQuality,
        },
      );
      notifyListeners();
    });
    _recordSubscription = _repository.records.listen((value) {
      _lastPipelineActivity = DateTime.now();
      _sessionManager.recordData(value);
      _decodeCanRecord(value);
      unawaited(
        _otmPublisher.publish(value, replayActive: replayStatus.active),
      );
    });
    _phoneSensorSubscription = _phoneSensors.snapshots.listen((value) {
      _lastPipelineActivity = DateTime.now();
      if (!replayStatus.active) {
        phoneSensors = value;
        _advanceNavigation(value.location);
        _sessionManager.recordPhoneSensors(value);
      }
      notifyListeners();
    });
    _otmSubscription = _otmPublisher.statuses.listen((value) {
      otmStatus = value;
      notifyListeners();
    });
    _sessionSubscription = _sessionManager.sessions.listen((value) {
      rideSessions = value;
      notifyListeners();
    });
    _replayStatusSubscription = _sessionManager.replayStatuses.listen((value) {
      replayStatus = value;
      notifyListeners();
    });
    _replayFrameSubscription = _sessionManager.replayFrames.listen((frame) {
      if (frame.obuSnapshot != null) {
        snapshot = _applyComfortableMaximum(frame.obuSnapshot!);
      }
      if (frame.phoneSensors != null) {
        phoneSensors = frame.phoneSensors!;
        _advanceNavigation(phoneSensors.location);
      }
      final record = frame.dataRecord;
      if (record != null &&
          (record.payload.containsKey('messageSet') ||
              record.payload.containsKey('type'))) {
        try {
          snapshot = _replayCitsProcessor
              .processPayload(
                record.payload,
                snapshot,
                now: record.acquisitionTime,
              )
              .copyWith(freshness: DataFreshness.replay);
        } on FormatException {
          // Non-C-ITS records remain available to replay/export unchanged.
        }
      }
      notifyListeners();
    });
  }

  void _decodeCanRecord(ObuDataRecord record) {
    if (!record.channel.toLowerCase().contains('can')) return;
    final identifierValue =
        record.payload['identifier'] ??
        record.payload['canId'] ??
        record.payload['id'];
    final identifier = identifierValue is num
        ? identifierValue.round()
        : int.tryParse(identifierValue?.toString() ?? '');
    if (identifier == null) return;

    Uint8List? bytes;
    final encoded = record.payload['dataBase64']?.toString();
    if (encoded != null && encoded.isNotEmpty) {
      try {
        bytes = base64Decode(encoded);
      } catch (_) {
        bytes = null;
      }
    } else if (record.payload['data'] is List<Object?>) {
      bytes = Uint8List.fromList(
        (record.payload['data']! as List<Object?>)
            .whereType<num>()
            .map((value) => value.round().clamp(0, 255).toInt())
            .toList(growable: false),
      );
    }
    if (bytes == null) return;

    for (final signal in _dbcCatalog.decode(identifier, bytes)) {
      _sessionManager.recordData(
        ObuDataRecord(
          channel: 'can/decoded/' + signal.messageName,
          source: record.source,
          acquisitionTime: record.acquisitionTime,
          arrivalTime: DateTime.now(),
          sequence: record.sequence,
          origin: record.origin,
          provenance: RecordProvenance.derived,
          payload: <String, Object?>{
            'databaseHash': signal.databaseHash,
            'messageName': signal.messageName,
            'signalName': signal.signalName,
            'value': signal.value,
            'unit': signal.unit,
            'sourceChannel': record.channel,
          },
          rawBytes: null,
          isRawV2x: false,
        ),
      );
    }
  }

  Future<void> _initializeOptionalServices() async {
    try {
      await _dbcCatalog.initialize();
    } catch (error) {
      appError = 'DBC storage unavailable: ' + error.toString();
    }
    try {
      await _sessionManager.initialize();
      rideSessions = _sessionManager.currentSessions;
    } catch (error) {
      appError = 'Session storage unavailable: ' + error.toString();
    }
    backgroundCapability = await _backgroundService.capability();
  }

  ObuSnapshot _applyComfortableMaximum(ObuSnapshot value) {
    final speed = value.glosa.recommendedSpeedKmh;
    if (speed == null || speed <= settings.comfortableMaximumSpeedKmh) {
      return value;
    }
    return value.copyWith(
      glosa: GlosaRecommendation.unavailable(
        GlosaAvailability.noReachableGreen,
        detail: 'Required speed exceeds the comfortable maximum.',
      ),
    );
  }

  Future<void> searchPlaces(String query) async {
    navigation = navigation.copyWith(
      status: NavigationStatus.searching,
      clearError: true,
    );
    notifyListeners();
    try {
      final location = phoneSensors.location;
      final results = await _navigationService.search(
        query,
        near: location == null
            ? null
            : LatLng(location.latitude, location.longitude),
      );
      navigation = navigation.copyWith(
        status: NavigationStatus.idle,
        searchResults: results,
      );
    } catch (error) {
      navigation = navigation.copyWith(
        status: NavigationStatus.error,
        error: error.toString(),
      );
    }
    notifyListeners();
  }

  Future<void> startNavigation(PlaceSuggestion destination) async {
    final location = phoneSensors.location;
    if (location == null) {
      navigation = navigation.copyWith(
        status: NavigationStatus.error,
        error: 'A phone location fix is required before routing.',
      );
      notifyListeners();
      return;
    }
    navigation = navigation.copyWith(
      status: NavigationStatus.routing,
      clearError: true,
    );
    notifyListeners();
    try {
      final route = await _navigationService.bicycleRoute(
        origin: LatLng(location.latitude, location.longitude),
        destination: destination,
      );
      navigation = navigation.copyWith(
        status: NavigationStatus.navigating,
        route: route,
        currentStepIndex: 0,
        searchResults: const <PlaceSuggestion>[],
      );
      _advanceNavigation(location);
      _sessionManager.recordSystemEvent('route_started', <String, Object?>{
        'provider': _navigationService.providerId,
        'profile': _navigationService.profileId,
        'providerFrozen': _navigationService.providerFrozen,
        'destination': destination.name,
        'geometry': route.geometry
            .map((point) => <double>[point.latitude, point.longitude])
            .toList(growable: false),
        'maneuvers': route.steps
            .map(
              (step) => <String, Object?>{
                'instruction': step.instruction,
                'street': step.street,
                'distanceMeters': step.distanceMeters,
              },
            )
            .toList(growable: false),
      });
    } catch (error) {
      navigation = navigation.copyWith(
        status: NavigationStatus.error,
        error: error.toString(),
      );
    }
    notifyListeners();
  }

  void stopNavigation() {
    navigation = NavigationState.initial();
    _sessionManager.recordSystemEvent(
      'route_stopped',
      const <String, Object?>{},
    );
    notifyListeners();
  }

  void _advanceNavigation(PhoneLocationReading? location) {
    final route = navigation.route;
    if (location == null || route == null || route.steps.isEmpty) return;
    var index = navigation.currentStepIndex
        .clamp(0, route.steps.length - 1)
        .toInt();
    var step = route.steps[index];
    var distance = Geolocator.distanceBetween(
      location.latitude,
      location.longitude,
      step.location.latitude,
      step.location.longitude,
    );
    if (distance < 18 && index < route.steps.length - 1) {
      index++;
      step = route.steps[index];
      distance = Geolocator.distanceBetween(
        location.latitude,
        location.longitude,
        step.location.latitude,
        step.location.longitude,
      );
    }
    navigation = navigation.copyWith(
      currentStepIndex: index,
      distanceToNextStepMeters: distance,
    );
  }

  Future<ObuCommandResult> updateSettings(
    AppSettings next, {
    String? obuCommand,
    Map<String, Object?> commandArguments = const <String, Object?>{},
  }) async {
    if (obuCommand != null) {
      final result = await command(obuCommand, commandArguments);
      if (!result.success) return result;
    }
    final previous = settings;
    final previousOtm = previous.otm;
    settings = next;
    _repository.setComfortableMaximumSpeed(next.comfortableMaximumSpeedKmh);
    _replayCitsProcessor.setComfortableMaximumSpeed(
      next.comfortableMaximumSpeedKmh,
    );
    try {
      await _settingsRepository.save(next);
    } catch (error) {
      settings = previous;
      _repository.setComfortableMaximumSpeed(
        previous.comfortableMaximumSpeedKmh,
      );
      _replayCitsProcessor.setComfortableMaximumSpeed(
        previous.comfortableMaximumSpeedKmh,
      );
      notifyListeners();
      return ObuCommandResult(
        success: false,
        code: 'SETTINGS_SAVE_FAILED',
        message: error.toString(),
      );
    }
    if (previousOtm.enabled != next.otm.enabled ||
        previousOtm.host != next.otm.host ||
        previousOtm.port != next.otm.port ||
        previousOtm.nodeId != next.otm.nodeId) {
      try {
        await _otmPublisher.configure(next.otm);
      } catch (error) {
        appError = 'OTM configuration failed: ' + error.toString();
        notifyListeners();
        return ObuCommandResult(
          success: false,
          code: 'OTM_CONFIG_FAILED',
          message: 'Setting saved; uplink failed: ' + error.toString(),
          state: next.toJson(),
        );
      }
    }
    snapshot = _applyComfortableMaximum(snapshot);
    _sessionManager.recordSystemEvent('settings_changed', next.toJson());
    notifyListeners();
    return ObuCommandResult(
      success: true,
      code: 'APPLIED',
      message: 'Setting saved and active.',
      state: next.toJson(),
    );
  }

  Future<ObuCommandResult> configureSensor(
    SensorConfiguration configuration,
  ) async {
    final updated = settings.sensorConfigurations
        .map((item) => item.id == configuration.id ? configuration : item)
        .toList(growable: false);
    return updateSettings(
      settings.copyWith(sensorConfigurations: updated),
      obuCommand: configuration.id == 'phone_motion'
          ? null
          : 'configure_sensor',
      commandArguments: configuration.toJson(),
    );
  }

  Future<void> saveSensorPose(SensorPose pose) async {
    final poses = <SensorPose>[
      ...settings.sensorPoses.where((item) => item.sensorId != pose.sensorId),
      pose,
    ];
    await updateSettings(settings.copyWith(sensorPoses: poses));
  }

  Future<DbcDefinition?> importDbc() async {
    final definition = await _dbcCatalog.importFromPicker();
    notifyListeners();
    return definition;
  }

  Future<void> setDbcEnabled(String hash, bool enabled) async {
    await _dbcCatalog.setEnabled(hash, enabled);
    _sessionManager.recordSystemEvent('dbc_state_changed', <String, Object?>{
      'hash': hash,
      'enabled': enabled,
    });
    notifyListeners();
  }

  Future<void> removeDbc(String hash) async {
    await _dbcCatalog.remove(hash);
    _sessionManager.recordSystemEvent('dbc_removed', <String, Object?>{
      'hash': hash,
    });
    notifyListeners();
  }

  Future<void> startRideRecording() async {
    await _sessionManager.start(
      settings: settings,
      dbcDefinitions: dbcDefinitions,
      transport: diagnostics,
      routingProvider: _navigationService.providerId,
      routingProfile: _navigationService.profileId,
    );
    if (settings.backgroundRideMode) {
      final started = await _backgroundService.start();
      backgroundState = started
          ? 'active; ' + backgroundCapability
          : 'requested but unavailable';
    }
    notifyListeners();
  }

  Future<void> stopRideRecording() async {
    await _sessionManager.stop();
    await _backgroundService.stop();
    backgroundState = 'foreground';
    notifyListeners();
  }

  Future<void> loadReplay(RideSessionSummary session) {
    _replayCitsProcessor.reset();
    return _sessionManager.loadReplay(session);
  }

  Future<void> playReplay() => _sessionManager.playReplay();
  Future<void> pauseReplay() => _sessionManager.pauseReplay();
  Future<void> stopReplay() {
    _replayCitsProcessor.reset();
    return _sessionManager.stopReplay();
  }

  void setReplaySpeed(double speed) => _sessionManager.setReplaySpeed(speed);
  void seekReplay(Duration position) {
    _replayCitsProcessor.reset();
    _sessionManager.seekReplay(position);
  }

  Future<File> exportCsv(RideSessionSummary session) =>
      _sessionManager.exportCsv(session);
  Future<File> exportPcapng(RideSessionSummary session) =>
      _sessionManager.exportPcapng(session);

  Future<ObuCommandResult> command(
    String command, [
    Map<String, Object?> arguments = const <String, Object?>{},
  ]) {
    return _repository.sendCommand(command, arguments);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final now = DateTime.now();
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _backgroundedAt = now;
      backgroundState = isRecording ? 'background requested' : 'background';
      _sessionManager.recordSystemEvent('app_backgrounded', <String, Object?>{
        'recording': isRecording,
      });
    } else if (state == AppLifecycleState.resumed) {
      final backgroundedAt = _backgroundedAt;
      if (backgroundedAt != null) {
        final gap = now.difference(_lastPipelineActivity);
        if (isRecording && gap > const Duration(seconds: 20)) {
          lastDetectedSuspension = gap;
          _sessionManager.recordSystemEvent(
            'possible_os_suspension',
            <String, Object?>{'pipelineGapMilliseconds': gap.inMilliseconds},
          );
        }
      }
      _backgroundedAt = null;
      backgroundState = 'foreground';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _snapshotSubscription?.cancel();
    _diagnosticSubscription?.cancel();
    _recordSubscription?.cancel();
    _phoneSensorSubscription?.cancel();
    _otmSubscription?.cancel();
    _sessionSubscription?.cancel();
    _replayStatusSubscription?.cancel();
    _replayFrameSubscription?.cancel();
    unawaited(_repository.dispose());
    unawaited(_phoneSensors.dispose());
    unawaited(_otmPublisher.dispose());
    unawaited(_sessionManager.dispose());
    super.dispose();
  }
}

class ObuScope extends InheritedNotifier<ObuController> {
  const ObuScope({
    required ObuController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static ObuController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ObuScope>();
    assert(scope != null, 'No ObuScope found above this context.');
    return scope!.notifier!;
  }
}
