import 'dart:io';

import 'package:flutter/services.dart';

class ScreenTimeInsightService {
  static const MethodChannel _channel = MethodChannel('mindpulse/screen_time');

  void _requireAndroid() {
    if (!Platform.isAndroid) {
      throw UnsupportedError(
        'Phone-use insights currently support Android only.',
      );
    }
  }

  Future<bool> hasUsageAccess() async {
    _requireAndroid();

    return await _channel.invokeMethod<bool>('hasUsageAccess') ?? false;
  }

  Future<void> openUsageAccessSettings() async {
    _requireAndroid();

    await _channel.invokeMethod<void>('openUsageAccessSettings');
  }

  Future<Map<String, dynamic>> getInsights() async {
    _requireAndroid();

    final value = await _channel.invokeMethod<dynamic>('getScreenTimeInsights');

    return _map(value);
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }
}
