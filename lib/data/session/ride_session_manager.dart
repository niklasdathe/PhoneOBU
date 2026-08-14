import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/app_settings.dart';
import '../../models/data_record.dart';
import '../../models/obu_snapshot.dart';
import '../../models/phone_sensor_snapshot.dart';
import '../dbc/dbc_catalog.dart';

class RideSessionSummary {
  const RideSessionSummary({
    required this.id,
    required this.path,
    required this.startedAt,
    required this.endedAt,
    required this.sizeBytes,
  });

  final String id;
  final String path;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int sizeBytes;

  Duration get duration => (endedAt ?? startedAt).difference(startedAt);
}

class ReplayFrame {
  const ReplayFrame({this.obuSnapshot, this.phoneSensors, this.dataRecord});

  final ObuSnapshot? obuSnapshot;
  final PhoneSensorSnapshot? phoneSensors;
  final ObuDataRecord? dataRecord;
}

class ReplayStatus {
  const ReplayStatus({
    required this.active,
    required this.playing,
    required this.speed,
    required this.position,
    required this.duration,
    required this.session,
  });

  factory ReplayStatus.idle() => const ReplayStatus(
    active: false,
    playing: false,
    speed: 1,
    position: Duration.zero,
    duration: Duration.zero,
    session: null,
  );

  final bool active;
  final bool playing;
  final double speed;
  final Duration position;
  final Duration duration;
  final RideSessionSummary? session;

  ReplayStatus copyWith({
    bool? active,
    bool? playing,
    double? speed,
    Duration? position,
    Duration? duration,
    RideSessionSummary? session,
    bool clearSession = false,
  }) {
    return ReplayStatus(
      active: active ?? this.active,
      playing: playing ?? this.playing,
      speed: speed ?? this.speed,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      session: clearSession ? null : session ?? this.session,
    );
  }
}

class RideSessionManager {
  final _sessionController =
      StreamController<List<RideSessionSummary>>.broadcast(sync: true);
  final _replayFrameController = StreamController<ReplayFrame>.broadcast(
    sync: true,
  );
  final _replayStatusController = StreamController<ReplayStatus>.broadcast(
    sync: true,
  );

  Directory? _directory;
  IOSink? _sink;
  List<RideSessionSummary> _sessions = const <RideSessionSummary>[];
  List<_ReplayEntry> _replayEntries = const <_ReplayEntry>[];
  ReplayStatus _replayStatus = ReplayStatus.idle();
  Timer? _replayTimer;
  Timer? _flushTimer;
  DateTime? _lastReplayTick;
  int _replayIndex = 0;

  Stream<List<RideSessionSummary>> get sessions => _sessionController.stream;
  Stream<ReplayFrame> get replayFrames => _replayFrameController.stream;
  Stream<ReplayStatus> get replayStatuses => _replayStatusController.stream;
  List<RideSessionSummary> get currentSessions => _sessions;
  ReplayStatus get replayStatus => _replayStatus;
  bool get isRecording => _sink != null;
  bool get replayActive => _replayStatus.active;

  Future<void> initialize() async {
    final documents = await getApplicationDocumentsDirectory();
    _directory = Directory(documents.path + '/BicycleOBU/sessions');
    await _directory!.create(recursive: true);
    await _refreshSessions();
  }

