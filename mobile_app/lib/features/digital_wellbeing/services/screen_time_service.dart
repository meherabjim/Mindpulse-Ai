import 'dart:io';

import 'package:flutter/services.dart';

class AppUsageEntry {
  const AppUsageEntry({
    required this.packageName,
    required this.appName,
    required this.totalTimeMs,
    required this.longestSessionMs,
    required this.sessionCount,
    required this.lastTimeUsed,
  });

  factory AppUsageEntry.fromMap(Map<dynamic, dynamic> map) {
    return AppUsageEntry(
      packageName: map['package_name']?.toString() ?? 'unknown',

      appName:
          map['app_name']?.toString() ??
          map['package_name']?.toString() ??
          'Unknown app',

      totalTimeMs: (map['total_time_ms'] as num?)?.toInt() ?? 0,

      longestSessionMs: (map['longest_session_ms'] as num?)?.toInt() ?? 0,

      sessionCount: (map['session_count'] as num?)?.toInt() ?? 0,

      lastTimeUsed: (map['last_time_used'] as num?)?.toInt() ?? 0,
    );
  }

  final String packageName;
  final String appName;
  final int totalTimeMs;
  final int longestSessionMs;
  final int sessionCount;
  final int lastTimeUsed;
}

class ScreenTimeService {
  static const MethodChannel _channel = MethodChannel('mindpulse/screen_time');

  Future<bool> hasUsageAccess() async {
    if (!Platform.isAndroid) {
      return false;
    }

    return await _channel.invokeMethod<bool>('hasUsageAccess') ?? false;
  }

  Future<void> openUsageAccessSettings() async {
    _requireAndroid();

    await _channel.invokeMethod<void>('openUsageAccessSettings');
  }

  Future<List<AppUsageEntry>> getTodayUsage() async {
    if (!Platform.isAndroid) {
      return const <AppUsageEntry>[];
    }

    final result = await _channel.invokeMethod<List<dynamic>>('getTodayUsage');

    final entries = (result ?? const <dynamic>[])
        .whereType<Map>()
        .map((item) => AppUsageEntry.fromMap(item))
        .toList();

    entries.sort(
      (first, second) => second.totalTimeMs.compareTo(first.totalTimeMs),
    );

    return entries;
  }

  Future<bool> hasNotificationPermission() async {
    if (!Platform.isAndroid) {
      return false;
    }

    return await _channel.invokeMethod<bool>('hasNotificationPermission') ??
        false;
  }

  Future<bool> requestNotificationPermission() async {
    _requireAndroid();

    return await _channel.invokeMethod<bool>('requestNotificationPermission') ??
        false;
  }

  Future<void> openNotificationSettings() async {
    _requireAndroid();

    await _channel.invokeMethod<void>('openNotificationSettings');
  }

  Future<void> enableBackgroundReminders({
    required int dailyLimitMinutes,
    required int sessionLimitMinutes,
  }) async {
    _requireAndroid();

    await _channel
        .invokeMethod<void>('enableBackgroundReminders', <String, dynamic>{
          'dailyLimitMinutes': dailyLimitMinutes,
          'sessionLimitMinutes': sessionLimitMinutes,
        });
  }

  Future<void> disableBackgroundReminders() async {
    _requireAndroid();

    await _channel.invokeMethod<void>('disableBackgroundReminders');
  }

  Future<void> runBackgroundCheckNow() async {
    _requireAndroid();

    await _channel.invokeMethod<void>('runBackgroundCheckNow');
  }

  Future<bool> sendTestScreenTimeReminder() async {
    _requireAndroid();

    return await _channel.invokeMethod<bool>('sendTestScreenTimeReminder') ??
        false;
  }

  Future<Map<String, dynamic>> getBackgroundReminderStatus() async {
    _requireAndroid();

    final result = await _channel.invokeMethod<Map>(
      'getBackgroundReminderStatus',
    );

    if (result == null) {
      return <String, dynamic>{};
    }

    return Map<String, dynamic>.from(result);
  }

  Future<bool> isBanglaVoiceReminderEnabled() async {
    _requireAndroid();

    return await _channel.invokeMethod<bool>('isBanglaVoiceReminderEnabled') ??
        false;
  }

  Future<void> setBanglaVoiceReminderEnabled(bool enabled) async {
    _requireAndroid();

    await _channel.invokeMethod<void>(
      'setBanglaVoiceReminderEnabled',
      <String, dynamic>{'enabled': enabled},
    );
  }

  Future<bool> testBanglaVoiceReminder() async {
    _requireAndroid();

    return await _channel.invokeMethod<bool>('testBanglaVoiceReminder') ??
        false;
  }

  void _requireAndroid() {
    if (!Platform.isAndroid) {
      throw UnsupportedError(
        'Screen-time monitoring currently supports Android only.',
      );
    }
  }
}
