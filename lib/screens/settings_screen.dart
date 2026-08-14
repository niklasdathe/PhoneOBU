import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../state/obu_controller.dart';
import '../theme/obu_theme.dart';
import 'sessions_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ObuScope.of(context);
    final settings = controller.settings;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: ObuColors.paper,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          const _SectionTitle('Connection and ride lifecycle'),
          Card(
            child: Column(
              children: <Widget>[
                SwitchListTile(
                  title: const Text('Auto-connect to OBU'),
                  subtitle: const Text(
                    'Reconnect to the previously associated ESP32-S3',
                  ),
                  value: settings.autoConnect,
                  onChanged: (value) => _save(
                    context,
                    controller,
                    settings.copyWith(autoConnect: value),
                  ),
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Background ride mode'),
                  subtitle: Text(
                    'Android foreground service / iOS BLE + location modes · ' +
                        controller.backgroundCapability,
                  ),
                  value: settings.backgroundRideMode,
                  onChanged: (value) => _save(
                    context,
                    controller,
                    settings.copyWith(backgroundRideMode: value),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const _SectionTitle('GLOSA'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(Icons.traffic_rounded, color: ObuColors.green),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Comfortable maximum speed',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Text(
                        settings.comfortableMaximumSpeedKmh.toStringAsFixed(0) +
                            ' km/h',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ],
                  ),
                  Slider(
                    min: 10,
                    max: 45,
                    divisions: 35,
                    value: settings.comfortableMaximumSpeedKmh,
                    label:
                        settings.comfortableMaximumSpeedKmh.toStringAsFixed(0) +
                        ' km/h',
                    onChanged: (value) => _save(
                      context,
                      controller,
                      settings.copyWith(comfortableMaximumSpeedKmh: value),
                      quiet: true,
                    ),
                  ),
                  const Text(
                    'Recommendations never exceed this value. Missing, stale or '
                    'ambiguous MAPEM/SPATEM produces no target speed.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          const _SectionTitle('Safety and attention'),
          Card(
            child: Column(
              children: <Widget>[
                const ListTile(
                  leading: Icon(Icons.science_outlined, color: ObuColors.red),
                  title: Text('Research prototype'),
                  subtitle: Text(
                    'Experimental safety functions are not certified. '
                    'Standardized DENM and inferred warnings remain visibly distinct.',
                  ),
                ),
                const Divider(),
                const ListTile(
                  leading: Icon(
                    Icons.crisis_alert_rounded,
                    color: ObuColors.red,
                  ),
                  title: Text('Critical warning display and sound'),
                  subtitle: Text('Always active during a ride'),
                  trailing: Icon(Icons.lock_outline_rounded),
                ),
                const Divider(),
                SwitchListTile(
                  secondary: const Icon(
                    Icons.directions_car_filled_rounded,
                    color: ObuColors.cyan,
                  ),
                  title: const Text('Nearby V2X vehicles'),
                  value: settings.v2xProximityWarnings,
                  onChanged: (value) => _save(
                    context,
                    controller,
                    settings.copyWith(v2xProximityWarnings: value),
                  ),
                ),
                const Divider(),
                SwitchListTile(
                  secondary: const Icon(
                    Icons.swap_vert_rounded,
                    color: ObuColors.blue,
                  ),
                  title: const Text('Gear recommendations'),
                  value: settings.shiftRecommendations,
                  onChanged: (value) => _save(
                    context,
                    controller,
                    settings.copyWith(shiftRecommendations: value),
                  ),
                ),
                const Divider(),
                SwitchListTile(
                  secondary: const Icon(Icons.vibration_rounded),
                  title: const Text('Haptic warnings'),
                  value: settings.hapticWarnings,
                  onChanged: (value) => _save(
                    context,
                    controller,
                    settings.copyWith(hapticWarnings: value),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const _SectionTitle('Sensors and data rates'),
          Card(
            child: Column(
              children: <Widget>[
                for (
                  var index = 0;
                  index < settings.sensorConfigurations.length;
                  index++
                ) ...<Widget>[
                  if (index > 0) const Divider(),
                  _SensorConfigurationTile(
                    configuration: settings.sensorConfigurations[index],
                    onChanged: (value) =>
                        _configureSensor(context, controller, value),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.threed_rotation_rounded),
                  title: const Text('Installation poses'),
                  subtitle: const Text(
                    'Rear-wheel-axle frame: x forward, y left, z up',
                  ),
                  trailing: IconButton(
                    tooltip: 'Add sensor pose',
                    onPressed: () => _editPose(context, controller),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ),
                for (final pose in settings.sensorPoses) ...<Widget>[
                  const Divider(),
                  ListTile(
                    title: Text(pose.displayName),
                    subtitle: Text(
                      'x ' +
                          pose.xMeters.toStringAsFixed(3) +
                          ' · y ' +
                          pose.yMeters.toStringAsFixed(3) +
                          ' · z ' +
                          pose.zMeters.toStringAsFixed(3) +
                          ' m\nroll ' +
                          pose.rollDegrees.toStringAsFixed(1) +
                          '° · pitch ' +
                          pose.pitchDegrees.toStringAsFixed(1) +
                          '° · yaw ' +
                          pose.yawDegrees.toStringAsFixed(1) +
                          '°',
                    ),
                    isThreeLine: true,
                    onTap: () => _editPose(context, controller, existing: pose),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),
          const _SectionTitle('CAN databases'),
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.upload_file_rounded),
                  title: const Text('Import DBC'),
                  subtitle: const Text(
                    'Decode third-party CAN frames without S3 firmware changes',
                  ),
                  trailing: const Icon(Icons.add_rounded),
                  onTap: () => _importDbc(context, controller),
                ),
                for (final definition in controller.dbcDefinitions) ...<Widget>[
                  const Divider(),
                  SwitchListTile(
                    title: Text(definition.fileName),
                    subtitle: Text(
                      definition.messages.length.toString() +
                          ' messages · SHA-256 ' +
                          definition.hash.substring(0, 12) +
                          '…',
                    ),
                    value: definition.enabled,
                    onChanged: (value) =>
                        controller.setDbcEnabled(definition.hash, value),
                    secondary: IconButton(
                      tooltip: 'Remove DBC',
                      onPressed: () => controller.removeDbc(definition.hash),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),
          const _SectionTitle('OpenTrafficMap contribution'),
          Card(
            child: Column(
              children: <Widget>[
                SwitchListTile(
                  secondary: const Icon(Icons.cloud_upload_outlined),
                  title: const Text('Upload live V2X frames'),
                  subtitle: const Text(
                    'Explicit opt-in · raw live frames only · no outage catch-up',
                  ),
                  value: settings.otm.enabled,
                  onChanged: (value) =>
                      _setOtmEnabled(context, controller, value),
                ),
                const Divider(),
                ListTile(
                  title: const Text('Broker'),
                  subtitle: Text(
                    settings.otm.host + ':' + settings.otm.port.toString(),
                  ),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _editOtm(context, controller),
                ),
                const Divider(),
                ListTile(
                  title: const Text('Node ID'),
                  subtitle: Text(settings.otm.nodeId),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _editOtm(context, controller),
                ),
                const Divider(),
                ListTile(
                  title: const Text('Upload counters'),
                  subtitle: Text(
                    'Attempted ' +
                        controller.otmStatus.attempted.toString() +
                        ' · sent ' +
                        controller.otmStatus.successful.toString() +
                        ' · failed ' +
                        controller.otmStatus.failed.toString(),
                  ),
                  trailing: Text(controller.otmStatus.state.name.toUpperCase()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const _SectionTitle('Data and display'),
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.folder_copy_outlined),
                  title: const Text('Ride sessions, export and replay'),
                  subtitle: const Text(
                    'Canonical JSONL · analysis CSV · V2X PCAPNG',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SessionsScreen(),
                    ),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.straighten_rounded),
                  title: const Text('Units'),
                  trailing: DropdownButton<UnitSystem>(
                    value: settings.unitSystem,
                    underline: const SizedBox.shrink(),
                    items: const <DropdownMenuItem<UnitSystem>>[
                      DropdownMenuItem(
                        value: UnitSystem.metric,
                        child: Text('Metric'),
                      ),
                      DropdownMenuItem(
                        value: UnitSystem.imperial,
                        child: Text('Imperial'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        _save(
                          context,
                          controller,
                          settings.copyWith(unitSystem: value),
                        );
                      }
                    },
                  ),
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('High-contrast map'),
                  value: settings.highContrastMap,
                  onChanged: (value) => _save(
                    context,
                    controller,
                    settings.copyWith(highContrastMap: value),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save(
    BuildContext context,
    ObuController controller,
    AppSettings settings, {
    bool quiet = false,
  }) async {
    final result = await controller.updateSettings(settings);
    if (!context.mounted || quiet) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: result.success ? ObuColors.ink : ObuColors.red,
        content: Text(result.code + ': ' + result.message),
      ),
    );
  }

  Future<void> _configureSensor(
    BuildContext context,
    ObuController controller,
    SensorConfiguration configuration,
  ) async {
    final result = await controller.configureSensor(configuration);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: result.success ? ObuColors.ink : ObuColors.red,
        content: Text(result.code + ': ' + result.message),
      ),
    );
  }

  Future<void> _importDbc(
    BuildContext context,
    ObuController controller,
  ) async {
    try {
      final definition = await controller.importDbc();
      if (!context.mounted || definition == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported ' +
                definition.fileName +
                ' with ' +
                definition.messages.length.toString() +
                ' messages.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('DBC import failed: ' + error.toString())),
      );
    }
  }

  Future<void> _setOtmEnabled(
    BuildContext context,
    ObuController controller,
    bool enabled,
  ) async {
    if (enabled) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Contribute live V2X frames?'),
          content: const Text(
            'OpenTrafficMap receives the exact raw ITS-G5 frames while they are '
            'live. No phone sensors, GPS, CAN or replay data are uploaded. '
            'Frames missed while offline are never sent later.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Opt in'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await _save(
      context,
      controller,
      controller.settings.copyWith(
        otm: controller.settings.otm.copyWith(enabled: enabled),
      ),
    );
  }

  Future<void> _editOtm(BuildContext context, ObuController controller) async {
    final host = TextEditingController(text: controller.settings.otm.host);
    final port = TextEditingController(
      text: controller.settings.otm.port.toString(),
    );
    final node = TextEditingController(text: controller.settings.otm.nodeId);
    final result = await showDialog<OtmConfiguration>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('OpenTrafficMap endpoint'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: host,
              decoration: const InputDecoration(labelText: 'MQTT TLS host'),
            ),
            TextField(
              controller: port,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Port'),
            ),
            TextField(
              controller: node,
              decoration: const InputDecoration(labelText: 'Node ID'),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final parsedPort = int.tryParse(port.text);
              if (host.text.trim().isEmpty ||
                  parsedPort == null ||
                  parsedPort < 1 ||
                  parsedPort > 65535 ||
                  !RegExp(r'^[a-zA-Z0-9_-]{3,64}$')
                      .hasMatch(node.text.trim())) {
                return;
              }
              Navigator.of(context).pop(
                controller.settings.otm.copyWith(
                  host: host.text.trim(),
                  port: parsedPort,
                  nodeId: node.text.trim().toLowerCase(),
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    host.dispose();
    port.dispose();
    node.dispose();
    if (result != null && context.mounted) {
      await _save(
        context,
        controller,
        controller.settings.copyWith(otm: result),
      );
    }
  }

  Future<void> _editPose(
    BuildContext context,
    ObuController controller, {
    SensorPose? existing,
  }) async {
    final id = TextEditingController(text: existing?.sensorId ?? '');
    final name = TextEditingController(text: existing?.displayName ?? '');
    final values = <TextEditingController>[
      TextEditingController(text: existing?.xMeters.toString() ?? '0'),
      TextEditingController(text: existing?.yMeters.toString() ?? '0'),
      TextEditingController(text: existing?.zMeters.toString() ?? '0'),
      TextEditingController(text: existing?.rollDegrees.toString() ?? '0'),
      TextEditingController(text: existing?.pitchDegrees.toString() ?? '0'),
      TextEditingController(text: existing?.yawDegrees.toString() ?? '0'),
    ];
    final pose = await showDialog<SensorPose>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Add sensor pose' : 'Edit sensor pose'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: id,
                enabled: existing == null,
                decoration: const InputDecoration(labelText: 'Sensor ID'),
              ),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Display name'),
              ),
              for (var index = 0; index < values.length; index++)
                TextField(
                  controller: values[index],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: const <String>[
                      'x forward (m)',
                      'y left (m)',
                      'z up (m)',
                      'roll (°)',
                      'pitch (°)',
                      'yaw (°)',
                    ][index],
                  ),
                ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = values
                  .map((item) => double.tryParse(item.text))
                  .toList();
              if (id.text.trim().isEmpty ||
                  name.text.trim().isEmpty ||
                  parsed.any((item) => item == null)) {
                return;
              }
              Navigator.of(context).pop(
                SensorPose(
                  sensorId: id.text.trim(),
                  displayName: name.text.trim(),
                  xMeters: parsed[0]!,
                  yMeters: parsed[1]!,
                  zMeters: parsed[2]!,
                  rollDegrees: parsed[3]!,
                  pitchDegrees: parsed[4]!,
                  yawDegrees: parsed[5]!,
                  updatedAt: DateTime.now(),
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    id.dispose();
    name.dispose();
    for (final controller in values) {
      controller.dispose();
    }
    if (pose != null) await controller.saveSensorPose(pose);
  }
}

class _SensorConfigurationTile extends StatelessWidget {
  const _SensorConfigurationTile({
    required this.configuration,
    required this.onChanged,
  });

  final SensorConfiguration configuration;
  final ValueChanged<SensorConfiguration> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(configuration.displayName),
      subtitle: DropdownButton<int>(
        value: configuration.rateHz,
        underline: const SizedBox.shrink(),
        items: configuration.supportedRatesHz
            .map(
              (rate) => DropdownMenuItem<int>(
                value: rate,
                child: Text(rate.toString() + ' Hz'),
              ),
            )
            .toList(growable: false),
        onChanged: configuration.enabled
            ? (value) {
                if (value != null)
                  onChanged(configuration.copyWith(rateHz: value));
              }
            : null,
      ),
      value: configuration.enabled,
      onChanged: (value) => onChanged(configuration.copyWith(enabled: value)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(text, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}
