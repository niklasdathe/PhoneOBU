import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class DbcSignal {
  const DbcSignal({
    required this.name,
    required this.startBit,
    required this.bitLength,
    required this.littleEndian,
    required this.signed,
    required this.factor,
    required this.offset,
    required this.unit,
  });

  final String name;
  final int startBit;
  final int bitLength;
  final bool littleEndian;
  final bool signed;
  final double factor;
  final double offset;
  final String unit;
}

class DbcMessage {
  const DbcMessage({
    required this.id,
    required this.name,
    required this.dlc,
    required this.signals,
  });

  final int id;
  final String name;
  final int dlc;
  final List<DbcSignal> signals;
}

class DbcDefinition {
  const DbcDefinition({
    required this.fileName,
    required this.hash,
    required this.enabled,
    required this.importedAt,
    required this.messages,
  });

  final String fileName;
  final String hash;
  final bool enabled;
  final DateTime importedAt;
  final List<DbcMessage> messages;

  DbcDefinition copyWith({bool? enabled}) {
    return DbcDefinition(
      fileName: fileName,
      hash: hash,
      enabled: enabled ?? this.enabled,
      importedAt: importedAt,
      messages: messages,
    );
  }

  Map<String, Object?> toManifestJson() => <String, Object?>{
        'fileName': fileName,
        'hash': hash,
        'enabled': enabled,
        'importedAt': importedAt.toUtc().toIso8601String(),
      };
}

class DecodedCanSignal {
  const DecodedCanSignal({
    required this.databaseHash,
    required this.messageName,
    required this.signalName,
    required this.value,
    required this.unit,
  });

  final String databaseHash;
  final String messageName;
  final String signalName;
  final double value;
  final String unit;
}

class DbcCatalog {
  List<DbcDefinition> _definitions = const <DbcDefinition>[];
  Directory? _directory;

  List<DbcDefinition> get definitions =>
      List<DbcDefinition>.unmodifiable(_definitions);

  Future<void> initialize() async {
    final support = await getApplicationSupportDirectory();
    _directory = Directory(support.path + '/dbc');
    await _directory!.create(recursive: true);
    final manifest = File(_directory!.path + '/manifest.json');
    if (!await manifest.exists()) return;
    try {
      final decoded = jsonDecode(await manifest.readAsString());
      if (decoded is! List<Object?>) return;
      final loaded = <DbcDefinition>[];
      for (final item in decoded.whereType<Map<Object?, Object?>>()) {
        final fileName = item['fileName']?.toString();
        if (fileName == null) continue;
        final file = File(_directory!.path + '/' + fileName);
        if (!await file.exists()) continue;
        final bytes = await file.readAsBytes();
        loaded.add(
          _parse(
            fileName,
            bytes,
            enabled: item['enabled'] != false,
            importedAt:
                DateTime.tryParse(item['importedAt']?.toString() ?? '') ??
                    DateTime.now(),
          ),
        );
      }
      _definitions = loaded;
    } catch (_) {
      _definitions = const <DbcDefinition>[];
    }
  }

  Future<DbcDefinition?> importFromPicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['dbc'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final bytes = file.bytes ??
        (file.path == null ? null : await File(file.path!).readAsBytes());
    if (bytes == null) throw StateError('The selected DBC could not be read.');
    return importBytes(file.name, bytes);
  }

  Future<DbcDefinition> importBytes(String fileName, Uint8List bytes) async {
    await _ensureInitialized();
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
    final definition = _parse(
      safeName,
      bytes,
      enabled: true,
      importedAt: DateTime.now(),
    );
    final replaced = _definitions
        .where(
          (item) => item.hash == definition.hash || item.fileName == safeName,
        )
        .toList(growable: false);
    for (final item in replaced) {
      final previousFile = File(_directory!.path + '/' + item.fileName);
      if (await previousFile.exists()) await previousFile.delete();
    }
    await File(_directory!.path + '/' + safeName).writeAsBytes(
      bytes,
      flush: true,
    );
    _definitions = <DbcDefinition>[
      ..._definitions.where(
        (item) => item.hash != definition.hash && item.fileName != safeName,
      ),
      definition,
    ];
    await _saveManifest();
    return definition;
  }

  DbcDefinition parseBytes(String fileName, Uint8List bytes) {
    return _parse(
      fileName,
      bytes,
      enabled: true,
      importedAt: DateTime.now(),
    );
  }

  Future<void> setEnabled(String hash, bool enabled) async {
    _definitions = _definitions
        .map((item) => item.hash == hash ? item.copyWith(enabled: enabled) : item)
        .toList(growable: false);
    await _saveManifest();
  }

  Future<void> remove(String hash) async {
    await _ensureInitialized();
    final matches = _definitions.where((item) => item.hash == hash).toList();
    for (final match in matches) {
      final file = File(_directory!.path + '/' + match.fileName);
      if (await file.exists()) await file.delete();
    }
    _definitions =
        _definitions.where((item) => item.hash != hash).toList(growable: false);
    await _saveManifest();
  }

  List<DecodedCanSignal> decode(int identifier, Uint8List payload) {
    return _decodeDefinitions(
      _definitions.where((item) => item.enabled),
      identifier,
      payload,
    );
  }

