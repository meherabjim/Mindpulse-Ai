import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class RegistrationApiException implements Exception {
  const RegistrationApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RegistrationService {
  RegistrationService({http.Client? client})
    : _client = client ?? http.Client();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000/api/v1',
  );

  final http.Client _client;

  Future<void> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/auth/register'),
            headers: const <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, String>{
              'full_name': fullName.trim(),
              'email': email.trim().toLowerCase(),
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 20));

      final payload = _decode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }

      final errors = payload['errors'];
      if (errors is List && errors.isNotEmpty) {
        throw RegistrationApiException(errors.first.toString());
      }

      throw RegistrationApiException(
        payload['message']?.toString() ??
            'Account registration could not be completed.',
      );
    } on TimeoutException {
      throw const RegistrationApiException(
        'The server took too long to respond. Please try again.',
      );
    } on SocketException {
      throw const RegistrationApiException(
        'Unable to reach the server. Check your connection.',
      );
    } on http.ClientException {
      throw const RegistrationApiException(
        'Unable to reach the server. Check your connection.',
      );
    } on RegistrationApiException {
      rethrow;
    } catch (_) {
      throw const RegistrationApiException(
        'Account registration could not be completed right now.',
      );
    }
  }

  Map<String, dynamic> _decode(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // Fall through to a safe generic response.
    }
    return <String, dynamic>{};
  }

  void dispose() {
    _client.close();
  }
}
