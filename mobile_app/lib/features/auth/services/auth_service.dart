import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/auth/auth_session_manager.dart';
import '../../../core/services/backend_api_service.dart';

class AuthLoginException implements Exception {
  const AuthLoginException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthService {
  AuthService({http.Client? client}) : _client = client ?? http.Client();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000/api/v1',
  );

  final http.Client _client;

  final AuthSessionManager _session = AuthSessionManager.instance;

  Future<bool> login(String email, String password) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));

      final body = _decodeMap(response.body);

      if (response.statusCode == 401 || response.statusCode == 403) {
        return false;
      }

      if (response.statusCode != 200 || body['success'] != true) {
        throw AuthLoginException(
          body['message']?.toString() ??
              'The login service is '
                  'temporarily unavailable.',
        );
      }

      final data = _asMap(body['data']);

      final user = _asMap(data['user']);

      final tokens = _asMap(data['tokens']);

      final accessToken = _firstString([
        tokens['access_token'],
        tokens['accessToken'],
      ]);

      final refreshToken = _firstString([
        tokens['refresh_token'],
        tokens['refreshToken'],
      ]);

      if (accessToken == null || refreshToken == null) {
        throw const AuthLoginException(
          'The server returned an '
          'incomplete login response.',
        );
      }

      await _session.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );

      await _session.saveUser(user);

      try {
        final firebaseToken = await FirebaseMessaging.instance.getToken();

        if (firebaseToken != null && firebaseToken.isNotEmpty) {
          await BackendApiService.instance.registerDeviceToken(firebaseToken);
        }
      } catch (error) {
        debugPrint(
          'MindPulse: FCM registration '
          'after login failed: $error',
        );
      }

      return true;
    } on TimeoutException {
      throw const AuthLoginException(
        'The server took too long to respond. '
        'Please try again.',
      );
    } on SocketException {
      throw const AuthLoginException(
        'Unable to reach the server. '
        'Check your connection and try again.',
      );
    } on http.ClientException {
      throw const AuthLoginException(
        'Unable to reach the server. '
        'Check your connection and try again.',
      );
    } on AuthLoginException {
      rethrow;
    } catch (error) {
      debugPrint('MindPulse: Login error: $error');

      throw const AuthLoginException(
        'Login could not be completed '
        'right now. Please try again.',
      );
    }
  }

  Future<bool> isLoggedIn() async {
    try {
      return await _session.ensureValidSession();
    } on AuthRefreshUnavailableException {
      final refreshToken = await _session.readRefreshToken();

      return refreshToken != null && refreshToken.isNotEmpty;
    }
  }

  Future<String?> getToken() async {
    final valid = await _session.ensureValidSession();

    if (!valid) {
      return null;
    }

    return _session.readAccessToken();
  }

  Future<Map<String, dynamic>> getUser() {
    return _session.readUser();
  }

  Future<void> logout() async {
    final refreshToken = await _session.readRefreshToken();

    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await _client
            .post(
              Uri.parse('$baseUrl/auth/logout'),
              headers: const {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode({'refresh_token': refreshToken}),
            )
            .timeout(const Duration(seconds: 10));
      } catch (error) {
        debugPrint('MindPulse: Remote logout failed: $error');
      }
    }

    await _session.clearSession();
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
    for (final value in candidates) {
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return null;
  }
}
