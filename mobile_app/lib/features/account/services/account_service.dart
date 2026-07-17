import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/auth/auth_session_manager.dart';
import '../../../core/auth/authenticated_http_client.dart';

class AccountApiException implements Exception {
  const AccountApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AccountService {
  AccountService({AuthenticatedHttpClient? client})
    : _client = client ?? AuthenticatedHttpClient.instance;

  final AuthenticatedHttpClient _client;
  final AuthSessionManager _session = AuthSessionManager.instance;

  Future<Map<String, dynamic>> getProfile() async {
    final response = await _client.get('/profile');
    final payload = _decode(response);
    final data = _asMap(payload['data']);
    final profile = _asMap(data['profile']);

    if (profile.isNotEmpty) {
      await _session.saveUser(profile);
    }

    return profile;
  }

  Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> profileData,
  ) async {
    final response = await _client.patch('/profile', body: profileData);

    final payload = _decode(response);
    final data = _asMap(payload['data']);
    final profile = _asMap(data['profile']);

    if (profile.isNotEmpty) {
      await _session.saveUser(profile);
    }

    return profile;
  }

  Future<Map<String, dynamic>> getSettings() async {
    final response = await _client.get('/settings');
    final payload = _decode(response);
    final data = _asMap(payload['data']);

    return _asMap(data['settings']);
  }

  Future<Map<String, dynamic>> updateSettings({
    required Map<String, dynamic> appSettings,
    required Map<String, dynamic> notificationPreferences,
  }) async {
    final response = await _client.patch(
      '/settings',
      body: <String, dynamic>{
        'app_settings': appSettings,
        'notification_preferences': notificationPreferences,
      },
    );

    final payload = _decode(response);
    final data = _asMap(payload['data']);

    return _asMap(data['settings']);
  }

  Future<Map<String, dynamic>> completeOnboarding({
    required Map<String, dynamic> profile,
    required Map<String, dynamic> appSettings,
    required Map<String, dynamic> notificationPreferences,
    required Map<String, bool> consents,
    String policyVersion = '1.0',
  }) async {
    final response = await _client.post(
      '/onboarding/complete',
      body: <String, dynamic>{
        'profile': profile,
        'app_settings': appSettings,
        'notification_preferences': notificationPreferences,
        'consents': consents,
        'policy_version': policyVersion,
      },
    );

    final payload = _decode(response);
    final data = _asMap(payload['data']);
    final savedProfile = _asMap(data['profile']);

    if (savedProfile.isNotEmpty) {
      await _session.saveUser(savedProfile);
    }

    return data;
  }

  Future<Map<String, dynamic>> getOnboardingStatus() async {
    final response = await _client.get('/onboarding/status');
    final payload = _decode(response);
    final data = _asMap(payload['data']);

    return _asMap(data['onboarding']);
  }

  Future<List<Map<String, dynamic>>> listEmergencyContacts() async {
    final response = await _client.get('/emergency-contacts');
    final payload = _decode(response);
    final data = _asMap(payload['data']);

    return _asList(data['contacts']).map(_asMap).toList();
  }

  Future<Map<String, dynamic>> createEmergencyContact({
    required String fullName,
    String? relationshipName,
    required String phoneNumber,
    String? email,
    required bool isPrimary,
  }) async {
    final response = await _client.post(
      '/emergency-contacts',
      body: <String, dynamic>{
        'full_name': fullName.trim(),
        'relationship_name': _nullableText(relationshipName),
        'phone_number': phoneNumber.trim(),
        'email': _nullableText(email),
        'is_primary': isPrimary,
      },
    );

    final payload = _decode(response);
    final data = _asMap(payload['data']);

    return _asMap(data['contact']);
  }

  Future<Map<String, dynamic>> updateEmergencyContact(
    int contactId, {
    required String fullName,
    String? relationshipName,
    required String phoneNumber,
    String? email,
    required bool isPrimary,
  }) async {
    final response = await _client.patch(
      '/emergency-contacts/$contactId',
      body: <String, dynamic>{
        'full_name': fullName.trim(),
        'relationship_name': _nullableText(relationshipName),
        'phone_number': phoneNumber.trim(),
        'email': _nullableText(email),
        'is_primary': isPrimary,
      },
    );

    final payload = _decode(response);
    final data = _asMap(payload['data']);

    return _asMap(data['contact']);
  }

  Future<void> deleteEmergencyContact(int contactId) async {
    final response = await _client.delete('/emergency-contacts/$contactId');

    _decode(response);
  }

  Future<void> logoutAllDevices() async {
    final response = await _client.post('/auth/logout-all');

    _decode(response);
    await _session.clearSession();
  }

  Map<String, dynamic> _decode(http.Response response) {
    dynamic decoded;

    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw const AccountApiException(
        'Invalid response received from the server.',
      );
    }

    if (decoded is! Map) {
      throw const AccountApiException('Unexpected account response format.');
    }

    final payload = Map<String, dynamic>.from(decoded);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errors = payload['errors'];

      if (errors is List && errors.isNotEmpty) {
        final firstError = errors.first;

        if (firstError is Map) {
          throw AccountApiException(
            firstError['message']?.toString() ??
                payload['message']?.toString() ??
                'Account request failed.',
          );
        }

        throw AccountApiException(firstError.toString());
      }

      throw AccountApiException(
        payload['message']?.toString() ?? 'Account request failed.',
      );
    }

    return payload;
  }

  static String? _nullableText(String? value) {
    final normalized = value?.trim() ?? '';

    return normalized.isEmpty ? null : normalized;
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
