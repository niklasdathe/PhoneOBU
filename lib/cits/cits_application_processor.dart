import '../models/obu_snapshot.dart';
import 'cits_interpreter.dart';
import 'glosa_service.dart';
import 'warning_coordinator.dart';

class CitsApplicationProcessor {
  CitsApplicationProcessor({double comfortableMaximumSpeedKmh = 30})
      : _comfortableMaximumSpeedKmh = comfortableMaximumSpeedKmh;

  final _warningCoordinator = WarningCoordinator();
  final _glosaService = const GlosaService();
  final _mapemByIntersection = <int, MapemIntersection>{};
  double _comfortableMaximumSpeedKmh;

  void setComfortableMaximumSpeed(double speedKmh) {
    _comfortableMaximumSpeedKmh = speedKmh.clamp(1, 80).toDouble();
  }

  void reset() {
    _mapemByIntersection.clear();
    _warningCoordinator.reset();
  }

  ObuSnapshot processPayload(
    Map<String, Object?> payload,
    ObuSnapshot snapshot, {
    DateTime? now,
  }) {
    return processMessage(CitsInterpreter.interpret(payload), snapshot, now: now);
  }

  ObuSnapshot processMessage(
    CitsMessage message,
    ObuSnapshot snapshot, {
    DateTime? now,
  }) {
    final receivedAt = now ?? DateTime.now();
    final previousCollisionExpiry = snapshot.collisionExpiresAt;
    if (snapshot.collisionRisk &&
        previousCollisionExpiry != null &&
        receivedAt.isAfter(previousCollisionExpiry)) {
      snapshot = snapshot.copyWith(
        collisionRisk: false,
        clearCollisionTime: true,
        clearCollisionProvenance: true,
        clearCollisionEventId: true,
        clearCollisionExpiry: true,
      );
    }
    final previousHazard = snapshot.roadHazard;
    if (previousHazard != null &&
        receivedAt.isAfter(previousHazard.expiresAt)) {
      snapshot = snapshot.copyWith(clearRoadHazard: true);
    }
    if (message is CamRoadUser) {
      return snapshot.copyWith(
        receivedAt: receivedAt,
        v2xVehicleNearby: true,
        v2xVehicleDistanceMeters: message.distanceMeters.round(),
      );
    }
    if (message is VamRoadUser) {
      return snapshot.copyWith(
        receivedAt: receivedAt,
        v2xVehicleNearby: true,
      );
    }
    if (message is DenmEvent) {
      final decision = _warningCoordinator.evaluate(message, now: receivedAt);
      if (!decision.shouldNotify) {
        if (decision.reason == 'duplicate_active_event') {
          if (snapshot.collisionEventId == message.eventId) {
            return snapshot.copyWith(
              receivedAt: receivedAt,
              collisionTimeSeconds: message.timeToCollisionSeconds,
              collisionExpiresAt: message.expiresAt,
            );
          }
          if (snapshot.roadHazard?.eventId == message.eventId) {
            return snapshot.copyWith(
              receivedAt: receivedAt,
              roadHazard: RoadHazard(
                eventId: message.eventId,
                title: message.cause,
                detail: message.description,
                distanceMeters: message.distanceMeters,
                severity: message.critical
                    ? HazardSeverity.warning
                    : HazardSeverity.advisory,
                provenance: WarningProvenance.standardizedDenm,
                sourceTimestamp: message.sourceTimestamp,
                expiresAt: message.expiresAt,
              ),
            );
          }
        }
        return snapshot;
      }
      final collision = message.cause.toLowerCase().contains('collision');
      return snapshot.copyWith(
        receivedAt: receivedAt,
        collisionRisk: collision && message.critical,
        collisionTimeSeconds: message.timeToCollisionSeconds,
        collisionProvenance:
            collision ? WarningProvenance.standardizedDenm : null,
        clearCollisionProvenance: !collision,
        collisionEventId: collision ? message.eventId : null,
        clearCollisionEventId: !collision,
        collisionExpiresAt: collision ? message.expiresAt : null,
        clearCollisionExpiry: !collision,
        roadHazard: collision
            ? null
            : RoadHazard(
                eventId: message.eventId,
                title: message.cause,
                detail: message.description,
                distanceMeters: message.distanceMeters,
                severity: message.critical
                    ? HazardSeverity.warning
                    : HazardSeverity.advisory,
                provenance: WarningProvenance.standardizedDenm,
                sourceTimestamp: message.sourceTimestamp,
                expiresAt: message.expiresAt,
              ),
        clearRoadHazard: collision,
      );
    }
    if (message is MapemIntersection) {
      _mapemByIntersection[message.intersectionId] = message;
      return snapshot.copyWith(receivedAt: receivedAt);
    }
    if (message is SpatemSignal) {
      final mapem = _mapemByIntersection[message.intersectionId];
      final recommendation = mapem == null
          ? GlosaRecommendation.unavailable(GlosaAvailability.noMapem)
          : _glosaService.evaluate(
              input: GlosaInput(
                distanceMeters: mapem.distanceMeters,
                intersectionId: mapem.intersectionId,
                intersectionName: mapem.intersectionName,
                signalGroup: message.signalGroup,
                signalState: message.state,
                mapemTimestamp: mapem.sourceTimestamp,
                spatemTimestamp: message.sourceTimestamp,
                validUntil: message.validUntil,
                routeMatched: mapem.routeMatched,
                associationUnambiguous: mapem.associationUnambiguous &&
                    mapem.signalGroup == message.signalGroup,
                greenIntervals: message.greenIntervals
                    .map(
                      (value) => GreenInterval(
                        startsInSeconds: value.startsInSeconds,
                        endsInSeconds: value.endsInSeconds,
                      ),
                    )
                    .toList(growable: false),
              ),
              comfortableMaximumSpeedKmh: _comfortableMaximumSpeedKmh,
              now: receivedAt,
            );
      return snapshot.copyWith(
        receivedAt: receivedAt,
        glosa: recommendation,
      );
    }
    if (message is IvimInformation) {
      return snapshot.copyWith(
        receivedAt: receivedAt,
        roadHazard: RoadHazard(
          eventId: 'ivim-' + message.rawFrameReference,
          title: message.informationCode,
          detail: message.text,
          distanceMeters: message.distanceMeters,
          severity: HazardSeverity.information,
          provenance: WarningProvenance.standardizedDenm,
          sourceTimestamp: message.sourceTimestamp,
          expiresAt: message.sourceTimestamp.add(const Duration(minutes: 2)),
        ),
      );
    }
    return snapshot;
  }
}
