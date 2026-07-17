import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/auth/authenticated_http_client.dart';

class AiApiException implements Exception {
  const AiApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AiMobileService {
  AiMobileService({AuthenticatedHttpClient? client})
    : _client = client ?? AuthenticatedHttpClient.instance;

  final AuthenticatedHttpClient _client;

  Future<Map<String, dynamic>> health() {
    return _authorizedRequest(method: 'GET', path: '/ai/health');
  }

  Future<Map<String, dynamic>> analyzeJournal({
    required String text,
    required int moodScore,
    String language = 'auto',
  }) {
    return _authorizedRequest(
      method: 'POST',
      path: '/ai/journal/analyze',
      body: {'text': text, 'language': language, 'mood_score': moodScore},
    );
  }

  Future<Map<String, dynamic>> getRecommendations({
    required int moodScore,
    required int stressLevel,
    required int energyLevel,
    required double sleepHours,
    required int hydrationCups,
    required double burnoutScore,
  }) {
    return _authorizedRequest(
      method: 'POST',
      path: '/ai/wellness/recommendations',
      body: {
        'mood_score': moodScore,
        'stress_level': stressLevel,
        'energy_level': energyLevel,
        'sleep_hours': sleepHours,
        'hydration_cups': hydrationCups,
        'burnout_score': burnoutScore,
      },
    );
  }

  Future<Map<String, dynamic>> predictWellness({
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
    required int hydrationCups,
    required int socialWithdrawal,
  }) {
    return _authorizedRequest(
      method: 'POST',
      path: '/ai/wellness/predict',
      body: {
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
        'hydration_cups': hydrationCups,
        'social_withdrawal': socialWithdrawal,
      },
    );
  }

  Future<Map<String, dynamic>> _authorizedRequest({
    required String method,
    required String path,
    Map<String, dynamic>? body,
  }) async {
    try {
      late final http.Response response;

      switch (method.toUpperCase()) {
        case 'GET':
          response = await _client.get(path);
          break;

        case 'POST':
          response = await _client.post(
            path,
            body: body ?? <String, dynamic>{},
          );
          break;

        default:
          throw AiApiException('Unsupported request method: $method');
      }

      return _decodeResponse(response);
    } on AuthSessionExpiredException catch (error) {
      throw AiApiException(error.toString());
    } on AiApiException {
      rethrow;
    } catch (error) {
      throw AiApiException('Unable to contact the AI service: $error');
    }
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    dynamic decoded;

    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw const AiApiException('Invalid server response.');
    }

    if (decoded is! Map) {
      throw const AiApiException('Unexpected response format.');
    }

    final payload = Map<String, dynamic>.from(decoded);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiApiException(
        payload['message']?.toString() ?? 'AI request failed.',
      );
    }

    return payload;
  }

  // Shared authenticated client app-wide ব্যবহৃত হয়,
  // তাই এই service থেকে client close করা হবে না।
  void dispose() {}
}
