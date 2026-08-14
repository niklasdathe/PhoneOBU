import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/obu_snapshot.dart';
import '../models/app_settings.dart';
import '../models/navigation_route.dart';
import '../models/phone_sensor_snapshot.dart';
import '../state/obu_controller.dart';
import '../theme/obu_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/monochrome_map.dart';
import '../widgets/target_speed_gauge.dart';

class RideScreen extends StatelessWidget {
  const RideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ObuScope.of(context);
    final snapshot = controller.snapshot;
    final phoneLocation = controller.phoneSensors.location;
    final displayedSpeed = snapshot.speedKmh > 0
        ? snapshot.speedKmh
        : (phoneLocation?.speedMps ?? 0) * 3.6;
    return Scaffold(
      drawer: const AppDrawer(),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          MonochromeMap(
            phoneSensors: controller.phoneSensors,
            navigation: controller.navigation,
            onDestinationSelected: controller.startNavigation,
            highContrast: controller.settings.highContrastMap,
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color(0x66F7F7F4),
                  Color(0x00F7F7F4),
                  Color(0x22F7F7F4),
                ],
                stops: <double>[0, 0.42, 1],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxHeight < 720;
                return Stack(
                  children: <Widget>[
                    Positioned(
                      left: 16,
                      right: 16,
                      top: 10,
                      child: _TopBar(
                        snapshot: snapshot,
                        controller: controller,
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: compact ? 155 : 188,
                      child: Center(
                        child: TargetSpeedGauge(
                          speedKmh: displayedSpeed,
                          glosa: snapshot.glosa,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: compact ? 132 : 164,
                      child: _MetricsRow(
                        snapshot: snapshot,
                        phoneSensors: controller.phoneSensors,
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: compact ? 66 : 92,
                      child: _AttentionStrip(
                        snapshot: snapshot,
                        settings: controller.settings,
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 12,
                      child: _RideFooter(controller: controller),
                    ),
                  ],
                );
              },
            ),
          ),
          if (snapshot.collisionRisk &&
              (snapshot.freshness == DataFreshness.replay ||
                  snapshot.collisionExpiresAt == null ||
                  DateTime.now().isBefore(snapshot.collisionExpiresAt!)))
            _CollisionOverlay(
              timeToCollision: snapshot.collisionTimeSeconds,
              provenance: snapshot.collisionProvenance,
              eventId: snapshot.collisionEventId,
              hapticEnabled: controller.settings.hapticWarnings,
              onDismiss: () => controller.command('clear_collision'),
            ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.snapshot, required this.controller});

  final ObuSnapshot snapshot;
  final ObuController controller;

  @override
  Widget build(BuildContext context) {
    final routeNavigation = controller.navigation;
    final routeStep = routeNavigation.currentStep;
    final navigation = routeStep == null
        ? snapshot.navigation
        : NavigationInstruction(
            action: routeStep.instruction,
            street: routeStep.street,
            distanceMeters:
                (routeNavigation.distanceToNextStepMeters ??
                        routeStep.distanceMeters)
                    .round(),
            etaMinutes: ((routeNavigation.route?.durationSeconds ?? 0) / 60)
                .ceil(),
          );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Builder(
          builder: (context) => IconButton(
            tooltip: 'Open menu',
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const Icon(Icons.menu_rounded),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _showDestinationSearch(context, controller),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.turn_right_rounded, size: 34),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            navigation == null
                                ? 'Choose a destination'
                                : '${navigation.distanceMeters} m · ${navigation.action}',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            navigation?.street ?? 'Navigation is idle',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: ObuColors.muted),
                          ),
                        ],
                      ),
                    ),
                    if (navigation != null)
                      Text(
                        '${navigation.etaMinutes} min',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _LiveBadge(snapshot: snapshot),
      ],
    );
  }

  Future<void> _showDestinationSearch(
    BuildContext context,
    ObuController controller,
  ) async {
    final textController = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final state = controller.navigation;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              18,
              16,
              16 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('Navigate', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                SearchBar(
                  controller: textController,
                  hintText: 'Search address or place',
                  leading: const Icon(Icons.search_rounded),
                  trailing: <Widget>[
                    IconButton(
                      tooltip: 'Search',
                      onPressed: () =>
                          controller.searchPlaces(textController.text),
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
                  ],
                  onSubmitted: controller.searchPlaces,
                ),
                if (state.status == NavigationStatus.searching ||
                    state.status == NavigationStatus.routing)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: LinearProgressIndicator(),
                  ),
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      state.error!,
                      style: const TextStyle(color: ObuColors.red),
                    ),
                  ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: state.searchResults.length,
                    itemBuilder: (context, index) {
                      final place = state.searchResults[index];
                      return ListTile(
                        leading: const Icon(Icons.location_on_outlined),
                        title: Text(place.name, maxLines: 2),
                        onTap: () async {
                          await controller.startNavigation(place);
                          if (sheetContext.mounted &&
                              controller.navigation.status ==
                                  NavigationStatus.navigating) {
                            Navigator.of(sheetContext).pop();
                          }
                        },
                      );
                    },
                  ),
                ),
                if (controller.navigation.route != null)
                  TextButton.icon(
                    onPressed: () {
                      controller.stopNavigation();
                      Navigator.of(sheetContext).pop();
                    },
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('Stop navigation'),
                  ),
              ],
            ),
          );
        },
      ),
    );
    textController.dispose();
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.snapshot});

  final ObuSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final live =
        snapshot.freshness == DataFreshness.live && snapshot.obuConnected;
    final recovered = snapshot.freshness == DataFreshness.bufferedRecovered;
    final replay = snapshot.freshness == DataFreshness.replay;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xF2FFFFFF),
        shape: BoxShape.circle,
        border: Border.all(color: ObuColors.line),
      ),
      child: Tooltip(
        message: live
            ? 'Live OBU data'
            : recovered
            ? 'Buffered data recovered after interruption'
            : replay
            ? 'Recorded session replay'
            : 'Data is stale or unavailable',
        child: Icon(
          live
              ? Icons.bluetooth_connected_rounded
              : replay
              ? Icons.replay_rounded
              : recovered
              ? Icons.restore_rounded
              : Icons.bluetooth_disabled_rounded,
          color: live
              ? ObuColors.green
              : recovered
              ? ObuColors.amber
              : replay
              ? ObuColors.blue
              : ObuColors.red,
        ),
      ),
    );
  }
}

