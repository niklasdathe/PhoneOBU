import 'dart:convert';
import 'dart:typed_data';

import 'package:bicycle_obu/protocol/obu_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OBU transport', () {
    test('fragments and reassembles a record larger than the BLE payload', () {
      final payload = Uint8List.fromList(
        utf8.encode('telemetry:${List<String>.filled(40, 'abcdef').join()}'),
      );
      final frames = ObuFrameCodec.encodeMessage(
        source: MessageSource.s3,
        type: MessageType.telemetry,
        messageId: 42,
        startSequence: 100,
        payload: payload,
        maxFragmentPayload: 24,
      );
      expect(frames.length, greaterThan(1));

      final reassembler = ObuMessageReassembler();
      ObuMessage? message;
      for (final frame in frames) {
        message = reassembler.add(frame) ?? message;
      }

      expect(message, isNotNull);
      expect(message!.messageId, 42);
      expect(message.type, MessageType.telemetry);
      expect(message.payload, orderedEquals(payload));
      expect(reassembler.lostSequences, 0);
    });

    test('detects sequence gaps', () {
      final reassembler = ObuMessageReassembler();
      final first = ObuFrameCodec.encodeMessage(
        source: MessageSource.s3,
        type: MessageType.telemetry,
        messageId: 1,
        startSequence: 10,
        payload: Uint8List.fromList(<int>[1]),
      ).single;
      final third = ObuFrameCodec.encodeMessage(
        source: MessageSource.s3,
        type: MessageType.telemetry,
        messageId: 2,
        startSequence: 12,
        payload: Uint8List.fromList(<int>[2]),
      ).single;

      reassembler.add(first);
      reassembler.add(third);
      expect(reassembler.lostSequences, 1);
    });

    test('detects an out-of-order fragment without corrupting stream state', () {
      final reassembler = ObuMessageReassembler();
      Uint8List frame(int sequence, int messageId) {
        return ObuFrameCodec.encodeMessage(
          source: MessageSource.s3,
          type: MessageType.telemetry,
          messageId: messageId,
          startSequence: sequence,
          payload: Uint8List.fromList(<int>[messageId]),
        ).single;
      }

      reassembler.add(frame(10, 1));
      reassembler.add(frame(12, 2));
      reassembler.add(frame(11, 3));
      reassembler.add(frame(13, 4));

      expect(reassembler.lostSequences, 1);
      expect(reassembler.outOfOrderSequences, 1);
    });

    test('rejects a corrupted frame', () {
      final frame = ObuFrameCodec.encodeMessage(
        source: MessageSource.s3,
        type: MessageType.diagnostics,
        messageId: 9,
        startSequence: 3,
        payload: Uint8List.fromList(<int>[1, 2, 3, 4]),
      ).single;
      frame[ObuFrameCodec.headerLength] ^= 0xff;

      expect(
        () => ObuFrameCodec.decodeFrame(frame),
        throwsA(isA<FormatException>()),
      );
    });

    test('fits a complete frame inside the default ATT payload', () {
      final payload = Uint8List.fromList(List<int>.generate(50, (index) => index));
      final frames = ObuFrameCodec.encodeMessage(
        source: MessageSource.phone,
        type: MessageType.command,
        messageId: 3,
        startSequence: 1,
        payload: payload,
        maxFragmentPayload: 4,
      );

      expect(frames, isNotEmpty);
      expect(frames.every((frame) => frame.length <= 20), isTrue);
    });
  });
}
