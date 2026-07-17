import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

class SmartReminderService {
  static const MethodChannel _channel = MethodChannel(
    'mindpulse/smart_reminders',
  );

  Future<Map<String, dynamic>?> getConfiguration() async {
    _requireAndroid();

    final jsonText = await _channel.invokeMethod<String>('getConfiguration');

    if (jsonText == null || jsonText.trim().isEmpty) {
      return null;
    }

    final decoded = jsonDecode(jsonText);

    if (decoded is! Map) {
      return null;
    }

    return Map<String, dynamic>.from(decoded);
  }

  Future<void> saveConfiguration(Map<String, dynamic> configuration) async {
    _requireAndroid();

    await _channel.invokeMethod<void>('saveConfiguration', <String, dynamic>{
      'configJson': jsonEncode(configuration),
    });
  }

  Future<void> runCheckNow() async {
    _requireAndroid();

    await _channel.invokeMethod<void>('runCheckNow');
  }

  Future<Map<String, dynamic>> getStatus() async {
    _requireAndroid();

    final response = await _channel.invokeMethod<Map>('getStatus');

    return Map<String, dynamic>.from(response ?? const <dynamic, dynamic>{});
  }

  Future<bool> hasNotificationPermission() async {
    _requireAndroid();

    return await _channel.invokeMethod<bool>('hasNotificationPermission') ??
        false;
  }

  Future<void> openNotificationSettings() async {
    _requireAndroid();

    await _channel.invokeMethod<void>('openNotificationSettings');
  }

  Future<bool> sendTestReminder({
    required String id,
    required String title,
    required String message,
    required bool voice,
    required bool vibration,
  }) async {
    _requireAndroid();

    return await _channel.invokeMethod<bool>(
          'sendTestReminder',
          <String, dynamic>{
            'id': id,
            'title': title,
            'message': message,
            'voice': voice,
            'vibration': vibration,
          },
        ) ??
        false;
  }

  void _requireAndroid() {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Smart reminders currently support Android only.');
    }
  }
}
