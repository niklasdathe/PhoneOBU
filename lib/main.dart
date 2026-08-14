import 'package:flutter/widgets.dart';

import 'app.dart';
import 'data/obu_repository.dart';
import 'data/navigation/navigation_service.dart';
import 'data/phone_sensors/phone_sensors_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ObuBootstrap(
      repository: ObuRepositoryFactory.create(),
      phoneSensors: PhoneSensorsRepositoryFactory.create(),
      navigationService: OpenNavigationService(),
    ),
  );
}
