import 'package:bicycle_obu/cits/glosa_service.dart';
import 'package:bicycle_obu/models/obu_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = GlosaService();
  final now = DateTime.utc(2026, 8, 13, 12);

  GlosaInput input(List<GreenInterval> intervals) => GlosaInput(
    distanceMeters: 120,
    intersectionId: 42,
    intersectionName: 'Test intersection',
    signalGroup: 3,
    signalState: 'red',
    mapemTimestamp: now.subtract(const Duration(seconds: 1)),
    spatemTimestamp: now,
    validUntil: now.add(const Duration(seconds: 60)),
    routeMatched: true,
    associationUnambiguous: true,
    greenIntervals: intervals,
  );

  test('selects a later reachable green without exceeding maximum speed', () {
    final result = service.evaluate(
      input: input(const <GreenInterval>[
        GreenInterval(startsInSeconds: 2, endsInSeconds: 8),
        GreenInterval(startsInSeconds: 25, endsInSeconds: 40),
      ]),
      comfortableMaximumSpeedKmh: 20,
      now: now,
    );

    expect(result.availability, GlosaAvailability.available);
    expect(result.targetsLaterGreen, isTrue);
    expect(result.recommendedSpeedKmh, lessThanOrEqualTo(20));
  });

  test('never invents a recommendation when timing is absent', () {
    final result = service.evaluate(
      input: input(const <GreenInterval>[]),
      comfortableMaximumSpeedKmh: 30,
      now: now,
    );

    expect(result.availability, GlosaAvailability.noSpatem);
    expect(result.recommendedSpeedKmh, isNull);
  });

  test('rejects ambiguous lane and signal association', () {
    final ambiguous = GlosaInput(
      distanceMeters: 100,
      intersectionId: 42,
      intersectionName: 'Test',
      signalGroup: 3,
      signalState: 'red',
      mapemTimestamp: now,
      spatemTimestamp: now,
      validUntil: now.add(const Duration(seconds: 30)),
      routeMatched: true,
      associationUnambiguous: false,
      greenIntervals: const <GreenInterval>[
        GreenInterval(startsInSeconds: 10, endsInSeconds: 20),
      ],
    );
    final result = service.evaluate(
      input: ambiguous,
      comfortableMaximumSpeedKmh: 30,
      now: now,
    );

    expect(result.availability, GlosaAvailability.ambiguousAssociation);
    expect(result.recommendedSpeedKmh, isNull);
  });

  test('rejects stale MAPEM even when SPATEM validity claims future time', () {
    final stale = GlosaInput(
      distanceMeters: 100,
      intersectionId: 42,
      intersectionName: 'Test',
      signalGroup: 3,
      signalState: 'red',
      mapemTimestamp: now.subtract(const Duration(minutes: 6)),
      spatemTimestamp: now,
      validUntil: now.add(const Duration(minutes: 1)),
      routeMatched: true,
      associationUnambiguous: true,
      greenIntervals: const <GreenInterval>[
        GreenInterval(startsInSeconds: 10, endsInSeconds: 20),
      ],
    );
    final result = service.evaluate(
      input: stale,
      comfortableMaximumSpeedKmh: 30,
      now: now,
    );

    expect(result.availability, GlosaAvailability.stale);
    expect(result.recommendedSpeedKmh, isNull);
  });
}
