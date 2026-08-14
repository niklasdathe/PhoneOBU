import 'package:flutter/services.dart';

class RideBackgroundService {
  static const _channel = MethodChannel('org.bicycleobu/backgroundRide');

  Future<String> capability() async {
    try {
      return await _channel.invokeMethod<String>('capability') ??
          'unknown_platform_capability';
    } on MissingPluginException {
      return 'not_available_in_this_runner';
    } on PlatformException catch (error) {
      return 'platform_error:' + error.code;
    }
  }

  Future<bool> start() async {
    try {
      return await _channel.invokeMethod<bool>('start') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> stop() async {
    try {
      return await _channel.invokeMethod<bool>('stop') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
