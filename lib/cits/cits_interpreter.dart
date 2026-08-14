abstract class CitsMessage {
  const CitsMessage({
    required this.messageSet,
    required this.sourceTimestamp,
    required this.rawFrameReference,
  });

  final String messageSet;
  final DateTime sourceTimestamp;
  final String rawFrameReference;
}

class CamRoadUser extends CitsMessage {
  CamRoadUser({
    required this.stationId,
    required this.latitude,
    required this.longitude,
    required this.headingDegrees,
    required this.speedKmh,
    required this.distanceMeters,
    required super.sourceTimestamp,
    required super.rawFrameReference,
  }) : super(messageSet: 'CAM');

  final int stationId;
  final double latitude;
  final double longitude;
  final double headingDegrees;
  final double speedKmh;
  final double distanceMeters;
}

class VamRoadUser extends CitsMessage {
  VamRoadUser({
    required this.stationId,
    required this.latitude,
    required this.longitude,
    required this.headingDegrees,
    required this.speedKmh,
    required this.profile,
    required super.sourceTimestamp,
    required super.rawFrameReference,
  }) : super(messageSet: 'VAM');

  final int stationId;
  final double latitude;
  final double longitude;
  final double headingDegrees;
  final double speedKmh;
  final String profile;
}

class DenmEvent extends CitsMessage {
  DenmEvent({
    required this.eventId,
    required this.originatingStationId,
    required this.cause,
    required this.description,
    required this.distanceMeters,
    required this.critical,
    required this.timeToCollisionSeconds,
    required this.expiresAt,
    required this.clearlyRelevant,
    required super.sourceTimestamp,
    required super.rawFrameReference,
  }) : super(messageSet: 'DENM');

  final String eventId;
  final int originatingStationId;
  final String cause;
  final String description;
  final int distanceMeters;
  final bool critical;
  final double? timeToCollisionSeconds;
  final DateTime expiresAt;
  final bool clearlyRelevant;
}

class MapemIntersection extends CitsMessage {
  MapemIntersection({
    required this.intersectionId,
    required this.intersectionName,
    required this.revision,
    required this.laneCount,
    required this.approachLaneId,
    required this.signalGroup,
    required this.associationUnambiguous,
    required this.distanceMeters,
    required this.routeMatched,
    required super.sourceTimestamp,
    required super.rawFrameReference,
  }) : super(messageSet: 'MAPEM');

  final int intersectionId;
  final String intersectionName;
  final int revision;
  final int laneCount;
  final int? approachLaneId;
  final int? signalGroup;
  final bool associationUnambiguous;
  final double distanceMeters;
  final bool routeMatched;
}

class SignalGreenInterval {
  const SignalGreenInterval({
    required this.startsInSeconds,
    required this.endsInSeconds,
  });

  final double startsInSeconds;
  final double endsInSeconds;
}

class SpatemSignal extends CitsMessage {
  SpatemSignal({
    required this.intersectionId,
    required this.signalGroup,
    required this.state,
    required this.greenIntervals,
    required this.validUntil,
    required super.sourceTimestamp,
    required super.rawFrameReference,
  }) : super(messageSet: 'SPATEM');

  final int intersectionId;
  final int signalGroup;
  final String state;
  final List<SignalGreenInterval> greenIntervals;
  final DateTime validUntil;
}

class IvimInformation extends CitsMessage {
  IvimInformation({
    required this.informationCode,
    required this.text,
    required this.distanceMeters,
    required super.sourceTimestamp,
    required super.rawFrameReference,
  }) : super(messageSet: 'IVIM');

  final String informationCode;
  final String text;
  final int distanceMeters;
}

