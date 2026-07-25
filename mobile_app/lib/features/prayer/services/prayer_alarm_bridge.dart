import 'dart:convert';

import 'package:flutter/services.dart';

class PrayerAlarmStatus {
  const PrayerAlarmStatus({
    required this.notificationPermission,
    required this.exactAlarmPermission,
  });

  final bool notificationPermission;
  final bool exactAlarmPermission;

  factory PrayerAlarmStatus.fromMap(Map<Object?, Object?> source) {
    return PrayerAlarmStatus(
      notificationPermission: source['notificationPermission'] == true,
      exactAlarmPermission: source['exactAlarmPermission'] == true,
    );
  }
}

class PrayerAlarmBridge {
  const PrayerAlarmBridge();

  static const MethodChannel _channel = MethodChannel('mindpulse/prayer_alarm');

  Future<PrayerAlarmStatus> getStatus() async {
    final value = await _channel.invokeMethod<Object?>('getStatus');
    if (value is Map<Object?, Object?>) {
      return PrayerAlarmStatus.fromMap(value);
    }
    return const PrayerAlarmStatus(
      notificationPermission: false,
      exactAlarmPermission: false,
    );
  }

  Future<void> requestNotificationPermission() async {
    await _channel.invokeMethod<void>('requestNotificationPermission');
  }

  Future<void> requestExactAlarmPermission() async {
    await _channel.invokeMethod<void>('requestExactAlarmPermission');
  }

  Future<int> scheduleAlarms(List<Map<String, Object?>> alarms) async {
    final scheduled = await _channel.invokeMethod<int>(
      'scheduleAlarms',
      <String, Object?>{'json': jsonEncode(alarms)},
    );
    return scheduled ?? 0;
  }

  Future<void> cancelAll() async {
    await _channel.invokeMethod<void>('cancelAll');
  }

  Future<void> testAlarm({required bool fajr}) async {
    await _channel.invokeMethod<void>('testAlarm', <String, Object?>{
      'fajr': fajr,
    });
  }
}
