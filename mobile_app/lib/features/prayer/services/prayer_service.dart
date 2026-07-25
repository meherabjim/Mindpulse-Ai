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
    return (
      hour: int.parse(match.group(1)!),
      minute: int.parse(match.group(2)!),
    );
  }
}

class PrayerSyncResult {
  const PrayerSyncResult({
    required this.locationLabel,
    required this.timezone,
    required this.scheduledCount,
    required this.todayTimes,
    required this.usedFallbackLocation,
  });

  final String locationLabel;
  final String timezone;
  final int scheduledCount;
  final Map<String, String> todayTimes;
  final bool usedFallbackLocation;
}

class PrayerService {
  PrayerService({http.Client? client, this._bridge = const PrayerAlarmBridge()})
    : _client = client ?? http.Client();

  static const String _enabledKey = 'prayer_alarm_enabled';
  static const String _lastSyncKey = 'prayer_alarm_last_sync';
  static const String _jamaatTimePrefix = 'prayer_jamaat_time_';

  static const List<String> editableJamaatKeys = <String>[
    'fajr',
    'dhuhr',
    'jummah',
    'asr',
    'maghrib',
    'isha',
  ];

  static const Map<String, String> defaultJamaatTimes = <String, String>{
    'dhuhr': '13:30',
    'jummah': '13:30',
  };
  static const double _dhakaLatitude = 23.8103;
  static const double _dhakaLongitude = 90.4125;

  static const int preparationMinutes = 20;
  static const int calculationMethod = 1;
  static const int asrSchool = 1;
  static const int scheduleHorizonDays = 30;

  static const int dhuhrHour = 13;
  static const int dhuhrMinute = 30;
  static const int jummahHour = 13;
  static const int jummahMinute = 30;

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

  Future<Map<String, String>> loadJamaatTimes() async {
    final preferences = await SharedPreferences.getInstance();

    final result = <String, String>{...defaultJamaatTimes};

    for (final prayerKey in editableJamaatKeys) {
      final savedValue = preferences.getString('$_jamaatTimePrefix$prayerKey');

      if (savedValue != null && savedValue.trim().isNotEmpty) {
        PrayerTimeParser.parse(savedValue);
        result[prayerKey] = savedValue.trim();
      }
    }

    return result;
  }

  Future<void> saveJamaatTimes(Map<String, String?> times) async {
    final preferences = await SharedPreferences.getInstance();

    for (final entry in times.entries) {
      final prayerKey = entry.key.trim().toLowerCase();

      if (!editableJamaatKeys.contains(prayerKey)) {
        throw ArgumentError('Unsupported jamaat prayer: ${entry.key}');
      }

      final value = entry.value?.trim() ?? '';
      final preferenceKey = '$_jamaatTimePrefix$prayerKey';

      if (value.isEmpty) {
        await preferences.remove(preferenceKey);
        continue;
      }

      PrayerTimeParser.parse(value);

      await preferences.setString(preferenceKey, value);
    }
  }

