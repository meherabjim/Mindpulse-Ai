import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/settings/app_preferences_controller.dart';
import '../../account/services/account_service.dart';
import '../../companion/screens/companion_permissions_screen.dart';
import '../../companion/services/movement_insight_service.dart';
import '../../dashboard/screens/main_dashboard_screen.dart';
import '../../digital_wellbeing/services/screen_time_service.dart';
import '../../prayer/services/prayer_alarm_bridge.dart';
import '../../prayer/services/prayer_service.dart';
import '../../religion/services/manual_faith_reminder_service.dart';

// MINDPULSE FIRST LOGIN FAITH PERMISSIONS V2
// MINDPULSE MANUAL FAITH ONBOARDING V3
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
  final ManualFaithReminderService _manualReminderService =
      ManualFaithReminderService();

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
  final TextEditingController _manualReminderTitleController =
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
  bool _manualReminderRequested = false;
  bool _manualReminderAlarmEnabled = true;
  TimeOfDay _manualReminderTime = const TimeOfDay(hour: 19, minute: 0);
  Set<int> _manualReminderWeekdays = <int>{1, 2, 3, 4, 5, 6, 7};
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

  List<String> get _stepTitles => <String>[
    _t('Body and daily baseline', 'শরীর ও দৈনিক ভিত্তি'),
    _t('Sleep and activity', 'ঘুম ও দৈনিক কার্যক্রম'),
    _t('Religion and reminders', 'ধর্ম ও রিমাইন্ডার'),
    _t('Language and preferences', 'ভাষা ও পছন্দ'),
    _t('Permissions', 'অনুমতি'),
    _t('Privacy and consent', 'গোপনীয়তা ও সম্মতি'),
  ];

  Map<String, String> get _religionLabels => <String, String>{
    'islam': _t('Islam', 'ইসলাম'),
    'hinduism': _t('Hinduism', 'হিন্দুধর্ম'),
    'christianity': _t('Christianity', 'খ্রিষ্টধর্ম'),
    'buddhism': _t('Buddhism', 'বৌদ্ধধর্ম'),
    'judaism': _t('Judaism', 'ইহুদি ধর্ম'),
    'sikhism': _t('Sikhism', 'শিখধর্ম'),
    'other': _t('Other', 'অন্যান্য'),
    'no_religion': _t('No religion', 'কোনো ধর্ম নেই'),
    'prefer_not_to_say': _t('Prefer not to say', 'বলতে চাই না'),
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
    _manualReminderTitleController.dispose();
    _timezoneController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final results = await Future.wait<dynamic>([
        _service.getProfile(),
        _service.getSettings(),
        _service.getOnboardingStatus(),
        _manualReminderService.load(),
      ]);
      final profile = _asMap(results[0]);
      final settings = _asMap(results[1]);
      final onboarding = _asMap(results[2]);
      final appSettings = _asMap(settings['app_settings']);
      final notifications = _asMap(settings['notification_preferences']);
      final consents = _asMap(onboarding['consents']);
      final manualReminders = results[3] is List<ManualFaithReminder>
          ? results[3] as List<ManualFaithReminder>
          : <ManualFaithReminder>[];
      ManualFaithReminder? onboardingReminder;
      for (final reminder in manualReminders) {
        if (reminder.id == 'onboarding_manual_v1') {
          onboardingReminder = reminder;
          break;
        }
      }

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
        if (onboardingReminder != null) {
          _manualReminderRequested = true;
          _manualReminderAlarmEnabled = onboardingReminder.enabled;
          _manualReminderTitleController.text = onboardingReminder.title;
          _manualReminderTime = TimeOfDay(
            hour: onboardingReminder.hour,
            minute: onboardingReminder.minute,
          );
          _manualReminderWeekdays = onboardingReminder.weekdays.toSet();
        }
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
      _applyPreferencesAfterFrame(
        languageCode: _languageCode,
        themeMode: _themeMode,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _loading = false;
      });
    }
  }

  void _applyPreferencesAfterFrame({String? languageCode, String? themeMode}) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      await AppPreferencesController.instance.apply(
        languageCode: languageCode,
        themeMode: themeMode,
      );
    });
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
        error = _t('Please enter your full name.', 'আপনার পূর্ণ নাম লিখুন।');
      } else {
        error = _validateBodyProfile();
      }
      if (error == null && _timezoneController.text.trim().isEmpty) {
        error = _t('Please enter your timezone.', 'আপনার সময় অঞ্চল লিখুন।');
      }
    } else if (_currentStep == 1) {
      if (_userType.isEmpty) {
        error = _t(
          'Select your work or study pattern.',
          'আপনার কাজ বা পড়াশোনার ধরন নির্বাচন করুন।',
        );
      }
    } else if (_currentStep == 2) {
      if (_religion == 'other' &&
          _otherReligionController.text.trim().isEmpty) {
        error = _t(
          'Write the religion name or choose another option.',
          'ধর্মের নাম লিখুন অথবা অন্য একটি অপশন বেছে নিন।',
        );
      } else if (_manualReminderRequested &&
          _manualReminderTitleController.text.trim().length < 2) {
        error = _t(
          'Enter a name for the manual reminder.',
          'ম্যানুয়াল রিমাইন্ডারের একটি নাম লিখুন।',
        );
      } else if (_manualReminderRequested && _manualReminderWeekdays.isEmpty) {
        error = _t(
          'Choose at least one day for the reminder.',
          'রিমাইন্ডারের জন্য অন্তত একটি দিন বেছে নিন।',
        );
      }
    } else if (_currentStep == 4) {
      if (!const <String>{
        'enable_all',
        'choose',
        'continue_without',
      }.contains(_permissionMode)) {
        error = _t(
          'Choose a permission setup option.',
          'অনুমতি সেটআপের একটি অপশন নির্বাচন করুন।',
        );
      }
    } else if (_currentStep == 5 &&
        (!_termsAccepted || !_privacyAccepted || !_wellnessDataAccepted)) {
      error = _t(
        'Terms, privacy and wellness data consent are required.',
        'শর্তাবলি, গোপনীয়তা ও ওয়েলনেস ডেটা সম্মতি প্রয়োজন।',
      );
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

      if (_religion == 'islam') {
        await _saveManualReminderPreference();
        await _applyFaithAlarmPreference();
      } else {
        await _applyFaithAlarmPreference();
        await _saveManualReminderPreference();
      }
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

  Future<void> _saveManualReminderPreference() async {
    final reminders = await _manualReminderService.load();
    final updated = reminders
        .where((item) => item.id != 'onboarding_manual_v1')
        .toList();

    if (_supportsManualReminder && _manualReminderRequested) {
      updated.add(
        ManualFaithReminder(
          id: 'onboarding_manual_v1',
          title: _manualReminderTitleController.text.trim(),
          hour: _manualReminderTime.hour,
          minute: _manualReminderTime.minute,
          weekdays: _manualReminderWeekdays.toList()..sort(),
          enabled:
              _manualReminderAlarmEnabled &&
              _permissionMode != 'continue_without',
        ),
      );
    }

    await _manualReminderService.save(updated);
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
      if (_religion == 'islam') {
        var locationPermission = await Geolocator.checkPermission();
        if (locationPermission == LocationPermission.denied) {
          locationPermission = await Geolocator.requestPermission();
        }
      }
      final manualAlarmRequested =
          _supportsManualReminder &&
          _manualReminderRequested &&
          _manualReminderAlarmEnabled;
      if ((_religion == 'islam' && _prayerAlarmEnabled) ||
          manualAlarmRequested) {
        await _prayerBridge.requestExactAlarmPermission();
      }
      if (!mounted) return;
      setState(() {
        _permissionMode = 'enable_all';
        _permissionMessage = _religion == 'islam'
            ? _t(
                'Notification, activity and location requests were started. Android Usage Access opens separately.',
                'নোটিফিকেশন, কার্যক্রম ও লোকেশন অনুমতির ধাপ শুরু হয়েছে। Android Usage Access আলাদাভাবে খুলবে।',
              )
            : _t(
                'Notification and activity requests were started. Location is not needed for this profile. Android Usage Access opens separately.',
                'নোটিফিকেশন ও কার্যক্রম অনুমতির ধাপ শুরু হয়েছে। এই প্রোফাইলের জন্য লোকেশন প্রয়োজন নেই। Android Usage Access আলাদাভাবে খুলবে।',
              );
      });
      await _screenTimeService.openUsageAccessSettings();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _permissionMessage = _t(
          'Some permission steps are still pending: $error',
          'কিছু অনুমতির ধাপ এখনো বাকি আছে: $error',
        );
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

  Future<void> _showReligionPicker() async {
    final searchController = TextEditingController();
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        var query = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final entries = _religionLabels.entries.where((entry) {
              return entry.value.toLowerCase().contains(query.toLowerCase());
            }).toList();

            return SafeArea(
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.72,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    18,
                    4,
                    18,
                    MediaQuery.viewInsetsOf(context).bottom + 18,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t('Choose religion', 'ধর্ম নির্বাচন করুন'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: searchController,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: _t('Search', 'খুঁজুন'),
                          prefixIcon: const Icon(Icons.search_rounded),
                        ),
                        onChanged: (value) {
                          setSheetState(() => query = value.trim());
                        },
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          itemCount: entries.length,
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            final chosen = entry.key == _religion;
                            return ListTile(
                              leading: Icon(
                                chosen
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded,
                              ),
                              title: Text(entry.value),
                              onTap: () =>
                                  Navigator.of(sheetContext).pop(entry.key),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    searchController.dispose();

    if (selected == null || !mounted) return;
    setState(() {
      _religion = selected;
      if (selected != 'islam') _prayerAlarmEnabled = false;
      if (selected == 'islam' ||
          selected == 'no_religion' ||
          selected == 'prefer_not_to_say') {
        _manualReminderRequested = false;
      }
    });
  }

  Future<void> _pickManualReminderTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _manualReminderTime,
    );
    if (selected != null && mounted) {
      setState(() => _manualReminderTime = selected);
    }
  }

  bool get _supportsManualReminder {
    return _religion != 'islam' &&
        _religion != 'no_religion' &&
        _religion != 'prefer_not_to_say';
  }

  String _t(String english, String bangla) {
    return AppPreferencesController.instance.text(english, bangla);
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
      return _t(
        'Enter a weight between 20 and 400 kg.',
        '২০ থেকে ৪০০ কেজির মধ্যে ওজন লিখুন।',
      );
    }
    if (feet == null ||
        inches == null ||
        inches < 0 ||
        inches > 11 ||
        height == null ||
        height < 80 ||
        height > 250) {
      return _t(
        'Enter a valid height in feet and inches.',
        'ফুট ও ইঞ্চিতে সঠিক উচ্চতা লিখুন।',
      );
    }
    if (glasses == null || glasses < 0 || glasses > 40) {
      return _t(
        'Enter daily water intake between 0 and 40 glasses.',
        'প্রতিদিন ০ থেকে ৪০ গ্লাসের মধ্যে পানি গ্রহণ লিখুন।',
      );
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
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(_t('Welcome to MindPulse', 'MindPulse-এ স্বাগতম')),
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
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t(
              'Step ${_currentStep + 1} of ${_stepTitles.length}',
              'ধাপ ${_currentStep + 1} / ${_stepTitles.length}',
            ),
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
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        _errorMessage!,
        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
      ),
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
          title: _t('Your body and daily baseline', 'আপনার শরীর ও দৈনিক তথ্য'),
          text: _t(
            'These details support BMI screening and personalized wellness guidance.',
            'এই তথ্য BMI স্ক্রিনিং ও ব্যক্তিগত ওয়েলনেস পরামর্শে সহায়তা করে।',
          ),
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
                  decoration: InputDecoration(
                    labelText: _t('Full name', 'পূর্ণ নাম'),
                    helperText: _t(
                      'Provided during registration.',
                      'রেজিস্ট্রেশনের সময় দেওয়া হয়েছে।',
                    ),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _dateOfBirthController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: _t('Date of birth', 'জন্মতারিখ'),
                    helperText: _t(
                      'Provided during registration.',
                      'রেজিস্ট্রেশনের সময় দেওয়া হয়েছে।',
                    ),
                    prefixIcon: const Icon(Icons.cake_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _gender,
                  decoration: InputDecoration(
                    labelText: _t('Gender', 'লিঙ্গ'),
                    prefixIcon: const Icon(Icons.people_outline),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: '',
                      child: Text(
                        _t('Prefer not to specify', 'উল্লেখ করতে চাই না'),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'male',
                      child: Text(_t('Male', 'পুরুষ')),
                    ),
                    DropdownMenuItem(
                      value: 'female',
                      child: Text(_t('Female', 'নারী')),
                    ),
                    DropdownMenuItem(
                      value: 'other',
                      child: Text(_t('Other', 'অন্যান্য')),
                    ),
                    DropdownMenuItem(
                      value: 'prefer_not_to_say',
                      child: Text(_t('Prefer not to say', 'বলতে চাই না')),
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
                  decoration: InputDecoration(
                    labelText: _t('Weight (kg)', 'ওজন (কেজি)'),
                    prefixIcon: const Icon(Icons.monitor_weight_outlined),
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
                        decoration: InputDecoration(
                          labelText: _t('Height (feet)', 'উচ্চতা (ফুট)'),
                          prefixIcon: const Icon(Icons.height_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _heightInchesController,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: _t('Inches', 'ইঞ্চি'),
                          hintText: '0–11',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _waterGlassesController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: _t(
                      'Daily water glasses',
                      'প্রতিদিন পানির গ্লাস সংখ্যা',
                    ),
                    hintText: _t('For example 8', 'যেমন ৮'),
                    prefixIcon: const Icon(Icons.water_drop_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _waterGlassMl,
                  decoration: InputDecoration(
                    labelText: _t('Glass size', 'প্রতি গ্লাসের পরিমাণ'),
                    prefixIcon: const Icon(Icons.local_drink_outlined),
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
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bmi == null
                            ? _t(
                                'BMI preview: add weight and height',
                                'BMI প্রিভিউ: ওজন ও উচ্চতা দিন',
                              )
                            : _t(
                                'BMI preview: ${bmi.toStringAsFixed(1)}',
                                'BMI প্রিভিউ: ${bmi.toStringAsFixed(1)}',
                              ),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _t(
                          'Source: WHO BMI formula. Screening information only; not a diagnosis.',
                          'উৎস: WHO BMI সূত্র। এটি শুধু স্ক্রিনিং তথ্য; রোগ নির্ণয় নয়।',
                        ),
                        style: const TextStyle(fontSize: 12.5, height: 1.35),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        waterMl == null
                            ? _t(
                                'Current fluid intake: add glasses and glass size',
                                'বর্তমান পানি গ্রহণ: গ্লাস সংখ্যা ও পরিমাণ দিন',
                              )
                            : _t(
                                'Current fluid intake: ${(waterMl / 1000).toStringAsFixed(2)} L/day',
                                'বর্তমান পানি গ্রহণ: ${(waterMl / 1000).toStringAsFixed(2)} লিটার/দিন',
                              ),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _timezoneController,
                  maxLength: 60,
                  decoration: InputDecoration(
                    labelText: _t('Timezone', 'টাইমজোন'),
                    hintText: 'Asia/Dhaka',
                    prefixIcon: const Icon(Icons.public_rounded),
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
          title: _t('Your usual routine', 'আপনার সাধারণ রুটিন'),
          text: _t(
            'A short baseline helps MindPulse avoid generic advice.',
            'সংক্ষিপ্ত কিছু তথ্য MindPulse-কে সাধারণ ধরনের পরামর্শ এড়িয়ে চলতে সাহায্য করে।',
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t(
                    'Typical sleep: ${_typicalSleepHours.toStringAsFixed(1)} hours',
                    'সাধারণ ঘুম: ${_typicalSleepHours.toStringAsFixed(1)} ঘণ্টা',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Slider(
                  value: _typicalSleepHours,
                  min: 3,
                  max: 14,
                  divisions: 22,
                  label: _t(
                    '${_typicalSleepHours.toStringAsFixed(1)} hours',
                    '${_typicalSleepHours.toStringAsFixed(1)} ঘণ্টা',
                  ),
                  onChanged: (value) =>
                      setState(() => _typicalSleepHours = value),
                ),
                const Divider(height: 28),
                DropdownButtonFormField<String>(
                  initialValue: _userType,
                  decoration: InputDecoration(
                    labelText: _t(
                      'Work or study pattern',
                      'কাজ বা পড়াশোনার ধরন',
                    ),
                    prefixIcon: const Icon(Icons.work_outline),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: '',
                      child: Text(_t('Select one', 'একটি নির্বাচন করুন')),
                    ),
                    DropdownMenuItem(
                      value: 'student',
                      child: Text(_t('Student', 'শিক্ষার্থী')),
                    ),
                    DropdownMenuItem(
                      value: 'employee',
                      child: Text(_t('Employee', 'চাকরিজীবী')),
                    ),
                    DropdownMenuItem(
                      value: 'self_employed',
                      child: Text(_t('Self-employed', 'স্বনিযুক্ত')),
                    ),
                    DropdownMenuItem(
                      value: 'other',
                      child: Text(_t('Other', 'অন্যান্য')),
                    ),
                  ],
                  onChanged: (value) => setState(() => _userType = value ?? ''),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _occupationController,
                  maxLength: 120,
                  decoration: InputDecoration(
                    labelText: _t(
                      'Occupation or study area (optional)',
                      'পেশা বা পড়াশোনার বিষয় (ঐচ্ছিক)',
                    ),
                    prefixIcon: const Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _activityPattern,
                  decoration: InputDecoration(
                    labelText: _t(
                      'Usual activity level',
                      'সাধারণ কার্যক্রমের মাত্রা',
                    ),
                    prefixIcon: const Icon(Icons.directions_walk_outlined),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'mostly_sitting',
                      child: Text(
                        _t('Mostly sitting', 'বেশিরভাগ সময় বসে থাকা'),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'lightly_active',
                      child: Text(_t('Lightly active', 'হালকা সক্রিয়')),
                    ),
                    DropdownMenuItem(
                      value: 'moderately_active',
                      child: Text(_t('Moderately active', 'মাঝারি সক্রিয়')),
                    ),
                    DropdownMenuItem(
                      value: 'very_active',
                      child: Text(_t('Very active', 'খুব সক্রিয়')),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _activityPattern = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _wellnessGoalController,
                  maxLength: 150,
                  decoration: InputDecoration(
                    labelText: _t(
                      'Main wellness goal (optional)',
                      'প্রধান ওয়েলনেস লক্ষ্য (ঐচ্ছিক)',
                    ),
                    prefixIcon: const Icon(Icons.flag_outlined),
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
          title: _t('Religion and reminders', 'ধর্ম ও রিমাইন্ডার'),
          text: _t(
            'This controls which faith content appears. MindPulse never shows Muslim prayer content to non-Muslim profiles.',
            'এটি কোন ধর্মীয় তথ্য দেখানো হবে তা নিয়ন্ত্রণ করে। অমুসলিম প্রোফাইলে MindPulse কখনো মুসলিম নামাজের তথ্য দেখাবে না।',
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Column(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _showReligionPicker,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: _t('Religion', 'ধর্ম'),
                      prefixIcon: const Icon(Icons.account_balance_outlined),
                      suffixIcon: const Icon(Icons.search_rounded),
                    ),
                    child: Text(_religionLabels[_religion] ?? _religion),
                  ),
                ),
                if (other) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _otherReligionController,
                    maxLength: 120,
                    decoration: InputDecoration(
                      labelText: _t('Write religion name', 'ধর্মের নাম লিখুন'),
                      prefixIcon: const Icon(Icons.edit_outlined),
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
                    title: Text(
                      _t(
                        'Turn on prayer alarms?',
                        'নামাজের অ্যালার্ম চালু করবেন?',
                      ),
                    ),
                    subtitle: Text(
                      _t(
                        'Yes: alarms will sound. No: alarms stay off, but prayer times and settings remain visible.',
                        'হ্যাঁ: অ্যালার্ম বাজবে। না: অ্যালার্ম বন্ধ থাকবে, তবে নামাজের সময় ও সেটিংস দেখা যাবে।',
                      ),
                    ),
                  )
                else if (_supportsManualReminder) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _t(
                        'Muslim prayer time, mosque, jamaat and Islamic alarms stay hidden. You can create only your own manual reminder.',
                        'মুসলিম নামাজের সময়, মসজিদ, জামাত ও ইসলামিক অ্যালার্ম দেখানো হবে না। আপনি শুধু নিজের ম্যানুয়াল রিমাইন্ডার তৈরি করতে পারবেন।',
                      ),
                      style: const TextStyle(height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _manualReminderRequested,
                    onChanged: (value) =>
                        setState(() => _manualReminderRequested = value),
                    title: Text(
                      _t(
                        'Create a manual prayer or spiritual reminder?',
                        'ম্যানুয়াল প্রার্থনা বা আধ্যাত্মিক রিমাইন্ডার তৈরি করবেন?',
                      ),
                    ),
                    subtitle: Text(
                      _t(
                        'Only the reminder you enter will appear in your dashboard.',
                        'আপনি যে রিমাইন্ডার লিখবেন, ড্যাশবোর্ডে শুধু সেটিই দেখা যাবে।',
                      ),
                    ),
                  ),
                  if (_manualReminderRequested) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _manualReminderTitleController,
                      maxLength: 80,
                      decoration: InputDecoration(
                        labelText: _t('Reminder name', 'রিমাইন্ডারের নাম'),
                        hintText: _t('Evening prayer', 'সন্ধ্যার প্রার্থনা'),
                        prefixIcon: const Icon(
                          Icons.edit_notifications_outlined,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.schedule_rounded),
                      title: Text(_t('Reminder time', 'রিমাইন্ডারের সময়')),
                      subtitle: Text(_manualReminderTime.format(context)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _pickManualReminderTime,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _t('Repeat days', 'যে দিনগুলোতে বাজবে'),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children:
                          <MapEntry<int, String>>[
                            MapEntry<int, String>(1, _t('M', 'সোম')),
                            MapEntry<int, String>(2, _t('T', 'মঙ্গল')),
                            MapEntry<int, String>(3, _t('W', 'বুধ')),
                            MapEntry<int, String>(4, _t('T', 'বৃহঃ')),
                            MapEntry<int, String>(5, _t('F', 'শুক্র')),
                            MapEntry<int, String>(6, _t('S', 'শনি')),
                            MapEntry<int, String>(7, _t('S', 'রবি')),
                          ].map((entry) {
                            final selected = _manualReminderWeekdays.contains(
                              entry.key,
                            );
                            return FilterChip(
                              label: Text(entry.value),
                              selected: selected,
                              onSelected: (value) {
                                setState(() {
                                  if (value) {
                                    _manualReminderWeekdays.add(entry.key);
                                  } else {
                                    _manualReminderWeekdays.remove(entry.key);
                                  }
                                });
                              },
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _manualReminderAlarmEnabled,
                      onChanged: (value) =>
                          setState(() => _manualReminderAlarmEnabled = value),
                      title: Text(_t('Alarm sound', 'অ্যালার্মের শব্দ')),
                      subtitle: Text(
                        _t(
                          'Turn this off to save the reminder without sound.',
                          'শব্দ ছাড়া রিমাইন্ডার রাখতে এটি বন্ধ করুন।',
                        ),
                      ),
                    ),
                  ],
                ] else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _t(
                        'No religious reminder will be created automatically.',
                        'কোনো ধর্মীয় রিমাইন্ডার স্বয়ংক্রিয়ভাবে তৈরি হবে না।',
                      ),
                      style: const TextStyle(height: 1.4),
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
          title: _t('Choose your experience', 'আপনার পছন্দ নির্বাচন করুন'),
          text: _t(
            'These preferences can be changed later.',
            'এই পছন্দগুলো পরে পরিবর্তন করা যাবে।',
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _languageCode,
                  decoration: InputDecoration(
                    labelText: _t('Preferred language', 'পছন্দের ভাষা'),
                    prefixIcon: const Icon(Icons.language_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'en', child: Text('English')),
                    DropdownMenuItem(value: 'bn', child: Text('বাংলা')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _languageCode = value);
                    _applyPreferencesAfterFrame(languageCode: value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _themeMode,
                  decoration: InputDecoration(
                    labelText: _t('Theme', 'থিম'),
                    prefixIcon: const Icon(Icons.contrast_rounded),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'system',
                      child: Text(_t('System default', 'ফোনের থিম')),
                    ),
                    DropdownMenuItem(
                      value: 'light',
                      child: Text(_t('Light', 'লাইট')),
                    ),
                    DropdownMenuItem(
                      value: 'dark',
                      child: Text(_t('Dark', 'ডার্ক')),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _themeMode = value);
                    _applyPreferencesAfterFrame(themeMode: value);
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _aiAnalysisEnabled,
                  onChanged: (value) =>
                      setState(() => _aiAnalysisEnabled = value),
                  title: Text(
                    _t('AI wellness analysis', 'AI ওয়েলনেস বিশ্লেষণ'),
                  ),
                  subtitle: Text(
                    _t(
                      'Generate personalized wellness insights.',
                      'ব্যক্তিগত ওয়েলনেস ধারণা তৈরি করুন।',
                    ),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _journalAnalysisEnabled,
                  onChanged: (value) =>
                      setState(() => _journalAnalysisEnabled = value),
                  title: Text(_t('Journal analysis', 'জার্নাল বিশ্লেষণ')),
                  subtitle: Text(
                    _t(
                      'Allow AI-supported journal insights.',
                      'AI-সহায়িত জার্নাল ধারণা অনুমোদন করুন।',
                    ),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _analyticsEnabled,
                  onChanged: (value) =>
                      setState(() => _analyticsEnabled = value),
                  title: Text(
                    _t('Anonymous analytics', 'নামবিহীন অ্যানালিটিক্স'),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _notificationsEnabled,
                  onChanged: (value) =>
                      setState(() => _notificationsEnabled = value),
                  title: Text(_t('Notifications', 'নোটিফিকেশন')),
                  subtitle: Text(
                    _t(
                      'Receive reminders and reports.',
                      'রিমাইন্ডার ও রিপোর্ট গ্রহণ করুন।',
                    ),
                  ),
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
          title: _t('Choose permission setup', 'অনুমতির ধরন নির্বাচন করুন'),
          text: _t(
            'Permissions and feature activation are separate. Enabling permissions never turns on prayer alarms by itself.',
            'অনুমতি ও ফিচার চালু করা আলাদা বিষয়। অনুমতি দিলেই নামাজ বা অন্য অ্যালার্ম নিজে থেকে চালু হবে না।',
          ),
        ),
        const SizedBox(height: 14),
        _permissionOption(
          value: 'enable_all',
          title: _t('Enable all needed permissions', 'প্রয়োজনীয় সব অনুমতি দিন'),
          subtitle: _t(
            'Guided requests for notifications, activity and Usage Access. Location is requested only for Islamic prayer times. Exact alarm is requested only for an enabled alarm.',
            'নোটিফিকেশন, কার্যক্রম ও Usage Access-এর ধাপ দেখানো হবে। লোকেশন শুধু ইসলামিক নামাজের সময়ের জন্য এবং Exact Alarm শুধু চালু অ্যালার্মের জন্য চাওয়া হবে।',
          ),
          icon: Icons.done_all_rounded,
          onTap: _enableAllNeededPermissions,
        ),
        const SizedBox(height: 10),
        _permissionOption(
          value: 'choose',
          title: _t('Choose permissions', 'অনুমতি বেছে নিন'),
          subtitle: _t(
            'Open the detailed MindPulse permission controls.',
            'MindPulse-এর বিস্তারিত অনুমতি নিয়ন্ত্রণ খুলুন।',
          ),
          icon: Icons.tune_rounded,
          onTap: _choosePermissions,
        ),
        const SizedBox(height: 10),
        _permissionOption(
          value: 'continue_without',
          title: _t('Continue without permissions', 'অনুমতি ছাড়াই এগিয়ে যান'),
          subtitle: _t(
            'Core account features remain available. You can enable access later.',
            'মূল অ্যাকাউন্ট ফিচারগুলো থাকবে। পরে অনুমতি দেওয়া যাবে।',
          ),
          icon: Icons.arrow_forward_rounded,
          onTap: () async {
            setState(() {
              _permissionMode = 'continue_without';
              _permissionMessage = _t(
                'No system permission was requested. A new manual reminder will be saved with its alarm off until permission is enabled later.',
                'কোনো সিস্টেম অনুমতি চাওয়া হয়নি। নতুন ম্যানুয়াল রিমাইন্ডার সংরক্ষিত হবে, তবে পরে অনুমতি না দেওয়া পর্যন্ত অ্যালার্ম বন্ধ থাকবে।',
              );
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
              color: Theme.of(context).colorScheme.primaryContainer,
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
          title: _t('Your privacy matters', 'আপনার গোপনীয়তা গুরুত্বপূর্ণ'),
          text: _t(
            'MindPulse provides wellness support and does not replace professional medical care.',
            'MindPulse ওয়েলনেস সহায়তা দেয়; এটি পেশাদার চিকিৎসার বিকল্প নয়।',
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Column(
            children: [
              CheckboxListTile(
                value: _termsAccepted,
                onChanged: (value) =>
                    setState(() => _termsAccepted = value == true),
                title: Text(
                  _t(
                    'I accept the Terms of Service',
                    'আমি সেবার শর্তাবলি গ্রহণ করছি',
                  ),
                ),
                subtitle: Text(_t('Required', 'আবশ্যক')),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const Divider(height: 1),
              CheckboxListTile(
                value: _privacyAccepted,
                onChanged: (value) =>
                    setState(() => _privacyAccepted = value == true),
                title: Text(
                  _t(
                    'I accept the Privacy Policy',
                    'আমি গোপনীয়তা নীতি গ্রহণ করছি',
                  ),
                ),
                subtitle: Text(_t('Required', 'আবশ্যক')),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const Divider(height: 1),
              CheckboxListTile(
                value: _wellnessDataAccepted,
                onChanged: (value) =>
                    setState(() => _wellnessDataAccepted = value == true),
                title: Text(
                  _t(
                    'I consent to wellness data processing',
                    'আমি ওয়েলনেস ডেটা প্রক্রিয়াকরণে সম্মতি দিচ্ছি',
                  ),
                ),
                subtitle: Text(
                  _t(
                    'Required for personalized wellness features',
                    'ব্যক্তিগত ওয়েলনেস ফিচারের জন্য আবশ্যক',
                  ),
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
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _saving ? null : _previousStep,
                child: Text(_t('Back', 'পেছনে')),
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
                  : Text(
                      last
                          ? _t('Complete setup', 'সেটআপ সম্পন্ন করুন')
                          : _t('Continue', 'পরবর্তী'),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
