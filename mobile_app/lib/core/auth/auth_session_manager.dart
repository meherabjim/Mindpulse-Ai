import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthRefreshUnavailableException implements Exception {
  const AuthRefreshUnavailableException([
    this.message =
        'Unable to verify your session right now. '
        'Check your connection and try again.',
  ]);

  final String message;

  @override
  String toString() => message;
}

class AuthSessionManager {
  AuthSessionManager._();

  static final AuthSessionManager instance = AuthSessionManager._();

  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000/api/v1',
  );

  static const String _accessTokenKey = 'mindpulse_access_token';
  static const String _refreshTokenKey = 'mindpulse_refresh_token';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  final http.Client _client = http.Client();

  Future<bool>? _refreshInFlight;

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _secureStorage.write(key: _accessTokenKey, value: accessToken),
      _secureStorage.write(key: _refreshTokenKey, value: refreshToken),
    ]);

    // পুরোনো insecure token থাকলে remove করা হবে।
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }

  Future<String?> readAccessToken() {
    return _secureStorage.read(key: _accessTokenKey);
  }

  Future<String?> readRefreshToken() {
    return _secureStorage.read(key: _refreshTokenKey);
  }

  Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt('user_id', (user['id'] as num?)?.toInt() ?? 0);

    await prefs.setString('user_email', user['email']?.toString() ?? '');

    await prefs.setString(
      'user_name',
      user['full_name']?.toString() ?? user['name']?.toString() ?? '',
    );
  }

  Future<Map<String, dynamic>> readUser() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      'id': prefs.getInt('user_id') ?? 0,
      'email': prefs.getString('user_email') ?? '',
      'full_name': prefs.getString('user_name') ?? '',
    };
  }

  Future<void> clearSession() async {
    await Future.wait([
      _secureStorage.delete(key: _accessTokenKey),
      _secureStorage.delete(key: _refreshTokenKey),
    ]);

    final prefs = await SharedPreferences.getInstance();

    const keys = [
      'access_token',
      'refresh_token',
      'user_id',
      'user_email',
      'user_name',
    ];

    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  Future<bool> ensureValidSession() async {
    final accessToken = await readAccessToken();

    if (accessToken != null &&
        accessToken.isNotEmpty &&
        !_isJwtExpired(accessToken)) {
      return true;
    }

    final refreshToken = await readRefreshToken();

    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    return refreshTokens();
  }

  Future<bool> refreshTokens() {
    final existingRequest = _refreshInFlight;

    if (existingRequest != null) {
      return existingRequest;
    }

    final request = _performRefresh();
    _refreshInFlight = request;

    request.whenComplete(() {
      _refreshInFlight = null;
    });

    return request;
  }

  Future<bool> _performRefresh() async {
    final currentRefreshToken = await readRefreshToken();

    if (currentRefreshToken == null || currentRefreshToken.isEmpty) {
      return false;
    }

    try {
      http.Response response = await _sendRefreshRequest(
        currentRefreshToken,
        useCamelCase: false,
      );

      if (response.statusCode == 400 || response.statusCode == 422) {
        response = await _sendRefreshRequest(
          currentRefreshToken,
          useCamelCase: true,
        );
      }

      final payload = _decodeMap(response.body);

      if (response.statusCode == 401 || response.statusCode == 403) {
        await clearSession();

        return false;
      }

      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          payload['success'] != true) {
        throw AuthRefreshUnavailableException(
          payload['message']?.toString() ??
              'The authentication service '
                  'is temporarily unavailable.',
        );
      }

      final data = _asMap(payload['data']);

      final tokens = _asMap(data['tokens']);

      final newAccessToken = _firstString([
        tokens['access_token'],
        tokens['accessToken'],
        data['access_token'],
        data['accessToken'],
      ]);

      final newRefreshToken =
          _firstString([
            tokens['refresh_token'],
            tokens['refreshToken'],
            data['refresh_token'],
            data['refreshToken'],
          ]) ??
          currentRefreshToken;

      if (newAccessToken == null || newAccessToken.isEmpty) {
        throw const AuthRefreshUnavailableException(
          'The authentication service returned '
          'an incomplete response.',
        );
      }

      await saveTokens(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
      );

      debugPrint(
        'MindPulse: Access token '
        'refreshed successfully.',
      );

      return true;
    } on TimeoutException {
      debugPrint('MindPulse: Token refresh timed out.');

      throw const AuthRefreshUnavailableException(
        'The server took too long to respond. '
        'Your saved session was kept.',
      );
    } on SocketException {
      debugPrint(
        'MindPulse: Token refresh network '
        'connection failed.',
      );

      throw const AuthRefreshUnavailableException(
        'Unable to reach the server. '
        'Your saved session was kept.',
      );
    } on http.ClientException {
      debugPrint(
        'MindPulse: Token refresh HTTP '
        'connection failed.',
      );

      throw const AuthRefreshUnavailableException(
        'Unable to reach the server. '
        'Your saved session was kept.',
      );
    } on AuthRefreshUnavailableException {
      rethrow;
    } catch (error) {
      debugPrint(
        'MindPulse: Token refresh failed: '
        '$error',
      );

      throw const AuthRefreshUnavailableException();
    }
  }

  Future<http.Response> _sendRefreshRequest(
    String refreshToken, {
    required bool useCamelCase,
  }) {
    return _client
        .post(
          Uri.parse('$_baseUrl/auth/refresh'),
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            useCamelCase ? 'refreshToken' : 'refresh_token': refreshToken,
          }),
        )
        .timeout(const Duration(seconds: 15));
  }

  bool _isJwtExpired(String token) {
    try {
      final parts = token.split('.');

      if (parts.length != 3) {
        return true;
      }

      final normalized = base64Url.normalize(parts[1]);

      final payload = jsonDecode(utf8.decode(base64Url.decode(normalized)));

      if (payload is! Map) {
        return true;
      }

      final expiry = payload['exp'];

      if (expiry is! num) {
        return true;
      }

      final expiryTime = DateTime.fromMillisecondsSinceEpoch(
        expiry.toInt() * 1000,
        isUtc: true,
      );

      // Expiry-এর ৩০ সেকেন্ড আগেই refresh করা হবে।
      return DateTime.now()
          .toUtc()
          .add(const Duration(seconds: 30))
          .isAfter(expiryTime);
    } catch (_) {
      return true;
    }
  }

  Map<String, dynamic> _decodeMap(String source) {
    try {
      return _asMap(jsonDecode(source));
    } catch (_) {
      return <String, dynamic>{};
    }
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

  String? _firstString(List<dynamic> candidates) {
    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }

    return null;
  }
}
