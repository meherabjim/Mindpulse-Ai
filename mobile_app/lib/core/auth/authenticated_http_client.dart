import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../navigation/app_navigator.dart';
import 'auth_session_manager.dart';

class AuthSessionExpiredException implements Exception {
  const AuthSessionExpiredException();

  @override
  String toString() {
    return 'Your session has expired. Please log in again.';
  }
}

class AuthServiceUnavailableException implements Exception {
  const AuthServiceUnavailableException([
    this.message =
        'The server is temporarily unavailable. '
        'Please check your connection and try again.',
  ]);

  final String message;

  @override
  String toString() => message;
}

class AuthenticatedHttpClient {
  AuthenticatedHttpClient._();

  static final AuthenticatedHttpClient instance = AuthenticatedHttpClient._();

  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000/api/v1',
  );

  final http.Client _client = http.Client();

  final AuthSessionManager _session = AuthSessionManager.instance;

  Future<http.Response> get(String path, {Map<String, String>? headers}) {
    return _request(method: 'GET', path: path, headers: headers);
  }

  Future<http.Response> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) {
    return _request(method: 'POST', path: path, body: body, headers: headers);
  }

  Future<http.Response> put(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) {
    return _request(method: 'PUT', path: path, body: body, headers: headers);
  }

  Future<http.Response> patch(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) {
    return _request(method: 'PATCH', path: path, body: body, headers: headers);
  }

  Future<http.Response> delete(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) {
    return _request(method: 'DELETE', path: path, body: body, headers: headers);
  }

  Future<http.Response> _request({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool allowRefresh = true,
  }) async {
    late final bool hasSession;

    try {
      hasSession = await _session.ensureValidSession();
    } on AuthRefreshUnavailableException catch (error) {
      throw AuthServiceUnavailableException(error.toString());
    }

    if (!hasSession) {
      AppNavigator.goToLogin();
      throw const AuthSessionExpiredException();
    }

    final response = await _send(
      method: method,
      path: path,
      body: body,
      headers: headers,
    );

    if (response.statusCode != 401 || !allowRefresh) {
      return response;
    }

    late final bool refreshed;

    try {
      refreshed = await _session.refreshTokens();
    } on AuthRefreshUnavailableException catch (error) {
      throw AuthServiceUnavailableException(error.toString());
    }

    if (!refreshed) {
      await _session.clearSession();
      AppNavigator.goToLogin();

      throw const AuthSessionExpiredException();
    }

    final retryResponse = await _send(
      method: method,
      path: path,
      body: body,
      headers: headers,
    );

    if (retryResponse.statusCode == 401) {
      await _session.clearSession();
      AppNavigator.goToLogin();

      throw const AuthSessionExpiredException();
    }

    return retryResponse;
  }

  Future<http.Response> _send({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final accessToken = await _session.readAccessToken();

    if (accessToken == null || accessToken.isEmpty) {
      throw const AuthSessionExpiredException();
    }

    final request = http.Request(method, Uri.parse('$_baseUrl$path'));

    request.headers.addAll({
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
      ...?headers,
    });

    if (body != null) {
      request.body = jsonEncode(body);
    }

    try {
      final streamedResponse = await _client
          .send(request)
          .timeout(const Duration(seconds: 20));

      return http.Response.fromStream(streamedResponse);
    } on TimeoutException {
      throw const AuthServiceUnavailableException(
        'The server took too long to respond. '
        'Please try again.',
      );
    } on SocketException {
      throw const AuthServiceUnavailableException(
        'Unable to reach the server. '
        'Check your connection and try again.',
      );
    } on http.ClientException {
      throw const AuthServiceUnavailableException(
        'Unable to reach the server. '
        'Check your connection and try again.',
      );
    }
  }
}
