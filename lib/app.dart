import 'package:flutter/material.dart';

import 'data/obu_repository.dart';
import 'data/navigation/navigation_service.dart';
import 'data/phone_sensors/phone_sensors_repository.dart';
import 'data/settings_repository.dart';
import 'screens/ride_screen.dart';
import 'state/obu_controller.dart';
import 'theme/obu_theme.dart';

class ObuBootstrap extends StatefulWidget {
  const ObuBootstrap({
    required this.repository,
    required this.phoneSensors,
    required this.navigationService,
    this.settingsRepository,
    super.key,
  });

  final ObuRepository repository;
  final PhoneSensorsRepository phoneSensors;
  final NavigationService navigationService;
  final SettingsRepository? settingsRepository;

  @override
  State<ObuBootstrap> createState() => _ObuBootstrapState();
}

class _ObuBootstrapState extends State<ObuBootstrap> {
  late final ObuController controller;

  @override
  void initState() {
    super.initState();
    controller = ObuController(
      widget.repository,
      widget.phoneSensors,
      widget.navigationService,
      settingsRepository: widget.settingsRepository,
    )..initialize();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ObuScope(controller: controller, child: const ObuApp());
  }
}

class ObuApp extends StatelessWidget {
  const ObuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bicycle OBU',
      debugShowCheckedModeBanner: false,
      theme: ObuTheme.light,
      home: const RideScreen(),
    );
  }
}
