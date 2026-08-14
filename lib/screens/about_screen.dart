import 'package:flutter/material.dart';

import '../theme/obu_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About & protocol'),
        backgroundColor: ObuColors.paper,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 54,
                    height: 54,
                    decoration: const BoxDecoration(
                      color: ObuColors.ink,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.pedal_bike_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Bicycle OBU',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Version 1.0.0 · Flutter Material 3 research prototype for '
                    'Android and iOS. Local C-ITS, bicycle telemetry, warnings '
                    'and recording do not require a server round trip.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(height: 1.45),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Experimental safety functions are not certified and must '
                    'not be treated as a substitute for rider attention.',
                    style: TextStyle(
                      color: ObuColors.red,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Transport contract',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          const _InfoCard(
            icon: Icons.layers_outlined,
            title: 'Versioned envelope',
            body:
                'Every frame carries protocol version, source, message type, sequence, message ID and fragmentation fields.',
          ),
          const SizedBox(height: 10),
          const _InfoCard(
            icon: Icons.notifications_active_outlined,
            title: 'Streaming first',
            body:
                'Telemetry uses BLE notifications. Command acknowledgements use indications and explicit success/failure payloads.',
          ),
          const SizedBox(height: 10),
          const _InfoCard(
            icon: Icons.call_split_rounded,
            title: 'MTU independent',
            body:
                'Records are fragmented at the application layer and reassembled by message ID. Sequence gaps remain observable.',
          ),
          const SizedBox(height: 22),
          Text(
            'C-ITS application set',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: const <Widget>[
                _CapabilityRow(
                  code: 'CAM',
                  purpose: 'Nearby road users and motion',
                ),
                Divider(),
                _CapabilityRow(
                  code: 'VAM',
                  purpose: 'Vulnerable road-user awareness',
                ),
                Divider(),
                _CapabilityRow(
                  code: 'DENM',
                  purpose: 'Location-relevant hazards',
                ),
                Divider(),
                _CapabilityRow(
                  code: 'MAPEM',
                  purpose: 'Intersection and lane geometry',
                ),
                Divider(),
                _CapabilityRow(
                  code: 'SPATEM',
                  purpose: 'Signal state and timing',
                ),
                Divider(),
                _CapabilityRow(
                  code: 'IVIM',
                  purpose: 'Infrastructure and sign information',
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text('Research data', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          const _InfoCard(
            icon: Icons.dataset_outlined,
            title: 'Traceable sessions',
            body:
                'Raw frames remain linked to decoded records. Source and '
                'acquisition/arrival times, settings, sensor poses, DBC hashes, '
                'routing metadata and timing state are retained for export/replay.',
          ),
          const SizedBox(height: 10),
          const _InfoCard(
            icon: Icons.cloud_upload_outlined,
            title: 'OpenTrafficMap is opt-in',
            body:
                'Only exact raw live V2X frames are eligible. Replay and '
                'buffered/recovered frames are never uploaded as live traffic.',
          ),
          const SizedBox(height: 22),
          Text('Runtime modes', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'The default demo mode is deterministic and needs no hardware. Start with --dart-define=OBU_TRANSPORT=ble to scan for the ESP32-S3 GATT service.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: ObuColors.muted,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: ObuColors.muted,
                      height: 1.4,
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
}

class _CapabilityRow extends StatelessWidget {
  const _CapabilityRow({required this.code, required this.purpose});

  final String code;
  final String purpose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 64,
            child: Text(code, style: Theme.of(context).textTheme.labelLarge),
          ),
          Expanded(
            child: Text(
              purpose,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: ObuColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}
