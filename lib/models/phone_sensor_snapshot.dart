enum PhoneSensorMode { live, simulated }

enum SensorAvailability { available, unavailable, permissionDenied, error }

class Vector3Reading {
  const Vector3Reading(this.x, this.y, this.z);

  const Vector3Reading.zero() : this(0, 0, 0);

  final double x;
  final double y;
  final double z;

  Map<String, double> toJson() => <String, double>{'x': x, 'y': y, 'z': z};

  factory Vector3Reading.fromJson(Map<String, Object?> json) {
    return Vector3Reading(
      (json['x'] as num?)?.toDouble() ?? 0,
      (json['y'] as num?)?.toDouble() ?? 0,
      (json['z'] as num?)?.toDouble() ?? 0,
    );
  }
}

class DeviceOrientationReading {
  const DeviceOrientationReading({
    required this.rollDegrees,
    required this.pitchDegrees,
    required this.yawDegrees,
    required this.source,
    required this.timestamp,
  });

  final double rollDegrees;
  final double pitchDegrees;
  final double yawDegrees;
  final String source;
  final DateTime timestamp;

  Map<String, Object?> toJson() => <String, Object?>{
        'rollDegrees': rollDegrees,
        'pitchDegrees': pitchDegrees,
        'yawDegrees': yawDegrees,
        'source': source,
        'timestamp': timestamp.toUtc().toIso8601String(),
      };

  factory DeviceOrientationReading.fromJson(Map<String, Object?> json) {
    return DeviceOrientationReading(
      rollDegrees: (json['rollDegrees'] as num?)?.toDouble() ?? 0,
      pitchDegrees: (json['pitchDegrees'] as num?)?.toDouble() ?? 0,
      yawDegrees: (json['yawDegrees'] as num?)?.toDouble() ?? 0,
      source: json['source']?.toString() ?? 'derived',
      timestamp: DateTime.parse(json['timestamp'].toString()),
    );
  }
}

class PhoneLocationReading {
  const PhoneLocationReading({
    required this.latitude,
    required this.longitude,
    required this.altitudeMeters,
    required this.horizontalAccuracyMeters,
    required this.verticalAccuracyMeters,
    required this.speedMps,
    required this.speedAccuracyMps,
    required this.courseDegrees,
    required this.courseAccuracyDegrees,
    required this.timestamp,
  });

  final double latitude;
  final double longitude;
  final double altitudeMeters;
  final double horizontalAccuracyMeters;
  final double verticalAccuracyMeters;
  final double speedMps;
  final double speedAccuracyMps;
  final double courseDegrees;
  final double courseAccuracyDegrees;
  final DateTime timestamp;

  Map<String, Object?> toJson() => <String, Object?>{
        'latitude': latitude,
        'longitude': longitude,
        'altitudeMeters': altitudeMeters,
        'horizontalAccuracyMeters': horizontalAccuracyMeters,
        'verticalAccuracyMeters': verticalAccuracyMeters,
        'speedMps': speedMps,
        'speedAccuracyMps': speedAccuracyMps,
        'courseDegrees': courseDegrees,
        'courseAccuracyDegrees': courseAccuracyDegrees,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'provenance': 'os_fused_location',
      };

  factory PhoneLocationReading.fromJson(Map<String, Object?> json) {
    return PhoneLocationReading(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      altitudeMeters: (json['altitudeMeters'] as num?)?.toDouble() ?? 0,
      horizontalAccuracyMeters:
          (json['horizontalAccuracyMeters'] as num?)?.toDouble() ?? 0,
      verticalAccuracyMeters:
          (json['verticalAccuracyMeters'] as num?)?.toDouble() ?? 0,
      speedMps: (json['speedMps'] as num?)?.toDouble() ?? 0,
      speedAccuracyMps:
          (json['speedAccuracyMps'] as num?)?.toDouble() ?? 0,
      courseDegrees: (json['courseDegrees'] as num?)?.toDouble() ?? 0,
      courseAccuracyDegrees:
          (json['courseAccuracyDegrees'] as num?)?.toDouble() ?? 0,
      timestamp: DateTime.parse(json['timestamp'].toString()),
    );
  }
}

