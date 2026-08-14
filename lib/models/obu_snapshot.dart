enum DataFreshness { live, bufferedRecovered, stale, replay, unavailable }

enum ShiftRecommendation { none, shiftUp, shiftDown }

enum HazardSeverity { information, advisory, warning, critical }

enum WarningProvenance { standardizedDenm, inferredExperimental, simulation }

enum SubsystemHealth { online, degraded, offline, unavailable }

enum ConnectionPhase {
  demo,
  scanning,
  connecting,
  connected,
  disconnected,
  error,
}

enum GlosaAvailability {
  available,
  noMapem,
  noSpatem,
  stale,
  ambiguousAssociation,
  offRoute,
  noReachableGreen,
  invalidTiming,
}

class GlosaRecommendation {
  const GlosaRecommendation({
    required this.availability,
    required this.recommendedSpeedKmh,
    required this.signalState,
    required this.secondsToChange,
    required this.intersectionId,
    required this.intersectionName,
    required this.signalGroup,
    required this.mapemTimestamp,
    required this.spatemTimestamp,
    required this.targetsLaterGreen,
    required this.statusDetail,
    this.validUntil,
  });

  factory GlosaRecommendation.unavailable(
    GlosaAvailability availability, {
    String? detail,
  }) {
    return GlosaRecommendation(
      availability: availability,
      recommendedSpeedKmh: null,
      signalState: null,
      secondsToChange: null,
      intersectionId: null,
      intersectionName: null,
      signalGroup: null,
      mapemTimestamp: null,
      spatemTimestamp: null,
      targetsLaterGreen: false,
      statusDetail: detail ?? _defaultGlosaDetail(availability),
      validUntil: null,
    );
  }

  final GlosaAvailability availability;
  final double? recommendedSpeedKmh;
  final String? signalState;
  final double? secondsToChange;
  final int? intersectionId;
  final String? intersectionName;
  final int? signalGroup;
  final DateTime? mapemTimestamp;
  final DateTime? spatemTimestamp;
  final bool targetsLaterGreen;
  final String statusDetail;
  final DateTime? validUntil;

  bool get hasRecommendation =>
      availability == GlosaAvailability.available &&
      recommendedSpeedKmh != null;

  Map<String, Object?> toJson() => <String, Object?>{
    'availability': availability.name,
    'recommendedSpeedKmh': recommendedSpeedKmh,
    'signalState': signalState,
    'secondsToChange': secondsToChange,
    'intersectionId': intersectionId,
    'intersectionName': intersectionName,
    'signalGroup': signalGroup,
    'mapemTimestamp': mapemTimestamp?.toUtc().toIso8601String(),
    'spatemTimestamp': spatemTimestamp?.toUtc().toIso8601String(),
    'targetsLaterGreen': targetsLaterGreen,
    'statusDetail': statusDetail,
    'validUntil': validUntil?.toUtc().toIso8601String(),
  };

  factory GlosaRecommendation.fromJson(Map<String, Object?> json) {
    return GlosaRecommendation(
      availability: GlosaAvailability.values.firstWhere(
        (value) => value.name == json['availability'],
        orElse: () => GlosaAvailability.invalidTiming,
      ),
      recommendedSpeedKmh: (json['recommendedSpeedKmh'] as num?)?.toDouble(),
      signalState: json['signalState']?.toString(),
      secondsToChange: (json['secondsToChange'] as num?)?.toDouble(),
      intersectionId: (json['intersectionId'] as num?)?.round(),
      intersectionName: json['intersectionName']?.toString(),
      signalGroup: (json['signalGroup'] as num?)?.round(),
      mapemTimestamp: DateTime.tryParse(
        json['mapemTimestamp']?.toString() ?? '',
      ),
      spatemTimestamp: DateTime.tryParse(
        json['spatemTimestamp']?.toString() ?? '',
      ),
      targetsLaterGreen: json['targetsLaterGreen'] == true,
      statusDetail: json['statusDetail']?.toString() ?? 'Timing unavailable',
      validUntil: DateTime.tryParse(json['validUntil']?.toString() ?? ''),
    );
  }
}

