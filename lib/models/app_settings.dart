enum UnitSystem { metric, imperial }

class SensorConfiguration {
  const SensorConfiguration({
    required this.id,
    required this.displayName,
    required this.enabled,
    required this.rateHz,
    required this.supportedRatesHz,
  });

  final String id;
  final String displayName;
  final bool enabled;
  final int rateHz;
  final List<int> supportedRatesHz;

  SensorConfiguration copyWith({bool? enabled, int? rateHz}) {
    return SensorConfiguration(
      id: id,
      displayName: displayName,
      enabled: enabled ?? this.enabled,
      rateHz: rateHz ?? this.rateHz,
      supportedRatesHz: supportedRatesHz,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'displayName': displayName,
    'enabled': enabled,
    'rateHz': rateHz,
    'supportedRatesHz': supportedRatesHz,
  };

  factory SensorConfiguration.fromJson(Map<String, Object?> json) {
    final parsedRates =
        (json['supportedRatesHz'] as List<Object?>? ?? <Object?>[1])
            .whereType<num>()
            .map((value) => value.round())
            .where((value) => value > 0)
            .toList(growable: false);
    final rates = parsedRates.isEmpty ? const <int>[1] : parsedRates;
    final requestedRate = (json['rateHz'] as num?)?.round();
    return SensorConfiguration(
      id: json['id']?.toString() ?? 'unknown',
      displayName: json['displayName']?.toString() ?? 'Unknown sensor',
      enabled: json['enabled'] != false,
      rateHz: requestedRate != null && rates.contains(requestedRate)
          ? requestedRate
          : rates.first,
      supportedRatesHz: rates,
    );
  }
}

class SensorPose {
  const SensorPose({
    required this.sensorId,
    required this.displayName,
    required this.xMeters,
    required this.yMeters,
    required this.zMeters,
    required this.rollDegrees,
    required this.pitchDegrees,
    required this.yawDegrees,
    required this.updatedAt,
  });

  final String sensorId;
  final String displayName;
  final double xMeters;
  final double yMeters;
  final double zMeters;
  final double rollDegrees;
  final double pitchDegrees;
  final double yawDegrees;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'sensorId': sensorId,
    'displayName': displayName,
    'positionMeters': <String, double>{
      'xForward': xMeters,
      'yLeft': yMeters,
      'zUp': zMeters,
    },
    'orientationDegrees': <String, double>{
      'roll': rollDegrees,
      'pitch': pitchDegrees,
      'yaw': yawDegrees,
    },
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'referenceFrame': 'rear_wheel_axle_x_forward_y_left_z_up',
  };