class _MetricsRow extends StatelessWidget {
  const _MetricsRow({required this.snapshot, required this.phoneSensors});

  final ObuSnapshot snapshot;
  final PhoneSensorSnapshot phoneSensors;

  @override
  Widget build(BuildContext context) {
    final phoneHeading =
        phoneSensors.location?.courseDegrees ??
        phoneSensors.compassHeadingDegrees;
    final heading = snapshot.headingCardinal == '—' && phoneHeading != null
        ? '${phoneHeading.round()}° phone'
        : '${snapshot.headingDegrees.round()}° ${snapshot.headingCardinal}';
    return Row(
      children: <Widget>[
        Expanded(
          child: _MetricCard(
            icon: Icons.explore_outlined,
            label: 'Heading',
            value: heading,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(
            icon: Icons.favorite_rounded,
            iconColor: ObuColors.red,
            label: 'Heart rate',
            value: snapshot.heartRateBpm == 0
                ? '—'
                : '${snapshot.heartRateBpm} bpm',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(
            icon: Icons.loop_rounded,
            label: 'Cadence',
            value: snapshot.cadenceRpm == 0
                ? '—'
                : '${snapshot.cadenceRpm} rpm',
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor = ObuColors.ink,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xF2FFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ObuColors.line),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: ObuColors.muted),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AttentionStrip extends StatelessWidget {
  const _AttentionStrip({required this.snapshot, required this.settings});

  final ObuSnapshot snapshot;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    if (settings.shiftRecommendations &&
        snapshot.shiftRecommendation != ShiftRecommendation.none) {
      items.add(
        _AttentionChip(
          icon: snapshot.shiftRecommendation == ShiftRecommendation.shiftUp
              ? Icons.arrow_upward_rounded
              : Icons.arrow_downward_rounded,
          color: ObuColors.blue,
          title: snapshot.shiftRecommendation == ShiftRecommendation.shiftUp
              ? 'Shift up'
              : 'Shift down',
          detail: '${snapshot.cadenceRpm} rpm',
        ),
      );
    }
    if (settings.v2xProximityWarnings && snapshot.v2xVehicleNearby) {
      items.add(
        _AttentionChip(
          icon: Icons.directions_car_filled_rounded,
          color: ObuColors.cyan,
          title: 'V2X vehicle',
          detail: '${snapshot.v2xVehicleDistanceMeters ?? '—'} m nearby',
        ),
      );
    }
    final hazard = snapshot.roadHazard;
    if (hazard != null &&
        (snapshot.freshness == DataFreshness.replay || !hazard.isExpired)) {
      items.add(
        _AttentionChip(
          icon: Icons.construction_rounded,
          color: ObuColors.amber,
          title: hazard.title,
          detail:
              hazard.distanceMeters.toString() +
              ' m · ' +
              (hazard.provenance == WarningProvenance.standardizedDenm
                  ? 'DENM'
                  : 'experimental'),
        ),
      );
    }
    if (items.isEmpty) {
      items.add(
        const _AttentionChip(
          icon: Icons.check_circle_outline_rounded,
          color: ObuColors.green,
          title: 'Route clear',
          detail: 'No active advisories',
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: <Widget>[
          for (var index = 0; index < items.length; index++) ...<Widget>[
            if (index > 0) const SizedBox(width: 8),
            items[index],
          ],
        ],
      ),
    );
  }
}

class _AttentionChip extends StatelessWidget {
  const _AttentionChip({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 14, 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.55)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x15000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 19, color: color),
          ),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.labelLarge),
              Text(
                detail,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: ObuColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RideFooter extends StatelessWidget {
  const _RideFooter({required this.controller});

  final ObuController controller;

  @override
  Widget build(BuildContext context) {
    final replay = controller.replayStatus;
    if (replay.active) {
      return Row(
        children: <Widget>[
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: replay.playing
                  ? controller.pauseReplay
                  : controller.playReplay,
              icon: Icon(
                replay.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
              label: Text(
                replay.playing
                    ? 'Pause replay'
                    : 'Replay at ' + replay.speed.toStringAsFixed(0) + '×',
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filledTonal(
            tooltip: 'Stop replay',
            onPressed: controller.stopReplay,
            icon: const Icon(Icons.stop_rounded),
          ),
        ],
      );
    }
    return Row(
      children: <Widget>[
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: controller.isRecording
                ? controller.stopRideRecording
                : controller.startRideRecording,
            icon: Icon(
              controller.isRecording
                  ? Icons.stop_circle_outlined
                  : Icons.fiber_manual_record_rounded,
              color: controller.isRecording ? ObuColors.red : null,
            ),
            label: Text(
              controller.isRecording ? 'Stop ride recording' : 'Start ride',
            ),
          ),
        ),
      ],
    );
  }
}

class _CollisionOverlay extends StatefulWidget {
  const _CollisionOverlay({
    required this.timeToCollision,
    required this.provenance,
    required this.eventId,
    required this.hapticEnabled,
    required this.onDismiss,
  });

  final double? timeToCollision;
  final WarningProvenance? provenance;
  final String? eventId;
  final bool hapticEnabled;
  final VoidCallback onDismiss;

  @override
  State<_CollisionOverlay> createState() => _CollisionOverlayState();
}

class _CollisionOverlayState extends State<_CollisionOverlay> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.hapticEnabled) await HapticFeedback.heavyImpact();
      await SystemSound.play(SystemSoundType.alert);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ObuColors.red.withValues(alpha: 0.94),
      child: SafeArea(
        child: InkWell(
          onTap: widget.onDismiss,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.warning_rounded,
                    color: Colors.white,
                    size: 82,
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.provenance == WarningProvenance.standardizedDenm
                          ? 'STANDARDIZED DENM ALERT'
                          : 'EXPERIMENTAL INFERRED WARNING',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: ObuColors.red,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'BRAKE',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.timeToCollision == null
                        ? 'Collision risk ahead'
                        : 'Collision possible in '
                              '${widget.timeToCollision!.toStringAsFixed(1)} s',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Research prototype · not a certified safety system' +
                        (widget.eventId == null
                            ? ''
                            : '\nEvent ' + widget.eventId!),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Tap when the situation is clear',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
