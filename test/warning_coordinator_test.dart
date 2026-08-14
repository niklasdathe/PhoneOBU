import 'package:bicycle_obu/cits/cits_interpreter.dart';
import 'package:bicycle_obu/cits/warning_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deduplicates active DENM notifications without dropping the event', () {
    final now = DateTime.utc(2026, 8, 13, 12);
    final event = DenmEvent(
      eventId: 'event-1',
      originatingStationId: 7,
      cause: 'roadWorks',
      description: 'Narrow lane',
      distanceMeters: 100,
      critical: false,
      timeToCollisionSeconds: null,
      expiresAt: now.add(const Duration(minutes: 1)),
      clearlyRelevant: true,
      sourceTimestamp: now,
      rawFrameReference: 'raw-1',
    );
    final coordinator = WarningCoordinator();

    expect(coordinator.evaluate(event, now: now).shouldNotify, isTrue);
    expect(coordinator.evaluate(event, now: now).shouldNotify, isFalse);
  });
}
