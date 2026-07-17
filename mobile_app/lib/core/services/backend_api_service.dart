import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../auth/authenticated_http_client.dart';

class BackendApiService {
  BackendApiService._();

  static final BackendApiService instance = BackendApiService._();

  final AuthenticatedHttpClient _client = AuthenticatedHttpClient.instance;

  Future<void> registerDeviceToken(String firebaseToken) async {
    if (firebaseToken.trim().isEmpty) {
      throw ArgumentError('Firebase token cannot be empty.');
    }

    final response = await _client.post(
      '/devices',
      body: {
        'token': firebaseToken,
        'platform': 'android',
        'device_name': 'Android Emulator',
      },
    );

    final responseData = _decodeMap(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        responseData['message']?.toString() ??
            'Device-token registration failed.',
      );
    }

    debugPrint('MindPulse: Real Firebase token registered with backend.');
  }

  Map<String, dynamic> _decodeMap(String source) {
    try {
      final decoded = jsonDecode(source);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // নিচে empty map return হবে।
    }

    return <String, dynamic>{};
  }
}
