import 'package:flutter/material.dart';

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

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _timezoneController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

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
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    final timezone = _timezoneController.text.trim();

    if (timezone.isEmpty) {
      setState(() {
        _errorMessage = 'Notification timezone is required.';
      });
      return;
    }

    if (_quietHoursEnabled &&
        (_quietHoursStart == null || _quietHoursEnd == null)) {
      setState(() {
        _errorMessage = 'Select both quiet hours start and end time.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      final result = await _service.updateSettings(
        appSettings: <String, dynamic>{
          'theme_mode': _themeMode,
          'language_code': _languageCode,
          'time_format': _timeFormat,
          'ai_analysis_enabled': _aiAnalysisEnabled,
          'journal_analysis_enabled': _journalAnalysisEnabled,
          'analytics_enabled': _analyticsEnabled,
        },
        notificationPreferences: <String, dynamic>{
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
        },
      );

      final appSettings = _asMap(result['app_settings']);

      final notifications = _asMap(result['notification_preferences']);

      if (!mounted) return;

      setState(() {
        _themeMode = appSettings['theme_mode']?.toString() ?? _themeMode;

        _languageCode =
            appSettings['language_code']?.toString() ?? _languageCode;

        _timeFormat = appSettings['time_format']?.toString() ?? _timeFormat;

        _notificationsEnabled = notifications['notifications_enabled'] == true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account settings saved successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
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

  TimeOfDay? _parseTime(dynamic value) {
    final text = value?.toString() ?? '';

    if (text.length < 5) return null;

    final parts = text.substring(0, 5).split(':');

    if (parts.length != 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) {
      return null;
    }

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
    );

    if (selected == null || !mounted) return;

    setState(() {
      _quietHoursStart = selected;
    });
  }

  Future<void> _pickQuietHoursEnd() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _quietHoursEnd ?? const TimeOfDay(hour: 7, minute: 0),
    );

    if (selected == null || !mounted) return;

    setState(() {
      _quietHoursEnd = selected;
    });
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
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FC),
      appBar: AppBar(
        title: const Text('Account Settings'),
        actions: [
          TextButton(
            onPressed: _loading || _saving ? null : _saveSettings,
            child: Text(_saving ? 'Saving...' : 'Save'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSettings,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                children: [
                  if (_errorMessage != null) _buildErrorBanner(),
                  _buildApplicationSettings(),
                  const SizedBox(height: 16),
                  _buildPrivacySettings(),
                  const SizedBox(height: 16),
                  _buildNotificationSettings(),
                  const SizedBox(height: 16),
                  _buildConsentStatus(),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _saving ? null : _saveSettings,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _saving ? 'Saving settings...' : 'Save Settings',
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.red.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red.shade800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationSettings() {
    return _settingsCard(
      title: 'Application',
      icon: Icons.tune_rounded,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _themeMode,
          decoration: const InputDecoration(
            labelText: 'Theme preference',
            prefixIcon: Icon(Icons.palette_outlined),
          ),
          items: const [
            DropdownMenuItem(value: 'system', child: Text('System default')),
            DropdownMenuItem(value: 'light', child: Text('Light')),
            DropdownMenuItem(value: 'dark', child: Text('Dark')),
          ],
          onChanged: (value) {
            if (value == null) return;

            setState(() {
              _themeMode = value;
            });
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _languageCode,
          decoration: const InputDecoration(
            labelText: 'Language',
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
        DropdownButtonFormField<String>(
          initialValue: _timeFormat,
          decoration: const InputDecoration(
            labelText: 'Time format',
            prefixIcon: Icon(Icons.schedule_rounded),
          ),
          items: const [
            DropdownMenuItem(value: '12_hour', child: Text('12-hour')),
            DropdownMenuItem(value: '24_hour', child: Text('24-hour')),
          ],
          onChanged: (value) {
            if (value == null) return;

            setState(() {
              _timeFormat = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildPrivacySettings() {
    return _settingsCard(
      title: 'Privacy and Analysis',
      icon: Icons.privacy_tip_outlined,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _aiAnalysisEnabled,
          onChanged: (value) {
            setState(() {
              _aiAnalysisEnabled = value;
            });
          },
          title: const Text('AI analysis'),
          subtitle: const Text('Allow MindPulse AI to analyse wellness data.'),
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
          subtitle: const Text('Allow AI-supported journal analysis.'),
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
            'Help improve the application through usage analytics.',
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationSettings() {
    final childEnabled = _notificationsEnabled;

    return _settingsCard(
      title: 'Notifications',
      icon: Icons.notifications_active_outlined,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _notificationsEnabled,
          onChanged: (value) {
            setState(() {
              _notificationsEnabled = value;
            });
          },
          title: const Text('Enable notifications'),
          subtitle: const Text('Master notification control.'),
        ),
        const Divider(height: 1),
        _notificationSwitch(
          title: 'Daily check-in reminders',
          value: _checkinReminders,
          enabled: childEnabled,
          onChanged: (value) {
            setState(() {
              _checkinReminders = value;
            });
          },
        ),
        _notificationSwitch(
          title: 'Habit reminders',
          value: _habitReminders,
          enabled: childEnabled,
          onChanged: (value) {
            setState(() {
              _habitReminders = value;
            });
          },
        ),
        _notificationSwitch(
          title: 'Sleep reminders',
          value: _sleepReminders,
          enabled: childEnabled,
          onChanged: (value) {
            setState(() {
              _sleepReminders = value;
            });
          },
        ),
        _notificationSwitch(
          title: 'Recovery reminders',
          value: _recoveryReminders,
          enabled: childEnabled,
          onChanged: (value) {
            setState(() {
              _recoveryReminders = value;
            });
          },
        ),
        _notificationSwitch(
          title: 'Wellness scan reminders',
          value: _wellnessScanReminders,
          enabled: childEnabled,
          onChanged: (value) {
            setState(() {
              _wellnessScanReminders = value;
            });
          },
        ),
        _notificationSwitch(
          title: 'Weekly report notifications',
          value: _reportNotifications,
          enabled: childEnabled,
          onChanged: (value) {
            setState(() {
              _reportNotifications = value;
            });
          },
        ),
        _notificationSwitch(
          title: 'Achievement notifications',
          value: _achievementNotifications,
          enabled: childEnabled,
          onChanged: (value) {
            setState(() {
              _achievementNotifications = value;
            });
          },
        ),
        _notificationSwitch(
          title: 'Inactivity reminders',
          value: _inactivityReminders,
          enabled: childEnabled,
          onChanged: (value) {
            setState(() {
              _inactivityReminders = value;
            });
          },
        ),
        _notificationSwitch(
          title: 'Announcements',
          value: _announcementNotifications,
          enabled: childEnabled,
          onChanged: (value) {
            setState(() {
              _announcementNotifications = value;
            });
          },
        ),
        const Divider(height: 1),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _quietHoursEnabled,
          onChanged: childEnabled
              ? (value) {
                  setState(() {
                    _quietHoursEnabled = value;
                  });
                }
              : null,
          title: const Text('Quiet hours'),
          subtitle: const Text(
            'Pause push notifications during selected hours.',
          ),
        ),
        if (_quietHoursEnabled) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.nights_stay_outlined),
            title: const Text('Quiet hours start'),
            subtitle: Text(_timeString(_quietHoursStart) ?? 'Select time'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickQuietHoursStart,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.wb_sunny_outlined),
            title: const Text('Quiet hours end'),
            subtitle: Text(_timeString(_quietHoursEnd) ?? 'Select time'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickQuietHoursEnd,
          ),
        ],
        const SizedBox(height: 8),
        TextField(
          controller: _timezoneController,
          decoration: const InputDecoration(
            labelText: 'Notification timezone',
            hintText: 'Asia/Dhaka',
            prefixIcon: Icon(Icons.public_rounded),
          ),
        ),
      ],
    );
  }

  Widget _notificationSwitch({
    required String title,
    required bool value,
    required bool enabled,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: enabled ? onChanged : null,
      title: Text(title),
    );
  }

  Widget _buildConsentStatus() {
    final consents = _asMap(_onboarding['consents']);

    final completed = _onboarding['required_consents_completed'] == true;

    const consentLabels = <String, String>{
      'terms': 'Terms of service',
      'privacy': 'Privacy policy',
      'wellness_data': 'Wellness data',
      'ai_analysis': 'AI analysis',
      'journal_analysis': 'Journal analysis',
      'analytics': 'Analytics',
      'notifications': 'Notifications',
    };

    return _settingsCard(
      title: 'Consent Status',
      icon: Icons.verified_user_outlined,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: completed ? Colors.green.shade50 : Colors.orange.shade50,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            completed
                ? 'All required consents are active.'
                : 'Some required consents are missing.',
            style: TextStyle(
              color: completed ? Colors.green.shade800 : Colors.orange.shade900,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...consentLabels.entries.map((entry) {
          final consent = _asMap(consents[entry.key]);

          final granted = consent['is_granted'] == true;

          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              granted ? Icons.check_circle_rounded : Icons.cancel_outlined,
              color: granted ? Colors.green : Colors.grey,
            ),
            title: Text(entry.value),
            trailing: Text(
              granted ? 'Granted' : 'Not granted',
              style: TextStyle(
                color: granted ? Colors.green.shade700 : Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _settingsCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF6059E8)),
                const SizedBox(width: 9),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}
