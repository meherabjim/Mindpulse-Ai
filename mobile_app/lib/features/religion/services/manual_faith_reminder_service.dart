import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../prayer/services/prayer_alarm_bridge.dart';

class ManualFaithReminder {
  const ManualFaithReminder({
    required this.id,
    required this.title,
    required this.hour,
    required this.minute,
    required this.weekdays,
    required this.enabled,
  });

  final String id;
  final String title;
  final int hour;
  final int minute;
  final List<int> weekdays;
  final bool enabled;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'hour': hour,
    'minute': minute,
    'weekdays': weekdays,
    'enabled': enabled,
  };

  factory ManualFaithReminder.fromJson(Map<String, dynamic> json) {
    final days = json['weekdays'];
    return ManualFaithReminder(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Personal reminder',
      hour: (json['hour'] as num?)?.toInt() ?? 9,
      minute: (json['minute'] as num?)?.toInt() ?? 0,
      weekdays: days is List
          ? days.map((day) => (day as num).toInt()).toList()
          : const <int>[1, 2, 3, 4, 5, 6, 7],
      enabled: json['enabled'] != false,
    );
  }

  ManualFaithReminder copyWith({
    String? title,
    int? hour,
    int? minute,
    List<int>? weekdays,
    bool? enabled,
  }) {
    return ManualFaithReminder(
      id: id,
      title: title ?? this.title,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      weekdays: weekdays ?? this.weekdays,
      enabled: enabled ?? this.enabled,
    );
  }
}

class ManualFaithReminderService {
  ManualFaithReminderService({this._bridge = const PrayerAlarmBridge()});

  static const String _storageKey = 'manual_faith_reminders_v1';
  static const int _horizonDays = 30;
  static const int maximumReminders = 10;
  final PrayerAlarmBridge _bridge;

  Future<List<ManualFaithReminder>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final source = prefs.getString(_storageKey);
    if (source == null || source.isEmpty) return <ManualFaithReminder>[];
    try {
      final decoded = jsonDecode(source);
      if (decoded is! List) return <ManualFaithReminder>[];
      return decoded
          .whereType<Map>()
          .map(
            (item) =>
                ManualFaithReminder.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((item) => item.id.isNotEmpty)
          .toList();
    } catch (_) {
      return <ManualFaithReminder>[];
    }
  }

  Future<void> save(List<ManualFaithReminder> reminders) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(reminders.map((item) => item.toJson()).toList()),
    );
    await reschedule(reminders);
  }

  Future<void> reschedule(List<ManualFaithReminder> reminders) async {
    await _bridge.cancelAll();
    final active = reminders
        .where((item) => item.enabled)
        .take(maximumReminders)
        .toList();
    if (active.isEmpty) return;
    await _bridge.requestNotificationPermission();
    await _bridge.requestExactAlarmPermission();
    final now = DateTime.now();
    final alarms = <Map<String, Object?>>[];
    for (var offset = 0; offset < _horizonDays; offset++) {
      final day = DateTime(
        now.year,
        now.month,
        now.day,
      ).add(Duration(days: offset));
      for (var index = 0; index < active.length; index++) {
        final reminder = active[index];
        if (!reminder.weekdays.contains(day.weekday)) continue;
        final trigger = DateTime(
          day.year,
          day.month,
          day.day,
          reminder.hour,
          reminder.minute,
        );
        if (!trigger.isAfter(now.add(const Duration(seconds: 20)))) continue;
        final dateCode = (day.year * 10000) + (day.month * 100) + day.day;
        alarms.add(<String, Object?>{
          'id': (dateCode * 100) + 70 + index,
          'triggerAtMillis': trigger.millisecondsSinceEpoch,
          'title': reminder.title,
          'message': 'Your manually scheduled reminder is due now.',
          'voiceBn': '${reminder.title} সময় হয়েছে।',
          'voiceEn': 'It is time for ${reminder.title}.',
          'prayerBn': reminder.title,
          'prayerEn': reminder.title,
          'durationSeconds': 15,
          'voiceRepeat': 1,
          'prayerKey': 'manual_${reminder.id}',
          'eventType': 'manual_spiritual_reminder',
        });
      }
    }
    await _bridge.scheduleAlarms(alarms);
  }
}
