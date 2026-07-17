import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/auth/authenticated_http_client.dart';

class WellnessScanApiException implements Exception {
  const WellnessScanApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class WellnessScanService {
  WellnessScanService({AuthenticatedHttpClient? client})
    : _client = client ?? AuthenticatedHttpClient.instance;

  final AuthenticatedHttpClient _client;

  Future<List<Map<String, dynamic>>> listQuestions() async {
    final response = await _client.get('/wellness/questions');

    final payload = _decode(response);
    final data = _asMap(payload['data']);

    return _asList(data['questions']).map(_asMap).toList();
  }

  Future<Map<String, dynamic>> submitScan(
    List<Map<String, dynamic>> answers,
  ) async {
    final response = await _client.post(
      '/wellness/scans',
      body: <String, dynamic>{'answers': answers},
    );

    final payload = _decode(response);
    final data = _asMap(payload['data']);

    return _asMap(data['scan']);
  }

  Future<Map<String, dynamic>?> getLatestScan() async {
    final response = await _client.get('/wellness/scans/latest');

    final payload = _decode(response);
    final data = _asMap(payload['data']);
    final scan = _asMap(data['scan']);

    return scan.isEmpty ? null : scan;
  }

  Future<Map<String, dynamic>> getScanHistory({
    int page = 1,
    int limit = 50,
  }) async {
    final response = await _client.get(
      '/wellness/scans/history'
      '?page=$page&limit=$limit',
    );

    final payload = _decode(response);
    final data = _asMap(payload['data']);

    return <String, dynamic>{
      'scans': _asList(data['scans']).map(_asMap).toList(),
      'pagination': _asMap(data['pagination']),
    };
  }

  Future<Map<String, dynamic>> getScanById(int scanId) async {
    final response = await _client.get('/wellness/scans/$scanId');

    final payload = _decode(response);
    final data = _asMap(payload['data']);

    return _asMap(data['scan']);
  }

  Future<Map<String, dynamic>?> getLatestBurnout() async {
    final response = await _client.get('/burnout/latest');

    final payload = _decode(response);
    final data = _asMap(payload['data']);
    final assessment = _asMap(data['assessment']);

    return assessment.isEmpty ? null : assessment;
  }

  Map<String, dynamic> _decode(http.Response response) {
    dynamic decoded;

    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw const WellnessScanApiException(
        'Invalid response received from the server.',
      );
    }

    if (decoded is! Map) {
      throw const WellnessScanApiException(
        'Unexpected wellness response format.',
      );
    }

    final payload = Map<String, dynamic>.from(decoded);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errors = payload['errors'];

      if (errors is List && errors.isNotEmpty) {
        final messages = errors
            .map((error) {
              if (error is Map) {
                return error['message']?.toString() ?? error.toString();
              }

              return error.toString();
            })
            .join('\n');

        throw WellnessScanApiException(messages);
      }

      throw WellnessScanApiException(
        payload['message']?.toString() ?? 'Wellness request failed.',
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
