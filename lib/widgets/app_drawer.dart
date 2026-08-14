import 'package:flutter/material.dart';

import '../screens/about_screen.dart';
import '../screens/diagnostics_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/sessions_screen.dart';
import '../state/obu_controller.dart';
import '../theme/obu_theme.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final controller = ObuScope.of(context);
    final connected = controller.snapshot.obuConnected;
    return Drawer(
      width: 320,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: ObuColors.ink,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.pedal_bike_rounded, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text('Bicycle OBU', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    'Ride interface',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: ObuColors.muted,
                        ),
                  ),
                ],
              ),
            ),
            const Divider(),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.navigation_rounded),
              title: const Text('Ride'),
              selected: true,
              selectedTileColor: ObuColors.surface,
              onTap: () => Navigator.of(context).pop(),
            ),
            ListTile(
              leading: const Icon(Icons.monitor_heart_outlined),
              title: const Text('Diagnostics'),
              onTap: () => _open(context, const DiagnosticsScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.folder_copy_outlined),
              title: const Text('Ride sessions'),
              onTap: () => _open(context, const SessionsScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.tune_rounded),
              title: const Text('Settings'),
              onTap: () => _open(context, const SettingsScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('About & protocol'),
              onTap: () => _open(context, const AboutScreen()),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: ObuColors.line),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: connected ? ObuColors.green : ObuColors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            connected ? 'OBU connected' : 'OBU disconnected',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          Text(
                            controller.diagnostics.transportName,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: ObuColors.muted,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
