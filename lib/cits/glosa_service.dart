import 'dart:math' as math;

import '../models/obu_snapshot.dart';

class GreenInterval {
  const GreenInterval({
    required this.startsInSeconds,
    required this.endsInSeconds,
  });

  final double startsInSeconds;
  final double endsInSeconds;
}

class GlosaInput {
  const GlosaInput({
    required this.distanceMeters,
    required this.intersectionId,
    required this.intersectionName,
    required this.signalGroup,
    required this.signalState,
    required this.mapemTimestamp,
    required this.spatemTimestamp,
    required this.validUntil,
    required this.routeMatched,
    required this.associationUnambiguous,
    required this.greenIntervals,
  });

  final double distanceMeters;
  final int intersectionId;
  final String intersectionName;
  final int signalGroup;
  final String signalState;
  final DateTime mapemTimestamp;
  final DateTime spatemTimestamp;
  final DateTime validUntil;
  final bool routeMatched;
  final bool associationUnambiguous;
  final List<GreenInterval> greenIntervals;
}

class GlosaService {
  const GlosaService();

  static const mapemMaximumAge = Duration(minutes: 5);
  static const spatemMaximumAge = Duration(seconds: 30);

  GlosaRecommendation evaluate({
    required GlosaInput? input,
    required double comfortableMaximumSpeedKmh,
    DateTime? now,
  }) {
    if (input == null) {
      return GlosaRecommendation.unavailable(GlosaAvailability.noMapem);
    }
    final evaluatedAt = now ?? DateTime.now();
    if (!input.routeMatched) {
      return GlosaRecommendation.unavailable(GlosaAvailability.offRoute);
    }
    if (!input.associationUnambiguous) {
      return GlosaRecommendation.unavailable(
        GlosaAvailability.ambiguousAssociation,
      );
    }
    if (input.mapemTimestamp.isBefore(evaluatedAt.subtract(mapemMaximumAge)) ||
        input.mapemTimestamp.isAfter(
          evaluatedAt.add(const Duration(seconds: 1)),
        ) ||
        input.spatemTimestamp.isBefore(
          evaluatedAt.subtract(spatemMaximumAge),
        ) ||
        input.spatemTimestamp.isAfter(
          evaluatedAt.add(const Duration(seconds: 1)),
        ) ||
        input.validUntil.isBefore(evaluatedAt)) {
      return GlosaRecommendation.unavailable(GlosaAvailability.stale);
    }
    if (input.distanceMeters <= 0 ||
        comfortableMaximumSpeedKmh <= 0 ||
        input.greenIntervals.isEmpty) {
      return GlosaRecommendation.unavailable(
        input.greenIntervals.isEmpty
            ? GlosaAvailability.noSpatem
            : GlosaAvailability.invalidTiming,
      );
    }

    for (var index = 0; index < input.greenIntervals.length; index++) {
      final interval = input.greenIntervals[index];
      if (interval.endsInSeconds <= 0 ||
          interval.endsInSeconds <= interval.startsInSeconds) {
        continue;
      }
      final earliest = math.max(0, interval.startsInSeconds);
      final latest = interval.endsInSeconds;
      final minimumSpeedKmh = input.distanceMeters / latest * 3.6;
      if (minimumSpeedKmh > comfortableMaximumSpeedKmh) continue;

      final midpoint = (earliest + latest) / 2;
      final preferredArrival = midpoint <= 0 ? latest : midpoint;
      var recommendation = input.distanceMeters / preferredArrival * 3.6;
      recommendation = recommendation.clamp(
        minimumSpeedKmh,
        comfortableMaximumSpeedKmh,
      );
      final secondsToChange = earliest > 0 ? earliest : latest;
      return GlosaRecommendation(
        availability: GlosaAvailability.available,
        recommendedSpeedKmh: recommendation,
        signalState: input.signalState,
        secondsToChange: secondsToChange.toDouble(),
        intersectionId: input.intersectionId,
        intersectionName: input.intersectionName,
        signalGroup: input.signalGroup,
        mapemTimestamp: input.mapemTimestamp,
        spatemTimestamp: input.spatemTimestamp,
        targetsLaterGreen: index > 0 || earliest > 0,
        statusDetail: earliest > 0 ? 'Targeting later green' : 'Green now',
        validUntil: input.validUntil,
      );
    }

    return GlosaRecommendation.unavailable(GlosaAvailability.noReachableGreen);
  }
}
