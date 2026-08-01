import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/reading_plan_models.dart';

class ReadingCatalogueException implements Exception {
  const ReadingCatalogueException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ReadingCatalogueService {
  ReadingCatalogueService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<ReadingCatalogueResult>> search({
    required String query,
    required String author,
    required String contentType,
  }) {
    if (<String>{'article', 'research_paper'}.contains(contentType)) {
      return _searchCrossref(
        query: query,
        author: author,
        contentType: contentType,
      );
    }

    return _searchGoogleBooks(
      query: query,
      author: author,
      contentType: contentType,
    );
  }

  Future<List<ReadingCatalogueResult>> _searchGoogleBooks({
    required String query,
    required String author,
    required String contentType,
  }) async {
    final compactIdentifier = query.replaceAll(RegExp(r'[^0-9Xx]'), '');
    final looksLikeIsbn =
        compactIdentifier.length == 10 || compactIdentifier.length == 13;

    final queryParts = <String>[
      looksLikeIsbn ? 'isbn:$compactIdentifier' : 'intitle:"$query"',
    ];

    if (author.trim().isNotEmpty) {
      queryParts.add('inauthor:"${author.trim()}"');
    }

    final printType = contentType == 'magazine' ? 'magazines' : 'all';

    final uri =
        Uri.https('www.googleapis.com', '/books/v1/volumes', <String, String>{
          'q': queryParts.join(' '),
          'maxResults': '10',
          'orderBy': 'relevance',
          'printType': printType,
          'projection': 'full',
        });

    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw ReadingCatalogueException(
        'Google Books returned ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const ReadingCatalogueException(
        'Google Books returned an invalid response.',
      );
    }

    final rawItems = decoded['items'];
    if (rawItems is! List) {
      return <ReadingCatalogueResult>[];
    }

    final results = <ReadingCatalogueResult>[];

    for (final raw in rawItems.whereType<Map>()) {
      final item = Map<String, dynamic>.from(raw);
      final volumeRaw = item['volumeInfo'];
      final volume = volumeRaw is Map
          ? Map<String, dynamic>.from(volumeRaw)
          : <String, dynamic>{};

      final title = volume['title']?.toString().trim() ?? '';
      if (title.isEmpty) continue;

      final authorsRaw = volume['authors'];
      final authors = authorsRaw is List
          ? authorsRaw.map((value) => value.toString()).join(', ')
          : '';

      var identifier = '';
      final identifiersRaw = volume['industryIdentifiers'];
      if (identifiersRaw is List) {
        for (final entry in identifiersRaw.whereType<Map>()) {
          final value = entry['identifier']?.toString().trim() ?? '';
          if (value.isNotEmpty) {
            identifier = value;
            break;
          }
        }
      }

      final printType = volume['printType']?.toString().toUpperCase() ?? '';
      final resolvedType = printType == 'MAGAZINE'
          ? 'magazine'
          : contentType == 'textbook' || contentType == 'supplementary'
          ? contentType
          : contentType == 'novel'
          ? 'novel'
          : 'book';

      final sourceId = item['id']?.toString() ?? '';

      results.add(
        ReadingCatalogueResult(
          id: sourceId.isEmpty
              ? DateTime.now().microsecondsSinceEpoch.toString()
              : sourceId,
          type: resolvedType,
          title: title,
          author: authors,
          publisher: volume['publisher']?.toString().trim() ?? '',
          publishedDate: volume['publishedDate']?.toString().trim() ?? '',
          language: volume['language']?.toString().trim() ?? '',
          identifier: identifier,
          source: 'google_books',
          sourceUrl: sourceId.isEmpty
              ? ''
              : 'https://books.google.com/books?id=$sourceId',
        ),
      );
    }

    return results;
  }

  Future<List<ReadingCatalogueResult>> _searchCrossref({
    required String query,
    required String author,
    required String contentType,
  }) async {
    final searchText = <String>[
      query.trim(),
      if (author.trim().isNotEmpty) author.trim(),
    ].join(' ');

    final uri = Uri.https('api.crossref.org', '/works', <String, String>{
      'query.bibliographic': searchText,
      'rows': '10',
      'select': 'DOI,title,author,publisher,published,type,URL',
    });

    final response = await _client
        .get(
          uri,
          headers: const <String, String>{
            'Accept': 'application/json',
            'User-Agent': 'MindPulse-AI/1.0',
          },
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw ReadingCatalogueException(
        'Crossref returned ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const ReadingCatalogueException(
        'Crossref returned an invalid response.',
      );
    }

    final messageRaw = decoded['message'];
    final message = messageRaw is Map
        ? Map<String, dynamic>.from(messageRaw)
        : <String, dynamic>{};
    final rawItems = message['items'];

    if (rawItems is! List) {
      return <ReadingCatalogueResult>[];
    }

    final results = <ReadingCatalogueResult>[];

    for (final raw in rawItems.whereType<Map>()) {
      final item = Map<String, dynamic>.from(raw);
      final titlesRaw = item['title'];
      final title = titlesRaw is List && titlesRaw.isNotEmpty
          ? titlesRaw.first.toString().trim()
          : '';
      if (title.isEmpty) continue;

      final authorsRaw = item['author'];
      final authors = <String>[];
      if (authorsRaw is List) {
        for (final rawAuthor in authorsRaw.whereType<Map>()) {
          final given = rawAuthor['given']?.toString().trim() ?? '';
          final family = rawAuthor['family']?.toString().trim() ?? '';
          final name = <String>[
            if (given.isNotEmpty) given,
            if (family.isNotEmpty) family,
          ].join(' ');
          if (name.isNotEmpty) authors.add(name);
        }
      }

      final doi = item['DOI']?.toString().trim() ?? '';
      final publishedDate = _crossrefDate(item['published']);
      final itemType = item['type']?.toString() ?? '';
      final resolvedType = contentType == 'research_paper'
          ? 'research_paper'
          : itemType.contains('journal') || itemType.contains('proceedings')
          ? 'article'
          : contentType;

      results.add(
        ReadingCatalogueResult(
          id: doi.isEmpty
              ? DateTime.now().microsecondsSinceEpoch.toString()
              : doi,
          type: resolvedType,
          title: title,
          author: authors.join(', '),
          publisher: item['publisher']?.toString().trim() ?? '',
          publishedDate: publishedDate,
          language: '',
          identifier: doi,
          source: 'crossref',
          sourceUrl:
              item['URL']?.toString().trim() ??
              (doi.isEmpty ? '' : 'https://doi.org/$doi'),
        ),
      );
    }

    return results;
  }

  String _crossrefDate(dynamic raw) {
    if (raw is! Map) return '';
    final partsRaw = raw['date-parts'];
    if (partsRaw is! List || partsRaw.isEmpty) return '';
    final first = partsRaw.first;
    if (first is! List || first.isEmpty) return '';
    return first.map((value) => value.toString()).join('-');
  }

  void dispose() {
    _client.close();
  }
}
