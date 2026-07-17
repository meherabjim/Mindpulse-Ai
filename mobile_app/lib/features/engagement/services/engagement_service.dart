import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/auth/authenticated_http_client.dart';

class EngagementApiException implements Exception {
  const EngagementApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class EngagementService {
  EngagementService({AuthenticatedHttpClient? client})
    : _client = client ?? AuthenticatedHttpClient.instance;

  final AuthenticatedHttpClient _client;

  Future<Map<String, dynamic>> listNotifications({
    int page = 1,
    int limit = 50,
  }) async {
    final response = await _client.get(
      '/notifications?page=$page&limit=$limit',
    );

    final payload = _decode(response);
    final data = _asMap(payload['data']);

    return <String, dynamic>{
      'notifications': _asList(data['notifications']).map(_asMap).toList(),
      'pagination': _asMap(data['pagination']),
    };
  }

  Future<int> getUnreadCount() async {
    final response = await _client.get('/notifications/unread-count');

    final payload = _decode(response);
    final data = _asMap(payload['data']);

    return _integerValue(data['unread_count']);
  }

  Future<void> markNotificationRead(int notificationId) async {
    final response = await _client.patch('/notifications/$notificationId/read');

    _decode(response);
  }

  Future<int> markAllNotificationsRead() async {
    final response = await _client.patch('/notifications/read-all');

    final payload = _decode(response);
    final data = _asMap(payload['data']);

    return _integerValue(data['updated_count']);
  }

  Future<void> deleteNotification(int notificationId) async {
    final response = await _client.delete('/notifications/$notificationId');

    _decode(response);
  }

  Future<Map<String, dynamic>> getAchievements() async {
    final response = await _client.get('/achievements');

    final payload = _decode(response);

    return _asMap(payload['data']);
  }

  Future<Map<String, dynamic>> syncAchievements() async {
    final response = await _client.post('/achievements/sync');

    final payload = _decode(response);

    return _asMap(payload['data']);
  }

  Map<String, dynamic> _decode(http.Response response) {
    dynamic decoded;

    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw const EngagementApiException(
        'Invalid response received from the server.',
      );
    }

    if (decoded is! Map) {
      throw const EngagementApiException(
        'Unexpected engagement response format.',
      );
    }

    final payload = Map<String, dynamic>.from(decoded);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errors = payload['errors'];

      if (errors is List && errors.isNotEmpty) {
        final firstError = errors.first;

        if (firstError is Map) {
          throw EngagementApiException(
            firstError['message']?.toString() ??
                payload['message']?.toString() ??
                'Request failed.',
          );
        }

        throw EngagementApiException(firstError.toString());
      }

      throw EngagementApiException(
        payload['message']?.toString() ?? 'Request failed.',
      );
    }

    return payload;
  }

  static int _integerValue(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
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