  Future<void> start({
    required AppSettings settings,
    required List<DbcDefinition> dbcDefinitions,
    required TransportDiagnostics transport,
    required String routingProvider,
    required String routingProfile,
  }) async {
    if (_sink != null) return;
    await _ensureInitialized();
    final now = DateTime.now().toUtc();
    final id = now.toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final file = File(_directory!.path + '/ride-' + id + '.jsonl');
    final package = await PackageInfo.fromPlatform();
    _sink = file.openWrite(mode: FileMode.write);
    _write(<String, Object?>{
      'schema': 'org.bicycleobu.session',
      'schemaVersion': 1,
      'kind': 'session_header',
      'timestamp': now.toIso8601String(),
      'sessionId': id,
      'provenance': <String, Object?>{
        'appName': package.appName,
        'appVersion': package.version,
        'appBuild': package.buildNumber,
        'transportProtocolVersion': transport.protocolVersion,
        'transportName': transport.transportName,
        'firmwareVersions': <String, String>{
          's3': transport.s3FirmwareVersion,
          'c5': transport.c5FirmwareVersion,
        },
        'settings': settings.toJson(),
        'dbcDefinitions': dbcDefinitions
            .map((value) => value.toManifestJson())
            .toList(growable: false),
        'routing': <String, String>{
          'provider': routingProvider,
          'profile': routingProfile,
        },
        'clockSynchronization': <String, Object?>{
          'state': transport.clockSyncState,
          'quality': transport.clockSyncQuality,
          'phoneTimeline': 'platform_native_acquisition_timestamps',
        },
        'bicycleReferenceFrame':
            'rear wheel axle origin; x forward, y left, z up; right handed',
      },
    });
    await _sink!.flush();
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final activeSink = _sink;
      if (activeSink != null) unawaited(activeSink.flush());
    });
    await _refreshSessions();
  }

  void recordObuSnapshot(ObuSnapshot snapshot) {
    _write(<String, Object?>{
      'kind': 'obu_snapshot',
      'timestamp': snapshot.receivedAt.toUtc().toIso8601String(),
      'source': 'app_live_model',
      'provenance': 'derived',
      'data': snapshot.toJson(),
    });
  }

  void recordPhoneSensors(PhoneSensorSnapshot snapshot) {
    _write(<String, Object?>{
      'kind': 'phone_sensors',
      'timestamp': snapshot.updatedAt.toUtc().toIso8601String(),
      'source': 'phone',
      'provenance': 'mixed_raw_and_os_fused',
      'data': snapshot.toJson(),
    });
  }

  void recordData(ObuDataRecord record) {
    _write(<String, Object?>{
      'kind': 'data_record',
      'timestamp': record.acquisitionTime.toUtc().toIso8601String(),
      'data': record.toJson(),
    });
  }

  void recordSystemEvent(String event, Map<String, Object?> data) {
    _write(<String, Object?>{
      'kind': 'system_event',
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'event': event,
      'data': data,
    });
  }

  Future<void> stop() async {
    final sink = _sink;
    if (sink == null) return;
    _flushTimer?.cancel();
    _flushTimer = null;
    _write(<String, Object?>{
      'kind': 'session_footer',
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'status': 'closed_cleanly',
    });
    _sink = null;
    await sink.flush();
    await sink.close();
    await _refreshSessions();
  }

  Future<File> exportCsv(RideSessionSummary session) async {
    final lines = await File(session.path).readAsLines();
    final output = File(session.path.replaceFirst('.jsonl', '.csv'));
    final sink = output.openWrite();
    sink.writeln(
      'acquisition_time,arrival_time,channel,source,origin,provenance,sequence,payload_json,raw_base64',
    );
    for (final line in lines) {
      final row = _decodeLine(line);
      if (row?['kind'] != 'data_record') continue;
      final data = _objectMap(row!['data']);
      final payload = jsonEncode(data['payload']);
      sink.writeln(
        <String>[
          data['acquisitionTime']?.toString() ?? '',
          data['arrivalTime']?.toString() ?? '',
          data['channel']?.toString() ?? '',
          data['source']?.toString() ?? '',
          data['origin']?.toString() ?? '',
          data['provenance']?.toString() ?? '',
          data['sequence']?.toString() ?? '',
          payload,
          data['rawBase64']?.toString() ?? '',
        ].map(_csv).join(','),
      );
    }
    await sink.flush();
    await sink.close();
    return output;
  }

  Future<File> exportPcapng(RideSessionSummary session) async {
    final lines = await File(session.path).readAsLines();
    final builder = BytesBuilder(copy: false)
      ..add(_sectionHeaderBlock())
      ..add(_interfaceDescriptionBlock());
    for (final line in lines) {
      final row = _decodeLine(line);
      if (row?['kind'] != 'data_record') continue;
      final data = _objectMap(row!['data']);
      if (data['isRawV2x'] != true || data['rawBase64'] == null) continue;
      final bytes = base64Decode(data['rawBase64'].toString());
      final timestamp = DateTime.parse(
        data['acquisitionTime'].toString(),
      ).toUtc();
      builder.add(_enhancedPacketBlock(timestamp, bytes));
    }
    final output = File(session.path.replaceFirst('.jsonl', '.pcapng'));
    await output.writeAsBytes(builder.takeBytes(), flush: true);
    return output;
  }

  Future<void> loadReplay(RideSessionSummary session) async {
    await pauseReplay();
    final rows = await File(session.path).readAsLines();
    final entries = <_ReplayEntry>[];
    for (final line in rows) {
      final row = _decodeLine(line);
      if (row == null) continue;
      final kind = row['kind']?.toString();
      if (kind != 'obu_snapshot' &&
          kind != 'phone_sensors' &&
          kind != 'data_record') {
        continue;
      }
      final timestamp = DateTime.tryParse(row['timestamp']?.toString() ?? '');
      if (timestamp == null) continue;
      entries.add(_ReplayEntry(timestamp: timestamp, value: row));
    }
    entries.sort((left, right) => left.timestamp.compareTo(right.timestamp));
    _replayEntries = entries;
    _replayIndex = 0;
    final duration = entries.length < 2
        ? Duration.zero
        : entries.last.timestamp.difference(entries.first.timestamp);
    _setReplayStatus(
      ReplayStatus(
        active: true,
        playing: false,
        speed: 1,
        position: Duration.zero,
        duration: duration,
        session: session,
      ),
    );
    _emitReplayUntil(Duration.zero);
  }

  Future<void> playReplay() async {
    if (!_replayStatus.active || _replayEntries.isEmpty) return;
    _lastReplayTick = DateTime.now();
    _setReplayStatus(_replayStatus.copyWith(playing: true));
    _replayTimer ??= Timer.periodic(
      const Duration(milliseconds: 50),
      (_) => _tickReplay(),
    );
  }

  Future<void> pauseReplay() async {
    _replayTimer?.cancel();
    _replayTimer = null;
    _lastReplayTick = null;
    if (_replayStatus.active) {
      _setReplayStatus(_replayStatus.copyWith(playing: false));
    }
  }

  Future<void> stopReplay() async {
    await pauseReplay();
    _replayEntries = const <_ReplayEntry>[];
    _replayIndex = 0;
    _setReplayStatus(ReplayStatus.idle());
  }

  void setReplaySpeed(double speed) {
    _setReplayStatus(
      _replayStatus.copyWith(speed: speed.clamp(0.25, 16).toDouble()),
    );
  }

  void seekReplay(Duration position) {
    if (!_replayStatus.active || _replayEntries.isEmpty) return;
    final clampedMicros = position.inMicroseconds
        .clamp(0, _replayStatus.duration.inMicroseconds)
        .toInt();
    final clamped = Duration(microseconds: clampedMicros);
    _replayIndex = 0;
    _setReplayStatus(_replayStatus.copyWith(position: clamped));
    _emitReplayUntil(clamped);
    _lastReplayTick = DateTime.now();
  }

  void _tickReplay() {
    if (!_replayStatus.playing) return;
    final now = DateTime.now();
    final elapsed = now.difference(_lastReplayTick ?? now);
    _lastReplayTick = now;
    final advanced = Duration(
      microseconds: (elapsed.inMicroseconds * _replayStatus.speed).round(),
    );
    final next = _replayStatus.position + advanced;
    if (next >= _replayStatus.duration) {
      _emitReplayUntil(_replayStatus.duration);
      pauseReplay();
      return;
    }
    _emitReplayUntil(next);
  }

  void _emitReplayUntil(Duration position) {
    if (_replayEntries.isEmpty) return;
    final first = _replayEntries.first.timestamp;
    while (_replayIndex < _replayEntries.length) {
      final entry = _replayEntries[_replayIndex];
      if (entry.timestamp.difference(first) > position) break;
      final kind = entry.value['kind'];
      final data = _objectMap(entry.value['data']);
      if (kind == 'obu_snapshot') {
        _replayFrameController.add(
          ReplayFrame(
            obuSnapshot: ObuSnapshot.fromJson(
              data,
            ).copyWith(freshness: DataFreshness.replay),
          ),
        );
      } else if (kind == 'phone_sensors') {
        _replayFrameController.add(
          ReplayFrame(phoneSensors: PhoneSensorSnapshot.fromJson(data)),
        );
      } else if (kind == 'data_record') {
        final record = ObuDataRecord.fromJson(data);
        _replayFrameController.add(
          ReplayFrame(
            dataRecord: ObuDataRecord(
              channel: record.channel,
              source: record.source,
              acquisitionTime: record.acquisitionTime,
              arrivalTime: DateTime.now(),
              sequence: record.sequence,
              origin: RecordOrigin.replay,
              provenance: record.provenance,
              payload: record.payload,
              rawBytes: record.rawBytes,
              isRawV2x: record.isRawV2x,
            ),
          ),
        );
      }
      _replayIndex++;
    }
    _setReplayStatus(_replayStatus.copyWith(position: position));
  }

  void _write(Map<String, Object?> value) {
    _sink?.writeln(jsonEncode(value));
  }

  Future<void> _refreshSessions() async {
    await _ensureInitialized();
    final files = await _directory!
        .list()
        .where((entry) => entry is File && entry.path.endsWith('.jsonl'))
        .cast<File>()
        .toList();
    final summaries = <RideSessionSummary>[];
    for (final file in files) {
      DateTime? startedAt;
      DateTime? endedAt;
      await for (final line
          in file
              .openRead()
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        final row = _decodeLine(line);
        if (row == null) continue;
        final timestamp = DateTime.tryParse(row['timestamp']?.toString() ?? '');
        if (timestamp == null) continue;
        startedAt ??= timestamp;
        endedAt = timestamp;
      }
      final stat = await file.stat();
      final start = startedAt ?? stat.modified.toUtc();
      summaries.add(
        RideSessionSummary(
          id: file.uri.pathSegments.last.replaceAll('.jsonl', ''),
          path: file.path,
          startedAt: start,
          endedAt: endedAt,
          sizeBytes: stat.size,
        ),
      );
    }
    summaries.sort((left, right) => right.startedAt.compareTo(left.startedAt));
    _sessions = List<RideSessionSummary>.unmodifiable(summaries);
    if (!_sessionController.isClosed) _sessionController.add(_sessions);
  }

  Map<String, Object?>? _decodeLine(String line) {
    try {
      final value = jsonDecode(line);
      if (value is Map<String, dynamic>) {
        return value.cast<String, Object?>();
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Map<String, Object?> _objectMap(Object? value) {
    if (value is! Map<Object?, Object?>) return const <String, Object?>{};
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  String _csv(String value) => '"' + value.replaceAll('"', '""') + '"';

  Uint8List _sectionHeaderBlock() {
    final bytes = Uint8List(28);
    ByteData.sublistView(bytes)
      ..setUint32(0, 0x0A0D0D0A, Endian.little)
      ..setUint32(4, 28, Endian.little)
      ..setUint32(8, 0x1A2B3C4D, Endian.little)
      ..setUint16(12, 1, Endian.little)
      ..setUint16(14, 0, Endian.little)
      ..setUint64(16, 0xFFFFFFFFFFFFFFFF, Endian.little)
      ..setUint32(24, 28, Endian.little);
    return bytes;
  }

  Uint8List _interfaceDescriptionBlock() {
    final bytes = Uint8List(20);
    ByteData.sublistView(bytes)
      ..setUint32(0, 1, Endian.little)
      ..setUint32(4, 20, Endian.little)
      ..setUint16(8, 105, Endian.little)
      ..setUint16(10, 0, Endian.little)
      ..setUint32(12, 65535, Endian.little)
      ..setUint32(16, 20, Endian.little);
    return bytes;
  }

  Uint8List _enhancedPacketBlock(DateTime timestamp, Uint8List packet) {
    final paddedLength = (packet.length + 3) & ~3;
    final blockLength = 32 + paddedLength;
    final bytes = Uint8List(blockLength);
    final micros = timestamp.microsecondsSinceEpoch;
    ByteData.sublistView(bytes)
      ..setUint32(0, 6, Endian.little)
      ..setUint32(4, blockLength, Endian.little)
      ..setUint32(8, 0, Endian.little)
      ..setUint32(12, (micros >> 32) & 0xffffffff, Endian.little)
      ..setUint32(16, micros & 0xffffffff, Endian.little)
      ..setUint32(20, packet.length, Endian.little)
      ..setUint32(24, packet.length, Endian.little)
      ..setUint32(blockLength - 4, blockLength, Endian.little);
    bytes.setRange(28, 28 + packet.length, packet);
    return bytes;
  }

  void _setReplayStatus(ReplayStatus value) {
    _replayStatus = value;
    if (!_replayStatusController.isClosed) {
      _replayStatusController.add(value);
    }
  }

  Future<void> _ensureInitialized() async {
    if (_directory == null) await initialize();
  }

  Future<void> dispose() async {
    _flushTimer?.cancel();
    await stop();
    await stopReplay();
    await _sessionController.close();
    await _replayFrameController.close();
    await _replayStatusController.close();
  }
}

class _ReplayEntry {
  const _ReplayEntry({required this.timestamp, required this.value});

  final DateTime timestamp;
  final Map<String, Object?> value;
}
