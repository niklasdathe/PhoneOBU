import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

enum MessageSource {
  phone(0),
  s3(1),
  c5(2),
  gnss(3),
  can(4),
  sensor(5);

  const MessageSource(this.value);
  final int value;

  static MessageSource fromValue(int value) {
    return values.firstWhere(
      (entry) => entry.value == value,
      orElse: () => MessageSource.s3,
    );
  }
}

enum MessageType {
  telemetry(1),
  cits(2),
  diagnostics(3),
  command(16),
  response(17);

  const MessageType(this.value);
  final int value;

  static MessageType fromValue(int value) {
    return values.firstWhere(
      (entry) => entry.value == value,
      orElse: () => MessageType.diagnostics,
    );
  }
}

class ObuMessage {
  const ObuMessage({
    required this.version,
    required this.source,
    required this.type,
    required this.messageId,
    required this.payload,
  });

  final int version;
  final MessageSource source;
  final MessageType type;
  final int messageId;
  final Uint8List payload;

  Map<String, Object?> decodeJson() {
    final decoded = jsonDecode(utf8.decode(payload));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('OBU payload is not a JSON object.');
    }
    return decoded.cast<String, Object?>();
  }
}

class ObuFrame {
  const ObuFrame({
    required this.version,
    required this.source,
    required this.type,
    required this.flags,
    required this.sequence,
    required this.messageId,
    required this.fragmentIndex,
    required this.fragmentCount,
    required this.payload,
  });

  final int version;
  final MessageSource source;
  final MessageType type;
  final int flags;
  final int sequence;
  final int messageId;
  final int fragmentIndex;
  final int fragmentCount;
  final Uint8List payload;
}

abstract final class ObuFrameCodec {
  static const int magic = 0xB10B;
  static const int version = 1;
  static const int headerLength = 14;
  static const int crcLength = 2;

  static List<Uint8List> encodeMessage({
    required MessageSource source,
    required MessageType type,
    required int messageId,
    required int startSequence,
    required Uint8List payload,
    int maxFragmentPayload = 160,
  }) {
    if (maxFragmentPayload < 1) {
      throw ArgumentError.value(maxFragmentPayload, 'maxFragmentPayload');
    }
    final count = math.max(1, (payload.length / maxFragmentPayload).ceil());
    if (count > 255) {
      throw ArgumentError('Message needs more than 255 BLE fragments.');
    }

    return List<Uint8List>.generate(count, (index) {
      final start = index * maxFragmentPayload;
      final end = math.min(payload.length, start + maxFragmentPayload);
      final fragment = Uint8List.fromList(payload.sublist(start, end));
      return encodeFrame(
        ObuFrame(
          version: version,
          source: source,
          type: type,
          flags: index == count - 1 ? 0x01 : 0,
          sequence: (startSequence + index) & 0xffff,
          messageId: messageId & 0xffff,
          fragmentIndex: index,
          fragmentCount: count,
          payload: fragment,
        ),
      );
    });
  }

  static Uint8List encodeFrame(ObuFrame frame) {
    final bytes = Uint8List(headerLength + frame.payload.length + crcLength);
    final data = ByteData.sublistView(bytes);
    data.setUint16(0, magic, Endian.little);
    data.setUint8(2, frame.version);
    data.setUint8(3, frame.source.value);
    data.setUint8(4, frame.type.value);
    data.setUint8(5, frame.flags);
    data.setUint16(6, frame.sequence, Endian.little);
    data.setUint16(8, frame.messageId, Endian.little);
    data.setUint8(10, frame.fragmentIndex);
    data.setUint8(11, frame.fragmentCount);
    data.setUint16(12, frame.payload.length, Endian.little);
    bytes.setRange(headerLength, headerLength + frame.payload.length, frame.payload);
    data.setUint16(
      headerLength + frame.payload.length,
      crc16(bytes.sublist(0, headerLength + frame.payload.length)),
      Endian.little,
    );
    return bytes;
  }

