import 'dart:convert';

import '../../../core/auth/authenticated_http_client.dart';

class RecommendationSessionApiException implements Exception {
  const RecommendationSessionApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RecommendationSessionService {
  RecommendationSessionService({AuthenticatedHttpClient? client})
    : _client = client ?? AuthenticatedHttpClient.instance;

  final AuthenticatedHttpClient _client;

  Future<Map<String, dynamic>> startSession({
    required String clientSessionKey,
    required String category,
    required String title,
    required String action,
    required String priority,
    required int suggestedDurationSeconds,
    required int beforeMood,
    required int beforeStress,
  }) async {
    final response = await _client.post(
      '/recommendation-sessions',
      body: <String, dynamic>{
        'client_session_key': clientSessionKey,
        'recommendation_source': 'ai_wellness',
        'recommendation_category': category,
        'recommendation_title': title,
        'recommendation_action': action,
        'priority_level': priority,
        'suggested_duration_seconds': suggestedDurationSeconds,
        'before_mood': beforeMood,
        'before_stress': beforeStress,
        'tracking_source': 'in_app_timer',
      },
    );

    final payload = _decodeResponse(response.body);

    _checkStatus(response.statusCode, payload);

    final data = _asMap(payload['data']);

    return _asMap(data['session']);
  }

  Future<Map<String, dynamic>> finishSession({
    required int sessionId,
    required String status,
    required int actualDurationSeconds,
    int? afterMood,
    int? afterStress,
    String? feedbackType,
    String? feedbackNote,
  }) async {
    final response = await _client.patch(
      '/recommendation-sessions/'
      '$sessionId',
      body: <String, dynamic>{
        'status': status,
        'actual_duration_seconds': actualDurationSeconds,
        'after_mood': afterMood,
        'after_stress': afterStress,
        'feedback_type': feedbackType,
        'feedback_note': feedbackNote?.trim().isEmpty == true
            ? null
            : feedbackNote?.trim(),
      },
    );

    final payload = _decodeResponse(response.body);

    _checkStatus(response.statusCode, payload);

    final data = _asMap(payload['data']);

    return _asMap(data['session']);
  }

  Future<Map<String, dynamic>> getSummary({int days = 7}) async {
    final safeDays = days.clamp(1, 90);

    final response = await _client.get(
      '/recommendation-sessions/'
      'summary?days=$safeDays',
    );

    final payload = _decodeResponse(response.body);

    _checkStatus(response.statusCode, payload);

    final data = _asMap(payload['data']);

    return _asMap(data['summary']);
  }

  Future<Map<String, dynamic>> getHistory({
    int page = 1,
    int limit = 50,
  }) async {
    final safePage = page < 1 ? 1 : page;

    final safeLimit = limit.clamp(1, 100);

    final response = await _client.get(
      '/recommendation-sessions/'
      'history?page=$safePage'
      '&limit=$safeLimit',
    );

    final payload = _decodeResponse(response.body);

    _checkStatus(response.statusCode, payload);

    return _asMap(payload['data']);
  }

  Map<String, dynamic> _decodeResponse(String source) {
    try {
      return _asMap(jsonDecode(source));
    } catch (_) {
      throw const RecommendationSessionApiException(
        'The server returned an invalid '
        'response.',
      );
    }
  }

  void _checkStatus(int statusCode, Map<String, dynamic> payload) {
    if (statusCode >= 200 && statusCode < 300) {
      return;
    }

    throw RecommendationSessionApiException(
      payload['message']?.toString() ??
          'Recommendation follow-up '
              'request failed.',
    );
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }
}