  List<DecodedCanSignal> decodeWithDefinition(
    DbcDefinition definition,
    int identifier,
    Uint8List payload,
  ) {
    return _decodeDefinitions(<DbcDefinition>[definition], identifier, payload);
  }

  List<DecodedCanSignal> _decodeDefinitions(
    Iterable<DbcDefinition> definitions,
    int identifier,
    Uint8List payload,
  ) {
    final results = <DecodedCanSignal>[];
    for (final definition in definitions) {
      for (final message
          in definition.messages.where((item) => item.id == identifier)) {
        for (final signal in message.signals) {
          final raw = signal.littleEndian
              ? _readLittleEndian(payload, signal.startBit, signal.bitLength)
              : _readBigEndian(payload, signal.startBit, signal.bitLength);
          var signedRaw = raw;
          if (signal.signed && signal.bitLength < 64) {
            final signBit = 1 << (signal.bitLength - 1);
            if ((raw & signBit) != 0) {
              signedRaw = raw - (1 << signal.bitLength);
            }
          }
          results.add(
            DecodedCanSignal(
              databaseHash: definition.hash,
              messageName: message.name,
              signalName: signal.name,
              value: signedRaw * signal.factor + signal.offset,
              unit: signal.unit,
            ),
          );
        }
      }
    }
    return results;
  }

  DbcDefinition _parse(
    String fileName,
    Uint8List bytes, {
    required bool enabled,
    required DateTime importedAt,
  }) {
    final text = utf8.decode(bytes, allowMalformed: true);
    final messagePattern = RegExp(r'^BO_\s+(\d+)\s+([A-Za-z0-9_]+):\s+(\d+)\s+.*$');
    final signalPattern = RegExp(
      r'^\s*SG_\s+([A-Za-z0-9_]+)(?:\s+[Mm]\d+)?\s*:\s*(\d+)\|(\d+)@([01])([+-])\s+\(([-+0-9.eE]+),([-+0-9.eE]+)\)\s+\[[^\]]*\]\s+"([^"]*)"',
    );
    final messages = <DbcMessage>[];
    int? currentId;
    String? currentName;
    int? currentDlc;
    var signals = <DbcSignal>[];

    void finishMessage() {
      if (currentId == null || currentName == null || currentDlc == null) return;
      messages.add(
        DbcMessage(
          id: currentId!,
          name: currentName!,
          dlc: currentDlc!,
          signals: List<DbcSignal>.unmodifiable(signals),
        ),
      );
    }

    for (final line in const LineSplitter().convert(text)) {
      final messageMatch = messagePattern.firstMatch(line);
      if (messageMatch != null) {
        finishMessage();
        currentId = int.parse(messageMatch.group(1)!);
        currentName = messageMatch.group(2)!;
        currentDlc = int.parse(messageMatch.group(3)!);
        signals = <DbcSignal>[];
        continue;
      }
      final signalMatch = signalPattern.firstMatch(line);
      if (signalMatch == null || currentId == null) continue;
      signals.add(
        DbcSignal(
          name: signalMatch.group(1)!,
          startBit: int.parse(signalMatch.group(2)!),
          bitLength: int.parse(signalMatch.group(3)!),
          littleEndian: signalMatch.group(4) == '1',
          signed: signalMatch.group(5) == '-',
          factor: double.parse(signalMatch.group(6)!),
          offset: double.parse(signalMatch.group(7)!),
          unit: signalMatch.group(8)!,
        ),
      );
    }
    finishMessage();
    if (messages.isEmpty) {
      throw const FormatException('The selected file contains no DBC messages.');
    }
    return DbcDefinition(
      fileName: fileName,
      hash: sha256.convert(bytes).toString(),
      enabled: enabled,
      importedAt: importedAt,
      messages: messages,
    );
  }

  int _readLittleEndian(Uint8List bytes, int startBit, int length) {
    var value = 0;
    for (var bit = 0; bit < length; bit++) {
      final sourceBit = startBit + bit;
      final byteIndex = sourceBit ~/ 8;
      if (byteIndex >= bytes.length) break;
      final bitValue = (bytes[byteIndex] >> (sourceBit % 8)) & 1;
      value |= bitValue << bit;
    }
    return value;
  }

  int _readBigEndian(Uint8List bytes, int startBit, int length) {
    var value = 0;
    var bitIndex = startBit;
    for (var bit = 0; bit < length; bit++) {
      final byteIndex = bitIndex ~/ 8;
      if (byteIndex >= bytes.length) break;
      final bitInByte = bitIndex % 8;
      value = (value << 1) | ((bytes[byteIndex] >> bitInByte) & 1);
      bitIndex = bitInByte == 0 ? bitIndex + 15 : bitIndex - 1;
    }
    return value;
  }

  Future<void> _ensureInitialized() async {
    if (_directory == null) await initialize();
  }

  Future<void> _saveManifest() async {
    await _ensureInitialized();
    final manifest = File(_directory!.path + '/manifest.json');
    await manifest.writeAsString(
      jsonEncode(_definitions.map((item) => item.toManifestJson()).toList()),
      flush: true,
    );
  }
}
