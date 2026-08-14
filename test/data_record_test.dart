import 'dart:typed_data';

import 'package:bicycle_obu/models/data_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ObuDataRecord record(RecordOrigin origin, {bool rawV2x = true}) {
    final now = DateTime.utc(2026, 8, 13, 12);
    return ObuDataRecord(
      channel: rawV2x ? 'v2x/raw' : 'can/raw',
      source: 'c5',
      acquisitionTime: now,
      arrivalTime: now.add(const Duration(milliseconds: 8)),
      sequence: 41,
      origin: origin,
      provenance: RecordProvenance.raw,
      payload: const <String, Object?>{'messageSet': 'DENM'},
      rawBytes: Uint8List.fromList(const <int>[1, 2, 3]),
      isRawV2x: rawV2x,
    );
  }

  test('only exact live raw V2X records are eligible for OTM', () {
    expect(record(RecordOrigin.live).mayUploadToOtm, isTrue);
    expect(record(RecordOrigin.bufferedRecovered).mayUploadToOtm, isFalse);
    expect(record(RecordOrigin.replay).mayUploadToOtm, isFalse);
    expect(record(RecordOrigin.simulation).mayUploadToOtm, isFalse);
    expect(record(RecordOrigin.live, rawV2x: false).mayUploadToOtm, isFalse);
  });

  test('round trip preserves source, times, provenance and raw bytes', () {
    final original = record(RecordOrigin.live);
    final restored = ObuDataRecord.fromJson(original.toJson());

    expect(restored.source, original.source);
    expect(restored.acquisitionTime, original.acquisitionTime);
    expect(restored.arrivalTime, original.arrivalTime);
    expect(restored.provenance, RecordProvenance.raw);
    expect(restored.rawBytes, orderedEquals(original.rawBytes!));
  });
}
