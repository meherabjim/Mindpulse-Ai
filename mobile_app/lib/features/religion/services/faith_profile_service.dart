import 'dart:convert';

import '../../../core/auth/authenticated_http_client.dart';

class FaithProfile {
  const FaithProfile({
    required this.religion,
    required this.religionLabel,
    required this.isIslam,
  });

  final String religion;
  final String religionLabel;
  final bool isIslam;
}

class FaithProfileService {
  const FaithProfileService();

  Future<FaithProfile> load() async {
    final response = await AuthenticatedHttpClient.instance.get('/profile');
    final payload = _decode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        payload['message']?.toString() ?? 'Unable to load profile.',
      );
    }
    final data = _asMap(payload['data']);
    final profile = _asMap(data['profile']);
    final religion = profile['religion']?.toString() ?? 'prefer_not_to_say';
    final custom = profile['religion_other']?.toString().trim() ?? '';
    return FaithProfile(
      religion: religion,
      religionLabel: religion == 'other' && custom.isNotEmpty
          ? custom
          : _label(religion),
      isIslam: religion == 'islam',
    );
  }

  String _label(String value) {
    const labels = <String, String>{
      'islam': 'Islam',
      'hinduism': 'Hinduism',
      'christianity': 'Christianity',
      'buddhism': 'Buddhism',
      'judaism': 'Judaism',
      'sikhism': 'Sikhism',
      'no_religion': 'No religion',
      'prefer_not_to_say': 'Prefer not to say',
    };
    return labels[value] ?? 'Other';
  }

  Map<String, dynamic> _decode(String source) {
    try {
      return _asMap(jsonDecode(source));
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }
}
