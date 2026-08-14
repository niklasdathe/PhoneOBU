import 'dart:convert';
import 'dart:typed_data';

enum RecordOrigin { live, bufferedRecovered, replay, simulation }

enum RecordProvenance { raw, measured, osFused, filtered, derived, event }

class ObuDataRecord {
  const ObuDataRecord({
    required this.channel,
    required this.source,
    required this.acquisitionTime,
    required this.arrivalTime,
    required this.sequence,
    required this.origin,
    required this.provenance,
    required this.payload,
    required this.rawBytes,
    required this.isRawV2x,
  });

  final String channel;
  final String source;
  final DateTime acquisitionTime;
  final DateTime arrivalTime;
  final int? sequence;
  final RecordOrigin origin;
  final RecordProvenance provenance;
  final Map<String, Object?> payload;
  final Uint8List? rawBytes;
  final bool isRawV2x;

  bool get mayUploadToOtm => isRawV2x && origin == RecordOrigin.live;

  Map<String, Object?> toJson() => <String, Object?>{
    'channel': channel,
    'source': source,
    'acquisitionTime': acquisitionTime.toUtc().toIso8601String(),
    'arrivalTime': arrivalTime.toUtc().toIso8601String(),
    'sequence': sequence,
    'origin': origin.name,
    'provenance': provenance.name,
    'payload': payload,
    if (rawBytes != null) 'rawBase64': base64Encode(rawBytes!),
    'isRawV2x': isRawV2x,
  };

  factory ObuDataRecord.fromJson(Map<String, Object?> json) {
    final raw = json['rawBase64']?.toString();
    return ObuDataRecord(
      channel: json['channel']?.toString() ?? 'unknown',
      source: json['source']?.toString() ?? 'unknown',
      acquisitionTime: DateTime.parse(json['acquisitionTime'].toString()),
      arrivalTime: DateTime.parse(json['arrivalTime'].toString()),
      sequence: (json['sequence'] as num?)?.round(),
      origin: RecordOrigin.values.firstWhere(
        (value) => value.name == json['origin'],
        orElse: () => RecordOrigin.replay,
      ),
      provenance: RecordProvenance.values.firstWhere(
        (value) => value.name == json['provenance'],
        orElse: () => RecordProvenance.event,
      ),
      payload: json['payload'] is Map<Object?, Object?>
          ? (json['payload']! as Map<Object?, Object?>).map(
              (key, value) => MapEntry(key.toString(), value),
            )
          : const <String, Object?>{},
      rawBytes: raw == null ? null : base64Decode(raw),
      isRawV2x: json['isRawV2x'] == true,
    );
  }
}
