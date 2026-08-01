import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'prayer_alarm_bridge.dart';

class PrayerTimeParser {
  const PrayerTimeParser._();

  static ({int hour, int minute}) parse(String raw) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(raw.trim());
    if (match == null) {
      throw FormatException('Unsupported prayer time: $raw');
    }

    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);

    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      throw FormatException('Unsupported prayer time: $raw');
    }

    return (hour: hour, minute: minute);
  }
}

class PrayerSyncResult {
  const PrayerSyncResult({
    required this.locationLabel,
    required this.timezone,
    required this.scheduledCount,
    required this.todayPrayerTimes,
    required this.todayReminderTimes,
    required this.usedFallbackLocation,
  });

  final String locationLabel;
  final String timezone;
  final int scheduledCount;
  final Map<String, String> todayPrayerTimes;
  final Map<String, String> todayReminderTimes;
  final bool usedFallbackLocation;
}

class PrayerService {
  PrayerService({http.Client? client, this._bridge = const PrayerAlarmBridge()})
    : _client = client ?? http.Client();

  static const String _enabledKey = 'prayer_alarm_enabled';
  static const String _lastSyncKey = 'prayer_alarm_last_sync';
  static const String _reminderTimePrefix = 'prayer_reminder_time_';
  static const String _legacyJamaatTimePrefix = 'prayer_jamaat_time_';
  static const String _legacyMigrationKey =
      'prayer_reminder_time_migration_v2_complete';

  static const List<String> editableReminderKeys = <String>[
    'fajr',
    'dhuhr',
    'jummah',
    'asr',
    'maghrib',
    'isha',
  ];

  /// These are reminder times, not mosque or congregation times.
  static const Map<String, String> defaultReminderTimes = <String, String>{
    'dhuhr': '13:05',
    'jummah': '12:35',
  };

  static const int automaticLeadMinutes = 10;
  static const int calculationMethod = 1;
  static const int asrSchool = 1;
  static const int scheduleHorizonDays = 30;

  static const String banglaReminderMessage =
      'নামাজের সময় হয়ে যাচ্ছে। আপনারা নামাজের প্রস্তুতি নিন।';
  static const String englishReminderMessage =
      'Prayer time is approaching. Please prepare for prayer.';

  static const double _dhakaLatitude = 23.8103;
  static const double _dhakaLongitude = 90.4125;

  final http.Client _client;
  final PrayerAlarmBridge _bridge;