  factory SensorPose.fromJson(Map<String, Object?> json) {
    final position =
        (json['positionMeters'] as Map<Object?, Object?>? ??
                const <Object?, Object?>{})
            .cast<Object?, Object?>();
    final orientation =
        (json['orientationDegrees'] as Map<Object?, Object?>? ??
                const <Object?, Object?>{})
            .cast<Object?, Object?>();
    return SensorPose(
      sensorId: json['sensorId']?.toString() ?? 'unknown',
      displayName: json['displayName']?.toString() ?? 'Unknown sensor',
      xMeters: (position['xForward'] as num?)?.toDouble() ?? 0,
      yMeters: (position['yLeft'] as num?)?.toDouble() ?? 0,
      zMeters: (position['zUp'] as num?)?.toDouble() ?? 0,
      rollDegrees: (orientation['roll'] as num?)?.toDouble() ?? 0,
      pitchDegrees: (orientation['pitch'] as num?)?.toDouble() ?? 0,
      yawDegrees: (orientation['yaw'] as num?)?.toDouble() ?? 0,
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}

class OtmConfiguration {
  const OtmConfiguration({
    required this.enabled,
    required this.host,
    required this.port,
    required this.nodeId,
  });

  final bool enabled;
  final String host;
  final int port;
  final String nodeId;

  OtmConfiguration copyWith({
    bool? enabled,
    String? host,
    int? port,
    String? nodeId,
  }) {
    return OtmConfiguration(
      enabled: enabled ?? this.enabled,
      host: host ?? this.host,
      port: port ?? this.port,
      nodeId: nodeId ?? this.nodeId,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'enabled': enabled,
    'host': host,
    'port': port,
    'nodeId': nodeId,
  };

  factory OtmConfiguration.fromJson(Map<String, Object?> json) {
    final host = json['host']?.toString().trim() ?? '';
    final nodeId = json['nodeId']?.toString().trim().toLowerCase() ?? '';
    final validNodeId = RegExp(r'^[a-z0-9_-]{3,64}$').hasMatch(nodeId);
    return OtmConfiguration(
      enabled: json['enabled'] == true,
      host: host.isEmpty ? 'cits1.opentrafficmap.org' : host,
      port: ((json['port'] as num?)?.round() ?? 8883).clamp(1, 65535).toInt(),
      nodeId: validNodeId ? nodeId : 'bicycleobu01',
    );
  }
}

class AppSettings {
  const AppSettings({
    required this.autoConnect,
    required this.backgroundRideMode,
    required this.v2xProximityWarnings,
    required this.shiftRecommendations,
    required this.hapticWarnings,
    required this.highContrastMap,
    required this.unitSystem,
    required this.comfortableMaximumSpeedKmh,
    required this.sensorConfigurations,
    required this.sensorPoses,
    required this.otm,
  });

  factory AppSettings.defaults() => const AppSettings(
    autoConnect: true,
    backgroundRideMode: true,
    v2xProximityWarnings: true,
    shiftRecommendations: true,
    hapticWarnings: true,
    highContrastMap: false,
    unitSystem: UnitSystem.metric,
    comfortableMaximumSpeedKmh: 30,
    sensorConfigurations: <SensorConfiguration>[
      SensorConfiguration(
        id: 'phone_motion',
        displayName: 'Phone motion sensors',
        enabled: true,
        rateHz: 50,
        supportedRatesHz: <int>[10, 25, 50, 100],
      ),
      SensorConfiguration(
        id: 'obu_gnss',
        displayName: 'OBU GNSS',
        enabled: true,
        rateHz: 5,
        supportedRatesHz: <int>[1, 2, 5],
      ),
      SensorConfiguration(
        id: 'can_stream',
        displayName: 'Classical CAN forwarding',
        enabled: true,
        rateHz: 100,
        supportedRatesHz: <int>[10, 20, 50, 100],
      ),
    ],
    sensorPoses: <SensorPose>[],
    otm: OtmConfiguration(
      enabled: false,
      host: 'cits1.opentrafficmap.org',
      port: 8883,
      nodeId: 'bicycleobu01',
    ),
  );

  final bool autoConnect;
  final bool backgroundRideMode;
  final bool v2xProximityWarnings;
  final bool shiftRecommendations;
  final bool hapticWarnings;
  final bool highContrastMap;
  final UnitSystem unitSystem;
  final double comfortableMaximumSpeedKmh;
  final List<SensorConfiguration> sensorConfigurations;
  final List<SensorPose> sensorPoses;
  final OtmConfiguration otm;

  AppSettings copyWith({
    bool? autoConnect,
    bool? backgroundRideMode,
    bool? v2xProximityWarnings,
    bool? shiftRecommendations,
    bool? hapticWarnings,
    bool? highContrastMap,
    UnitSystem? unitSystem,
    double? comfortableMaximumSpeedKmh,
    List<SensorConfiguration>? sensorConfigurations,
    List<SensorPose>? sensorPoses,
    OtmConfiguration? otm,
  }) {
    return AppSettings(
      autoConnect: autoConnect ?? this.autoConnect,
      backgroundRideMode: backgroundRideMode ?? this.backgroundRideMode,
      v2xProximityWarnings: v2xProximityWarnings ?? this.v2xProximityWarnings,
      shiftRecommendations: shiftRecommendations ?? this.shiftRecommendations,
      hapticWarnings: hapticWarnings ?? this.hapticWarnings,
      highContrastMap: highContrastMap ?? this.highContrastMap,
      unitSystem: unitSystem ?? this.unitSystem,
      comfortableMaximumSpeedKmh:
          comfortableMaximumSpeedKmh ?? this.comfortableMaximumSpeedKmh,
      sensorConfigurations: sensorConfigurations ?? this.sensorConfigurations,
      sensorPoses: sensorPoses ?? this.sensorPoses,
      otm: otm ?? this.otm,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': 1,
    'autoConnect': autoConnect,
    'backgroundRideMode': backgroundRideMode,
    'v2xProximityWarnings': v2xProximityWarnings,
    'shiftRecommendations': shiftRecommendations,
    'hapticWarnings': hapticWarnings,
    'highContrastMap': highContrastMap,
    'unitSystem': unitSystem.name,
    'comfortableMaximumSpeedKmh': comfortableMaximumSpeedKmh,
    'sensorConfigurations': sensorConfigurations
        .map((value) => value.toJson())
        .toList(),
    'sensorPoses': sensorPoses.map((value) => value.toJson()).toList(),
    'otm': otm.toJson(),
  };

  factory AppSettings.fromJson(Map<String, Object?> json) {
    final defaults = AppSettings.defaults();
    final comfortableMaximum =
        (json['comfortableMaximumSpeedKmh'] as num?)?.toDouble() ??
        defaults.comfortableMaximumSpeedKmh;
    return defaults.copyWith(
      autoConnect: json['autoConnect'] as bool?,
      backgroundRideMode: json['backgroundRideMode'] as bool?,
      v2xProximityWarnings: json['v2xProximityWarnings'] as bool?,
      shiftRecommendations: json['shiftRecommendations'] as bool?,
      hapticWarnings: json['hapticWarnings'] as bool?,
      highContrastMap: json['highContrastMap'] as bool?,
      unitSystem: UnitSystem.values.firstWhere(
        (value) => value.name == json['unitSystem'],
        orElse: () => UnitSystem.metric,
      ),
      comfortableMaximumSpeedKmh: comfortableMaximum.clamp(10, 45).toDouble(),
      sensorConfigurations: (json['sensorConfigurations'] as List<Object?>?)
          ?.whereType<Map<Object?, Object?>>()
          .map(
            (value) => SensorConfiguration.fromJson(
              value.map((key, item) => MapEntry(key.toString(), item)),
            ),
          )
          .toList(growable: false),
      sensorPoses: (json['sensorPoses'] as List<Object?>?)
          ?.whereType<Map<Object?, Object?>>()
          .map(
            (value) => SensorPose.fromJson(
              value.map((key, item) => MapEntry(key.toString(), item)),
            ),
          )
          .toList(growable: false),
      otm: json['otm'] is Map<Object?, Object?>
          ? OtmConfiguration.fromJson(
              (json['otm']! as Map<Object?, Object?>).map(
                (key, value) => MapEntry(key.toString(), value),
              ),
            )
          : null,
    );
  }
}
