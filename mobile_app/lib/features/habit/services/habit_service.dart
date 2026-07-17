import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/auth/authenticated_http_client.dart';

class HabitApiException implements Exception {
  const HabitApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class HabitService {
  HabitService({AuthenticatedHttpClient? client})
    : _client = client ?? AuthenticatedHttpClient.instance;

  final AuthenticatedHttpClient _client;

  Future<List<Map<String, dynamic>>> listTemplates() async {
    final response = await _client.get('/habit-templates');
    final payload = _decode(response);
    final data = _asMap(payload['data']);

    return _asList(data['templates']).map(_asMap).toList();
  }

  Future<Map<String, dynamic>> listTodayHabits() async {
    final response = await _client.get('/habits/today');
    final payload = _decode(response);
    final data = _asMap(payload['data']);

    return <String, dynamic>{
      'date': data['date'],
      'habits': _asList(data['habits']).map(_asMap).toList(),
      'total': data['total'] ?? 0,
    };
  }

  Future<List<Map<String, dynamic>>> listHabits() async {
    final response = await _client.get('/habits');
    final payload = _decode(response);
    final data = _asMap(payload['data']);

    return _asList(data['habits']).map(_asMap).toList();
  }

  Future<Map<String, dynamic>> getHabit(int habitId) async {
    final response = await _client.get('/habits/$habitId');
    final payload = _decode(response);
    final data = _asMap(payload['data']);

    return _asMap(data['habit']);
  }

  Future<Map<String, dynamic>> createHabit({
    int? templateId,
    String? name,
    String? description,
    String? category,
    required String frequencyType,
    List<String>? scheduleDays,
    required double targetValue,
    String? unit,
    required bool reminderEnabled,
    String? reminderTime,
    required String startDate,
    String? endDate,
  }) async {
    final response = await _client.post(
      '/habits',
      body: <String, dynamic>{
        'template_id': templateId,
        'name': _nullableText(name),
        'description': _nullableText(description),
        'category': _nullableText(category),
        'frequency_type': frequencyType,
        'schedule_days': frequencyType == 'daily' ? null : scheduleDays,
        'target_value': targetValue,
        'unit': _nullableText(unit),
        'reminder_enabled': reminderEnabled,
        'reminder_time': reminderEnabled ? _nullableText(reminderTime) : null,
        'start_date': startDate,
        'end_date': _nullableText(endDate),
      },
    );

    final payload = _decode(response);
    final data = _asMap(payload['data']);

    return _asMap(data['habit']);
  }

  Future<Map<String, dynamic>> updateHabit(
    int habitId, {
    required String name,
    String? description,
    required String category,
    required String frequencyType,
    List<String>? scheduleDays,
    required double targetValue,
    String? unit,
    required bool reminderEnabled,
    String? reminderTime,
    required String startDate,
    String? endDate,
    required bool isActive,
  }) async {
    final response = await _client.patch(
      '/habits/$habitId',
      body: <String, dynamic>{
        'name': name.trim(),
        'description': _nullableText(description),
        'category': category.trim(),
        'frequency_type': frequencyType,
        'schedule_days': frequencyType == 'daily' ? <String>[] : scheduleDays,
        'target_value': targetValue,
        'unit': _nullableText(unit),
        'reminder_enabled': reminderEnabled,
        'reminder_time': reminderEnabled ? _nullableText(reminderTime) : null,
        'start_date': startDate,
        'end_date': _nullableText(endDate),
        'is_active': isActive,
      },
    );

    final payload = _decode(response);
    final data = _asMap(payload['data']);

    return _asMap(data['habit']);
  }

  Future<Map<String, dynamic>> saveHabitLog(
    int habitId, {
    String? logDate,
    required String status,
    double? completedValue,
    String? note,
  }) async {
    final response = await _client.post(
      '/habits/$habitId/logs',
      body: <String, dynamic>{
        'log_date': logDate,
        'status': status,
        'completed_value': completedValue,
        'note': _nullableText(note),
      },
    );

    final payload = _decode(response);
    final data = _asMap(payload['data']);

    return <String, dynamic>{
      'log': _asMap(data['log']),
      'habit': _asMap(data['habit']),
    };
  }

  Future<Map<String, dynamic>> getHabitLogs(
    int habitId, {
    int page = 1,
    int limit = 31,
    String? fromDate,
    String? toDate,
  }) async {
    final query = <String, String>{'page': '$page', 'limit': '$limit'};

    if (fromDate != null && fromDate.isNotEmpty) {
      query['from_date'] = fromDate;
    }

    if (toDate != null && toDate.isNotEmpty) {
      query['to_date'] = toDate;
    }

    final encodedQuery = Uri(queryParameters: query).query;

    final response = await _client.get('/habits/$habitId/logs?$encodedQuery');

    final payload = _decode(response);
    final data = _asMap(payload['data']);

    return <String, dynamic>{
      'habit': _asMap(data['habit']),
      'logs': _asList(data['logs']).map(_asMap).toList(),
      'pagination': _asMap(data['pagination']),
    };
  }

  Future<void> archiveHabit(int habitId) async {
    final response = await _client.delete('/habits/$habitId');
    _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    dynamic decoded;

    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw const HabitApiException(
        'Invalid response received from the server.',
      );
    }

    if (decoded is! Map) {
      throw const HabitApiException('Unexpected habit response format.');
    }

    final payload = Map<String, dynamic>.from(decoded);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errors = payload['errors'];

      if (errors is List && errors.isNotEmpty) {
        final firstError = errors.first;

        if (firstError is Map) {
          throw HabitApiException(
            firstError['message']?.toString() ??
                payload['message']?.toString() ??
                'Habit request failed.',
          );
        }

        throw HabitApiException(firstError.toString());
      }

      throw HabitApiException(
        payload['message']?.toString() ?? 'Habit request failed.',
      );
    }

    return payload;
  }

  static String? _nullableText(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
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