  Future<bool> isEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_enabledKey) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_enabledKey, value);

    if (!value) {
      await _bridge.cancelAll();
    }
  }

  Future<DateTime?> lastSync() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_lastSyncKey);
    return value == null ? null : DateTime.tryParse(value);
  }

  Future<Map<String, String>> loadReminderTimes() async {
    final preferences = await SharedPreferences.getInstance();
    await _removeLegacyJamaatPreferences(preferences);

    final result = <String, String>{...defaultReminderTimes};

    for (final prayerKey in editableReminderKeys) {
      final savedValue = preferences.getString(
        '$_reminderTimePrefix$prayerKey',
      );

      if (savedValue != null && savedValue.trim().isNotEmpty) {
        PrayerTimeParser.parse(savedValue);
        result[prayerKey] = savedValue.trim();
      }
    }

    return result;
  }

  Future<void> saveReminderTimes(Map<String, String?> times) async {
    final preferences = await SharedPreferences.getInstance();
    await _removeLegacyJamaatPreferences(preferences);

    for (final entry in times.entries) {
      final prayerKey = entry.key.trim().toLowerCase();

      if (!editableReminderKeys.contains(prayerKey)) {
        throw ArgumentError('Unsupported prayer reminder: ${entry.key}');
      }

      final value = entry.value?.trim() ?? '';
      final preferenceKey = '$_reminderTimePrefix$prayerKey';

      if (value.isEmpty) {
        await preferences.remove(preferenceKey);
        continue;
      }

      PrayerTimeParser.parse(value);
      await preferences.setString(preferenceKey, value);
    }
  }

  Future<void> _removeLegacyJamaatPreferences(
    SharedPreferences preferences,
  ) async {
    if (preferences.getBool(_legacyMigrationKey) == true) {
      return;
    }

    for (final prayerKey in editableReminderKeys) {
      await preferences.remove('$_legacyJamaatTimePrefix$prayerKey');
    }

    await preferences.setBool(_legacyMigrationKey, true);
  }

  Future<PrayerSyncResult> syncOnlineSchedule() async {
    tz_data.initializeTimeZones();

    final coordinates = await _resolveCoordinates();
    final reminderTimes = await loadReminderTimes();

    final monthlyPayloads = <Map<String, dynamic>>[];
    var cursor = DateTime(DateTime.now().year, DateTime.now().month);

    for (var index = 0; index < 2; index++) {
      monthlyPayloads.add(
        await _fetchMonth(
          year: cursor.year,
          month: cursor.month,
          latitude: coordinates.latitude,
          longitude: coordinates.longitude,
        ),
      );
      cursor = DateTime(cursor.year, cursor.month + 1);
    }

    final alarms = <Map<String, Object?>>[];
    final todayPrayerTimes = <String, String>{};
    final todayReminderTimes = <String, String>{};

    var timezoneName = 'Asia/Dhaka';
    final now = DateTime.now();
    final horizon = now.add(const Duration(days: scheduleHorizonDays));

    const definitions =
        <
          ({
            String apiKey,
            String key,
            String english,
            String bangla,
            int index,
          })
        >[
          (
            apiKey: 'Fajr',
            key: 'fajr',
            english: 'Fajr',
            bangla: 'ফজর',
            index: 1,
          ),
          (
            apiKey: 'Dhuhr',
            key: 'dhuhr',
            english: 'Dhuhr',
            bangla: 'যোহর',
            index: 2,
          ),
          (apiKey: 'Asr', key: 'asr', english: 'Asr', bangla: 'আসর', index: 3),
          (
            apiKey: 'Maghrib',
            key: 'maghrib',
            english: 'Maghrib',
            bangla: 'মাগরিব',
            index: 4,
          ),
          (
            apiKey: 'Isha',
            key: 'isha',
            english: 'Isha',
            bangla: 'এশা',
            index: 5,
          ),
        ];

    for (final payload in monthlyPayloads) {
      final data = payload['data'];
      if (data is! List) {
        continue;
      }

      for (final rawDay in data) {
        if (rawDay is! Map) {
          continue;
        }

        final day = Map<String, dynamic>.from(rawDay);
        final date = _parseGregorianDate(day);
        final timings = _readMap(day['timings']);
        final meta = _readMap(day['meta']);
        final apiTimezone = meta['timezone']?.toString();

        if (apiTimezone != null && apiTimezone.isNotEmpty) {
          timezoneName = apiTimezone;
        }

        tz.Location location;
        try {
          location = tz.getLocation(timezoneName);
        } catch (_) {
          location = tz.getLocation('Asia/Dhaka');
          timezoneName = 'Asia/Dhaka';
        }

        for (final prayer in definitions) {
          var displayEnglish = prayer.english;
          var displayBangla = prayer.bangla;
          var eventKey = prayer.key;

          if (prayer.key == 'dhuhr' && date.weekday == DateTime.friday) {
            displayEnglish = 'Jummah';
            displayBangla = 'জুমা';
            eventKey = 'jummah';
          }

          final rawTime = timings[prayer.apiKey]?.toString();
          if (rawTime == null) {
            continue;
          }

          final parsed = PrayerTimeParser.parse(rawTime);
          final prayerMoment = tz.TZDateTime(
            location,
            date.year,
            date.month,
            date.day,
            parsed.hour,
            parsed.minute,
          );

          final selectedReminder = reminderTimes[eventKey];
          final tz.TZDateTime reminderMoment;

          if (selectedReminder != null && selectedReminder.trim().isNotEmpty) {
            final parsedReminder = PrayerTimeParser.parse(selectedReminder);
            reminderMoment = tz.TZDateTime(
              location,
              date.year,
              date.month,
              date.day,
              parsedReminder.hour,
              parsedReminder.minute,
            );
          } else {
            reminderMoment = prayerMoment.subtract(
              const Duration(minutes: automaticLeadMinutes),
            );
          }

          if (_isSameDate(date, now)) {
            todayPrayerTimes[displayEnglish] = _formatClock(prayerMoment);
            todayReminderTimes[displayEnglish] = _formatClock(reminderMoment);
          }

          final dateCode = (date.year * 10000) + (date.month * 100) + date.day;
          final currentMoment = tz.TZDateTime.from(
            now.add(const Duration(seconds: 30)),
            location,
          );

          if (reminderMoment.isAfter(currentMoment) &&
              reminderMoment.isBefore(tz.TZDateTime.from(horizon, location))) {
            alarms.add(<String, Object?>{
              'id': (dateCode * 100) + (prayer.index * 10) + 2,
              'triggerAtMillis': reminderMoment.millisecondsSinceEpoch,
              'title': '$displayBangla নামাজ',
              'message': banglaReminderMessage,
              'voiceBn': banglaReminderMessage,
              'voiceEn': englishReminderMessage,
              'prayerBn': displayBangla,
              'prayerEn': displayEnglish,
              'durationSeconds': 15,
              'voiceRepeat': 1,
              'prayerKey': eventKey,
              'eventType': 'prayer_reminder',
            });
          }
        }
      }
    }

    alarms.sort(
      (left, right) => (left['triggerAtMillis'] as int).compareTo(
        right['triggerAtMillis'] as int,
      ),
    );

    final scheduledCount = await _bridge.scheduleAlarms(alarms);
    final preferences = await SharedPreferences.getInstance();

    await preferences.setBool(_enabledKey, true);
    await preferences.setString(_lastSyncKey, DateTime.now().toIso8601String());

    return PrayerSyncResult(
      locationLabel: coordinates.locationLabel,
      timezone: timezoneName,
      scheduledCount: scheduledCount,
      todayPrayerTimes: todayPrayerTimes,
      todayReminderTimes: todayReminderTimes,
      usedFallbackLocation: coordinates.usedFallback,
    );
  }

  Future<Map<String, dynamic>> _fetchMonth({
    required int year,
    required int month,
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.https(
      'api.aladhan.com',
      '/v1/calendar/$year/$month',
      <String, String>{
        'latitude': latitude.toStringAsFixed(6),
        'longitude': longitude.toStringAsFixed(6),
        'method': calculationMethod.toString(),
        'school': asrSchool.toString(),
      },
    );

    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw StateError('Prayer API returned HTTP ${response.statusCode}.');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Prayer API returned an invalid response.');
    }

    final payload = Map<String, dynamic>.from(decoded);
    if (payload['code'] != 200) {
      throw StateError(
        payload['status']?.toString() ?? 'Prayer API request failed.',
      );
    }

    return payload;
  }

  Future<
    ({
      double latitude,
      double longitude,
      String locationLabel,
      bool usedFallback,
    })
  >
  _resolveCoordinates() async {
    try {
      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        final lastKnown = await Geolocator.getLastKnownPosition();

        if (lastKnown != null) {
          return (
            latitude: lastKnown.latitude,
            longitude: lastKnown.longitude,
            locationLabel:
                '${lastKnown.latitude.toStringAsFixed(4)}, '
                '${lastKnown.longitude.toStringAsFixed(4)}',
            usedFallback: true,
          );
        }

        return (
          latitude: _dhakaLatitude,
          longitude: _dhakaLongitude,
          locationLabel: 'Dhaka fallback — location permission not granted',
          usedFallback: true,
        );
      }

      if (!await Geolocator.isLocationServiceEnabled()) {
        final lastKnown = await Geolocator.getLastKnownPosition();

        if (lastKnown != null) {
          return (
            latitude: lastKnown.latitude,
            longitude: lastKnown.longitude,
            locationLabel:
                '${lastKnown.latitude.toStringAsFixed(4)}, '
                '${lastKnown.longitude.toStringAsFixed(4)}',
            usedFallback: true,
          );
        }

        return (
          latitude: _dhakaLatitude,
          longitude: _dhakaLongitude,
          locationLabel: 'Dhaka fallback — device location is off',
          usedFallback: true,
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );

      return (
        latitude: position.latitude,
        longitude: position.longitude,
        locationLabel:
            '${position.latitude.toStringAsFixed(4)}, '
            '${position.longitude.toStringAsFixed(4)}',
        usedFallback: false,
      );
    } catch (_) {
      return (
        latitude: _dhakaLatitude,
        longitude: _dhakaLongitude,
        locationLabel: 'Dhaka fallback — location unavailable',
        usedFallback: true,
      );
    }
  }

  DateTime _parseGregorianDate(Map<String, dynamic> day) {
    final dateMap = _readMap(day['date']);
    final gregorian = _readMap(dateMap['gregorian']);
    final source = gregorian['date']?.toString();

    if (source == null) {
      throw const FormatException('Prayer date is missing.');
    }

    final parts = source.split('-');
    if (parts.length != 3) {
      throw FormatException('Unsupported prayer date: $source');
    }

    return DateTime(
      int.parse(parts[2]),
      int.parse(parts[1]),
      int.parse(parts[0]),
    );
  }

  Map<String, dynamic> _readMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }

  bool _isSameDate(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  String _formatClock(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  void dispose() {
    _client.close();
  }
}
