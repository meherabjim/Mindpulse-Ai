import 'dart:convert';

import '../../../core/auth/authenticated_http_client.dart';

class EmergencyContact {
  const EmergencyContact({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    required this.isPrimary,
    this.relationshipName,
    this.email,
  });

  final int id;
  final String fullName;
  final String phoneNumber;
  final bool isPrimary;
  final String? relationshipName;
  final String? email;

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    final primary = json['is_primary'];
    return EmergencyContact(
      id: (json['id'] as num?)?.toInt() ?? 0,
      fullName: json['full_name']?.toString() ?? '',
      phoneNumber: json['phone_number']?.toString() ?? '',
      relationshipName: json['relationship_name']?.toString(),
      email: json['email']?.toString(),
      isPrimary: primary == true || primary == 1 || primary?.toString() == '1',
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'full_name': fullName.trim(),
    'relationship_name': relationshipName?.trim().isEmpty == true
        ? null
        : relationshipName?.trim(),
    'phone_number': phoneNumber.trim(),
    'email': email?.trim().isEmpty == true ? null : email?.trim(),
    'is_primary': isPrimary,
  };
}

class EmergencyContactApiException implements Exception {
  const EmergencyContactApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class EmergencyContactService {
  final AuthenticatedHttpClient _client = AuthenticatedHttpClient.instance;

  Future<List<EmergencyContact>> listContacts() async {
    final response = await _client.get('/emergency-contacts');
    final payload = _decode(response.body);
    _check(response.statusCode, payload);
    final data = _map(payload['data']);
    final contacts = data['contacts'];
    if (contacts is! List) return const <EmergencyContact>[];
    return contacts
        .whereType<Map>()
        .map(
          (item) => EmergencyContact.fromJson(Map<String, dynamic>.from(item)),
        )
        .where((item) => item.id > 0)
        .toList();
  }

  Future<void> create(EmergencyContact contact) async {
    final response = await _client.post(
      '/emergency-contacts',
      body: contact.toJson(),
    );
    _check(response.statusCode, _decode(response.body));
  }

  Future<void> update(EmergencyContact contact) async {
    final response = await _client.patch(
      '/emergency-contacts/${contact.id}',
      body: contact.toJson(),
    );
    _check(response.statusCode, _decode(response.body));
  }

  Future<void> delete(int id) async {
    final response = await _client.delete('/emergency-contacts/$id');
    _check(response.statusCode, _decode(response.body));
  }

  Map<String, dynamic> _decode(String source) {
    try {
      return _map(jsonDecode(source));
    } catch (_) {
      throw const EmergencyContactApiException(
        'The server returned an invalid response.',
      );
    }
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  void _check(int statusCode, Map<String, dynamic> payload) {
    if (statusCode >= 200 && statusCode < 300) return;
    throw EmergencyContactApiException(
      payload['message']?.toString() ?? 'Emergency contact request failed.',
    );
  }
}
