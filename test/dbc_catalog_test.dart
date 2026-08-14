import 'dart:convert';
import 'dart:typed_data';

import 'package:bicycle_obu/data/dbc/dbc_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses and decodes a standard little-endian DBC signal', () {
    final catalog = DbcCatalog();
    const source = '''
VERSION ""
BO_ 256 Wheel: 8 Node
 SG_ Speed : 0|16@1+ (0.01,0) [0|655.35] "km/h" Node
''';
    final definition = catalog.parseBytes(
      'wheel.dbc',
      Uint8List.fromList(utf8.encode(source)),
    );
    final decoded = catalog.decodeWithDefinition(
      definition,
      256,
      Uint8List.fromList(<int>[0xD2, 0x04]),
    );

    expect(definition.messages.single.name, 'Wheel');
    expect(decoded.single.value, closeTo(12.34, 0.001));
  });

  test('decodes DBC Motorola bit ordering', () {
    final catalog = DbcCatalog();
    const source = '''
VERSION ""
BO_ 512 Status: 8 Node
 SG_ Counter : 7|16@0+ (1,0) [0|65535] "" Node
''';
    final definition = catalog.parseBytes(
      'status.dbc',
      Uint8List.fromList(utf8.encode(source)),
    );
    final decoded = catalog.decodeWithDefinition(
      definition,
      512,
      Uint8List.fromList(<int>[0x12, 0x34]),
    );

    expect(decoded.single.value, 0x1234);
  });
}
