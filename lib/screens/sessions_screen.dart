import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/session/ride_session_manager.dart';
import '../state/obu_controller.dart';
import '../theme/obu_theme.dart';

class SessionsScreen extends StatelessWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ObuScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride sessions'),
        backgroundColor: ObuColors.paper,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: <Widget>[
          _RecordingCard(controller: controller),
          if (controller.replayStatus.active) ...<Widget>[
            const SizedBox(height: 16),
            _ReplayCard(controller: controller),
          ],
          const SizedBox(height: 24),
          Text(
            'Recorded sessions',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (controller.rideSessions.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.folder_open_rounded),
                title: Text('No completed sessions yet'),
                subtitle: Text(
                  'Start a ride to create the canonical synchronized JSONL log.',
                ),
              ),
            )
          else
            for (final session in controller.rideSessions)
              _SessionCard(session: session, controller: controller),
        ],
      ),
    );
  }
}

class _RecordingCard extends StatelessWidget {
  const _RecordingCard({required this.controller});

  final ObuController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  controller.isRecording
                      ? Icons.fiber_manual_record_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: controller.isRecording
                      ? ObuColors.red
                      : ObuColors.muted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    controller.isRecording
                        ? 'Scientific ride recording active'
                        : 'No active recording',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'The canonical session contains OBU data, raw V2X, phone sensors, '
              'warnings, GLOSA, configuration and provenance in one JSONL file.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: ObuColors.muted),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: controller.isRecording
                  ? controller.stopRideRecording
                  : controller.startRideRecording,
              icon: Icon(
                controller.isRecording
                    ? Icons.stop_rounded
                    : Icons.play_arrow_rounded,
              ),
              label: Text(
                controller.isRecording ? 'Stop and close' : 'Start ride',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplayCard extends StatelessWidget {
  const _ReplayCard({required this.controller});

  final ObuController controller;

  @override
  Widget build(BuildContext context) {
    final replay = controller.replayStatus;
    final max = replay.duration.inMilliseconds <= 0
        ? 1.0
        : replay.duration.inMilliseconds.toDouble();
    final value = replay.position.inMilliseconds
        .clamp(0, max.toInt())
        .toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Replay · ' + (replay.session?.id ?? 'session'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Slider(
              value: value,
              max: max,
              onChanged: (milliseconds) => controller.seekReplay(
                Duration(milliseconds: milliseconds.round()),
              ),
            ),
            Row(
              children: <Widget>[
                IconButton.filledTonal(
                  tooltip: replay.playing ? 'Pause replay' : 'Play replay',
                  onPressed: replay.playing
                      ? controller.pauseReplay
                      : controller.playReplay,
                  icon: Icon(
                    replay.playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<double>(
                  value: replay.speed,
                  items: const <DropdownMenuItem<double>>[
                    DropdownMenuItem(value: 0.5, child: Text('0.5×')),
                    DropdownMenuItem(value: 1, child: Text('1×')),
                    DropdownMenuItem(value: 2, child: Text('2×')),
                    DropdownMenuItem(value: 4, child: Text('4×')),
                    DropdownMenuItem(value: 8, child: Text('8×')),
                  ],
                  onChanged: (value) {
                    if (value != null) controller.setReplaySpeed(value);
                  },
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: controller.stopReplay,
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('Exit replay'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'REPLAY data is visibly marked and is never sent to '
              'OpenTrafficMap or V2X.',
              style: TextStyle(color: ObuColors.blue),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.controller});

  final RideSessionSummary session;
  final ObuController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.route_rounded),
        title: Text(_date(session.startedAt)),
        subtitle: Text(
          _duration(session.duration) +
              ' · ' +
              (session.sizeBytes / 1024 / 1024).toStringAsFixed(1) +
              ' MB',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.tonalIcon(
                onPressed: () async {
                  await controller.loadReplay(session);
                  await controller.playReplay();
                },
                icon: const Icon(Icons.replay_rounded),
                label: const Text('Replay'),
              ),
              OutlinedButton.icon(
                onPressed: () => _export(
                  context,
                  controller.exportCsv(session),
                  'Analysis CSV',
                ),
                icon: const Icon(Icons.table_chart_outlined),
                label: const Text('CSV'),
              ),
              OutlinedButton.icon(
                onPressed: () => _export(
                  context,
                  controller.exportPcapng(session),
                  'V2X PCAPNG',
                ),
                icon: const Icon(Icons.network_check_rounded),
                label: const Text('PCAPNG'),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    _share(File(session.path), 'Canonical Bicycle OBU session'),
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('Session'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _export(
    BuildContext context,
    Future<File> operation,
    String label,
  ) async {
    try {
      final file = await operation;
      if (!context.mounted) return;
      await _share(file, label);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(label + ' export failed: ' + error.toString())),
      );
    }
  }

  Future<void> _share(File file, String label) async {
    await SharePlus.instance.share(
      ShareParams(subject: label, files: <XFile>[XFile(file.path)]),
    );
  }

  String _date(DateTime value) {
    final local = value.toLocal();
    return local.year.toString().padLeft(4, '0') +
        '-' +
        local.month.toString().padLeft(2, '0') +
        '-' +
        local.day.toString().padLeft(2, '0') +
        ' ' +
        local.hour.toString().padLeft(2, '0') +
        ':' +
        local.minute.toString().padLeft(2, '0');
  }

  String _duration(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60);
    final seconds = value.inSeconds.remainder(60);
    if (hours > 0) {
      return hours.toString() +
          ' h ' +
          minutes.toString().padLeft(2, '0') +
          ' min';
    }
    return minutes.toString() +
        ' min ' +
        seconds.toString().padLeft(2, '0') +
        ' s';
  }
}