class RoadHazard {
  const RoadHazard({
    required this.eventId,
    required this.title,
    required this.detail,
    required this.distanceMeters,
    required this.severity,
    required this.provenance,
    required this.sourceTimestamp,
    required this.expiresAt,
  });

  final String eventId;
  final String title;
  final String detail;
  final int distanceMeters;
  final HazardSeverity severity;
  final WarningProvenance provenance;
  final DateTime sourceTimestamp;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, Object?> toJson() => <String, Object?>{
    'eventId': eventId,
    'title': title,
    'detail': detail,
    'distanceMeters': distanceMeters,
    'severity': severity.name,
    'provenance': provenance.name,
    'sourceTimestamp': sourceTimestamp.toUtc().toIso8601String(),
    'expiresAt': expiresAt.toUtc().toIso8601String(),
  };

  factory RoadHazard.fromJson(Map<String, Object?> json) {
    return RoadHazard(
      eventId: json['eventId']?.toString() ?? 'unknown',
      title: json['title']?.toString() ?? 'Hazard',
      detail: json['detail']?.toString() ?? '',
      distanceMeters: (json['distanceMeters'] as num?)?.round() ?? 0,
      severity: HazardSeverity.values.firstWhere(
        (value) => value.name == json['severity'],
        orElse: () => HazardSeverity.advisory,
      ),
      provenance: WarningProvenance.values.firstWhere(
        (value) => value.name == json['provenance'],
        orElse: () => WarningProvenance.standardizedDenm,
      ),
      sourceTimestamp:
          DateTime.tryParse(json['sourceTimestamp']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      expiresAt:
          DateTime.tryParse(json['expiresAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}

class NavigationInstruction {
  const NavigationInstruction({
    required this.action,
    required this.street,
    required this.distanceMeters,
    required this.etaMinutes,
  });

  final String action;
  final String street;
  final int distanceMeters;
  final int etaMinutes;

  Map<String, Object?> toJson() => <String, Object?>{
    'action': action,
    'street': street,
    'distanceMeters': distanceMeters,
    'etaMinutes': etaMinutes,
  };

  factory NavigationInstruction.fromJson(Map<String, Object?> json) {
    return NavigationInstruction(
      action: json['action']?.toString() ?? 'Continue',
      street: json['street']?.toString() ?? 'Unknown street',
      distanceMeters: (json['distanceMeters'] as num?)?.round() ?? 0,
      etaMinutes: (json['etaMinutes'] as num?)?.round() ?? 0,
    );
  }
}

class SubsystemStatus {
  const SubsystemStatus({
    required this.name,
    required this.health,
    required this.detail,
  });

  final String name;
  final SubsystemHealth health;
  final String detail;

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'health': health.name,
    'detail': detail,
  };

  factory SubsystemStatus.fromJson(Map<String, Object?> json) {
    return SubsystemStatus(
      name: json['name']?.toString() ?? 'Unknown',
      health: SubsystemHealth.values.firstWhere(
        (value) => value.name == json['health'],
        orElse: () => SubsystemHealth.unavailable,
      ),
      detail: json['detail']?.toString() ?? 'No detail',
    );
  }
}

class ObuSnapshot {
  const ObuSnapshot({
    required this.receivedAt,
    required this.freshness,
    required this.speedKmh,
    required this.glosa,
    required this.headingDegrees,
    required this.headingCardinal,
    required this.heartRateBpm,
    required this.cadenceRpm,
    required this.shiftRecommendation,
    required this.v2xVehicleNearby,
    required this.v2xVehicleDistanceMeters,
    required this.collisionRisk,
    required this.collisionTimeSeconds,
    required this.collisionProvenance,
    required this.collisionEventId,
    required this.roadHazard,
    required this.navigation,
    required this.obuConnected,
    required this.subsystems,
    this.collisionExpiresAt,
  });

  factory ObuSnapshot.initial() {
    return ObuSnapshot(
      receivedAt: DateTime.fromMillisecondsSinceEpoch(0),
      freshness: DataFreshness.unavailable,
      speedKmh: 0,
      glosa: GlosaRecommendation.unavailable(GlosaAvailability.noMapem),
      headingDegrees: 0,
      headingCardinal: '—',
      heartRateBpm: 0,
      cadenceRpm: 0,
      shiftRecommendation: ShiftRecommendation.none,
      v2xVehicleNearby: false,
      v2xVehicleDistanceMeters: null,
      collisionRisk: false,
      collisionTimeSeconds: null,
      collisionProvenance: null,
      collisionEventId: null,
      roadHazard: null,
      navigation: null,
      obuConnected: false,
      subsystems: const <SubsystemStatus>[],
    );
  }

  final DateTime receivedAt;
  final DataFreshness freshness;
  final double speedKmh;
  final GlosaRecommendation glosa;
  final double headingDegrees;
  final String headingCardinal;
  final int heartRateBpm;
  final int cadenceRpm;
  final ShiftRecommendation shiftRecommendation;
  final bool v2xVehicleNearby;
  final int? v2xVehicleDistanceMeters;
  final bool collisionRisk;
  final double? collisionTimeSeconds;
  final WarningProvenance? collisionProvenance;
  final String? collisionEventId;
  final DateTime? collisionExpiresAt;
  final RoadHazard? roadHazard;
  final NavigationInstruction? navigation;
  final bool obuConnected;
  final List<SubsystemStatus> subsystems;

  ObuSnapshot copyWith({
    DateTime? receivedAt,
    DataFreshness? freshness,
    double? speedKmh,
    GlosaRecommendation? glosa,
    double? headingDegrees,
    String? headingCardinal,
    int? heartRateBpm,
    int? cadenceRpm,
    ShiftRecommendation? shiftRecommendation,
    bool? v2xVehicleNearby,
    int? v2xVehicleDistanceMeters,
    bool clearV2xDistance = false,
    bool? collisionRisk,
    double? collisionTimeSeconds,
    bool clearCollisionTime = false,
    WarningProvenance? collisionProvenance,
    bool clearCollisionProvenance = false,
    String? collisionEventId,
    bool clearCollisionEventId = false,
    DateTime? collisionExpiresAt,
    bool clearCollisionExpiry = false,
    RoadHazard? roadHazard,
    bool clearRoadHazard = false,
    NavigationInstruction? navigation,
    bool clearNavigation = false,
    bool? obuConnected,
    List<SubsystemStatus>? subsystems,
  }) {
    return ObuSnapshot(
      receivedAt: receivedAt ?? this.receivedAt,
      freshness: freshness ?? this.freshness,
      speedKmh: speedKmh ?? this.speedKmh,
      glosa: glosa ?? this.glosa,
      headingDegrees: headingDegrees ?? this.headingDegrees,
      headingCardinal: headingCardinal ?? this.headingCardinal,
      heartRateBpm: heartRateBpm ?? this.heartRateBpm,
      cadenceRpm: cadenceRpm ?? this.cadenceRpm,
      shiftRecommendation: shiftRecommendation ?? this.shiftRecommendation,
      v2xVehicleNearby: v2xVehicleNearby ?? this.v2xVehicleNearby,
      v2xVehicleDistanceMeters: clearV2xDistance
          ? null
          : v2xVehicleDistanceMeters ?? this.v2xVehicleDistanceMeters,
      collisionRisk: collisionRisk ?? this.collisionRisk,
      collisionTimeSeconds: clearCollisionTime
          ? null
          : collisionTimeSeconds ?? this.collisionTimeSeconds,
      collisionProvenance: clearCollisionProvenance
          ? null
          : collisionProvenance ?? this.collisionProvenance,
      collisionEventId: clearCollisionEventId
          ? null
          : collisionEventId ?? this.collisionEventId,
      collisionExpiresAt: clearCollisionExpiry
          ? null
          : collisionExpiresAt ?? this.collisionExpiresAt,
      roadHazard: clearRoadHazard ? null : roadHazard ?? this.roadHazard,
      navigation: clearNavigation ? null : navigation ?? this.navigation,
      obuConnected: obuConnected ?? this.obuConnected,
      subsystems: subsystems ?? this.subsystems,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'receivedAt': receivedAt.toUtc().toIso8601String(),
    'freshness': freshness.name,
    'speedKmh': speedKmh,
    'glosa': glosa.toJson(),
    'headingDegrees': headingDegrees,
    'headingCardinal': headingCardinal,
    'heartRateBpm': heartRateBpm,
    'cadenceRpm': cadenceRpm,
    'shiftRecommendation': shiftRecommendation.name,
    'v2xVehicleNearby': v2xVehicleNearby,
    'v2xVehicleDistanceMeters': v2xVehicleDistanceMeters,
    'collisionRisk': collisionRisk,
    'collisionTimeSeconds': collisionTimeSeconds,
    'collisionProvenance': collisionProvenance?.name,
    'collisionEventId': collisionEventId,
    'collisionExpiresAt': collisionExpiresAt?.toUtc().toIso8601String(),
    'roadHazard': roadHazard?.toJson(),
    'navigation': navigation?.toJson(),
    'obuConnected': obuConnected,
    'subsystems': subsystems.map((value) => value.toJson()).toList(),
  };

  factory ObuSnapshot.fromJson(Map<String, Object?> json) {
    Map<String, Object?>? objectMap(Object? value) {
      if (value is! Map<Object?, Object?>) return null;
      return value.map((key, item) => MapEntry(key.toString(), item));
    }

    final collisionProvenanceName = json['collisionProvenance']?.toString();
    return ObuSnapshot(
      receivedAt: DateTime.parse(json['receivedAt'].toString()),
      freshness: DataFreshness.values.firstWhere(
        (value) => value.name == json['freshness'],
        orElse: () => DataFreshness.replay,
      ),
      speedKmh: (json['speedKmh'] as num?)?.toDouble() ?? 0,
      glosa: GlosaRecommendation.fromJson(
        objectMap(json['glosa']) ?? const <String, Object?>{},
      ),
      headingDegrees: (json['headingDegrees'] as num?)?.toDouble() ?? 0,
      headingCardinal: json['headingCardinal']?.toString() ?? '—',
      heartRateBpm: (json['heartRateBpm'] as num?)?.round() ?? 0,
      cadenceRpm: (json['cadenceRpm'] as num?)?.round() ?? 0,
      shiftRecommendation: ShiftRecommendation.values.firstWhere(
        (value) => value.name == json['shiftRecommendation'],
        orElse: () => ShiftRecommendation.none,
      ),
      v2xVehicleNearby: json['v2xVehicleNearby'] == true,
      v2xVehicleDistanceMeters: (json['v2xVehicleDistanceMeters'] as num?)
          ?.round(),
      collisionRisk: json['collisionRisk'] == true,
      collisionTimeSeconds: (json['collisionTimeSeconds'] as num?)?.toDouble(),
      collisionProvenance: collisionProvenanceName == null
          ? null
          : WarningProvenance.values.firstWhere(
              (value) => value.name == collisionProvenanceName,
              orElse: () => WarningProvenance.inferredExperimental,
            ),
      collisionEventId: json['collisionEventId']?.toString(),
      collisionExpiresAt: DateTime.tryParse(
        json['collisionExpiresAt']?.toString() ?? '',
      ),
      roadHazard: objectMap(json['roadHazard']) == null
          ? null
          : RoadHazard.fromJson(objectMap(json['roadHazard'])!),
      navigation: objectMap(json['navigation']) == null
          ? null
          : NavigationInstruction.fromJson(objectMap(json['navigation'])!),
      obuConnected: json['obuConnected'] == true,
      subsystems: (json['subsystems'] as List<Object?>? ?? const <Object?>[])
          .map(objectMap)
          .whereType<Map<String, Object?>>()
          .map(SubsystemStatus.fromJson)
          .toList(growable: false),
    );
  }
}

class TransportDiagnostics {
  const TransportDiagnostics({
    required this.phase,
    required this.transportName,
    required this.protocolVersion,
    required this.negotiatedMtu,
    required this.receivedFrames,
    required this.transmittedFrames,
    required this.lostSequences,
    required this.lastMessageType,
    required this.lastError,
    this.recoveredRecords = 0,
    this.overflowDrops = 0,
    this.outOfOrderSequences = 0,
    this.authenticated = false,
    this.sessionContinuity = 'new',
    this.s3FirmwareVersion = 'unknown',
    this.c5FirmwareVersion = 'unknown',
    this.clockSyncState = 'unknown',
    this.clockSyncQuality = 'unknown',
  });

  factory TransportDiagnostics.initial({required String transportName}) {
    return TransportDiagnostics(
      phase: transportName == 'Demo'
          ? ConnectionPhase.demo
          : ConnectionPhase.disconnected,
      transportName: transportName,
      protocolVersion: 1,
      negotiatedMtu: null,
      receivedFrames: 0,
      transmittedFrames: 0,
      lostSequences: 0,
      lastMessageType: '—',
      lastError: null,
      authenticated: transportName == 'Demo',
    );
  }

  final ConnectionPhase phase;
  final String transportName;
  final int protocolVersion;
  final int? negotiatedMtu;
  final int receivedFrames;
  final int transmittedFrames;
  final int lostSequences;
  final int recoveredRecords;
  final int overflowDrops;
  final int outOfOrderSequences;
  final bool authenticated;
  final String sessionContinuity;
  final String s3FirmwareVersion;
  final String c5FirmwareVersion;
  final String clockSyncState;
  final String clockSyncQuality;
  final String lastMessageType;
  final String? lastError;

  TransportDiagnostics copyWith({
    ConnectionPhase? phase,
    String? transportName,
    int? protocolVersion,
    int? negotiatedMtu,
    bool clearMtu = false,
    int? receivedFrames,
    int? transmittedFrames,
    int? lostSequences,
    int? recoveredRecords,
    int? overflowDrops,
    int? outOfOrderSequences,
    bool? authenticated,
    String? sessionContinuity,
    String? s3FirmwareVersion,
    String? c5FirmwareVersion,
    String? clockSyncState,
    String? clockSyncQuality,
    String? lastMessageType,
    String? lastError,
    bool clearError = false,
  }) {
    return TransportDiagnostics(
      phase: phase ?? this.phase,
      transportName: transportName ?? this.transportName,
      protocolVersion: protocolVersion ?? this.protocolVersion,
      negotiatedMtu: clearMtu ? null : negotiatedMtu ?? this.negotiatedMtu,
      receivedFrames: receivedFrames ?? this.receivedFrames,
      transmittedFrames: transmittedFrames ?? this.transmittedFrames,
      lostSequences: lostSequences ?? this.lostSequences,
      recoveredRecords: recoveredRecords ?? this.recoveredRecords,
      overflowDrops: overflowDrops ?? this.overflowDrops,
      outOfOrderSequences: outOfOrderSequences ?? this.outOfOrderSequences,
      authenticated: authenticated ?? this.authenticated,
      sessionContinuity: sessionContinuity ?? this.sessionContinuity,
      s3FirmwareVersion: s3FirmwareVersion ?? this.s3FirmwareVersion,
      c5FirmwareVersion: c5FirmwareVersion ?? this.c5FirmwareVersion,
      clockSyncState: clockSyncState ?? this.clockSyncState,
      clockSyncQuality: clockSyncQuality ?? this.clockSyncQuality,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      lastError: clearError ? null : lastError ?? this.lastError,
    );
  }
}

String _defaultGlosaDetail(GlosaAvailability availability) {
  return switch (availability) {
    GlosaAvailability.available => 'Recommendation available',
    GlosaAvailability.noMapem => 'Waiting for intersection geometry',
    GlosaAvailability.noSpatem => 'Waiting for signal timing',
    GlosaAvailability.stale => 'Signal timing is stale',
    GlosaAvailability.ambiguousAssociation =>
      'Lane or signal-group association is ambiguous',
    GlosaAvailability.offRoute => 'No equipped signal on the planned route',
    GlosaAvailability.noReachableGreen =>
      'No green interval is reachable below the comfortable maximum',
    GlosaAvailability.invalidTiming => 'Signal timing is invalid',
  };
}
