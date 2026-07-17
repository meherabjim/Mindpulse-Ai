import 'package:flutter/material.dart';

import '../services/account_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({required this.profile, super.key});

  final Map<String, dynamic> profile;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final AccountService _service = AccountService();

  late final TextEditingController _nameController;

  late final TextEditingController _ageRangeController;

  late final TextEditingController _occupationController;

  late final TextEditingController _wellnessGoalController;

  late final TextEditingController _timezoneController;

  String _gender = '';
  String _userType = '';
  String _preferredLanguage = 'en';

  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: widget.profile['full_name']?.toString() ?? '',
    );

    _ageRangeController = TextEditingController(
      text: widget.profile['age_range']?.toString() ?? '',
    );

    _occupationController = TextEditingController(
      text: widget.profile['occupation']?.toString() ?? '',
    );

    _wellnessGoalController = TextEditingController(
      text: widget.profile['wellness_goal']?.toString() ?? '',
    );

    _timezoneController = TextEditingController(
      text: widget.profile['timezone']?.toString() ?? 'Asia/Dhaka',
    );

    _gender = widget.profile['gender']?.toString() ?? '';

    _userType = widget.profile['user_type']?.toString() ?? '';

    _preferredLanguage =
        widget.profile['preferred_language']?.toString() ?? 'en';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageRangeController.dispose();
    _occupationController.dispose();
    _wellnessGoalController.dispose();
    _timezoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final fullName = _nameController.text.trim();
    final timezone = _timezoneController.text.trim();

    if (fullName.length < 2) {
      setState(() {
        _errorMessage = 'Full name must contain at least 2 characters.';
      });
      return;
    }

    if (timezone.isEmpty) {
      setState(() {
        _errorMessage = 'Timezone is required.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      final profile = await _service.updateProfile(<String, dynamic>{
        'full_name': fullName,
        'age_range': _nullableText(_ageRangeController.text),
        'gender': _gender.isEmpty ? null : _gender,
        'occupation': _nullableText(_occupationController.text),
        'user_type': _userType.isEmpty ? null : _userType,
        'wellness_goal': _nullableText(_wellnessGoalController.text),
        'preferred_language': _preferredLanguage,
        'timezone': timezone,
      });

      if (!mounted) return;

      Navigator.of(context).pop(profile);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  String? _nullableText(String value) {
    final normalized = value.trim();

    return normalized.isEmpty ? null : normalized;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FC),
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveProfile,
            child: Text(_saving ? 'Saving...' : 'Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red.shade800),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(17),
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    maxLength: 120,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _ageRangeController,
                    maxLength: 30,
                    decoration: const InputDecoration(
                      labelText: 'Age range',
                      hintText: '18-24',
                      prefixIcon: Icon(Icons.cake_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _gender,
                    decoration: const InputDecoration(
                      labelText: 'Gender',
                      prefixIcon: Icon(Icons.people_outline),
                    ),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('Not specified')),
                      DropdownMenuItem(value: 'male', child: Text('Male')),
                      DropdownMenuItem(value: 'female', child: Text('Female')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                      DropdownMenuItem(
                        value: 'prefer_not_to_say',
                        child: Text('Prefer not to say'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _gender = value ?? '';
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _occupationController,
                    maxLength: 120,
                    decoration: const InputDecoration(
                      labelText: 'Occupation',
                      prefixIcon: Icon(Icons.work_outline),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _userType,
                    decoration: const InputDecoration(
                      labelText: 'User type',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('Not specified')),
                      DropdownMenuItem(
                        value: 'student',
                        child: Text('Student'),
                      ),
                      DropdownMenuItem(
                        value: 'employee',
                        child: Text('Employee'),
                      ),
                      DropdownMenuItem(
                        value: 'self_employed',
                        child: Text('Self-employed'),
                      ),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _userType = value ?? '';
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _wellnessGoalController,
                    maxLength: 150,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Wellness goal',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.flag_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _preferredLanguage,
                    decoration: const InputDecoration(
                      labelText: 'Preferred language',
                      prefixIcon: Icon(Icons.language),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'bn', child: Text('বাংলা')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;

                      setState(() {
                        _preferredLanguage = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _timezoneController,
                    maxLength: 60,
                    decoration: const InputDecoration(
                      labelText: 'Timezone',
                      hintText: 'Asia/Dhaka',
                      prefixIcon: Icon(Icons.public_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _saveProfile,
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Saving profile...' : 'Update Profile'),
          ),
        ],
      ),
    );
  }
}
