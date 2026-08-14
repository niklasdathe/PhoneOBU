import 'dart:async';
import 'dart:math' as math;

import '../../models/phone_sensor_snapshot.dart';
import 'phone_sensors_repository.dart';

class DemoPhoneSensorsRepository implements PhoneSensorsRepository {
  final _controller = StreamController<PhoneSensorSnapshot>.broadcast(
    sync: true,
  );
  Timer? _timer;
  double _time = 0;

  @override
  PhoneSensorMode get mode => PhoneSensorMode.simulated;

  @override
  Stream<PhoneSensorSnapshot> get snapshots => _controller.stream;

  @override
  Future<void> start() async {
    _emit();
    _timer ??= Timer.periodic(const Duration(milliseconds: 100), (_) {
      _time += 0.1;
      _emit();
    });
  }

  void _emit() {
    const startLat = 53.551086;
    const startLon = 9.993682;
    final progress = (_time % 180) / 180;
    final heading = 42 + math.sin(_time / 8) * 5;
    final timestamp = DateTime.now();
    _controller.add(
      PhoneSensorSnapshot(
        mode: mode,
        updatedAt: timestamp,
        accelerometer: Vector3Reading(
          math.sin(_time * 3) * 0.18,
          math.cos(_time * 2) * 0.12,
          9.81 + math.sin(_time * 7) * 0.08,
        ),
        accelerometerTimestamp: timestamp,
        userAccelerometer: Vector3Reading(
          math.sin(_time * 3) * 0.18,
          math.cos(_time * 2) * 0.12,
          math.sin(_time * 7) * 0.08,
        ),
        userAccelerometerTimestamp: timestamp,
        gyroscope: Vector3Reading(0.01, 0.02, math.sin(_time / 5) * 0.03),
        gyroscopeTimestamp: timestamp,
        magnetometer: const Vector3Reading(18.4, -7.2, 43.8),
        magnetometerTimestamp: timestamp,
        pressureHpa: 1013.2 + math.sin(_time / 30) * 0.4,
        barometerTimestamp: timestamp,
        location: PhoneLocationReading(
          latitude: startLat + progress * 0.010,
          longitude: startLon + progress * 0.014,
          altitudeMeters: 11.8,
          horizontalAccuracyMeters: 3.5,
          verticalAccuracyMeters: 5.2,
          speedMps: 6.1,
          speedAccuracyMps: 0.25,
          courseDegrees: heading,
          courseAccuracyDegrees: 2.5,
          timestamp: timestamp,
        ),
        compassHeadingDegrees: heading,
        orientation: DeviceOrientationReading(
          rollDegrees: math.sin(_time / 9) * 1.5,
          pitchDegrees: 4 + math.sin(_time / 7),
          yawDegrees: heading,
          source: 'simulated_fused_orientation',
          timestamp: timestamp,
        ),
        motionAvailability: SensorAvailability.available,
        magnetometerAvailability: SensorAvailability.available,
        barometerAvailability: SensorAvailability.available,
        locationAvailability: SensorAvailability.available,
        orientationAvailability: SensorAvailability.available,
        lastError: null,
      ),
    );
  }

  @override
  Future<void> dispose() async {
    _timer?.cancel();
    await _controller.close();
  }
}