  static ObuFrame decodeFrame(Uint8List bytes) {
    if (bytes.length < headerLength + crcLength) {
      throw const FormatException('BLE frame is shorter than the protocol header.');
    }
    final data = ByteData.sublistView(bytes);
    if (data.getUint16(0, Endian.little) != magic) {
      throw const FormatException('BLE frame magic does not match.');
    }
    final payloadLength = data.getUint16(12, Endian.little);
    final expectedLength = headerLength + payloadLength + crcLength;
    if (bytes.length != expectedLength) {
      throw FormatException(
        'BLE frame length ${bytes.length} does not match $expectedLength.',
      );
    }
    final receivedCrc = data.getUint16(expectedLength - crcLength, Endian.little);
    final calculatedCrc = crc16(bytes.sublist(0, expectedLength - crcLength));
    if (receivedCrc != calculatedCrc) {
      throw const FormatException('BLE frame CRC check failed.');
    }

    final fragmentCount = data.getUint8(11);
    final fragmentIndex = data.getUint8(10);
    if (fragmentCount < 1 || fragmentIndex >= fragmentCount) {
      throw const FormatException('BLE fragmentation metadata is invalid.');
    }

    return ObuFrame(
      version: data.getUint8(2),
      source: MessageSource.fromValue(data.getUint8(3)),
      type: MessageType.fromValue(data.getUint8(4)),
      flags: data.getUint8(5),
      sequence: data.getUint16(6, Endian.little),
      messageId: data.getUint16(8, Endian.little),
      fragmentIndex: fragmentIndex,
      fragmentCount: fragmentCount,
      payload: Uint8List.fromList(
        bytes.sublist(headerLength, headerLength + payloadLength),
      ),
    );
  }

  static int crc16(List<int> bytes) {
    var crc = 0xffff;
    for (final byte in bytes) {
      crc ^= byte << 8;
      for (var bit = 0; bit < 8; bit++) {
        crc = (crc & 0x8000) != 0
            ? ((crc << 1) ^ 0x1021) & 0xffff
            : (crc << 1) & 0xffff;
      }
    }
    return crc;
  }
}

class ObuMessageReassembler {
  final Map<String, _PendingMessage> _pending = <String, _PendingMessage>{};
  final Map<String, int> _expectedSequenceByStream = <String, int>{};

  int lostSequences = 0;
  int outOfOrderSequences = 0;

  ObuMessage? add(Uint8List bytes) {
    final frame = ObuFrameCodec.decodeFrame(bytes);
    _trackSequence(frame.source, frame.type, frame.sequence);
    _removeExpired();

    if (frame.fragmentCount == 1) {
      return ObuMessage(
        version: frame.version,
        source: frame.source,
        type: frame.type,
        messageId: frame.messageId,
        payload: frame.payload,
      );
    }

    final key = '${frame.source.value}:${frame.type.value}:${frame.messageId}';
    final pending = _pending.putIfAbsent(
      key,
      () => _PendingMessage(
        version: frame.version,
        source: frame.source,
        type: frame.type,
        messageId: frame.messageId,
        fragmentCount: frame.fragmentCount,
      ),
    );
    if (pending.fragmentCount != frame.fragmentCount) {
      _pending.remove(key);
      throw const FormatException('Fragment count changed within one message.');
    }
    pending.fragments[frame.fragmentIndex] = frame.payload;

    if (pending.fragments.length != pending.fragmentCount) {
      return null;
    }

    final builder = BytesBuilder(copy: false);
    for (var index = 0; index < pending.fragmentCount; index++) {
      final fragment = pending.fragments[index];
      if (fragment == null) {
        return null;
      }
      builder.add(fragment);
    }
    _pending.remove(key);
    return ObuMessage(
      version: pending.version,
      source: pending.source,
      type: pending.type,
      messageId: pending.messageId,
      payload: builder.takeBytes(),
    );
  }

  void _trackSequence(
    MessageSource source,
    MessageType type,
    int sequence,
  ) {
    final stream = '${source.value}:${type.value}';
    final expected = _expectedSequenceByStream[stream];
    if (expected != null && sequence != expected) {
      final forwardDistance = (sequence - expected) & 0xffff;
      if (forwardDistance < 0x8000) {
        lostSequences += forwardDistance;
      } else {
        outOfOrderSequences++;
        return;
      }
    }
    _expectedSequenceByStream[stream] = (sequence + 1) & 0xffff;
  }

  void _removeExpired() {
    final cutoff = DateTime.now().subtract(const Duration(seconds: 5));
    _pending.removeWhere((_, value) => value.createdAt.isBefore(cutoff));
  }
}

class _PendingMessage {
  _PendingMessage({
    required this.version,
    required this.source,
    required this.type,
    required this.messageId,
    required this.fragmentCount,
  });

  final int version;
  final MessageSource source;
  final MessageType type;
  final int messageId;
  final int fragmentCount;
  final DateTime createdAt = DateTime.now();
  final Map<int, Uint8List> fragments = <int, Uint8List>{};
}
