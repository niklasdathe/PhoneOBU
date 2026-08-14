import 'package:bicycle_obu/cits/cits_application_processor.dart';
import 'package:bicycle_obu/models/obu_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalized MAPEM/SPATEM uses the shared live/replay GLOSA path', () {
    final now = DateTime.utc(2026, 8, 13, 12);
    final processor = CitsApplicationProcessor(comfortableMaximumSpeedKmh: 20);
    var snapshot = ObuSnapshot.initial();
    snapshot = processor.processPayload(
      <String, Object?>{
        'messageSet': 'MAPEM',
        'intersectionId': 77,
        'intersectionName': 'Test crossing',
        'revision': 1,
        'laneCount': 4,
        'approachLaneId': 2,
        'signalGroup': 8,
        'associationUnambiguous': true,
        'distanceM': 120,
        'routeMatched': true,
        'sourceTimestamp': now.toIso8601String(),
      },
      snapshot,
      now: now,
    );
    snapshot = processor.processPayload(
      <String, Object?>{
        'messageSet': 'SPATEM',
        'intersectionId': 77,
        'signalGroup': 8,
        'state': 'red',
        'sourceTimestamp': now.toIso8601String(),
        'validUntil': now.add(const Duration(minutes: 1)).toIso8601String(),
        'greenIntervals': const <Map<String, double>>[
          <String, double>{'startsInSeconds': 2, 'endsInSeconds': 8},
          <String, double>{'startsInSeconds': 25, 'endsInSeconds': 40},
        ],
      },
      snapshot,
      now: now,
    );

    expect(snapshot.glosa.hasRecommendation, isTrue);
    expect(snapshot.glosa.targetsLaterGreen, isTrue);
    expect(snapshot.glosa.recommendedSpeedKmh, lessThanOrEqualTo(20));
  });
}
