import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/auth/authenticated_http_client.dart';

class RecoveryApiException implements Exception {
  const RecoveryApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RecoveryService {
  RecoveryService({AuthenticatedHttpClient? client})
    : _client = client ?? AuthenticatedHttpClient.instance;

  final AuthenticatedHttpClient _client;

  Future<List<Map<String, dynamic>>> listActivities() async {
    final response = await _client.get('/recovery/activities');

    final payload = _decodeResponse(response);
    final data = _asMap(payload['data']);

    return _asList(data['activities']).map(_asMap).toList();
  }

  Future<Map<String, dynamic>> saveActivityLog(
    int activityId, {
    String status = 'completed',
    int? durationSeconds,
    int? rating,
    String? note,
  }) async {
    final response = await _client.post(
      '/recovery/activities/$activityId/logs',
      body: <String, dynamic>{
        'status': status,
        'duration_seconds': durationSeconds,
        'rating': rating,
        'note': note?.trim().isEmpty == true ? null : note?.trim(),
      },
    );

    final payload = _decodeResponse(response);
    final data = _asMap(payload['data']);

    return _asMap(data['log']);
  }

  Future<List<Map<String, dynamic>>> listActivityLogs({
    int page = 1,
    int limit = 50,
  }) async {
    final response = await _client.get(
      '/recovery/activity-logs?page=$page&limit=$limit',
    );

    final payload = _decodeResponse(response);
    final data = _asMap(payload['data']);

    return _asList(data['logs']).map(_asMap).toList();
  }

  Future<Map<String, dynamic>?> getActivePlan() async {
    final response = await _client.get('/recovery/plans/active');

    final payload = _decodeResponse(response);
    final data = _asMap(payload['data']);
    final plan = data['plan'];

    if (plan == null) {
      return null;
    }

    return _asMap(plan);
  }

  Future<List<Map<String, dynamic>>> listPlans() async {
    final response = await _client.get('/recovery/plans');

    final payload = _decodeResponse(response);
    final data = _asMap(payload['data']);

    return _asList(data['plans']).map(_asMap).toList();
  }

  Future<Map<String, dynamic>> createPlan({
    required String title,
    String? description,
    String? overallGoal,
    required String startDate,
    String? endDate,
    String? reviewDate,
    required List<Map<String, dynamic>> tasks,
  }) async {
    final response = await _client.post(
      '/recovery/plans',
      body: <String, dynamic>{
        'title': title.trim(),
        'description': description?.trim().isEmpty == true
            ? null
            : description?.trim(),
        'overall_goal': overallGoal?.trim().isEmpty == true
            ? null
            : overallGoal?.trim(),
        'generated_by': 'manual',
        'start_date': startDate,
        'end_date': endDate,
        'review_date': reviewDate,
        'tasks': tasks,
      },
    );

    final payload = _decodeResponse(response);
    final data = _asMap(payload['data']);

    return _asMap(data['plan']);
  }

  Future<Map<String, dynamic>> getPlan(int planId) async {
    final response = await _client.get('/recovery/plans/$planId');

    final payload = _decodeResponse(response);
    final data = _asMap(payload['data']);

    return _asMap(data['plan']);
  }

  Future<Map<String, dynamic>> updatePlanStatus(
    int planId,
    String status,
  ) async {
    final response = await _client.patch(
      '/recovery/plans/$planId/status',
      body: <String, dynamic>{'status': status},
    );

    final payload = _decodeResponse(response);
    final data = _asMap(payload['data']);

    return _asMap(data['plan']);
  }

  Future<Map<String, dynamic>> updateTask(
    int taskId, {
    required String status,
  }) async {
    final response = await _client.patch(
      '/recovery/tasks/$taskId',
      body: <String, dynamic>{'status': status},
    );

    final payload = _decodeResponse(response);
    final data = _asMap(payload['data']);

    return _asMap(data['task']);
  }

  Future<List<Map<String, dynamic>>> listProgress({
    int page = 1,
    int limit = 50,
  }) async {
    final response = await _client.get(
      '/recovery/progress?page=$page&limit=$limit',
    );

    final payload = _decodeResponse(response);
    final data = _asMap(payload['data']);

    return _asList(data['progress']).map(_asMap).toList();
  }

  Future<Map<String, dynamic>> saveProgress({
    int? recoveryPlanId,
    required String progressDate,
    required double moodScore,
    required double stressScore,
    required double sleepHours,
    required double energyLevel,
    required double habitCompletionPercent,
    required double activityCompletionPercent,
    required double burnoutScore,
    String? note,
  }) async {
    final response = await _client.post(
      '/recovery/progress',
      body: <String, dynamic>{
        'recovery_plan_id': recoveryPlanId,
        'progress_date': progressDate,
        'mood_score': moodScore,
        'stress_score': stressScore,
        'sleep_hours': sleepHours,
        'energy_level': energyLevel,
        'habit_completion_percent': habitCompletionPercent,
        'activity_completion_percent': activityCompletionPercent,
        'burnout_score': burnoutScore,
        'note': note?.trim().isEmpty == true ? null : note?.trim(),
      },
    );

    final payload = _decodeResponse(response);
    final data = _asMap(payload['data']);

    return _asMap(data['progress']);
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    dynamic decoded;

    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw const RecoveryApiException(
        'Invalid response received from the server.',
      );
    }

    if (decoded is! Map) {
      throw const RecoveryApiException('Unexpected recovery response format.');
    }

    final payload = Map<String, dynamic>.from(decoded);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errors = payload['errors'];

      if (errors is List && errors.isNotEmpty) {
        final firstError = errors.first;

        if (firstError is Map) {
          throw RecoveryApiException(
            firstError['message']?.toString() ??
                payload['message']?.toString() ??
                'Recovery request failed.',
          );
        }

        throw RecoveryApiException(firstError.toString());
      }

      throw RecoveryApiException(
        payload['message']?.toString() ?? 'Recovery request failed.',
      );
    }

    return payload;
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }

  static List<dynamic> _asList(dynamic value) {
    return value is List ? value : <dynamic>[];
  }
}