abstract final class CitsInterpreter {
  static CitsMessage interpret(Map<String, Object?> json) {
    final messageSet = (json['messageSet'] ?? json['type'])
        ?.toString()
        .toUpperCase();
    final timestamp =
        DateTime.tryParse(json['sourceTimestamp']?.toString() ?? '') ??
        DateTime.now();
    final rawReference =
        json['rawFrameReference']?.toString() ??
        'transport-message-' + (json['messageId']?.toString() ?? 'unknown');
    return switch (messageSet) {
      'CAM' => CamRoadUser(
        stationId: _int(json['stationId']),
        latitude: _double(json['latitude']),
        longitude: _double(json['longitude']),
        headingDegrees: _double(json['headingDeg']),
        speedKmh: _double(json['speedKmh']),
        distanceMeters: _double(json['distanceM']),
        sourceTimestamp: timestamp,
        rawFrameReference: rawReference,
      ),
      'VAM' || 'VRU' => VamRoadUser(
        stationId: _int(json['stationId']),
        latitude: _double(json['latitude']),
        longitude: _double(json['longitude']),
        headingDegrees: _double(json['headingDeg']),
        speedKmh: _double(json['speedKmh']),
        profile: json['profile']?.toString() ?? 'bicyclist',
        sourceTimestamp: timestamp,
        rawFrameReference: rawReference,
      ),
      'DENM' => DenmEvent(
        eventId:
            json['eventId']?.toString() ??
            'denm-' +
                _int(json['originatingStationId']).toString() +
                '-' +
                (json['sequenceNumber']?.toString() ?? '0'),
        originatingStationId: _int(json['originatingStationId']),
        cause: json['cause']?.toString() ?? 'unknown',
        description: json['description']?.toString() ?? 'Hazard reported',
        distanceMeters: _int(json['distanceM']),
        critical: json['critical'] == true,
        timeToCollisionSeconds: _nullableDouble(json['timeToCollisionS']),
        expiresAt:
            DateTime.tryParse(json['expiresAt']?.toString() ?? '') ??
            timestamp.add(const Duration(minutes: 2)),
        clearlyRelevant: json['clearlyRelevant'] != false,
        sourceTimestamp: timestamp,
        rawFrameReference: rawReference,
      ),
      'MAPEM' => MapemIntersection(
        intersectionId: _int(json['intersectionId']),
        intersectionName:
            json['intersectionName']?.toString() ?? 'Equipped intersection',
        revision: _int(json['revision']),
        laneCount: _int(json['laneCount']),
        approachLaneId: _nullableInt(json['approachLaneId']),
        signalGroup: _nullableInt(json['signalGroup']),
        associationUnambiguous: json['associationUnambiguous'] == true,
        distanceMeters: _double(json['distanceM']),
        routeMatched: json['routeMatched'] == true,
        sourceTimestamp: timestamp,
        rawFrameReference: rawReference,
      ),
      'SPATEM' => SpatemSignal(
        intersectionId: _int(json['intersectionId']),
        signalGroup: _int(json['signalGroup']),
        state: json['state']?.toString() ?? 'unknown',
        greenIntervals: _intervals(json),
        validUntil:
            DateTime.tryParse(json['validUntil']?.toString() ?? '') ??
            timestamp.add(const Duration(seconds: 15)),
        sourceTimestamp: timestamp,
        rawFrameReference: rawReference,
      ),
      'IVIM' => IvimInformation(
        informationCode: json['informationCode']?.toString() ?? 'unknown',
        text: json['text']?.toString() ?? 'Infrastructure information',
        distanceMeters: _int(json['distanceM']),
        sourceTimestamp: timestamp,
        rawFrameReference: rawReference,
      ),
      _ => throw FormatException(
        'Unsupported C-ITS message set: ' + messageSet.toString(),
      ),
    };
  }

  static List<SignalGreenInterval> _intervals(Map<String, Object?> json) {
    final raw = json['greenIntervals'];
    if (raw is List<Object?>) {
      return raw
          .whereType<Map<Object?, Object?>>()
          .map((item) {
            return SignalGreenInterval(
              startsInSeconds: _double(item['startsInSeconds']),
              endsInSeconds: _double(item['endsInSeconds']),
            );
          })
          .toList(growable: false);
    }
    final seconds = _nullableDouble(json['secondsToChange']);
    if (seconds == null) return const <SignalGreenInterval>[];
    final state = json['state']?.toString().toLowerCase() ?? '';
    if (state.contains('green') || state.contains('permissive')) {
      return <SignalGreenInterval>[
        SignalGreenInterval(startsInSeconds: 0, endsInSeconds: seconds),
      ];
    }
    return <SignalGreenInterval>[
      SignalGreenInterval(
        startsInSeconds: seconds,
        endsInSeconds: seconds + 20,
      ),
    ];
  }

  static int _int(Object? value) => value is num ? value.round() : 0;

  static int? _nullableInt(Object? value) =>
      value is num ? value.round() : null;

  static double _double(Object? value) => value is num ? value.toDouble() : 0;

  static double? _nullableDouble(Object? value) {
    return value is num ? value.toDouble() : null;
  }
}
