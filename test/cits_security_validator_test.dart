import 'dart:typed_data';

import 'package:bicycle_obu/cits/cits_security_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('absent PKI module is explicit and does not alter the raw frame', () {
    const validator = NoCitsSecurityValidator();
    final raw = Uint8List.fromList(const <int>[0x01, 0x02, 0x03]);
    final before = Uint8List.fromList(raw);

    final result = validator.validate(
      raw,
      const <String, Object?>{'messageSet': 'CAM'},
    );

    expect(result.state, CitsVerificationState.notConfigured);
    expect(raw, orderedEquals(before));
  });
}
