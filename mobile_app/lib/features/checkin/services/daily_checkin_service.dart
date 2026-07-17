import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/auth/authenticated_http_client.dart';

class DailyCheckinApiException implements Exception {
  const DailyCheckinApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DailyCheckinService {
  DailyCheckinService({AuthenticatedHttpClient? client})
    : _client = client ?? AuthenticatedHttpClient.instance;

  final AuthenticatedHttpClient _client;

  Future<Map<String, dynamic>> submitCheckin({
    required int moodScore,
    required int stressLevel,
    required int energyLevel,
    required double sleepHours,
    required int sleepQuality,
    required int focusLevel,
    required int motivationLevel,
    required int restlessnessLevel,
    required int workStudyPressure,
    required int physicalActivityMinutes,
    required int waterIntakeGlasses,
    String? note,
  }) async {
    final response = await _client.post(
      '/checkins',
      body: <String, dynamic>{
        'mood_score': moodScore,
        'stress_level': stressLevel,
        'energy_level': energyLevel,
        'sleep_hours': sleepHours,
        'sleep_quality': sleepQuality,
        'focus_level': focusLevel,
        'motivation_level': motivationLevel,
        'restlessness_level': restlessnessLevel,
        'work_study_pressure': workStudyPressure,
        'physical_activity_minutes': physicalActivityMinutes,
        'water_intake_glasses': waterIntakeGlasses,
        'note': note?.trim().isEmpty == true ? null : note?.trim(),
      },
    );

    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> getTodayCheckin() async {
    final response = await _client.get('/checkins/today');

    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> getCheckinHistory() async {
    final response = await _client.get('/checkins/history');

    return _decodeResponse(response);
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    dynamic decoded;

    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw const DailyCheckinApiException('Invalid server response.');
    }

    if (decoded is! Map) {
      throw const DailyCheckinApiException('Unexpected response format.');
    }

    final payload = Map<String, dynamic>.from(decoded);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errors = payload['errors'];

      if (errors is List && errors.isNotEmpty) {
        final firstError = errors.first;

        if (firstError is Map) {
          throw DailyCheckinApiException(
            firstError['message']?.toString() ??
                payload['message']?.toString() ??
                'Daily check-in request failed.',
          );
        }
      }

      throw DailyCheckinApiException(
        payload['message']?.toString() ?? 'Daily check-in request failed.',
      );
    }

    return payload;
  }
}
