import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

abstract interface class SettingsRepository {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
  Future<void> saveSecureCredential(String key, String? value);
  Future<String?> readSecureCredential(String key);
}

class PersistentSettingsRepository implements SettingsRepository {
  PersistentSettingsRepository({
    SharedPreferencesAsync? preferences,
    FlutterSecureStorage? secureStorage,
  }) : _preferences = preferences ?? SharedPreferencesAsync(),
       _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _settingsKey = 'bicycle_obu.settings.v1';

  final SharedPreferencesAsync _preferences;
  final FlutterSecureStorage _secureStorage;

  @override
  Future<AppSettings> load() async {
    final encoded = await _preferences.getString(_settingsKey);
    if (encoded == null) return AppSettings.defaults();
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is Map<String, dynamic>) {
        return AppSettings.fromJson(decoded.cast<String, Object?>());
      }
    } catch (_) {
      // Corrupt preferences must not prevent a ride from starting.
    }
    return AppSettings.defaults();
  }

  @override
  Future<void> save(AppSettings settings) {
    return _preferences.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  @override
  Future<void> saveSecureCredential(String key, String? value) async {
    if (value == null || value.isEmpty) {
      await _secureStorage.delete(key: key);
    } else {
      await _secureStorage.write(key: key, value: value);
    }
  }

  @override
  Future<String?> readSecureCredential(String key) {
    return _secureStorage.read(key: key);
  }
}
