import 'dart:async';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../../models/app_settings.dart';
import '../../models/data_record.dart';

enum OtmConnectionState { disabled, connecting, connected, error }

class OtmStatus {
  const OtmStatus({
    required this.state,
    required this.attempted,
    required this.successful,
    required this.failed,
    required this.lastError,
  });

  factory OtmStatus.disabled() => const OtmStatus(
    state: OtmConnectionState.disabled,
    attempted: 0,
    successful: 0,
    failed: 0,
    lastError: null,
  );

  final OtmConnectionState state;
  final int attempted;
  final int successful;
  final int failed;
  final String? lastError;

  OtmStatus copyWith({
    OtmConnectionState? state,
    int? attempted,
    int? successful,
    int? failed,
    String? lastError,
    bool clearError = false,
  }) {
    return OtmStatus(
      state: state ?? this.state,
      attempted: attempted ?? this.attempted,
      successful: successful ?? this.successful,
      failed: failed ?? this.failed,
      lastError: clearError ? null : lastError ?? this.lastError,
    );
  }
}

abstract interface class OtmPublisher {
  Stream<OtmStatus> get statuses;
  OtmStatus get currentStatus;

  Future<void> configure(OtmConfiguration configuration);
  Future<void> publish(ObuDataRecord record, {required bool replayActive});
  Future<void> dispose();
}

class MqttOtmPublisher implements OtmPublisher {
  final _statusController = StreamController<OtmStatus>.broadcast(sync: true);
  MqttServerClient? _client;
  OtmConfiguration _configuration = AppSettings.defaults().otm;
  OtmStatus _status = OtmStatus.disabled();

  @override
  Stream<OtmStatus> get statuses => _statusController.stream;

  @override
  OtmStatus get currentStatus => _status;

  @override
  Future<void> configure(OtmConfiguration configuration) async {
    if (!RegExp(r'^[a-z0-9_-]{3,64}$').hasMatch(configuration.nodeId)) {
      throw const FormatException('Invalid OpenTrafficMap node ID.');
    }
    _configuration = configuration;
    await _disconnect();
    if (!configuration.enabled) {
      _setStatus(
        _status.copyWith(state: OtmConnectionState.disabled, clearError: true),
      );
      return;
    }
    _setStatus(
      _status.copyWith(state: OtmConnectionState.connecting, clearError: true),
    );
    final client =
        MqttServerClient.withPort(
            configuration.host,
            'bicycle-obu-' + configuration.nodeId,
            configuration.port,
          )
          ..secure = true
          ..keepAlivePeriod = 30
          ..logging(on: false)
          ..onDisconnected = () {
            if (_configuration.enabled) {
              _setStatus(
                _status.copyWith(
                  state: OtmConnectionState.error,
                  lastError: 'MQTT connection closed.',
                ),
              );
            }
          };
    client.setProtocolV311();
    client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier('bicycle-obu-' + configuration.nodeId)
        .startClean()
        .withWillTopic('its/' + configuration.nodeId + '/status')
        .withWillMessage('offline')
        .withWillQos(MqttQos.atMostOnce)
        .withWillRetain();
    _client = client;
    try {
      await client.connect();
      if (client.connectionStatus?.state != MqttConnectionState.connected) {
        throw StateError(
          client.connectionStatus?.returnCode.toString() ??
              'Unknown MQTT connection failure',
        );
      }
      _setStatus(
        _status.copyWith(state: OtmConnectionState.connected, clearError: true),
      );
      _publishText(
        'its/' + configuration.nodeId + '/status',
        'online',
        retain: true,
      );
      _publishText(
        'its/' + configuration.nodeId + '/info',
        'BicycleOBU Flutter app',
      );
    } catch (error) {
      _setStatus(
        _status.copyWith(
          state: OtmConnectionState.error,
          lastError: error.toString(),
        ),
      );
      client.disconnect();
    }
  }

  @override
  Future<void> publish(
    ObuDataRecord record, {
    required bool replayActive,
  }) async {
    if (!_configuration.enabled || replayActive || !record.mayUploadToOtm) {
      return;
    }
    final nextAttempt = _status.attempted + 1;
    final client = _client;
    if (client?.connectionStatus?.state != MqttConnectionState.connected ||
        record.rawBytes == null) {
      _setStatus(
        _status.copyWith(
          attempted: nextAttempt,
          failed: _status.failed + 1,
          lastError: 'Live frame dropped because the OTM uplink was offline.',
        ),
      );
      return;
    }
    try {
      final payload = MqttClientPayloadBuilder()..addBuffer(record.rawBytes!);
      client!.publishMessage(
        'its/' + _configuration.nodeId + '/packet',
        MqttQos.atMostOnce,
        payload.payload!,
        retain: false,
      );
      _setStatus(
        _status.copyWith(
          attempted: nextAttempt,
          successful: _status.successful + 1,
          clearError: true,
        ),
      );
    } catch (error) {
      _setStatus(
        _status.copyWith(
          attempted: nextAttempt,
          failed: _status.failed + 1,
          lastError: error.toString(),
        ),
      );
    }
  }

  void _publishText(String topic, String text, {bool retain = false}) {
    final client = _client;
    if (client?.connectionStatus?.state != MqttConnectionState.connected) {
      return;
    }
    final payload = MqttClientPayloadBuilder()..addString(text);
    client!.publishMessage(
      topic,
      MqttQos.atMostOnce,
      payload.payload!,
      retain: retain,
    );
  }

  Future<void> _disconnect() async {
    final client = _client;
    if (client == null) return;
    if (client.connectionStatus?.state == MqttConnectionState.connected) {
      _publishText(
        'its/' + _configuration.nodeId + '/status',
        'offline',
        retain: true,
      );
    }
    client.disconnect();
    _client = null;
  }

  void _setStatus(OtmStatus value) {
    _status = value;
    if (!_statusController.isClosed) _statusController.add(value);
  }

  @override
  Future<void> dispose() async {
    await _disconnect();
    await _statusController.close();
  }
}
