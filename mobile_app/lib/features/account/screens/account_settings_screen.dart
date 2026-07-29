import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/settings/app_preferences_controller.dart';
import '../services/account_service.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final AccountService _service = AccountService();
  final TextEditingController _timezoneController = TextEditingController(
    text: 'Asia/Dhaka',
  );

  Timer? _autosaveTimer;
  Timer? _preferenceTimer;

  String _themeMode = 'system';
  String _languageCode = 'en';
  String _timeFormat = '12_hour';

  bool _aiAnalysisEnabled = true;
  bool _journalAnalysisEnabled = false;
  bool _analyticsEnabled = false;

  bool _notificationsEnabled = true;
  bool _checkinReminders = true;
  bool _habitReminders = true;
  bool _sleepReminders = true;
  bool _recoveryReminders = true;
  bool _wellnessScanReminders = true;
  bool _reportNotifications = true;
  bool _achievementNotifications = true;
  bool _inactivityReminders = true;
  bool _announcementNotifications = true;

  bool _quietHoursEnabled = false;
  TimeOfDay? _quietHoursStart;
  TimeOfDay? _quietHoursEnd;

  Map<String, dynamic> _onboarding = <String, dynamic>{};

  bool _loading = true;
  bool _saving = false;
  bool _saveQueued = false;
  bool _allowPop = false;

  int _changeVersion = 0;
  int _savedVersion = 0;

  String? _errorMessage;
  DateTime? _lastSavedAt;

  bool get _hasUnsavedChanges => _changeVersion > _savedVersion;

  String _t(String english, String bangla) {
    return AppPreferencesController.instance.text(english, bangla);
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _preferenceTimer?.cancel();
    _timezoneController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final results = await Future.wait<Map<String, dynamic>>([
        _service.getSettings(),
        _service.getOnboardingStatus(),
      ]);

      final settings = results[0];
      final appSettings = _asMap(settings['app_settings']);
      final notifications = _asMap(settings['notification_preferences']);

      if (!mounted) return;

      setState(() {
        _themeMode = appSettings['theme_mode']?.toString() ?? 'system';
        _languageCode = appSettings['language_code']?.toString() ?? 'en';
        _timeFormat = appSettings['time_format']?.toString() ?? '12_hour';

        _aiAnalysisEnabled = appSettings['ai_analysis_enabled'] == true;
        _journalAnalysisEnabled =
            appSettings['journal_analysis_enabled'] == true;
        _analyticsEnabled = appSettings['analytics_enabled'] == true;

        _notificationsEnabled = notifications['notifications_enabled'] == true;
        _checkinReminders = notifications['checkin_reminders'] == true;
        _habitReminders = notifications['habit_reminders'] == true;
        _sleepReminders = notifications['sleep_reminders'] == true;
        _recoveryReminders = notifications['recovery_reminders'] == true;
        _wellnessScanReminders =
            notifications['wellness_scan_reminders'] == true;
        _reportNotifications = notifications['report_notifications'] == true;
        _achievementNotifications =
            notifications['achievement_notifications'] == true;
        _inactivityReminders = notifications['inactivity_reminders'] == true;
        _announcementNotifications =
            notifications['announcement_notifications'] == true;

        _quietHoursEnabled = notifications['quiet_hours_enabled'] == true;
        _quietHoursStart = _parseTime(notifications['quiet_hours_start']);
        _quietHoursEnd = _parseTime(notifications['quiet_hours_end']);
        _timezoneController.text =
            notifications['timezone']?.toString() ?? 'Asia/Dhaka';

        _onboarding = results[1];
        _loading = false;
        _changeVersion = 0;
        _savedVersion = 0;
        _lastSavedAt = DateTime.now();
      });

      _scheduleVisiblePreferenceApply(
        languageCode: _languageCode,
        themeMode: _themeMode,
        delay: const Duration(milliseconds: 100),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
        _loading = false;
      });
    }
  }

  void _updateSetting(
    VoidCallback update, {
    bool applyVisiblePreferences = false,
    bool immediate = false,
  }) {
    setState(() {
      update();
      _changeVersion += 1;
      _errorMessage = null;
    });

    if (applyVisiblePreferences) {
      _scheduleVisiblePreferenceApply(
        languageCode: _languageCode,
        themeMode: _themeMode,
      );
    }

    _scheduleAutosave(immediate: immediate);
  }

  void _scheduleAutosave({bool immediate = false}) {
    _autosaveTimer?.cancel();

    _autosaveTimer = Timer(
      immediate
          ? const Duration(milliseconds: 120)
          : const Duration(milliseconds: 550),
      () {
        _saveSettings(_changeVersion);
      },
    );
  }

  void _scheduleVisiblePreferenceApply({
    required String languageCode,
    required String themeMode,
    Duration delay = const Duration(milliseconds: 420),
  }) {
    _preferenceTimer?.cancel();

    _preferenceTimer = Timer(delay, () async {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;

      await AppPreferencesController.instance.apply(
        languageCode: languageCode,
        themeMode: themeMode,
      );
    });
  }

  Future<void> _saveBeforeLeaving() async {
    _autosaveTimer?.cancel();

    if (_saving) {
      _saveQueued = true;

      while (_saving && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
    }

    if (!mounted) return;

    if (_hasUnsavedChanges) {
      await _saveSettings(_changeVersion);
    }

    if (!mounted || _hasUnsavedChanges || _errorMessage != null) {
      return;
    }

    setState(() => _allowPop = true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  Future<void> _saveSettings(int requestedVersion) async {
    if (_loading || !mounted) return;

    if (_saving) {
      _saveQueued = true;
      return;
    }

    final timezone = _timezoneController.text.trim();

    if (timezone.isEmpty) {
      setState(() {
        _errorMessage = _t(
          'Notification timezone is required.',
          'নোটিফিকেশনের সময় অঞ্চল দিতে হবে।',
        );
      });
      return;
    }

    if (_quietHoursEnabled &&
        (_quietHoursStart == null || _quietHoursEnd == null)) {
      setState(() {
        _errorMessage = _t(
          'Select both quiet-hours start and end time.',
          'নীরব সময়ের শুরু ও শেষ—দুটো সময়ই নির্বাচন করুন।',
        );
      });
      return;
    }

    final appSettings = <String, dynamic>{
      'theme_mode': _themeMode,
      'language_code': _languageCode,
      'time_format': _timeFormat,
      'ai_analysis_enabled': _aiAnalysisEnabled,
      'journal_analysis_enabled': _journalAnalysisEnabled,
      'analytics_enabled': _analyticsEnabled,
    };

    final notificationPreferences = <String, dynamic>{
      'notifications_enabled': _notificationsEnabled,
      'checkin_reminders': _checkinReminders,
      'habit_reminders': _habitReminders,
      'sleep_reminders': _sleepReminders,
      'recovery_reminders': _recoveryReminders,
      'wellness_scan_reminders': _wellnessScanReminders,
      'report_notifications': _reportNotifications,
      'achievement_notifications': _achievementNotifications,
      'inactivity_reminders': _inactivityReminders,
      'announcement_notifications': _announcementNotifications,
      'quiet_hours_enabled': _quietHoursEnabled,
      'quiet_hours_start': _quietHoursEnabled
          ? _timeString(_quietHoursStart)
          : null,
      'quiet_hours_end': _quietHoursEnabled
          ? _timeString(_quietHoursEnd)
          : null,
      'timezone': timezone,
    };

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      final result = await _service.updateSettings(
        appSettings: appSettings,
        notificationPreferences: notificationPreferences,
      );

      final savedAppSettings = _asMap(result['app_settings']);
      final savedNotifications = _asMap(result['notification_preferences']);

      final savedLanguage =
          savedAppSettings['language_code']?.toString() ?? _languageCode;
      final savedTheme =
          savedAppSettings['theme_mode']?.toString() ?? _themeMode;

      await AppPreferencesController.instance.apply(
        languageCode: savedLanguage,
        themeMode: savedTheme,
      );

      if (!mounted) return;

      setState(() {
        _themeMode = savedTheme;
        _languageCode = savedLanguage;
        _timeFormat =
            savedAppSettings['time_format']?.toString() ?? _timeFormat;
        _notificationsEnabled =
            savedNotifications['notifications_enabled'] == true;

        if (requestedVersion > _savedVersion) {
          _savedVersion = requestedVersion;
        }

        _lastSavedAt = DateTime.now();
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        final shouldSaveAgain =
            _saveQueued || _changeVersion > requestedVersion;

        setState(() {
          _saving = false;
          _saveQueued = false;
        });

        if (shouldSaveAgain) {
          _scheduleAutosave(immediate: true);
        }
      }
    }
  }

  TimeOfDay? _parseTime(dynamic value) {
    final text = value?.toString() ?? '';
    if (text.length < 5) return null;

    final parts = text.substring(0, 5).split(':');
    if (parts.length != 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) return null;

    return TimeOfDay(hour: hour, minute: minute);
  }

  String? _timeString(TimeOfDay? value) {
    if (value == null) return null;

    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  Future<void> _pickQuietHoursStart() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _quietHoursStart ?? const TimeOfDay(hour: 22, minute: 0),
      helpText: _t('Quiet hours start', 'নীরব সময়ের শুরু'),
      cancelText: _t('Cancel', 'বাতিল'),
      confirmText: _t('Select', 'নির্বাচন'),
    );

    if (selected == null || !mounted) return;

    _updateSetting(() => _quietHoursStart = selected, immediate: true);
  }

  Future<void> _pickQuietHoursEnd() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _quietHoursEnd ?? const TimeOfDay(hour: 7, minute: 0),
      helpText: _t('Quiet hours end', 'নীরব সময়ের শেষ'),
      cancelText: _t('Cancel', 'বাতিল'),
      confirmText: _t('Select', 'নির্বাচন'),
    );

    if (selected == null || !mounted) return;

    _updateSetting(() => _quietHoursEnd = selected, immediate: true);
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return PopScope(
      canPop: _allowPop || (!_hasUnsavedChanges && !_saving),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _saveBeforeLeaving();
        }
      },
      child: Scaffold(
        backgroundColor: colors.surface,
        appBar: AppBar(
          title: Text(_t('Settings', 'সেটিংস')),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(child: _buildSaveStatus()),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadSettings,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 42),
                  children: [
                    _buildPremiumHeader(),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 14),
                      _buildErrorBanner(),
                    ],
                    const SizedBox(height: 18),
                    _sectionLabel(
                      icon: Icons.auto_awesome_rounded,
                      title: _t('Your experience', 'আপনার অভিজ্ঞতা'),
                      subtitle: _t(
                        'Language, appearance and time display.',
                        'ভাষা, অ্যাপের রূপ ও সময় দেখানোর ধরন।',
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildApplicationSettings(),
                    const SizedBox(height: 20),
                    _sectionLabel(
                      icon: Icons.privacy_tip_outlined,
                      title: _t('Privacy and AI', 'গোপনীয়তা ও এআই'),
                      subtitle: _t(
                        'Choose which information MindPulse may analyse.',
                        'MindPulse কোন তথ্য বিশ্লেষণ করবে তা নিয়ন্ত্রণ করুন।',
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildPrivacySettings(),
                    const SizedBox(height: 20),
                    _sectionLabel(
                      icon: Icons.notifications_active_outlined,
                      title: _t('Notifications', 'নোটিফিকেশন'),
                      subtitle: _t(
                        'Control every wellness alert from one place.',
                        'সব ওয়েলনেস নোটিফিকেশন এক জায়গা থেকে নিয়ন্ত্রণ করুন।',
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildNotificationSettings(),
                    const SizedBox(height: 20),
                    _sectionLabel(
                      icon: Icons.verified_user_outlined,
                      title: _t('Consent status', 'সম্মতির অবস্থা'),
                      subtitle: _t(
                        'Review the permissions recorded during onboarding.',
                        'প্রথম সেটআপে দেওয়া সম্মতিগুলো দেখুন।',
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildConsentStatus(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSaveStatus() {
    final colors = Theme.of(context).colorScheme;

    final IconData icon;
    final String label;
    final Color background;
    final Color foreground;

    if (_saving) {
      icon = Icons.sync_rounded;
      label = _t('Saving', 'সংরক্ষণ হচ্ছে');
      background = colors.secondaryContainer;
      foreground = colors.onSecondaryContainer;
    } else if (_errorMessage != null && _hasUnsavedChanges) {
      icon = Icons.error_outline_rounded;
      label = _t('Not saved', 'সংরক্ষণ হয়নি');
      background = colors.errorContainer;
      foreground = colors.onErrorContainer;
    } else if (_hasUnsavedChanges) {
      icon = Icons.schedule_rounded;
      label = _t('Waiting', 'অপেক্ষায়');
      background = colors.tertiaryContainer;
      foreground = colors.onTertiaryContainer;
    } else {
      icon = Icons.cloud_done_outlined;
      label = _t('Saved', 'সংরক্ষিত');
      background = colors.primaryContainer;
      foreground = colors.onPrimaryContainer;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumHeader() {
    final savedTime = _lastSavedAt == null
        ? _t('Not saved yet', 'এখনও সংরক্ষণ হয়নি')
        : TimeOfDay.fromDateTime(_lastSavedAt!).format(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5C58E8), Color(0xFF8A63F4)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x335C58E8),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0x26FFFFFF),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.tune_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t(
                    'Everything saves automatically',
                    'সব পরিবর্তন নিজে থেকেই সংরক্ষিত হবে',
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _t(
                    'Change any option and continue. No separate save button is needed.',
                    'যেকোনো অপশন পরিবর্তন করে স্বাভাবিকভাবে বের হয়ে যান। আলাদা সেভ বাটন প্রয়োজন নেই।',
                  ),
                  style: const TextStyle(color: Color(0xFFEDEBFF), height: 1.4),
                ),
                const SizedBox(height: 10),
                Text(
                  _t('Last saved: $savedTime', 'সর্বশেষ সংরক্ষণ: $savedTime'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: colors.onPrimaryContainer),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner() {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: colors.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: colors.onErrorContainer),
            ),
          ),
          IconButton(
            onPressed: () => _saveSettings(_changeVersion),
            tooltip: _t('Try again', 'আবার চেষ্টা করুন'),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationSettings() {
    return _settingsCard(
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey<String>('theme_$_themeMode'),
          initialValue: _themeMode,
          decoration: InputDecoration(
            labelText: _t('Theme preference', 'থিম পছন্দ'),
            helperText: _t(
              'The selected theme applies immediately.',
              'নির্বাচিত থিম সঙ্গে সঙ্গে চালু হবে।',
            ),
            prefixIcon: const Icon(Icons.palette_outlined),
          ),
          items: [
            DropdownMenuItem(
              value: 'system',
              child: Text(_t('System default', 'ফোনের সেটিং অনুযায়ী')),
            ),
            DropdownMenuItem(value: 'light', child: Text(_t('Light', 'লাইট'))),
            DropdownMenuItem(value: 'dark', child: Text(_t('Dark', 'ডার্ক'))),
          ],
          onChanged: (value) {
            if (value == null) return;

            _updateSetting(
              () => _themeMode = value,
              applyVisiblePreferences: true,
            );
          },
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          key: ValueKey<String>('language_$_languageCode'),
          initialValue: _languageCode,
          decoration: InputDecoration(
            labelText: _t('Language', 'ভাষা'),
            helperText: _t(
              'The screen language changes automatically.',
              'স্ক্রিনের ভাষা স্বয়ংক্রিয়ভাবে পরিবর্তিত হবে।',
            ),
            prefixIcon: const Icon(Icons.language_rounded),
          ),
          items: const [
            DropdownMenuItem(value: 'en', child: Text('English')),
            DropdownMenuItem(value: 'bn', child: Text('বাংলা')),
          ],
          onChanged: (value) {
            if (value == null) return;

            _updateSetting(
              () => _languageCode = value,
              applyVisiblePreferences: true,
            );
          },
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          key: ValueKey<String>('time_$_timeFormat'),
          initialValue: _timeFormat,
          decoration: InputDecoration(
            labelText: _t('Time format', 'সময়ের ধরন'),
            prefixIcon: const Icon(Icons.schedule_rounded),
          ),
          items: [
            DropdownMenuItem(
              value: '12_hour',
              child: Text(_t('12-hour', '১২ ঘণ্টা')),
            ),
            DropdownMenuItem(
              value: '24_hour',
              child: Text(_t('24-hour', '২৪ ঘণ্টা')),
            ),
          ],
          onChanged: (value) {
            if (value == null) return;
            _updateSetting(() => _timeFormat = value);
          },
        ),
      ],
    );
  }

  Widget _buildPrivacySettings() {
    return _settingsCard(
      children: [
        _premiumSwitch(
          icon: Icons.psychology_alt_outlined,
          title: _t('AI analysis', 'এআই বিশ্লেষণ'),
          subtitle: _t(
            'Allow MindPulse AI to analyse wellness data.',
            'MindPulse AI-কে ওয়েলনেস তথ্য বিশ্লেষণের অনুমতি দিন।',
          ),
          value: _aiAnalysisEnabled,
          onChanged: (value) {
            _updateSetting(() => _aiAnalysisEnabled = value);
          },
        ),
        const Divider(height: 1),
        _premiumSwitch(
          icon: Icons.menu_book_outlined,
          title: _t('Journal analysis', 'জার্নাল বিশ্লেষণ'),
          subtitle: _t(
            'Allow AI-supported journal analysis.',
            'এআই-সহায়িত জার্নাল বিশ্লেষণের অনুমতি দিন।',
          ),
          value: _journalAnalysisEnabled,
          onChanged: (value) {
            _updateSetting(() => _journalAnalysisEnabled = value);
          },
        ),
        const Divider(height: 1),
        _premiumSwitch(
          icon: Icons.analytics_outlined,
          title: _t('Anonymous analytics', 'নামবিহীন ব্যবহার বিশ্লেষণ'),
          subtitle: _t(
            'Help improve the app with anonymous usage data.',
            'নামবিহীন ব্যবহার তথ্য দিয়ে অ্যাপ উন্নত করতে সহায়তা করুন।',
          ),
          value: _analyticsEnabled,
          onChanged: (value) {
            _updateSetting(() => _analyticsEnabled = value);
          },
        ),
      ],
    );
  }

  Widget _buildNotificationSettings() {
    final childEnabled = _notificationsEnabled;

    return Column(
      children: [
        _settingsCard(
          children: [
            _premiumSwitch(
              icon: Icons.notifications_active_outlined,
              title: _t('Enable notifications', 'নোটিফিকেশন চালু রাখুন'),
              subtitle: _t(
                'Master control for all wellness notifications.',
                'সব ওয়েলনেস নোটিফিকেশনের প্রধান নিয়ন্ত্রণ।',
              ),
              value: _notificationsEnabled,
              onChanged: (value) {
                _updateSetting(
                  () => _notificationsEnabled = value,
                  immediate: true,
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: childEnabled ? 1 : 0.48,
          child: IgnorePointer(
            ignoring: !childEnabled,
            child: _settingsCard(
              children: [
                _notificationSwitch(
                  icon: Icons.fact_check_outlined,
                  title: _t(
                    'Daily check-in reminders',
                    'দৈনিক চেক-ইন রিমাইন্ডার',
                  ),
                  value: _checkinReminders,
                  onChanged: (value) {
                    _updateSetting(() => _checkinReminders = value);
                  },
                ),
                _notificationDivider(),
                _notificationSwitch(
                  icon: Icons.track_changes_rounded,
                  title: _t('Habit reminders', 'অভ্যাসের রিমাইন্ডার'),
                  value: _habitReminders,
                  onChanged: (value) {
                    _updateSetting(() => _habitReminders = value);
                  },
                ),
                _notificationDivider(),
                _notificationSwitch(
                  icon: Icons.bedtime_outlined,
                  title: _t('Sleep reminders', 'ঘুমের রিমাইন্ডার'),
                  value: _sleepReminders,
                  onChanged: (value) {
                    _updateSetting(() => _sleepReminders = value);
                  },
                ),
                _notificationDivider(),
                _notificationSwitch(
                  icon: Icons.battery_charging_full_rounded,
                  title: _t('Recovery reminders', 'পুনরুদ্ধারের রিমাইন্ডার'),
                  value: _recoveryReminders,
                  onChanged: (value) {
                    _updateSetting(() => _recoveryReminders = value);
                  },
                ),
                _notificationDivider(),
                _notificationSwitch(
                  icon: Icons.monitor_heart_outlined,
                  title: _t(
                    'Wellness scan reminders',
                    'ওয়েলনেস স্ক্যান রিমাইন্ডার',
                  ),
                  value: _wellnessScanReminders,
                  onChanged: (value) {
                    _updateSetting(() => _wellnessScanReminders = value);
                  },
                ),
                _notificationDivider(),
                _notificationSwitch(
                  icon: Icons.insights_outlined,
                  title: _t(
                    'Weekly report notifications',
                    'সাপ্তাহিক রিপোর্ট নোটিফিকেশন',
                  ),
                  value: _reportNotifications,
                  onChanged: (value) {
                    _updateSetting(() => _reportNotifications = value);
                  },
                ),
                _notificationDivider(),
                _notificationSwitch(
                  icon: Icons.emoji_events_outlined,
                  title: _t('Achievement notifications', 'অর্জনের নোটিফিকেশন'),
                  value: _achievementNotifications,
                  onChanged: (value) {
                    _updateSetting(() => _achievementNotifications = value);
                  },
                ),
                _notificationDivider(),
                _notificationSwitch(
                  icon: Icons.hourglass_empty_rounded,
                  title: _t('Inactivity reminders', 'নিষ্ক্রিয়তার রিমাইন্ডার'),
                  value: _inactivityReminders,
                  onChanged: (value) {
                    _updateSetting(() => _inactivityReminders = value);
                  },
                ),
                _notificationDivider(),
                _notificationSwitch(
                  icon: Icons.campaign_outlined,
                  title: _t('Announcements', 'ঘোষণা'),
                  value: _announcementNotifications,
                  onChanged: (value) {
                    _updateSetting(() => _announcementNotifications = value);
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: childEnabled ? 1 : 0.48,
          child: IgnorePointer(
            ignoring: !childEnabled,
            child: _settingsCard(
              children: [
                _premiumSwitch(
                  icon: Icons.do_not_disturb_on_outlined,
                  title: _t('Quiet hours', 'নীরব সময়'),
                  subtitle: _t(
                    'Pause push notifications during selected hours.',
                    'নির্বাচিত সময়ে পুশ নোটিফিকেশন বন্ধ রাখুন।',
                  ),
                  value: _quietHoursEnabled,
                  onChanged: (value) {
                    _updateSetting(() => _quietHoursEnabled = value);
                  },
                ),
                if (_quietHoursEnabled) ...[
                  const Divider(height: 1),
                  _timeTile(
                    icon: Icons.nights_stay_outlined,
                    title: _t('Quiet hours start', 'নীরব সময়ের শুরু'),
                    value: _quietHoursStart,
                    onTap: _pickQuietHoursStart,
                  ),
                  const Divider(height: 1),
                  _timeTile(
                    icon: Icons.wb_sunny_outlined,
                    title: _t('Quiet hours end', 'নীরব সময়ের শেষ'),
                    value: _quietHoursEnd,
                    onTap: _pickQuietHoursEnd,
                  ),
                ],
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
                  child: TextField(
                    controller: _timezoneController,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: _t(
                        'Notification timezone',
                        'নোটিফিকেশনের সময় অঞ্চল',
                      ),
                      hintText: 'Asia/Dhaka',
                      helperText: _t(
                        'Saved automatically after typing.',
                        'লেখা শেষ হলে নিজে থেকেই সংরক্ষিত হবে।',
                      ),
                      prefixIcon: const Icon(Icons.public_rounded),
                    ),
                    onChanged: (_) {
                      setState(() {
                        _changeVersion += 1;
                        _errorMessage = null;
                      });
                      _scheduleAutosave();
                    },
                    onEditingComplete: () {
                      FocusScope.of(context).unfocus();
                      _scheduleAutosave(immediate: true);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConsentStatus() {
    final consents = _asMap(_onboarding['consents']);
    final completed = _onboarding['required_consents_completed'] == true;

    final consentLabels = <String, String>{
      'terms': _t('Terms of service', 'সেবার শর্তাবলি'),
      'privacy': _t('Privacy policy', 'গোপনীয়তা নীতি'),
      'wellness_data': _t('Wellness data', 'ওয়েলনেস তথ্য'),
      'ai_analysis': _t('AI analysis', 'এআই বিশ্লেষণ'),
      'journal_analysis': _t('Journal analysis', 'জার্নাল বিশ্লেষণ'),
      'analytics': _t('Analytics', 'ব্যবহার বিশ্লেষণ'),
      'notifications': _t('Notifications', 'নোটিফিকেশন'),
    };

    final colors = Theme.of(context).colorScheme;

    return _settingsCard(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: completed
                ? colors.primaryContainer
                : colors.tertiaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(
                completed ? Icons.verified_rounded : Icons.info_outline_rounded,
                color: completed
                    ? colors.onPrimaryContainer
                    : colors.onTertiaryContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  completed
                      ? _t(
                          'All required consents are active.',
                          'প্রয়োজনীয় সব সম্মতি চালু আছে।',
                        )
                      : _t(
                          'Some required consents are missing.',
                          'কিছু প্রয়োজনীয় সম্মতি এখনও দেওয়া হয়নি।',
                        ),
                  style: TextStyle(
                    color: completed
                        ? colors.onPrimaryContainer
                        : colors.onTertiaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...consentLabels.entries.map((entry) {
          final consent = _asMap(consents[entry.key]);
          final granted = consent['is_granted'] == true;

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: Icon(
              granted ? Icons.check_circle_rounded : Icons.cancel_outlined,
              color: granted ? Colors.green : colors.outline,
            ),
            title: Text(entry.value),
            trailing: Text(
              granted
                  ? _t('Granted', 'অনুমোদিত')
                  : _t('Not granted', 'অনুমোদিত নয়'),
              textAlign: TextAlign.right,
              style: TextStyle(
                color: granted ? Colors.green.shade700 : colors.outline,
                fontWeight: FontWeight.w800,
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _settingsCard({required List<Widget> children}) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: children),
      ),
    );
  }

  Widget _premiumSwitch({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
      secondary: Icon(icon, color: Theme.of(context).colorScheme.primary),
      value: value,
      onChanged: onChanged,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
    );
  }

  Widget _notificationSwitch({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: 2),
      secondary: Icon(icon, color: Theme.of(context).colorScheme.primary),
      value: value,
      onChanged: onChanged,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  Widget _notificationDivider() {
    return const Divider(height: 1, indent: 52);
  }

  Widget _timeTile({
    required IconData icon,
    required String title,
    required TimeOfDay? value,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(
        value == null
            ? _t('Select time', 'সময় নির্বাচন করুন')
            : value.format(context),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