  Future<PrayerSyncResult> syncOnlineSchedule() async {
    tz_data.initializeTimeZones();
    final coordinates = await _resolveCoordinates();
    final jamaatTimes = await loadJamaatTimes();

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
    final todayTimes = <String, String>{};
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
            bangla: 'ফজরের',
            index: 1,
          ),
          (
            apiKey: 'Dhuhr',
            key: 'dhuhr',
            english: 'Dhuhr',
            bangla: 'যোহরের',
            index: 2,
          ),
          (
            apiKey: 'Asr',
            key: 'asr',
            english: 'Asr',
            bangla: 'আসরের',
            index: 3,
          ),
          (
            apiKey: 'Maghrib',
            key: 'maghrib',
            english: 'Maghrib',
            bangla: 'মাগরিবের',
            index: 4,
          ),
          (
            apiKey: 'Isha',
            key: 'isha',
            english: 'Isha',
            bangla: 'এশার',
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

          late final tz.TZDateTime prayerMoment;

          if (prayer.key == 'dhuhr') {
            final isFriday = date.weekday == DateTime.friday;

            if (isFriday) {
              displayEnglish = 'Jummah';
              displayBangla = 'জুমার';
              eventKey = 'jummah';

              prayerMoment = tz.TZDateTime(
                location,
                date.year,
                date.month,
                date.day,
                jummahHour,
                jummahMinute,
              );
            } else {
              prayerMoment = tz.TZDateTime(
                location,
                date.year,
                date.month,
                date.day,
                dhuhrHour,
                dhuhrMinute,
              );
            }
          } else {
            final rawTime = timings[prayer.apiKey]?.toString();

            if (rawTime == null) {
              continue;
            }

            final parsed = PrayerTimeParser.parse(rawTime);

            prayerMoment = tz.TZDateTime(
              location,
              date.year,
              date.month,
              date.day,
              parsed.hour,
              parsed.minute,
            );
          }

          final savedJamaatTime = jamaatTimes[eventKey];

          var effectivePrayerMoment = prayerMoment;

          late final tz.TZDateTime alarmMoment;

          if (savedJamaatTime != null && savedJamaatTime.trim().isNotEmpty) {
            final parsedJamaat = PrayerTimeParser.parse(savedJamaatTime);

            effectivePrayerMoment = tz.TZDateTime(
              location,
              date.year,
              date.month,
              date.day,
              parsedJamaat.hour,
              parsedJamaat.minute,
            );

            alarmMoment = effectivePrayerMoment.subtract(
              const Duration(minutes: preparationMinutes),
            );
          } else if (eventKey == 'fajr') {
            alarmMoment = prayerMoment.add(const Duration(minutes: 10));
          } else if (eventKey == 'maghrib') {
            alarmMoment = prayerMoment.subtract(const Duration(minutes: 15));
          } else if (eventKey == 'dhuhr' || eventKey == 'jummah') {
            alarmMoment = prayerMoment.subtract(
              const Duration(minutes: preparationMinutes),
            );
          } else {
            alarmMoment = prayerMoment;
          }

          if (date.year == now.year &&
              date.month == now.month &&
              date.day == now.day) {
            todayTimes[displayEnglish] = _formatClock(effectivePrayerMoment);
          }

          final dateCode = (date.year * 10000) + (date.month * 100) + date.day;

          if (alarmMoment.isAfter(
                tz.TZDateTime.from(
                  now.add(const Duration(seconds: 30)),
                  location,
                ),
              ) &&
              alarmMoment.isBefore(tz.TZDateTime.from(horizon, location))) {
            final isFajr = eventKey == 'fajr';
            alarms.add(<String, Object?>{
              'id': (dateCode * 100) + (prayer.index * 10) + 2,
              'triggerAtMillis': alarmMoment.millisecondsSinceEpoch,
              'title': '$displayEnglish prayer reminder',
              'message':
                  '$displayEnglish reminder at ${_formatClock(effectivePrayerMoment)}.',
              'voiceBn':
                  '$displayBangla নামাজের জন্য প্রস্তুতি নিন। '
                  'তারপর নামাজ পড়তে যান। নামাজেই আসল সুখ।',
              'voiceEn':
                  'Please prepare for $displayEnglish prayer, '
                  'then go and pray.',
              'prayerBn': displayBangla,
              'prayerEn': displayEnglish,
              'durationSeconds': isFajr ? 30 : 15,
              'voiceRepeat': isFajr ? 2 : 1,
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
      todayTimes: todayTimes,
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
        return (
          latitude: _dhakaLatitude,
          longitude: _dhakaLongitude,
          locationLabel: 'Dhaka fallback — location permission not granted',
          usedFallback: true,
        );
      }

      if (!await Geolocator.isLocationServiceEnabled()) {
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
            '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
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

  String _formatClock(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final suffix = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  void dispose() {
    _client.close();
  }
}
