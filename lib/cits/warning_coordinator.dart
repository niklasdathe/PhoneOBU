import 'cits_interpreter.dart';

class WarningDecision {
  const WarningDecision({
    required this.shouldNotify,
    required this.reason,
  });

  final bool shouldNotify;
  final String reason;
}

class WarningCoordinator {
  final Map<String, DateTime> _activeEvents = <String, DateTime>{};

  void reset() => _activeEvents.clear();

  WarningDecision evaluate(DenmEvent event, {DateTime? now}) {
    final evaluatedAt = now ?? DateTime.now();
    _activeEvents.removeWhere((_, expiry) => expiry.isBefore(evaluatedAt));
    if (event.expiresAt.isBefore(evaluatedAt)) {
      return const WarningDecision(
        shouldNotify: false,
        reason: 'expired',
      );
    }
    if (!event.clearlyRelevant) {
      return const WarningDecision(
        shouldNotify: false,
        reason: 'clearly_irrelevant',
      );
    }
    if (_activeEvents.containsKey(event.eventId)) {
      _activeEvents[event.eventId] = event.expiresAt;
      return const WarningDecision(
        shouldNotify: false,
        reason: 'duplicate_active_event',
      );
    }
    _activeEvents[event.eventId] = event.expiresAt;
    return const WarningDecision(
      shouldNotify: true,
      reason: 'new_relevant_event',
    );
  }
}
