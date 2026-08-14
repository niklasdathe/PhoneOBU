import 'dart:async';

import 'package:bicycle_obu/app.dart';
import 'package:bicycle_obu/data/obu_repository.dart';
import 'package:bicycle_obu/data/navigation/navigation_service.dart';
import 'package:bicycle_obu/data/phone_sensors/demo_phone_sensors_repository.dart';
import 'package:bicycle_obu/data/settings_repository.dart';
import 'package:bicycle_obu/models/app_settings.dart';
import 'package:bicycle_obu/models/navigation_route.dart';
import 'package:bicycle_obu/models/data_record.dart';
import 'package:bicycle_obu/models/obu_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  testWidgets('ride screen exposes primary telemetry and navigation', (
    tester,
  ) async {
    final repository = _StaticRepository();
    await tester.pumpWidget(
      ObuBootstrap(
        repository: repository,
        phoneSensors: DemoPhoneSensorsRepository(),
        navigationService: _FakeNavigationService(),
        settingsRepository: _MemorySettingsRepository(),
      ),
    );
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Jungfernstieg'), findsOneWidget);
    expect(find.text('22'), findsOneWidget);
    expect(find.text('148 bpm'), findsOneWidget);
    expect(find.text('Road work'), findsOneWidget);
  });
}

class _MemorySettingsRepository implements SettingsRepository {
  AppSettings settings = AppSettings.defaults();

  @override
  Future<AppSettings> load() async => settings;

  @override
  Future<void> save(AppSettings settings) async {
    this.settings = settings;
  }

  @override
  Future<String?> readSecureCredential(String key) async => null;

  @override
  Future<void> saveSecureCredential(String key, String? value) async {}
}

class _FakeNavigationService implements NavigationService {
  @override
  String get providerId => 'test';

  @override
  String get profileId => 'bicycle';

  @override
  bool get providerFrozen => false;

  @override
  Future<NavigationRoute> bicycleRoute({
    required LatLng origin,
    required PlaceSuggestion destination,
  }) => throw UnimplementedError();

  @override
  Future<List<PlaceSuggestion>> search(String query, {LatLng? near}) async =>
      const <PlaceSuggestion>[];
}

class _StaticRepository implements ObuRepository {
  final _snapshots = StreamController<ObuSnapshot>.broadcast();
  final _diagnostics = StreamController<TransportDiagnostics>.broadcast();
  final _records = StreamController<ObuDataRecord>.broadcast();

  @override
  Stream<TransportDiagnostics> get diagnostics => _diagnostics.stream;

  @override
  Stream<ObuSnapshot> get snapshots => _snapshots.stream;

  @override
  Stream<ObuDataRecord> get records => _records.stream;

  @override
  void setComfortableMaximumSpeed(double speedKmh) {}

  @override
  Future<void> start() async {
    _snapshots.add(
      ObuSnapshot(
        receivedAt: DateTime.now(),
        freshness: DataFreshness.live,
        speedKmh: 22,
        glosa: GlosaRecommendation(
          availability: GlosaAvailability.available,
          recommendedSpeedKmh: 24,
          signalState: 'red',
          secondsToChange: 12,
          intersectionId: 7,
          intersectionName: 'Test intersection',
          signalGroup: 2,
          mapemTimestamp: DateTime.now(),
          spatemTimestamp: DateTime.now(),
          targetsLaterGreen: false,
          statusDetail: 'Targeting green',
        ),
        headingDegrees: 42,
        headingCardinal: 'NE',
        heartRateBpm: 148,
        cadenceRpm: 90,
        shiftRecommendation: ShiftRecommendation.none,
        v2xVehicleNearby: false,
        v2xVehicleDistanceMeters: null,
        collisionRisk: false,
        collisionTimeSeconds: null,
        collisionProvenance: null,
        collisionEventId: null,
        roadHazard: RoadHazard(
          eventId: 'test-roadwork',
          title: 'Road work',
          detail: 'Narrow lane',
          distanceMeters: 320,
          severity: HazardSeverity.advisory,
          provenance: WarningProvenance.standardizedDenm,
          sourceTimestamp: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(minutes: 1)),
        ),
        navigation: const NavigationInstruction(
          action: 'Turn right',
          street: 'Jungfernstieg',
          distanceMeters: 180,
          etaMinutes: 12,
        ),
        obuConnected: true,
        subsystems: const <SubsystemStatus>[],
      ),
    );
    _diagnostics.add(TransportDiagnostics.initial(transportName: 'Test'));
  }

  @override
  Future<ObuCommandResult> sendCommand(
    String command, [
    Map<String, Object?> arguments = const <String, Object?>{},
  ]) async {
    return const ObuCommandResult(success: true, code: 'OK', message: 'Done');
  }

  @override
  Future<void> dispose() async {
    await _snapshots.close();
    await _diagnostics.close();
    await _records.close();
  }
}
