import 'package:flutter/material.dart';

import '../../account/services/account_service.dart';
import '../../dashboard/screens/main_dashboard_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    this.initialStatus = const <String, dynamic>{},
    super.key,
  });

  final Map<String, dynamic> initialStatus;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final AccountService _service = AccountService();
  final PageController _pageController = PageController();

  final TextEditingController _nameController = TextEditingController();

  final TextEditingController _ageRangeController = TextEditingController();

  final TextEditingController _occupationController = TextEditingController();

  final TextEditingController _wellnessGoalController = TextEditingController();

  final TextEditingController _timezoneController = TextEditingController(
    text: 'Asia/Dhaka',
  );

  Map<String, dynamic> _appSettings = <String, dynamic>{};

  Map<String, dynamic> _notificationPreferences = <String, dynamic>{};

  int _currentStep = 0;

  String _gender = '';
  String _userType = '';
  String _languageCode = 'en';

  bool _aiAnalysisEnabled = true;
  bool _journalAnalysisEnabled = false;
  bool _analyticsEnabled = false;
  bool _notificationsEnabled = true;

  bool _termsAccepted = false;
  bool _privacyAccepted = false;
  bool _wellnessDataAccepted = false;

  bool _loading = true;
  bool _saving = false;

  String? _errorMessage;

  static const List<String> _stepTitles = <String>[
    'Personalize your profile',
    'Choose your preferences',
    'Privacy and consent',
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _ageRangeController.dispose();
    _occupationController.dispose();
    _wellnessGoalController.dispose();
    _timezoneController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final results = await Future.wait<dynamic>([
        _service.getProfile(),
        _service.getSettings(),
        _service.getOnboardingStatus(),
      ]);

      final profile = _asMap(results[0]);

      final settings = _asMap(results[1]);

      final onboarding = _asMap(results[2]);

      final appSettings = _asMap(settings['app_settings']);

      final notificationPreferences = _asMap(
        settings['notification_preferences'],
      );

      final consents = _asMap(onboarding['consents']);

      if (!mounted) return;

      setState(() {
        _nameController.text = profile['full_name']?.toString() ?? '';

        _ageRangeController.text = profile['age_range']?.toString() ?? '';

        _occupationController.text = profile['occupation']?.toString() ?? '';

        _wellnessGoalController.text =
            profile['wellness_goal']?.toString() ?? '';

        _timezoneController.text =
            profile['timezone']?.toString() ??
            notificationPreferences['timezone']?.toString() ??
            'Asia/Dhaka';

        _gender = profile['gender']?.toString() ?? '';

        _userType = profile['user_type']?.toString() ?? '';

        _languageCode =
            appSettings['language_code']?.toString() ??
            profile['preferred_language']?.toString() ??
            'en';

        _aiAnalysisEnabled = appSettings['ai_analysis_enabled'] != false;

        _journalAnalysisEnabled =
            appSettings['journal_analysis_enabled'] == true;

        _analyticsEnabled = appSettings['analytics_enabled'] == true;

        _notificationsEnabled =
            notificationPreferences['notifications_enabled'] != false;

        _termsAccepted = _consentGranted(consents, 'terms');

        _privacyAccepted = _consentGranted(consents, 'privacy');

        _wellnessDataAccepted = _consentGranted(consents, 'wellness_data');

        _appSettings = appSettings;
        _notificationPreferences = notificationPreferences;

        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
        _loading = false;
      });
    }
  }

  bool _consentGranted(Map<String, dynamic> consents, String key) {
    final consent = _asMap(consents[key]);

    return consent['is_granted'] == true;
  }

  Future<void> _nextStep() async {
    if (!_validateCurrentStep()) {
      return;
    }

    if (_currentStep == 2) {
      await _completeOnboarding();
      return;
    }

    setState(() {
      _currentStep += 1;
      _errorMessage = null;
    });

    await _pageController.animateToPage(
      _currentStep,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  Future<void> _previousStep() async {
    if (_currentStep == 0) {
      return;
    }

    setState(() {
      _currentStep -= 1;
      _errorMessage = null;
    });

    await _pageController.animateToPage(
      _currentStep,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  bool _validateCurrentStep() {
    if (_currentStep == 0) {
      final name = _nameController.text.trim();
      final timezone = _timezoneController.text.trim();

      if (name.length < 2) {
        setState(() {
          _errorMessage = 'Please enter your full name.';
        });

        return false;
      }

      if (timezone.isEmpty) {
        setState(() {
          _errorMessage = 'Please enter your timezone.';
        });

        return false;
      }
    }

    if (_currentStep == 2 &&
        (!_termsAccepted || !_privacyAccepted || !_wellnessDataAccepted)) {
      setState(() {
        _errorMessage =
            'Terms, privacy and wellness data consent are required.';
      });

      return false;
    }

    return true;
  }

  Future<void> _completeOnboarding() async {
    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      await _service.completeOnboarding(
        profile: <String, dynamic>{
          'full_name': _nameController.text.trim(),
          'age_range': _nullableText(_ageRangeController.text),
          'gender': _gender.isEmpty ? null : _gender,
          'occupation': _nullableText(_occupationController.text),
          'user_type': _userType.isEmpty ? null : _userType,
          'wellness_goal': _nullableText(_wellnessGoalController.text),
          'preferred_language': _languageCode,
          'timezone': _timezoneController.text.trim(),
        },
        appSettings: <String, dynamic>{
          'theme_mode': _appSettings['theme_mode'] ?? 'system',
          'language_code': _languageCode,
          'time_format': _appSettings['time_format'] ?? '12_hour',
          'ai_analysis_enabled': _aiAnalysisEnabled,
          'journal_analysis_enabled': _journalAnalysisEnabled,
          'analytics_enabled': _analyticsEnabled,
        },
        notificationPreferences: <String, dynamic>{
          'notifications_enabled': _notificationsEnabled,
          'checkin_reminders': _notificationValue('checkin_reminders'),
          'habit_reminders': _notificationValue('habit_reminders'),
          'sleep_reminders': _notificationValue('sleep_reminders'),
          'recovery_reminders': _notificationValue('recovery_reminders'),
          'wellness_scan_reminders': _notificationValue(
            'wellness_scan_reminders',
          ),
          'report_notifications': _notificationValue('report_notifications'),
          'achievement_notifications': _notificationValue(
            'achievement_notifications',
          ),
          'inactivity_reminders': _notificationValue('inactivity_reminders'),
          'announcement_notifications': _notificationValue(
            'announcement_notifications',
          ),
          'quiet_hours_enabled':
              _notificationPreferences['quiet_hours_enabled'] == true,
          'quiet_hours_start': _notificationPreferences['quiet_hours_start'],
          'quiet_hours_end': _notificationPreferences['quiet_hours_end'],
          'timezone': _timezoneController.text.trim(),
        },
        consents: <String, bool>{
          'terms': _termsAccepted,
          'privacy': _privacyAccepted,
          'wellness_data': _wellnessDataAccepted,
          'ai_analysis': _aiAnalysisEnabled,
          'journal_analysis': _journalAnalysisEnabled,
          'analytics': _analyticsEnabled,
          'notifications': _notificationsEnabled,
        },
      );

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const MainDashboardScreen()),
        (route) => false,
      );
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

  bool _notificationValue(String key) {
    final value = _notificationPreferences[key];

    return value is bool ? value : true;
  }

  String? _nullableText(String value) {
    final normalized = value.trim();

    return normalized.isEmpty ? null : normalized;
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7FC),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Welcome to MindPulse'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildProgressHeader(),
                  if (_errorMessage != null) _buildErrorBanner(),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildProfileStep(),
                        _buildPreferencesStep(),
                        _buildConsentStep(),
                      ],
                    ),
                  ),
                  _buildNavigationButtons(),
                ],
              ),
      ),
    );
  }

  Widget _buildProgressHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Step ${_currentStep + 1} of 3',
            style: const TextStyle(
              color: Color(0xFF6059E8),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            _stepTitles[_currentStep],
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 13),
          LinearProgressIndicator(
            value: (_currentStep + 1) / 3,
            minHeight: 8,
            borderRadius: BorderRadius.circular(10),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade800)),
    );
  }

  Widget _buildProfileStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _introCard(
          icon: Icons.person_outline_rounded,
          title: 'Tell us about yourself',
          text: 'This information helps personalize your wellness experience.',
        ),
        const SizedBox(height: 14),
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
                    DropdownMenuItem(
                      value: '',
                      child: Text('Prefer not to specify'),
                    ),
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
                    DropdownMenuItem(value: 'student', child: Text('Student')),
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
                    labelText: 'Main wellness goal',
                    hintText: 'Reduce stress and improve sleep',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                ),
                const SizedBox(height: 10),
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
      ],
    );
  }

  Widget _buildPreferencesStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _introCard(
          icon: Icons.tune_rounded,
          title: 'Choose your experience',
          text: 'You can change these preferences later from Account Settings.',
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _languageCode,
                  decoration: const InputDecoration(
                    labelText: 'Preferred language',
                    prefixIcon: Icon(Icons.language_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'en', child: Text('English')),
                    DropdownMenuItem(value: 'bn', child: Text('বাংলা')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      _languageCode = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _aiAnalysisEnabled,
                  onChanged: (value) {
                    setState(() {
                      _aiAnalysisEnabled = value;
                    });
                  },
                  title: const Text('AI wellness analysis'),
                  subtitle: const Text(
                    'Use wellness information to generate personalized insights.',
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _journalAnalysisEnabled,
                  onChanged: (value) {
                    setState(() {
                      _journalAnalysisEnabled = value;
                    });
                  },
                  title: const Text('Journal analysis'),
                  subtitle: const Text('Allow AI-supported journal insights.'),
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _analyticsEnabled,
                  onChanged: (value) {
                    setState(() {
                      _analyticsEnabled = value;
                    });
                  },
                  title: const Text('Anonymous analytics'),
                  subtitle: const Text(
                    'Help improve MindPulse through usage information.',
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _notificationsEnabled,
                  onChanged: (value) {
                    setState(() {
                      _notificationsEnabled = value;
                    });
                  },
                  title: const Text('Notifications'),
                  subtitle: const Text(
                    'Receive reminders, reports and achievement updates.',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConsentStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _introCard(
          icon: Icons.verified_user_outlined,
          title: 'Your privacy matters',
          text:
              'MindPulse provides wellness support and does not replace professional medical care.',
        ),
        const SizedBox(height: 14),
        Card(
          child: Column(
            children: [
              CheckboxListTile(
                value: _termsAccepted,
                onChanged: (value) {
                  setState(() {
                    _termsAccepted = value == true;
                  });
                },
                title: const Text('I accept the Terms of Service'),
                subtitle: const Text('Required'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const Divider(height: 1),
              CheckboxListTile(
                value: _privacyAccepted,
                onChanged: (value) {
                  setState(() {
                    _privacyAccepted = value == true;
                  });
                },
                title: const Text('I accept the Privacy Policy'),
                subtitle: const Text('Required'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const Divider(height: 1),
              CheckboxListTile(
                value: _wellnessDataAccepted,
                onChanged: (value) {
                  setState(() {
                    _wellnessDataAccepted = value == true;
                  });
                },
                title: const Text('I consent to wellness data processing'),
                subtitle: const Text(
                  'Required for wellness tracking and recommendations',
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: const Color(0xFFF0EFFF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.health_and_safety_outlined, color: Color(0xFF6059E8)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'MindPulse AI provides non-diagnostic wellness guidance. Seek qualified professional or emergency help when necessary.',
                  style: TextStyle(height: 1.45),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _introCard({
    required IconData icon,
    required String title,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5C58E8), Color(0xFF875EF0)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 27,
            backgroundColor: const Color(0x33FFFFFF),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  text,
                  style: const TextStyle(color: Color(0xFFEDEBFF), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 15,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : _previousStep,
                  child: const Text('Back'),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _saving ? null : _nextStep,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _currentStep == 2
                            ? Icons.check_rounded
                            : Icons.arrow_forward_rounded,
                      ),
                label: Text(
                  _saving
                      ? 'Completing...'
                      : _currentStep == 2
                      ? 'Complete Setup'
                      : 'Continue',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