class PhoneSensorSnapshot {
  const PhoneSensorSnapshot({
    required this.mode,
    required this.updatedAt,
    required this.accelerometer,
    required this.accelerometerTimestamp,
    required this.userAccelerometer,
    required this.userAccelerometerTimestamp,
    required this.gyroscope,
    required this.gyroscopeTimestamp,
    required this.magnetometer,
    required this.magnetometerTimestamp,
    required this.pressureHpa,
    required this.barometerTimestamp,
    required this.location,
    required this.compassHeadingDegrees,
    required this.orientation,
    required this.motionAvailability,
    required this.magnetometerAvailability,
    required this.barometerAvailability,
    required this.locationAvailability,
    required this.orientationAvailability,
    required this.lastError,
  });

  factory PhoneSensorSnapshot.initial(PhoneSensorMode mode) {
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    return PhoneSensorSnapshot(
      mode: mode,
      updatedAt: epoch,
      accelerometer: const Vector3Reading.zero(),
      accelerometerTimestamp: epoch,
      userAccelerometer: const Vector3Reading.zero(),
      userAccelerometerTimestamp: epoch,
      gyroscope: const Vector3Reading.zero(),
      gyroscopeTimestamp: epoch,
      magnetometer: const Vector3Reading.zero(),
      magnetometerTimestamp: epoch,
      pressureHpa: null,
      barometerTimestamp: null,
      location: null,
      compassHeadingDegrees: null,
      orientation: null,
      motionAvailability: SensorAvailability.unavailable,
      magnetometerAvailability: SensorAvailability.unavailable,
      barometerAvailability: SensorAvailability.unavailable,
      locationAvailability: SensorAvailability.unavailable,
      orientationAvailability: SensorAvailability.unavailable,
      lastError: null,
    );
  }

  final PhoneSensorMode mode;
  final DateTime updatedAt;
  final Vector3Reading accelerometer;
  final DateTime accelerometerTimestamp;
  final Vector3Reading userAccelerometer;
  final DateTime userAccelerometerTimestamp;
  final Vector3Reading gyroscope;
  final DateTime gyroscopeTimestamp;
  final Vector3Reading magnetometer;
  final DateTime magnetometerTimestamp;
  final double? pressureHpa;
  final DateTime? barometerTimestamp;
  final PhoneLocationReading? location;
  final double? compassHeadingDegrees;
  final DeviceOrientationReading? orientation;
  final SensorAvailability motionAvailability;
  final SensorAvailability magnetometerAvailability;
  final SensorAvailability barometerAvailability;
  final SensorAvailability locationAvailability;
  final SensorAvailability orientationAvailability;
  final String? lastError;

