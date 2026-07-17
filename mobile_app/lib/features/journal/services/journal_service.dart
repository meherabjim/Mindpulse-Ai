import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/auth/authenticated_http_client.dart';

class JournalApiException implements Exception {
  const JournalApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class JournalService {
  JournalService({AuthenticatedHttpClient? client})
    : _client = client ?? AuthenticatedHttpClient.instance;

  final AuthenticatedHttpClient _client;

  Future<List<Map<String, dynamic>>> listJournals({
    String search = '',
    bool? favorite,
    String? tag,
    int page = 1,
    int limit = 50,
  }) async {
    final query = <String, String>{'page': '$page', 'limit': '$limit'};

    if (search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }

    if (favorite != null) {
      query['favorite'] = '$favorite';
    }

    if (tag != null && tag.trim().isNotEmpty) {
      query['tag'] = tag.trim();
    }

    final encodedQuery = Uri(queryParameters: query).query;

    final response = await _client.get('/journals?$encodedQuery');

    final payload = _decodeResponse(response);
    final data = _asMap(payload['data']);

    return _asList(data['journals']).map(_asMap).toList();
  }

  Future<Map<String, dynamic>> getJournal(int journalId) async {
    final response = await _client.get('/journals/$journalId');

    final payload = _decodeResponse(response);
    final data = _asMap(payload['data']);

    return _asMap(data['journal']);
  }

  Future<Map<String, dynamic>> createJournal({
    String? title,
    required String content,
    required String entryDate,
    int? moodScore,
    required bool isPrivate,
    required bool isFavorite,
    required List<String> tags,
  }) async {
    final response = await _client.post(
      '/journals',
      body: <String, dynamic>{
        'title': title?.trim().isEmpty == true ? null : title?.trim(),
        'content': content.trim(),
        'entry_date': entryDate,
        'mood_score': moodScore,
        'is_private': isPrivate,
        'is_favorite': isFavorite,
        'tags': tags,
      },
    );

    final payload = _decodeResponse(response);
    final data = _asMap(payload['data']);

    return _asMap(data['journal']);
  }

  Future<Map<String, dynamic>> updateJournal(
    int journalId, {
    String? title,
    required String content,
    required String entryDate,
    int? moodScore,
    required bool isPrivate,
    required bool isFavorite,
    required List<String> tags,
  }) async {
    final response = await _client.patch(
      '/journals/$journalId',
      body: <String, dynamic>{
        'title': title?.trim().isEmpty == true ? null : title?.trim(),
        'content': content.trim(),
        'entry_date': entryDate,
        'mood_score': moodScore,
        'is_private': isPrivate,
        'is_favorite': isFavorite,
        'tags': tags,
      },
    );

    final payload = _decodeResponse(response);
    final data = _asMap(payload['data']);

    return _asMap(data['journal']);
  }

  Future<void> updateFavorite(int journalId, bool isFavorite) async {
    final response = await _client.patch(
      '/journals/$journalId',
      body: <String, dynamic>{'is_favorite': isFavorite},
    );

    _decodeResponse(response);
  }

  Future<void> deleteJournal(int journalId) async {
    final response = await _client.delete('/journals/$journalId');

    _decodeResponse(response);
  }

  Future<List<Map<String, dynamic>>> listTags() async {
    final response = await _client.get('/journals/tags');

    final payload = _decodeResponse(response);
    final data = _asMap(payload['data']);

    return _asList(data['tags']).map(_asMap).toList();
  }

  Future<Map<String, dynamic>> createTag(String name) async {
    final response = await _client.post(
      '/journals/tags',
      body: <String, dynamic>{'name': name.trim()},
    );

    final payload = _decodeResponse(response);
    final data = _asMap(payload['data']);

    return _asMap(data['tag']);
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    dynamic decoded;

    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw const JournalApiException(
        'Invalid response received from the server.',
      );
    }

    if (decoded is! Map) {
      throw const JournalApiException('Unexpected journal response format.');
    }

    final payload = Map<String, dynamic>.from(decoded);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errors = payload['errors'];

      if (errors is List && errors.isNotEmpty) {
        throw JournalApiException(errors.first.toString());
      }

      throw JournalApiException(
        payload['message']?.toString() ?? 'Journal request failed.',
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
