import 'dart:async';

import '../models/obu_snapshot.dart';
import '../models/data_record.dart';
import 'demo_obu_repository.dart';
import 'universal_ble_obu_repository.dart';

class ObuCommandResult {
  const ObuCommandResult({
    required this.success,
    required this.code,
    required this.message,
    this.state = const <String, Object?>{},
  });

  final bool success;
  final String code;
  final String message;
  final Map<String, Object?> state;
}

abstract class ObuRepository {
  Stream<ObuSnapshot> get snapshots;

  Stream<TransportDiagnostics> get diagnostics;

  Stream<ObuDataRecord> get records;

  void setComfortableMaximumSpeed(double speedKmh);

  Future<void> start();

  Future<ObuCommandResult> sendCommand(
    String command, [
    Map<String, Object?> arguments = const <String, Object?>{},
  ]);

  Future<void> dispose();
}

abstract final class ObuRepositoryFactory {
  static ObuRepository create() {
    const transport = String.fromEnvironment(
      'OBU_TRANSPORT',
      defaultValue: 'demo',
    );

    if (transport.toLowerCase() == 'ble') {
      return UniversalBleObuRepository();
    }
    return DemoObuRepository();
  }
}