  PhoneSensorSnapshot copyWith({
    DateTime? updatedAt,
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
    return PhoneSensorSnapshot(
      mode: mode,
      updatedAt: updatedAt ?? this.updatedAt,
      accelerometer: accelerometer ?? this.accelerometer,
      accelerometerTimestamp:
          accelerometerTimestamp ?? this.accelerometerTimestamp,
      userAccelerometer: userAccelerometer ?? this.userAccelerometer,
      userAccelerometerTimestamp:
          userAccelerometerTimestamp ?? this.userAccelerometerTimestamp,
      gyroscope: gyroscope ?? this.gyroscope,
      gyroscopeTimestamp: gyroscopeTimestamp ?? this.gyroscopeTimestamp,
      magnetometer: magnetometer ?? this.magnetometer,
      magnetometerTimestamp:
          magnetometerTimestamp ?? this.magnetometerTimestamp,
      pressureHpa: pressureHpa ?? this.pressureHpa,
      barometerTimestamp: barometerTimestamp ?? this.barometerTimestamp,
      location: location ?? this.location,
      compassHeadingDegrees:
          compassHeadingDegrees ?? this.compassHeadingDegrees,
      orientation: orientation ?? this.orientation,
      motionAvailability: motionAvailability ?? this.motionAvailability,
      magnetometerAvailability:
          magnetometerAvailability ?? this.magnetometerAvailability,
      barometerAvailability:
          barometerAvailability ?? this.barometerAvailability,
      locationAvailability:
          locationAvailability ?? this.locationAvailability,
      orientationAvailability:
          orientationAvailability ?? this.orientationAvailability,
      lastError: clearError ? null : lastError ?? this.lastError,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'mode': mode.name,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'rawAccelerometer': accelerometer.toJson(),
        'rawAccelerometerTimestamp':
            accelerometerTimestamp.toUtc().toIso8601String(),
        'osFusedLinearAcceleration': userAccelerometer.toJson(),
        'osFusedLinearAccelerationTimestamp':
            userAccelerometerTimestamp.toUtc().toIso8601String(),
        'rawGyroscope': gyroscope.toJson(),
        'rawGyroscopeTimestamp': gyroscopeTimestamp.toUtc().toIso8601String(),
        'rawMagnetometer': magnetometer.toJson(),
        'rawMagnetometerTimestamp':
            magnetometerTimestamp.toUtc().toIso8601String(),
        'pressureHpa': pressureHpa,
        'barometerTimestamp': barometerTimestamp?.toUtc().toIso8601String(),
        'osFusedLocation': location?.toJson(),
        'derivedCompassHeadingDegrees': compassHeadingDegrees,
        'derivedOrientation': orientation?.toJson(),
        'availability': <String, String>{
          'motion': motionAvailability.name,
          'magnetometer': magnetometerAvailability.name,
          'barometer': barometerAvailability.name,
          'location': locationAvailability.name,
          'orientation': orientationAvailability.name,
        },
        'lastError': lastError,
      };

  factory PhoneSensorSnapshot.fromJson(Map<String, Object?> json) {
    Map<String, Object?> map(Object? value) {
      if (value is! Map<Object?, Object?>) return const <String, Object?>{};
      return value.map((key, item) => MapEntry(key.toString(), item));
    }

    final availability = map(json['availability']);
    SensorAvailability status(String key) {
      return SensorAvailability.values.firstWhere(
        (value) => value.name == availability[key],
        orElse: () => SensorAvailability.unavailable,
      );
    }

    final pressureTimestamp =
        DateTime.tryParse(json['barometerTimestamp']?.toString() ?? '');
    return PhoneSensorSnapshot(
      mode: PhoneSensorMode.values.firstWhere(
        (value) => value.name == json['mode'],
        orElse: () => PhoneSensorMode.simulated,
      ),
      updatedAt: DateTime.parse(json['updatedAt'].toString()),
      accelerometer: Vector3Reading.fromJson(map(json['rawAccelerometer'])),
      accelerometerTimestamp:
          DateTime.parse(json['rawAccelerometerTimestamp'].toString()),
      userAccelerometer:
          Vector3Reading.fromJson(map(json['osFusedLinearAcceleration'])),
      userAccelerometerTimestamp: DateTime.parse(
        json['osFusedLinearAccelerationTimestamp'].toString(),
      ),
      gyroscope: Vector3Reading.fromJson(map(json['rawGyroscope'])),
      gyroscopeTimestamp:
          DateTime.parse(json['rawGyroscopeTimestamp'].toString()),
      magnetometer: Vector3Reading.fromJson(map(json['rawMagnetometer'])),
      magnetometerTimestamp:
          DateTime.parse(json['rawMagnetometerTimestamp'].toString()),
      pressureHpa: (json['pressureHpa'] as num?)?.toDouble(),
      barometerTimestamp: pressureTimestamp,
      location: json['osFusedLocation'] == null
          ? null
          : PhoneLocationReading.fromJson(map(json['osFusedLocation'])),
      compassHeadingDegrees:
          (json['derivedCompassHeadingDegrees'] as num?)?.toDouble(),
      orientation: json['derivedOrientation'] == null
          ? null
          : DeviceOrientationReading.fromJson(
              map(json['derivedOrientation']),
            ),
      motionAvailability: status('motion'),
      magnetometerAvailability: status('magnetometer'),
      barometerAvailability: status('barometer'),
      locationAvailability: status('location'),
      orientationAvailability: status('orientation'),
      lastError: json['lastError']?.toString(),
    );
  }
}
