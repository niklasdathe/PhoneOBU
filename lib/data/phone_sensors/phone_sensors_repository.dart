import '../../models/phone_sensor_snapshot.dart';
import 'demo_phone_sensors_repository.dart';
import 'live_phone_sensors_repository.dart';

abstract interface class PhoneSensorsRepository {
  Stream<PhoneSensorSnapshot> get snapshots;
  PhoneSensorMode get mode;

  Future<void> start();
  Future<void> dispose();
}

class PhoneSensorsRepositoryFactory {
  static const _mode = String.fromEnvironment(
    'PHONE_SENSORS',
    defaultValue: 'live',
  );

  static PhoneSensorsRepository create() => _mode == 'demo'
      ? DemoPhoneSensorsRepository()
      : LivePhoneSensorsRepository();
}
