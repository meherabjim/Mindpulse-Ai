// HUMAN_COMPANION_MOVEMENT_SERVICE_V1

import 'dart:io';

import 'package:flutter/services.dart';

class MovementInsightService {
  static const MethodChannel _channel = MethodChannel('mindpulse/movement');

  void _requireAndroid() {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Movement insights support Android only.');
    }
  }

  Future<bool> hasPermission() async {
    _requireAndroid();

    return await _channel.invokeMethod<bool>(
          'hasActivityRecognitionPermission',
        ) ??
        false;
  }

  Future<void> requestPermission() async {
    _requireAndroid();

    await _channel.invokeMethod<void>('requestActivityRecognitionPermission');
  }

  Future<bool> isStepCounterAvailable() async {
    _requireAndroid();

    return await _channel.invokeMethod<bool>('isStepCounterAvailable') ?? false;
  }

  Future<Map<String, dynamic>> getInsights() async {
    _requireAndroid();

    final value = await _channel.invokeMethod<dynamic>('getMovementInsights');

    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }

  Future<void> openAppSettings() async {
    _requireAndroid();

    await _channel.invokeMethod<void>('openAppSettings');
  }
}
