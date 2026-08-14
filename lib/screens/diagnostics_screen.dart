import 'package:flutter/material.dart';

import '../data/obu_repository.dart';
import '../models/obu_snapshot.dart';
import '../models/phone_sensor_snapshot.dart';
import '../state/obu_controller.dart';
import '../theme/obu_theme.dart';

class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ObuScope.of(context);
    final snapshot = controller.snapshot;
    final diagnostics = controller.diagnostics;
    final phone = controller.phoneSensors;
    final embeddedSubsystems = snapshot.subsystems.isEmpty
        ? _unavailableSubsystems
        : snapshot.subsystems;
    final subsystems = <SubsystemStatus>[
      ...embeddedSubsystems.where(
        (item) => item.name != 'Storage' && item.name != 'Internet / OTM',
      ),
      SubsystemStatus(
        name: 'Storage',
        health: controller.appError?.contains('storage') == true
            ? SubsystemHealth.degraded
            : SubsystemHealth.online,
        detail: controller.isRecording
            ? 'Scientific session recording'
            : controller.rideSessions.length.toString() + ' saved sessions',
      ),
      SubsystemStatus(
        name: 'Internet / OTM',
        health: controller.otmStatus.state.name == 'connected'
            ? SubsystemHealth.online
            : controller.settings.otm.enabled
            ? SubsystemHealth.degraded
            : SubsystemHealth.offline,
        detail: controller.settings.otm.enabled
            ? controller.otmStatus.state.name
            : 'OTM opt-in disabled',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostics'),
        backgroundColor: ObuColors.paper,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          _ConnectionHeader(
            connected: snapshot.obuConnected,
            phase: diagnostics.phase,
            transportName: diagnostics.transportName,
            error: diagnostics.lastError,
          ),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              leading: Icon(Icons.science_outlined, color: ObuColors.red),
              title: Text(
                'Research prototype · safety functions not certified',
              ),
              subtitle: Text(
                'DENM alerts and experimental inferred warnings carry '
                'separate provenance.',
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Subsystems', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: subsystems.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 132,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
            ),
            itemBuilder: (context, index) =>
                _SubsystemCard(status: subsystems[index]),
          ),
          const SizedBox(height: 24),
          Text('Phone sensors', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: <Widget>[
                _DiagnosticRow(
                  label: 'Source',
                  value: phone.mode == PhoneSensorMode.live
                      ? 'Physical phone'
                      : 'Simulated Hamburg ride',
                ),
                const Divider(),
                _DiagnosticRow(
                  label: 'GPS / fused location',
                  value: phone.location == null
                      ? _availability(phone.locationAvailability)
                      : '${phone.location!.latitude.toStringAsFixed(6)}, '
                            '${phone.location!.longitude.toStringAsFixed(6)} '
                            '±${phone.location!.horizontalAccuracyMeters.toStringAsFixed(1)} m',
                ),
                const Divider(),
                _DiagnosticRow(
                  label: 'Altitude / speed / course',
                  value: phone.location == null
                      ? '—'
                      : '${phone.location!.altitudeMeters.toStringAsFixed(1)} m · '
                            '${(phone.location!.speedMps * 3.6).toStringAsFixed(1)} km/h · '
                            '${phone.location!.courseDegrees.toStringAsFixed(0)}°',
                ),
                const Divider(),
                _DiagnosticRow(
                  label: 'Accelerometer (m/s²)',
                  value: _vector(phone.accelerometer),
                ),
                const Divider(),
                _DiagnosticRow(
                  label: 'Linear acceleration (m/s²)',
                  value: _vector(phone.userAccelerometer),
                ),
                const Divider(),
                _DiagnosticRow(
                  label: 'Gyroscope (rad/s)',
                  value: _vector(phone.gyroscope),
                ),
                const Divider(),
                _DiagnosticRow(
                  label: 'Magnetometer (µT) / compass',
                  value:
                      '${_vector(phone.magnetometer)} · '
                      '${phone.compassHeadingDegrees?.toStringAsFixed(0) ?? '—'}°',
                ),
                const Divider(),
                _DiagnosticRow(
                  label: 'Barometer',
                  value: phone.pressureHpa == null
                      ? _availability(phone.barometerAvailability)
                      : '${phone.pressureHpa!.toStringAsFixed(1)} hPa',
                ),
                const Divider(),
                _DiagnosticRow(
                  label: 'Device orientation',
                  value: phone.orientation == null
                      ? _availability(phone.orientationAvailability)
                      : 'roll ' +
                            phone.orientation!.rollDegrees.toStringAsFixed(1) +
                            '° · pitch ' +
                            phone.orientation!.pitchDegrees.toStringAsFixed(1) +
                            '° · yaw ' +
                            phone.orientation!.yawDegrees.toStringAsFixed(1) +
                            '°',
                ),
                const Divider(),
                const _DiagnosticRow(
                  label: 'Sensor provenance',
                  value: 'raw + OS-fused stored separately',
                ),
                if (phone.lastError != null) ...<Widget>[
                  const Divider(),
                  _DiagnosticRow(
                    label: 'Sensor error',
                    value: phone.lastError!,
                    valueColor: ObuColors.red,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('GLOSA', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: <Widget>[
                _DiagnosticRow(
                  label: 'Availability',
                  value: snapshot.glosa.availability.name,
                  valueColor: snapshot.glosa.hasRecommendation
                      ? ObuColors.green
                      : ObuColors.muted,
                ),
                const Divider(),
                _DiagnosticRow(
                  label: 'Recommendation',
                  value: snapshot.glosa.recommendedSpeedKmh == null
                      ? '— · ' + snapshot.glosa.statusDetail
                      : snapshot.glosa.recommendedSpeedKmh!.toStringAsFixed(1) +
                            ' km/h',
                ),
                const Divider(),
                _DiagnosticRow(
                  label: 'Intersection / signal',
                  value: snapshot.glosa.intersectionId == null
                      ? '—'
                      : (snapshot.glosa.intersectionName ?? 'Intersection') +
                            ' · ID ' +
                            snapshot.glosa.intersectionId.toString() +
                            ' · SG ' +
                            (snapshot.glosa.signalGroup?.toString() ?? '—'),
                ),
                const Divider(),
                _DiagnosticRow(
                  label: 'MAPEM source time',
                  value:
                      snapshot.glosa.mapemTimestamp
                          ?.toUtc()
                          .toIso8601String() ??
                      '—',
                ),
                const Divider(),
                _DiagnosticRow(
                  label: 'SPATEM source time',
                  value:
                      snapshot.glosa.spatemTimestamp
                          ?.toUtc()
                          .toIso8601String() ??
                      '—',
                ),
                const Divider(),
                _DiagnosticRow(
                  label: 'Timing valid until',
                  value:
                      snapshot.glosa.validUntil?.toUtc().toIso8601String() ??
                      '—',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Transport', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: <Widget>[
                _DiagnosticRow(
                  label: 'Protocol',
                  value: 'OBU transport v${diagnostics.protocolVersion}',
                ),
                const Divider(),
                _DiagnosticRow(
                  label: 'Firmware',
                  value:
                      'S3 ' +
                      diagnostics.s3FirmwareVersion +
                      ' · C5 ' +
                      diagnostics.c5FirmwareVersion,
                ),
                const Divider(),
                _DiagnosticRow(
                  label: 'Clock synchronization',
                  value:
                      diagnostics.clockSyncState +
                      ' · ' +
                      diagnostics.clockSyncQuality,
                ),
                const Divider(),
                _DiagnosticRow(
                  label: 'Negotiated MTU',
                  value:
                      diagnostics.negotiatedMtu?.toString() ??
                      'OS managed / unknown',
                ),
                const Divider(),
                _DiagnosticRow(
                  label: 'Frames received',
                  value: diagnostics.receivedFrames.toString(),
                ),
                const Divider(),
                _DiagnosticRow(
                  label: 'Frames transmitted',
                  value: diagnostics.transmittedFrames.toString(),
                ),
                const Divider(),
                _DiagnosticRow(
                  label: 'Lost sequences',
                  value: diagnostics.lostSequences.toString(),
                  valueColor: diagnostics.lostSequences == 0
                      ? ObuColors.green
                      : ObuColors.red,
                ),
                const Divider(),
                _DiagnosticRow(
                  label: 'Out-of-order sequences',
                  value: diagnostics.outOfOrderSequences.toString(),
                  valueColor: diagnostics.outOfOrderSequences == 0
                      ? ObuColors.green
                      : ObuColors.red,
                ),
                const Divider(),
                _DiagnosticRow(
                  label: 'Recovered / buffered',
                  value: diagnostics.recoveredRecords.toString(),
                ),
                const Divider(),
                _DiagnosticRow(
                  label: 'Overflow drops',
                  value: diagnostics.overflowDrops.toString(),
                  valueColor: diagnostics.overflowDrops == 0
                      ? ObuColors.green
                      : ObuColors.red,
                ),
                const Divider(),
                _DiagnosticRow(
                  label: 'Link protection',
                  value: diagnostics.authenticated
                      ? 'Authenticated / encrypted'
                      : 'Not confirmed by transport',
                  valueColor: diagnostics.authenticated
                      ? ObuColors.green
                      : ObuColors.amber,
                ),
                const Divider(),
                _DiagnosticRow(
                  label: 'Stream continuity',
                  value: diagnostics.sessionContinuity,
                ),
                const Divider(),
                _DiagnosticRow(
                  label: 'Displayed data class',
                  value: snapshot.freshness.name,
                ),
                const Divider(),
                _DiagnosticRow(
                  label: 'Last message',
                  value: diagnostics.lastMessageType,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'App data pipeline',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: <Widget>[
                _DiagnosticRow(
                  label: 'Scientific recording',
                  value: controller.isRecording ? 'ACTIVE' : 'Stopped',
                  valueColor: controller.isRecording
                      ? ObuColors.red
                      : ObuColors.muted,
                ),
                const Divider(),
                _DiagnosticRow(
                  label: 'Background mode',
                  value: controller.backgroundState,
                ),
                const Divider(),
                _DiagnosticRow(
                  label: 'Detected OS suspension',
                  value: controller.lastDetectedSuspension == null
                      ? 'None'
                      : controller.lastDetectedSuspension!.inSeconds
                                .toString() +
                            ' s pipeline gap',
                  valueColor: controller.lastDetectedSuspension == null
                      ? ObuColors.green
                      : ObuColors.red,
                ),
                const Divider(),
                _DiagnosticRow(
                  label: 'DBC definitions',
                  value: controller.dbcDefinitions.length.toString(),
                ),
                const Divider(),
                _DiagnosticRow(
                  label: 'OTM upload',
                  value:
                      controller.otmStatus.state.name +
                      ' · ' +
                      controller.otmStatus.successful.toString() +
                      ' sent / ' +
                      controller.otmStatus.failed.toString() +
                      ' failed',
                ),
                if (controller.appError != null) ...<Widget>[
                  const Divider(),
                  _DiagnosticRow(
                    label: 'App error',
                    value: controller.appError!,
                    valueColor: ObuColors.red,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Test controls', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'These commands exercise explicit success/failure responses. In demo mode they control the built-in scenarios.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: ObuColors.muted),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: ObuColors.red),
                onPressed: () =>
                    _runCommand(context, controller, 'simulate_collision'),
                icon: const Icon(Icons.warning_rounded),
                label: const Text('Simulate collision'),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    _runCommand(context, controller, 'clear_collision'),
                icon: const Icon(Icons.clear_rounded),
                label: const Text('Clear alarm'),
              ),
              OutlinedButton.icon(
                onPressed: () => _runCommand(context, controller, 'reconnect'),
                icon: const Icon(Icons.sync_rounded),
                label: const Text('Reconnect'),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    _runCommand(context, controller, 'simulate_missing_spatem'),
                icon: const Icon(Icons.timer_off_outlined),
                label: const Text('Remove SPATEM'),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    _runCommand(context, controller, 'restore_spatem'),
                icon: const Icon(Icons.restore_rounded),
                label: const Text('Restore SPATEM'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _vector(Vector3Reading value) =>
      '${value.x.toStringAsFixed(2)}, ${value.y.toStringAsFixed(2)}, ${value.z.toStringAsFixed(2)}';

  String _availability(SensorAvailability value) => switch (value) {
    SensorAvailability.available => 'Available',
    SensorAvailability.unavailable => 'Unavailable on this device',
    SensorAvailability.permissionDenied => 'Permission denied',
    SensorAvailability.error => 'Sensor error',
  };

  Future<void> _runCommand(
    BuildContext context,
    ObuController controller,
    String command,
  ) async {
    final result = await controller.command(command);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: result.success ? ObuColors.ink : ObuColors.red,
        content: Text('${result.code}: ${result.message}'),
      ),
    );
  }
}

const _unavailableSubsystems = <SubsystemStatus>[
  SubsystemStatus(
    name: 'C5 V2X radio',
    health: SubsystemHealth.unavailable,
    detail: 'Awaiting diagnostics',
  ),
  SubsystemStatus(
    name: 'GNSS',
    health: SubsystemHealth.unavailable,
    detail: 'Awaiting diagnostics',
  ),
  SubsystemStatus(
    name: 'CAN',
    health: SubsystemHealth.unavailable,
    detail: 'Awaiting diagnostics',
  ),
  SubsystemStatus(
    name: 'BLE sensors',
    health: SubsystemHealth.unavailable,
    detail: 'Awaiting diagnostics',
  ),
  SubsystemStatus(
    name: 'OBU BLE',
    health: SubsystemHealth.offline,
    detail: 'No transport data',
  ),
];

class _ConnectionHeader extends StatelessWidget {
  const _ConnectionHeader({
    required this.connected,
    required this.phase,
    required this.transportName,
    required this.error,
  });

  final bool connected;
  final ConnectionPhase phase;
  final String transportName;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: <Widget>[
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: (connected ? ObuColors.green : ObuColors.red).withValues(
                  alpha: 0.12,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                connected
                    ? Icons.bluetooth_connected_rounded
                    : Icons.bluetooth_searching_rounded,
                color: connected ? ObuColors.green : ObuColors.red,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    connected ? 'OBU link active' : _phaseLabel(phase),
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    error ?? transportName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: error == null ? ObuColors.muted : ObuColors.red,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _phaseLabel(ConnectionPhase phase) {
    return switch (phase) {
      ConnectionPhase.demo => 'Demo transport active',
      ConnectionPhase.scanning => 'Scanning for OBU',
      ConnectionPhase.connecting => 'Connecting to OBU',
      ConnectionPhase.connected => 'OBU link active',
      ConnectionPhase.disconnected => 'OBU disconnected',
      ConnectionPhase.error => 'Transport error',
    };
  }
}

class _SubsystemCard extends StatelessWidget {
  const _SubsystemCard({required this.status});

  final SubsystemStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _healthColor(status.health);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const Spacer(),
                Text(
                  _healthLabel(status.health),
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: color),
                ),
              ],
            ),
            const Spacer(),
            Text(
              status.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(
              status.detail,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: ObuColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}

Color _healthColor(SubsystemHealth health) {
  return switch (health) {
    SubsystemHealth.online => ObuColors.green,
    SubsystemHealth.degraded => ObuColors.amber,
    SubsystemHealth.offline => ObuColors.red,
    SubsystemHealth.unavailable => ObuColors.muted,
  };
}

String _healthLabel(SubsystemHealth health) {
  return switch (health) {
    SubsystemHealth.online => 'ONLINE',
    SubsystemHealth.degraded => 'DEGRADED',
    SubsystemHealth.offline => 'OFFLINE',
    SubsystemHealth.unavailable => 'UNKNOWN',
  };
}
