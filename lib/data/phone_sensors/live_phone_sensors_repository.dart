import 'dart:async';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../models/phone_sensor_snapshot.dart';
import 'phone_sensors_repository.dart';

class LivePhoneSensorsRepository implements PhoneSensorsRepository {
  final _controller = StreamController<PhoneSensorSnapshot>.broadcast(
    sync: true,
  );
  final _subscriptions = <StreamSubscription<dynamic>>[];
  PhoneSensorSnapshot _current = PhoneSensorSnapshot.initial(
    PhoneSensorMode.live,
  );

  @override
  PhoneSensorMode get mode => PhoneSensorMode.live;

  @override
  Stream<PhoneSensorSnapshot> get snapshots => _controller.stream;

  @override
  Future<void> start() async {
    _listenMotionSensors();
    await _listenLocation();
    _emit();
  }

  void _listenMotionSensors() {
    _subscriptions.add(
      accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval)
          .listen(
            (event) => _update(
              accelerometer: Vector3Reading(event.x, event.y, event.z),
              accelerometerTimestamp: event.timestamp,
              motionAvailability: SensorAvailability.available,
            ),
            onError: (Object error) => _sensorError(error, motion: true),
          ),
    );
    _subscriptions.add(
      userAccelerometerEventStream(samplingPeriod: SensorInterval.gameInterval)
          .listen(
            (event) => _update(
              userAccelerometer: Vector3Reading(event.x, event.y, event.z),
              userAccelerometerTimestamp: event.timestamp,
              motionAvailability: SensorAvailability.available,
            ),
            onError: (Object error) => _sensorError(error, motion: true),
          ),
    );
    _subscriptions.add(
      gyroscopeEventStream(samplingPeriod: SensorInterval.gameInterval).listen(
        (event) => _update(
          gyroscope: Vector3Reading(event.x, event.y, event.z),
          gyroscopeTimestamp: event.timestamp,
          motionAvailability: SensorAvailability.available,
        ),
        onError: (Object error) => _sensorError(error, motion: true),
      ),
    );
    _subscriptions.add(
      magnetometerEventStream(samplingPeriod: SensorInterval.uiInterval).listen(
        (event) {
          final heading =
              (math.atan2(event.y, event.x) * 180 / math.pi + 360) % 360;
          _update(
            magnetometer: Vector3Reading(event.x, event.y, event.z),
            magnetometerTimestamp: event.timestamp,
            compassHeadingDegrees: heading,
            orientation: _orientation(
              _current.accelerometer,
              heading,
              event.timestamp,
            ),
            magnetometerAvailability: SensorAvailability.available,
            orientationAvailability: SensorAvailability.available,
          );
        },
        onError: (Object error) => _sensorError(error, magnetometer: true),
      ),
    );
    _subscriptions.add(
      barometerEventStream(samplingPeriod: SensorInterval.normalInterval)
          .listen(
            (event) => _update(
              pressureHpa: event.pressure,
              barometerTimestamp: event.timestamp,
              barometerAvailability: SensorAvailability.available,
            ),
            onError: (Object error) => _sensorError(error, barometer: true),
          ),
    );
  }

  Future<void> _listenLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _update(
        locationAvailability: SensorAvailability.unavailable,
        lastError: 'Location services are disabled.',
      );
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _update(
        locationAvailability: SensorAvailability.permissionDenied,
        lastError: 'Location permission is denied.',
      );
      return;
    }
    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 1,
    );
    _subscriptions.add(
      Geolocator.getPositionStream(locationSettings: settings).listen(
        (position) => _update(
          location: PhoneLocationReading(
            latitude: position.latitude,
            longitude: position.longitude,
            altitudeMeters: position.altitude,
            horizontalAccuracyMeters: position.accuracy,
            verticalAccuracyMeters: position.altitudeAccuracy,
            speedMps: position.speed < 0 ? 0 : position.speed,
            speedAccuracyMps: position.speedAccuracy,
            courseDegrees: position.heading < 0 ? 0 : position.heading,
            courseAccuracyDegrees: position.headingAccuracy,
            timestamp: position.timestamp,
          ),
          locationAvailability: SensorAvailability.available,
          clearError: true,
        ),
        onError: (Object error) => _update(
          locationAvailability: SensorAvailability.error,
          lastError: 'Location: $error',
        ),
      ),
    );
  }

  void _sensorError(
    Object error, {
    bool motion = false,
    bool magnetometer = false,
    bool barometer = false,
  }) => _update(
    motionAvailability: motion ? SensorAvailability.error : null,
    magnetometerAvailability: magnetometer ? SensorAvailability.error : null,
    barometerAvailability: barometer ? SensorAvailability.error : null,
    lastError: 'Phone sensor: $error',
  );

  void _update({
    Vector3Reading? accelerometer,
    DateTime? accelerometerTimestamp,
    Vector3Reading? userAccelerometer,
    DateTime? userAccelerometerTimestamp,
    Vector3Reading? gyroscope,
    DateTime? gyroscopeTimestamp,
    Vector3Reading? magnetometer,
    DateTime? magnetometerTimestamp,
    double? pressureHpa,
    DateTime? barometerTimestamp,
    PhoneLocationReading? location,
    double? compassHeadingDegrees,
    DeviceOrientationReading? orientation,
    SensorAvailability? motionAvailability,
    SensorAvailability? magnetometerAvailability,
    SensorAvailability? barometerAvailability,
    SensorAvailability? locationAvailability,
    SensorAvailability? orientationAvailability,
    String? lastError,
    bool clearError = false,
  }) {
    _current = _current.copyWith(
      updatedAt: DateTime.now(),
      accelerometer: accelerometer,
      accelerometerTimestamp: accelerometerTimestamp,
      userAccelerometer: userAccelerometer,
      userAccelerometerTimestamp: userAccelerometerTimestamp,
      gyroscope: gyroscope,
      gyroscopeTimestamp: gyroscopeTimestamp,
      magnetometer: magnetometer,
      magnetometerTimestamp: magnetometerTimestamp,
      pressureHpa: pressureHpa,
      barometerTimestamp: barometerTimestamp,
      location: location,
      compassHeadingDegrees: compassHeadingDegrees,
      orientation: orientation,
      motionAvailability: motionAvailability,
      magnetometerAvailability: magnetometerAvailability,
      barometerAvailability: barometerAvailability,
      locationAvailability: locationAvailability,
      orientationAvailability: orientationAvailability,
      lastError: lastError,
      clearError: clearError,
    );
    _emit();
  }

  DeviceOrientationReading _orientation(
    Vector3Reading acceleration,
    double yawDegrees,
    DateTime timestamp,
  ) {
    final roll = math.atan2(acceleration.y, acceleration.z);
    final pitch = math.atan2(
      -acceleration.x,
      math.sqrt(
        acceleration.y * acceleration.y + acceleration.z * acceleration.z,
      ),
    );
    return DeviceOrientationReading(
      rollDegrees: roll * 180 / math.pi,
      pitchDegrees: pitch * 180 / math.pi,
      yawDegrees: yawDegrees,
      source: 'derived_accelerometer_magnetometer',
      timestamp: timestamp,
    );
  }

  void _emit() {
    if (!_controller.isClosed) _controller.add(_current);
  }

  @override
  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _controller.close();
  }
}
