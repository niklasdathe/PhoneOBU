import 'package:bicycle_obu/data/phone_sensors/demo_phone_sensors_repository.dart';
import 'package:bicycle_obu/models/phone_sensor_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('simulation exposes every phone sensor group', () async {
    final repository = DemoPhoneSensorsRepository();
    final first = repository.snapshots.first;
    await repository.start();
    final snapshot = await first;

    expect(snapshot.mode, PhoneSensorMode.simulated);
    expect(snapshot.location, isNotNull);
    expect(snapshot.motionAvailability, SensorAvailability.available);
    expect(snapshot.magnetometerAvailability, SensorAvailability.available);
    expect(snapshot.barometerAvailability, SensorAvailability.available);
    expect(snapshot.locationAvailability, SensorAvailability.available);
    expect(snapshot.pressureHpa, isNotNull);

    await repository.dispose();
  });
}
