import 'package:bicycle_obu/models/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fresh settings keep OTM disabled and preserve pose provenance', () {
    final defaults = AppSettings.defaults();
    expect(defaults.otm.enabled, isFalse);

    final pose = SensorPose(
      sensorId: 'imu-1',
      displayName: 'Frame IMU',
      xMeters: 0.41,
      yMeters: -0.03,
      zMeters: 0.72,
      rollDegrees: 1,
      pitchDegrees: 2,
      yawDegrees: 3,
      updatedAt: DateTime.utc(2026, 8, 13),
    );
    final restored = AppSettings.fromJson(
      defaults.copyWith(sensorPoses: <SensorPose>[pose]).toJson(),
    );

    expect(restored.sensorPoses.single.sensorId, 'imu-1');
    expect(restored.sensorPoses.single.updatedAt, pose.updatedAt);
    expect(
      restored.sensorPoses.single.toJson()['referenceFrame'],
      'rear_wheel_axle_x_forward_y_left_z_up',
    );
  });
}
