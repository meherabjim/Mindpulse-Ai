import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../account/services/account_service.dart';
import '../../companion/screens/companion_permissions_screen.dart';
import '../../companion/services/movement_insight_service.dart';
import '../../dashboard/screens/main_dashboard_screen.dart';
import '../../digital_wellbeing/services/screen_time_service.dart';
import '../../prayer/services/prayer_alarm_bridge.dart';
import '../../prayer/services/prayer_service.dart';

// MINDPULSE FIRST LOGIN FAITH PERMISSIONS V2
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
  final PrayerAlarmBridge _prayerBridge = const PrayerAlarmBridge();
  late final PrayerService _prayerService = PrayerService();
  final ScreenTimeService _screenTimeService = ScreenTimeService();
  final MovementInsightService _movementService = MovementInsightService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dateOfBirthController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightFeetController = TextEditingController();
  final TextEditingController _heightInchesController = TextEditingController();
  final TextEditingController _waterGlassesController = TextEditingController();
  final TextEditingController _occupationController = TextEditingController();
  final TextEditingController _wellnessGoalController = TextEditingController();
  final TextEditingController _otherReligionController =
      TextEditingController();
  final TextEditingController _timezoneController = TextEditingController(
    text: 'Asia/Dhaka',
  );

  Map<String, dynamic> _appSettings = <String, dynamic>{};
  Map<String, dynamic> _notificationPreferences = <String, dynamic>{};

  int _currentStep = 0;
  String _gender = '';
  String _userType = '';
  String _languageCode = 'en';
  String _themeMode = 'system';
  String _activityPattern = 'mostly_sitting';
  String _religion = 'prefer_not_to_say';
  String _permissionMode = 'choose';
  int _waterGlassMl = 250;
  double _typicalSleepHours = 7;

  bool _prayerAlarmEnabled = false;
  bool _aiAnalysisEnabled = true;
  bool _journalAnalysisEnabled = false;
  bool _analyticsEnabled = false;
  bool _notificationsEnabled = true;
  bool _termsAccepted = false;
  bool _privacyAccepted = false;
  bool _wellnessDataAccepted = false;
  bool _loading = true;
  bool _saving = false;
  bool _requestingPermissions = false;
  String? _errorMessage;
  String? _permissionMessage;

  static const List<String> _stepTitles = <String>[
    'Body and daily baseline',
    'Sleep and activity',
    'Religion and reminders',
    'Language and preferences',
    'Permissions',
    'Privacy and consent',
  ];

  static const Map<String, String> _religionLabels = <String, String>{
    'islam': 'Islam',
    'hinduism': 'Hinduism',
    'christianity': 'Christianity',
    'buddhism': 'Buddhism',
    'judaism': 'Judaism',
    'sikhism': 'Sikhism',
    'other': 'Other',
    'no_religion': 'No religion',
    'prefer_not_to_say': 'Prefer not to say',
  };

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _prayerService.dispose();
    _nameController.dispose();
    _dateOfBirthController.dispose();
    _weightController.dispose();
    _heightFeetController.dispose();
    _heightInchesController.dispose();
    _waterGlassesController.dispose();
    _occupationController.dispose();
    _wellnessGoalController.dispose();
    _otherReligionController.dispose();
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
      final notifications = _asMap(settings['notification_preferences']);
      final consents = _asMap(onboarding['consents']);

      if (!mounted) return;
      setState(() {
        _nameController.text = profile['full_name']?.toString() ?? '';
        _dateOfBirthController.text =
            profile['date_of_birth']?.toString().split('T').first ?? '';
        final weight = _number(profile['weight_kg']);
        final heightCm = _number(profile['height_cm']);
        final waterMl = _number(profile['usual_water_ml']);
        final glassMl = _number(profile['water_glass_ml']);
        _weightController.text = weight == null
            ? ''
            : weight.toStringAsFixed(1);
        if (heightCm != null) {
          final totalInches = (heightCm / 2.54).round();
          _heightFeetController.text = (totalInches ~/ 12).toString();
          _heightInchesController.text = (totalInches % 12).toString();
        }
        _waterGlassMl = glassMl?.round() ?? 250;
        if (waterMl != null && _waterGlassMl > 0) {
          _waterGlassesController.text = (waterMl / _waterGlassMl)
              .round()
              .toString();
        }
        _occupationController.text = profile['occupation']?.toString() ?? '';
        _wellnessGoalController.text =
            profile['wellness_goal']?.toString() ?? '';
        _otherReligionController.text =
            profile['religion_other']?.toString() ?? '';
        _timezoneController.text =
            profile['timezone']?.toString() ??
            notifications['timezone']?.toString() ??
            'Asia/Dhaka';
        _gender = profile['gender']?.toString() ?? '';
        _userType = profile['user_type']?.toString() ?? '';
        _activityPattern =
            profile['activity_pattern']?.toString() ?? 'mostly_sitting';
        _religion = profile['religion']?.toString() ?? 'prefer_not_to_say';
        _permissionMode = profile['permission_mode']?.toString() ?? 'choose';
        _prayerAlarmEnabled = profile['prayer_alarm_enabled'] == true;
        _typicalSleepHours = (_number(profile['typical_sleep_hours']) ?? 7)
            .clamp(3, 14)
            .toDouble();
        _languageCode =
            appSettings['language_code']?.toString() ??
            profile['preferred_language']?.toString() ??
            'en';
        _themeMode = appSettings['theme_mode']?.toString() ?? 'system';
        _aiAnalysisEnabled = appSettings['ai_analysis_enabled'] != false;
        _journalAnalysisEnabled =
            appSettings['journal_analysis_enabled'] == true;
        _analyticsEnabled = appSettings['analytics_enabled'] == true;
        _notificationsEnabled = notifications['notifications_enabled'] != false;
        _termsAccepted = _consentGranted(consents, 'terms');
        _privacyAccepted = _consentGranted(consents, 'privacy');
        _wellnessDataAccepted = _consentGranted(consents, 'wellness_data');
        _appSettings = appSettings;
        _notificationPreferences = notifications;
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
    return _asMap(consents[key])['is_granted'] == true;
  }

  Future<void> _nextStep() async {
    if (!_validateCurrentStep()) return;
    if (_currentStep == _stepTitles.length - 1) {
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
    if (_currentStep == 0) return;
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
    String? error;
    if (_currentStep == 0) {
      if (_nameController.text.trim().length < 2) {
        error = 'Please enter your full name.';
      } else {
        error = _validateBodyProfile();
      }
      if (error == null && _timezoneController.text.trim().isEmpty) {
        error = 'Please enter your timezone.';
      }
    } else if (_currentStep == 1) {
      if (_userType.isEmpty) {
        error = 'Select your work or study pattern.';
      }
    } else if (_currentStep == 2) {
      if (_religion == 'other' &&
          _otherReligionController.text.trim().isEmpty) {
        error = 'Write the religion name or choose another option.';
      }
    } else if (_currentStep == 4) {
      if (!const <String>{
        'enable_all',
        'choose',
        'continue_without',
      }.contains(_permissionMode)) {
        error = 'Choose a permission setup option.';
      }
    } else if (_currentStep == 5 &&
        (!_termsAccepted || !_privacyAccepted || !_wellnessDataAccepted)) {
      error = 'Terms, privacy and wellness data consent are required.';
    }
    if (error != null) {
      setState(() => _errorMessage = error);
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
          'date_of_birth': _nullableText(_dateOfBirthController.text),
          'weight_kg': _weightKg,
          'height_cm': _heightCm,
          'usual_water_ml': _usualWaterMl,
          'water_glass_ml': _waterGlassMl,
          'typical_sleep_hours': _typicalSleepHours,
          'activity_pattern': _activityPattern,
          'religion': _religion,
          'religion_other': _religion == 'other'
              ? _nullableText(_otherReligionController.text)
              : null,
          'prayer_alarm_enabled': _religion == 'islam' && _prayerAlarmEnabled,
          'permission_mode': _permissionMode,
          'gender': _gender.isEmpty ? null : _gender,
          'occupation': _nullableText(_occupationController.text),
          'user_type': _userType.isEmpty ? null : _userType,
          'wellness_goal': _nullableText(_wellnessGoalController.text),
          'preferred_language': _languageCode,
          'timezone': _timezoneController.text.trim(),
        },
        appSettings: <String, dynamic>{
          'theme_mode': _themeMode,
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

      await _applyFaithAlarmPreference();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const MainDashboardScreen()),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _applyFaithAlarmPreference() async {
    if (_religion != 'islam') {
      await _prayerService.setEnabled(false);
      return;
    }
    if (!_prayerAlarmEnabled) {
      await _prayerService.setEnabled(false);
      return;
    }
    try {
      await _prayerBridge.requestNotificationPermission();
      await _prayerBridge.requestExactAlarmPermission();
      await _prayerService.syncOnlineSchedule();
    } catch (error) {
      debugPrint('MindPulse: prayer alarm setup deferred: $error');
    }
  }

  Future<void> _enableAllNeededPermissions() async {
    setState(() {
      _requestingPermissions = true;
      _permissionMessage = null;
    });
    try {
      await _prayerBridge.requestNotificationPermission();
      await _movementService.requestPermission();
      var locationPermission = await Geolocator.checkPermission();
      if (locationPermission == LocationPermission.denied) {
        locationPermission = await Geolocator.requestPermission();
      }
      if (_religion == 'islam' && _prayerAlarmEnabled) {
        await _prayerBridge.requestExactAlarmPermission();
      }
      if (!mounted) return;
      setState(() {
        _permissionMode = 'enable_all';
        _permissionMessage =
            'Notification, activity and location requests were started. '
            'Android Usage Access opens separately.';
      });
      await _screenTimeService.openUsageAccessSettings();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _permissionMessage = 'Some permission steps are still pending: $error';
      });
    } finally {
      if (mounted) setState(() => _requestingPermissions = false);
    }
  }

  Future<void> _choosePermissions() async {
    setState(() => _permissionMode = 'choose');
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const CompanionPermissionsScreen(),
      ),
    );
  }

  bool _notificationValue(String key) {
    final value = _notificationPreferences[key];
    return value is bool ? value : true;
  }

  String? _nullableText(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  double? _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  double? get _weightKg => double.tryParse(_weightController.text.trim());

  double? get _heightCm {
    final feet = int.tryParse(_heightFeetController.text.trim());
    final inches = int.tryParse(_heightInchesController.text.trim());
    if (feet == null || inches == null) return null;
    return (feet * 30.48) + (inches * 2.54);
  }

  int? get _usualWaterMl {
    final glasses = int.tryParse(_waterGlassesController.text.trim());
    return glasses == null ? null : glasses * _waterGlassMl;
  }

  double? get _bmi {
    final weight = _weightKg;
    final height = _heightCm;
    if (weight == null || height == null || height <= 0) return null;
    final metres = height / 100;
    return weight / (metres * metres);
  }

  String? _validateBodyProfile() {
    final weight = _weightKg;
    final height = _heightCm;
    final feet = int.tryParse(_heightFeetController.text.trim());
    final inches = int.tryParse(_heightInchesController.text.trim());
    final glasses = int.tryParse(_waterGlassesController.text.trim());
    if (weight == null || weight < 20 || weight > 400) {
      return 'Enter a weight between 20 and 400 kg.';
    }
    if (feet == null ||
        inches == null ||
        inches < 0 ||
        inches > 11 ||
        height == null ||
        height < 80 ||
        height > 250) {
      return 'Enter a valid height in feet and inches.';
    }
    if (glasses == null || glasses < 0 || glasses > 40) {
      return 'Enter daily water intake between 0 and 40 glasses.';
    }
    return null;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
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
                        _buildBodyStep(),
                        _buildLifestyleStep(),
                        _buildReligionStep(),
                        _buildPreferencesStep(),
                        _buildPermissionsStep(),
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
            'Step ${_currentStep + 1} of ${_stepTitles.length}',
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
            value: (_currentStep + 1) / _stepTitles.length,
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

  Widget _buildBodyStep() {
    final bmi = _bmi;
    final waterMl = _usualWaterMl;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _introCard(
          icon: Icons.monitor_weight_outlined,
          title: 'Your body and daily baseline',
          text:
              'These details support BMI screening and personalized wellness guidance.',
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    helperText: 'Provided during registration.',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _dateOfBirthController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Date of birth',
                    helperText: 'Provided during registration.',
                    prefixIcon: Icon(Icons.cake_outlined),
                  ),
                ),
                const SizedBox(height: 12),
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
                  onChanged: (value) => setState(() => _gender = value ?? ''),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Weight (kg)',
                    prefixIcon: Icon(Icons.monitor_weight_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _heightFeetController,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Height (feet)',
                          prefixIcon: Icon(Icons.height_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _heightInchesController,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Inches',
                          hintText: '0–11',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _waterGlassesController,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Water glasses/day',
                          prefixIcon: Icon(Icons.water_drop_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _waterGlassMl,
                        decoration: const InputDecoration(
                          labelText: 'Glass size',
                        ),
                        items: const [
                          DropdownMenuItem(value: 200, child: Text('200 ml')),
                          DropdownMenuItem(value: 250, child: Text('250 ml')),
                          DropdownMenuItem(value: 300, child: Text('300 ml')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _waterGlassMl = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0EFFF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bmi == null
                            ? 'BMI preview: add weight and height'
                            : 'BMI preview: ${bmi.toStringAsFixed(1)}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Source: WHO BMI formula. Screening information only; not a diagnosis.',
                        style: TextStyle(fontSize: 12.5, height: 1.35),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        waterMl == null
                            ? 'Current fluid intake: add glasses and glass size'
                            : 'Current fluid intake: ${(waterMl / 1000).toStringAsFixed(2)} L/day',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
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
      ],
    );
  }

  Widget _buildLifestyleStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _introCard(
          icon: Icons.bedtime_outlined,
          title: 'Your usual routine',
          text: 'A short baseline helps MindPulse avoid generic advice.',
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Typical sleep: ${_typicalSleepHours.toStringAsFixed(1)} hours',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Slider(
                  value: _typicalSleepHours,
                  min: 3,
                  max: 14,
                  divisions: 22,
                  label: '${_typicalSleepHours.toStringAsFixed(1)} hours',
                  onChanged: (value) =>
                      setState(() => _typicalSleepHours = value),
                ),
                const Divider(height: 28),
                DropdownButtonFormField<String>(
                  initialValue: _userType,
                  decoration: const InputDecoration(
                    labelText: 'Work or study pattern',
                    prefixIcon: Icon(Icons.work_outline),
                  ),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('Select one')),
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
                  onChanged: (value) => setState(() => _userType = value ?? ''),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _occupationController,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Occupation or study area (optional)',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _activityPattern,
                  decoration: const InputDecoration(
                    labelText: 'Usual activity level',
                    prefixIcon: Icon(Icons.directions_walk_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'mostly_sitting',
                      child: Text('Mostly sitting'),
                    ),
                    DropdownMenuItem(
                      value: 'lightly_active',
                      child: Text('Lightly active'),
                    ),
                    DropdownMenuItem(
                      value: 'moderately_active',
                      child: Text('Moderately active'),
                    ),
                    DropdownMenuItem(
                      value: 'very_active',
                      child: Text('Very active'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _activityPattern = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _wellnessGoalController,
                  maxLength: 150,
                  decoration: const InputDecoration(
                    labelText: 'Main wellness goal (optional)',
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReligionStep() {
    final islam = _religion == 'islam';
    final other = _religion == 'other';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _introCard(
          icon: Icons.self_improvement_outlined,
          title: 'Religion and reminders',
          text:
              'This controls which faith content appears. MindPulse never shows Muslim prayer content to non-Muslim profiles.',
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _religion,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Religion',
                    prefixIcon: Icon(Icons.account_balance_outlined),
                  ),
                  items: _religionLabels.entries
                      .map(
                        (entry) => DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _religion = value;
                      if (value != 'islam') _prayerAlarmEnabled = false;
                    });
                  },
                ),
                if (other) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _otherReligionController,
                    maxLength: 120,
                    decoration: const InputDecoration(
                      labelText: 'Write religion name',
                      prefixIcon: Icon(Icons.edit_outlined),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if (islam)
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _prayerAlarmEnabled,
                    onChanged: (value) =>
                        setState(() => _prayerAlarmEnabled = value),
                    title: const Text('Prayer alarm চালু করবেন?'),
                    subtitle: const Text(
                      'Yes: alarms will sound. No: alarms stay off, but prayer times and settings remain visible.',
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0EFFF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'No Muslim prayer time, mosque, jamaat or Islamic alarm will be shown. Only reminders you create manually will appear.',
                      style: TextStyle(height: 1.4),
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
          text: 'These preferences can be changed later.',
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
                    if (value != null) setState(() => _languageCode = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _themeMode,
                  decoration: const InputDecoration(
                    labelText: 'Theme',
                    prefixIcon: Icon(Icons.contrast_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'system',
                      child: Text('System default'),
                    ),
                    DropdownMenuItem(value: 'light', child: Text('Light')),
                    DropdownMenuItem(value: 'dark', child: Text('Dark')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _themeMode = value);
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _aiAnalysisEnabled,
                  onChanged: (value) =>
                      setState(() => _aiAnalysisEnabled = value),
                  title: const Text('AI wellness analysis'),
                  subtitle: const Text(
                    'Generate personalized wellness insights.',
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _journalAnalysisEnabled,
                  onChanged: (value) =>
                      setState(() => _journalAnalysisEnabled = value),
                  title: const Text('Journal analysis'),
                  subtitle: const Text('Allow AI-supported journal insights.'),
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _analyticsEnabled,
                  onChanged: (value) =>
                      setState(() => _analyticsEnabled = value),
                  title: const Text('Anonymous analytics'),
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _notificationsEnabled,
                  onChanged: (value) =>
                      setState(() => _notificationsEnabled = value),
                  title: const Text('Notifications'),
                  subtitle: const Text('Receive reminders and reports.'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionsStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _introCard(
          icon: Icons.admin_panel_settings_outlined,
          title: 'Choose permission setup',
          text:
              'Permissions and feature activation are separate. Enabling permissions never turns on prayer alarms by itself.',
        ),
        const SizedBox(height: 14),
        _permissionOption(
          value: 'enable_all',
          title: 'Enable all needed permissions',
          subtitle:
              'Guided requests for notifications, activity, location and Usage Access. Exact alarm is requested only for an enabled alarm feature.',
          icon: Icons.done_all_rounded,
          onTap: _enableAllNeededPermissions,
        ),
        const SizedBox(height: 10),
        _permissionOption(
          value: 'choose',
          title: 'Choose permissions',
          subtitle: 'Open the detailed MindPulse permission controls.',
          icon: Icons.tune_rounded,
          onTap: _choosePermissions,
        ),
        const SizedBox(height: 10),
        _permissionOption(
          value: 'continue_without',
          title: 'Continue without permissions',
          subtitle:
              'Core account features remain available. You can enable access later.',
          icon: Icons.arrow_forward_rounded,
          onTap: () async {
            setState(() {
              _permissionMode = 'continue_without';
              _permissionMessage = 'No system permission was requested.';
            });
          },
        ),
        if (_requestingPermissions) ...[
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator()),
        ],
        if (_permissionMessage != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFFF0EFFF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(_permissionMessage!),
          ),
        ],
      ],
    );
  }

  Widget _permissionOption({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
    required Future<void> Function() onTap,
  }) {
    final selected = _permissionMode == value;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _requestingPermissions ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? const Color(0xFF6059E8) : null,
              ),
              const SizedBox(width: 12),
              Icon(icon, color: selected ? const Color(0xFF6059E8) : null),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 5),
                    Text(subtitle, style: const TextStyle(height: 1.35)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
                onChanged: (value) =>
                    setState(() => _termsAccepted = value == true),
                title: const Text('I accept the Terms of Service'),
                subtitle: const Text('Required'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const Divider(height: 1),
              CheckboxListTile(
                value: _privacyAccepted,
                onChanged: (value) =>
                    setState(() => _privacyAccepted = value == true),
                title: const Text('I accept the Privacy Policy'),
                subtitle: const Text('Required'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const Divider(height: 1),
              CheckboxListTile(
                value: _wellnessDataAccepted,
                onChanged: (value) =>
                    setState(() => _wellnessDataAccepted = value == true),
                title: const Text('I consent to wellness data processing'),
                subtitle: const Text(
                  'Required for personalized wellness features',
                ),
                controlAffinity: ListTileControlAffinity.leading,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6059E8), Color(0xFF7E78F2)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 30),
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
                const SizedBox(height: 6),
                Text(
                  text,
                  style: const TextStyle(color: Colors.white, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    final last = _currentStep == _stepTitles.length - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      color: Colors.white,
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
            child: FilledButton(
              onPressed: _saving ? null : _nextStep,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(last ? 'Complete setup' : 'Continue'),
            ),
          ),
        ],
      ),
    );
  }
}
