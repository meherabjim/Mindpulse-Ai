import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/auth/authenticated_http_client.dart';

class WeeklyReportApiException implements Exception {
  const WeeklyReportApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class WeeklyReportService {
  WeeklyReportService({AuthenticatedHttpClient? client})
    : _client = client ?? AuthenticatedHttpClient.instance;

  final AuthenticatedHttpClient _client;

  Future<List<Map<String, dynamic>>> listReports({
    int page = 1,
    int limit = 50,
  }) async {
    final response = await _client.get('/reports?page=$page&limit=$limit');

    final payload = _decodeResponse(response);
    final data = _asMap(payload['data']);

    final reportsValue = data['reports'] ?? payload['reports'];

    return _asList(reportsValue).map(_asMap).toList();
  }

  Future<Map<String, dynamic>> generateWeeklyReport() async {
    final response = await _client.post(
      '/reports/generate',
      body: <String, dynamic>{'report_type': 'weekly'},
    );

    final payload = _decodeResponse(response);
    final data = _asMap(payload['data']);

    if (data['report'] != null) {
      return _asMap(data['report']);
    }

    return data;
  }

  Future<Map<String, dynamic>> getReport(int reportId) async {
    final response = await _client.get('/reports/$reportId');

    final payload = _decodeResponse(response);
    final data = _asMap(payload['data']);

    if (data['report'] != null) {
      return _asMap(data['report']);
    }

    return data;
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    dynamic decoded;

    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw const WeeklyReportApiException(
        'Invalid response received from the server.',
      );
    }

    if (decoded is! Map) {
      throw const WeeklyReportApiException(
        'Unexpected weekly report response format.',
      );
    }

    final payload = Map<String, dynamic>.from(decoded);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errors = payload['errors'];

      if (errors is List && errors.isNotEmpty) {
        final firstError = errors.first;

        if (firstError is Map) {
          throw WeeklyReportApiException(
            firstError['message']?.toString() ??
                payload['message']?.toString() ??
                'Weekly report request failed.',
          );
        }

        throw WeeklyReportApiException(firstError.toString());
      }

      throw WeeklyReportApiException(
        payload['message']?.toString() ?? 'Weekly report request failed.',
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
