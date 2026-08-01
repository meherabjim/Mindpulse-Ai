import 'package:flutter/material.dart';

import '../../../core/settings/app_preferences_controller.dart';
import '../services/prayer_alarm_bridge.dart';
import '../services/prayer_service.dart';

class PrayerSettingsScreen extends StatefulWidget {
  const PrayerSettingsScreen({super.key});

  @override
  State<PrayerSettingsScreen> createState() => _PrayerSettingsScreenState();
}

class _PrayerSettingsScreenState extends State<PrayerSettingsScreen> {
  final PrayerAlarmBridge _bridge = const PrayerAlarmBridge();
  late final PrayerService _service = PrayerService(bridge: _bridge);

  bool _loading = true;
  bool _syncing = false;
  bool _enabled = false;
  Map<String, String> _reminderTimes = <String, String>{};
  String? _savingPrayerKey;

  PrayerAlarmStatus _status = const PrayerAlarmStatus(
    notificationPermission: false,
    exactAlarmPermission: false,
  );

  PrayerSyncResult? _lastResult;
  DateTime? _lastSync;
  String? _error;

  String _t(String english, String bangla) {
    return AppPreferencesController.instance.text(english, bangla);
  }

  bool get _permissionsReady {
    return _status.notificationPermission && _status.exactAlarmPermission;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait<Object?>(<Future<Object?>>[
        _service.isEnabled(),
        _bridge.getStatus(),
        _service.lastSync(),
        _service.loadReminderTimes(),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _enabled = values[0] as bool;
        _status = values[1] as PrayerAlarmStatus;
        _lastSync = values[2] as DateTime?;
        _reminderTimes = values[3] as Map<String, String>;
        _loading = false;
        _error = null;
      });

      if (_enabled) {
        await _sync(silent: true);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _refreshPermissionStatus() async {
    final status = await _bridge.getStatus();

    if (!mounted) {
      return;
    }

    setState(() {
      _status = status;
    });
  }

  Future<void> _requestMissingPermissions() async {
    try {
      if (!_status.notificationPermission) {
        await _bridge.requestNotificationPermission();
      }

      if (!_status.exactAlarmPermission) {
        await _bridge.requestExactAlarmPermission();
      }

      await Future<void>.delayed(const Duration(milliseconds: 350));
      await _refreshPermissionStatus();

      if (!mounted) {
        return;
      }

      if (!_permissionsReady) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t(
                'Allow notifications and Alarms & reminders, then return to MindPulse.',
                'নোটিফিকেশন এবং অ্যালার্মের অনুমতি দিয়ে MindPulse-এ ফিরে আসুন।',
              ),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _toggleEnabled(bool value) async {
    if (!value) {
      setState(() {
        _syncing = true;
        _error = null;
      });

      try {
        await _service.setEnabled(false);

        if (!mounted) {
          return;
        }

        setState(() {
          _enabled = false;
          _syncing = false;
          _lastResult = null;
        });
      } catch (error) {
        if (!mounted) {
          return;
        }

        setState(() {
          _syncing = false;
        });
        _showError(error);
      }

      return;
    }

    await _requestMissingPermissions();

    if (!mounted || !_permissionsReady) {
      return;
    }

    await _sync();
  }

  TimeOfDay _initialTimeFor(String prayerKey) {
    final storedValue = _reminderTimes[prayerKey];

    if (storedValue == null || storedValue.trim().isEmpty) {
      final now = TimeOfDay.now();
      return TimeOfDay(hour: now.hour, minute: now.minute);
    }

    final parsed = PrayerTimeParser.parse(storedValue);
    return TimeOfDay(hour: parsed.hour, minute: parsed.minute);
  }

  Future<void> _editReminderTime(String prayerKey, String prayerLabel) async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: _initialTimeFor(prayerKey),
      helpText: _t(
        'Select $prayerLabel reminder time',
        '$prayerLabel নামাজের মনে করানোর সময়',
      ),
    );

    if (selectedTime == null || !mounted) {
      return;
    }

    final storedValue =
        '${selectedTime.hour.toString().padLeft(2, '0')}:'
        '${selectedTime.minute.toString().padLeft(2, '0')}';

    setState(() {
      _savingPrayerKey = prayerKey;
    });

    try {
      await _service.saveReminderTimes(<String, String?>{
        prayerKey: storedValue,
      });

      final updatedTimes = await _service.loadReminderTimes();

      if (!mounted) {
        return;
      }

      setState(() {
        _reminderTimes = updatedTimes;
        _savingPrayerKey = null;
      });

      if (_enabled) {
        await _sync(silent: true);
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              '$prayerLabel reminder time saved.',
              '$prayerLabel নামাজের মনে করানোর সময় সংরক্ষণ হয়েছে।',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _savingPrayerKey = null;
        });
      }
      _showError(error);
    }
  }

  Future<void> _resetReminderTime(String prayerKey, String prayerLabel) async {
    setState(() {
      _savingPrayerKey = prayerKey;
    });

    try {
      await _service.saveReminderTimes(<String, String?>{prayerKey: null});
      final updatedTimes = await _service.loadReminderTimes();

      if (!mounted) {
        return;
      }

      setState(() {
        _reminderTimes = updatedTimes;
        _savingPrayerKey = null;
      });

      if (_enabled) {
        await _sync(silent: true);
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              '$prayerLabel reminder returned to its default rule.',
              '$prayerLabel নামাজের মনে করানোর সময় আগের নিয়মে ফিরে গেছে।',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _savingPrayerKey = null;
        });
      }
      _showError(error);
    }
  }

  Future<void> _sync({bool silent = false}) async {
    if (_syncing) {
      return;
    }

    setState(() {
      _syncing = true;
      _error = null;
    });

    try {
      final result = await _service.syncOnlineSchedule();
      final status = await _bridge.getStatus();
      final lastSync = await _service.lastSync();

      if (!mounted) {
        return;
      }

      setState(() {
        _enabled = true;
        _status = status;
        _lastResult = result;
        _lastSync = lastSync;
        _syncing = false;
      });

      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t(
                '${result.scheduledCount} prayer reminders are ready.',
                '${result.scheduledCount}টি নামাজের স্মরণ প্রস্তুত হয়েছে।',
              ),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _syncing = false;
        _error = error.toString();
      });
    }
  }

  void _showError(Object error) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.toString()),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatLastSync(BuildContext context) {
    final value = _lastSync;

    if (value == null) {
      return _t('Not updated yet', 'এখনো আপডেট হয়নি');
    }

    final local = value.toLocal();
    final date = MaterialLocalizations.of(context).formatShortDate(local);
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(local));

    return '$date • $time';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(_t('Prayer reminders', 'নামাজের স্মরণ'))),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
                  children: [
                    _PrayerHero(
                      enabled: _enabled,
                      syncing: _syncing,
                      onChanged: _toggleEnabled,
                      translate: _t,
                    ),
                    const SizedBox(height: 14),
                    _MessageCard(translate: _t),
                    if (!_permissionsReady) ...[
                      const SizedBox(height: 14),
                      _PermissionCard(
                        status: _status,
                        onRequest: _requestMissingPermissions,
                        translate: _t,
                      ),
                    ],
                    const SizedBox(height: 14),
                    _ReminderTimesCard(
                      times: _reminderTimes,
                      savingPrayerKey: _savingPrayerKey,
                      onEdit: _editReminderTime,
                      onReset: _resetReminderTime,
                      translate: _t,
                    ),
                    if (_lastResult != null) ...[
                      const SizedBox(height: 14),
                      _TodayPrayerCard(result: _lastResult!, translate: _t),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colors.errorContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: colors.onErrorContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _syncing || !_enabled ? null : () => _sync(),
                      icon: _syncing
                          ? const SizedBox(
                              width: 19,
                              height: 19,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync_rounded),
                      label: Text(
                        _t('Update prayer times', 'নামাজের সময় আপডেট করুন'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${_t('Last update', 'সর্বশেষ আপডেট')}: '
                      '${_formatLastSync(context)}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

typedef _Translate = String Function(String english, String bangla);

class _PrayerHero extends StatelessWidget {
  const _PrayerHero({
    required this.enabled,
    required this.syncing,
    required this.onChanged,
    required this.translate,
  });

  final bool enabled;
  final bool syncing;
  final ValueChanged<bool> onChanged;
  final _Translate translate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF4F46D8), Color(0xFF7B58E8)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x334F46D8),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.notifications_active_rounded,
            color: Colors.white,
            size: 34,
          ),
          const SizedBox(height: 14),
          Text(
            translate('Prayer reminder', 'নামাজের স্মরণ'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            translate(
              'Online prayer times are used for your location. You control the reminder time.',
              'আপনার অবস্থান অনুযায়ী অনলাইন নামাজের সময় নেওয়া হবে। কখন মনে করাবে, সেটি আপনি ঠিক করবেন।',
            ),
            style: const TextStyle(color: Color(0xFFF0EEFF), height: 1.45),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(
                enabled
                    ? translate('Reminders are on', 'নামাজের স্মরণ চালু আছে')
                    : translate('Reminders are off', 'নামাজের স্মরণ বন্ধ আছে'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                enabled
                    ? translate(
                        'The saved schedule will also return after a device restart.',
                        'ফোন বন্ধ করে চালু করলেও সংরক্ষিত সময়গুলো আবার সক্রিয় হবে।',
                      )
                    : translate(
                        'Turn on to prepare the next 30 days.',
                        'পরবর্তী ৩০ দিনের স্মরণ তৈরি করতে চালু করুন।',
                      ),
                style: const TextStyle(color: Color(0xFFE8E5FF), fontSize: 12),
              ),
              value: enabled,
              onChanged: syncing ? null : onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.translate});

  final _Translate translate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.record_voice_over_rounded, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  translate('Voice message', 'যে কথাটি শোনা যাবে'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                Text(
                  PrayerService.banglaReminderMessage,
                  style: TextStyle(
                    color: colors.onPrimaryContainer,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.status,
    required this.onRequest,
    required this.translate,
  });

  final PrayerAlarmStatus status;
  final VoidCallback onRequest;
  final _Translate translate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final missing = <String>[];

    if (!status.notificationPermission) {
      missing.add(translate('Notifications', 'নোটিফিকেশন'));
    }

    if (!status.exactAlarmPermission) {
      missing.add(translate('Alarms & reminders', 'অ্যালার্ম ও স্মরণ'));
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            translate('Permission needed', 'একবার অনুমতি প্রয়োজন'),
            style: TextStyle(
              color: colors.onTertiaryContainer,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            missing.join(' • '),
            style: TextStyle(color: colors.onTertiaryContainer),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRequest,
            icon: const Icon(Icons.admin_panel_settings_outlined),
            label: Text(translate('Allow permissions', 'অনুমতি দিন')),
          ),
        ],
      ),
    );
  }
}

class _ReminderTimesCard extends StatelessWidget {
  const _ReminderTimesCard({
    required this.times,
    required this.savingPrayerKey,
    required this.onEdit,
    required this.onReset,
    required this.translate,
  });

  final Map<String, String> times;
  final String? savingPrayerKey;
  final Future<void> Function(String prayerKey, String prayerLabel) onEdit;
  final Future<void> Function(String prayerKey, String prayerLabel) onReset;
  final _Translate translate;

  static const List<_PrayerReminderDefinition> _prayers =
      <_PrayerReminderDefinition>[
        _PrayerReminderDefinition(
          keyName: 'fajr',
          english: 'Fajr',
          bangla: 'ফজর',
          automaticBangla: 'অনলাইন সময়ের ১০ মিনিট আগে',
          automaticEnglish: '10 minutes before online time',
        ),
        _PrayerReminderDefinition(
          keyName: 'dhuhr',
          english: 'Dhuhr',
          bangla: 'যোহর',
          automaticBangla: 'প্রাথমিক সময়: ১:০৫ PM',
          automaticEnglish: 'Default reminder: 1:05 PM',
        ),
        _PrayerReminderDefinition(
          keyName: 'jummah',
          english: 'Jummah',
          bangla: 'জুমা',
          automaticBangla: 'শুক্রবারের সময়: ১২:৩৫ PM',
          automaticEnglish: 'Friday reminder: 12:35 PM',
        ),
        _PrayerReminderDefinition(
          keyName: 'asr',
          english: 'Asr',
          bangla: 'আসর',
          automaticBangla: 'অনলাইন সময়ের ১০ মিনিট আগে',
          automaticEnglish: '10 minutes before online time',
        ),
        _PrayerReminderDefinition(
          keyName: 'maghrib',
          english: 'Maghrib',
          bangla: 'মাগরিব',
          automaticBangla: 'অনলাইন সময়ের ১০ মিনিট আগে',
          automaticEnglish: '10 minutes before online time',
        ),
        _PrayerReminderDefinition(
          keyName: 'isha',
          english: 'Isha',
          bangla: 'এশা',
          automaticBangla: 'অনলাইন সময়ের ১০ মিনিট আগে',
          automaticEnglish: '10 minutes before online time',
        ),
      ];

  String _displayTime(BuildContext context, String? value) {
    if (value == null || value.trim().isEmpty) {
      return translate('Automatic', 'Automatic');
    }

    final parsed = PrayerTimeParser.parse(value);
    return TimeOfDay(hour: parsed.hour, minute: parsed.minute).format(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            translate('Reminder times', 'মনে করানোর সময়'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            translate(
              'These are reminder times. Edit any row when your routine is different.',
              'এগুলো মনে করানোর সময়। আপনার রুটিন আলাদা হলে যেকোনো সময় পরিবর্তন করুন।',
            ),
            style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < _prayers.length; index++) ...[
            _ReminderTimeRow(
              definition: _prayers[index],
              displayedTime: _displayTime(
                context,
                times[_prayers[index].keyName],
              ),
              saving: savingPrayerKey == _prayers[index].keyName,
              onEdit: () => onEdit(
                _prayers[index].keyName,
                translate(_prayers[index].english, _prayers[index].bangla),
              ),
              onReset: () => onReset(
                _prayers[index].keyName,
                translate(_prayers[index].english, _prayers[index].bangla),
              ),
              translate: translate,
            ),
            if (index != _prayers.length - 1) const Divider(height: 22),
          ],
        ],
      ),
    );
  }
}

class _PrayerReminderDefinition {
  const _PrayerReminderDefinition({
    required this.keyName,
    required this.english,
    required this.bangla,
    required this.automaticBangla,
    required this.automaticEnglish,
  });

  final String keyName;
  final String english;
  final String bangla;
  final String automaticBangla;
  final String automaticEnglish;
}

class _ReminderTimeRow extends StatelessWidget {
  const _ReminderTimeRow({
    required this.definition,
    required this.displayedTime,
    required this.saving,
    required this.onEdit,
    required this.onReset,
    required this.translate,
  });

  final _PrayerReminderDefinition definition;
  final String displayedTime;
  final bool saving;
  final VoidCallback onEdit;
  final VoidCallback onReset;
  final _Translate translate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                translate(definition.english, definition.bangla),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                translate(
                  definition.automaticEnglish,
                  definition.automaticBangla,
                ),
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (saving)
          const SizedBox(
            width: 32,
            height: 32,
            child: Padding(
              padding: EdgeInsets.all(7),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                displayedTime,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: colors.primary,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: translate('Edit time', 'সময় পরিবর্তন'),
                    visualDensity: VisualDensity.compact,
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_calendar_rounded, size: 20),
                  ),
                  IconButton(
                    tooltip: translate('Use default', 'আগের নিয়ম ব্যবহার'),
                    visualDensity: VisualDensity.compact,
                    onPressed: onReset,
                    icon: const Icon(Icons.restart_alt_rounded, size: 20),
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }
}

class _TodayPrayerCard extends StatelessWidget {
  const _TodayPrayerCard({required this.result, required this.translate});

  final PrayerSyncResult result;
  final _Translate translate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isFriday = DateTime.now().weekday == DateTime.friday;
    final order = isFriday
        ? <String>['Fajr', 'Jummah', 'Asr', 'Maghrib', 'Isha']
        : <String>['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

    final labels = <String, String>{
      'Fajr': translate('Fajr', 'ফজর'),
      'Dhuhr': translate('Dhuhr', 'যোহর'),
      'Jummah': translate('Jummah', 'জুমা'),
      'Asr': translate('Asr', 'আসর'),
      'Maghrib': translate('Maghrib', 'মাগরিব'),
      'Isha': translate('Isha', 'এশা'),
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            translate('Today', 'আজ'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            result.locationLabel,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 12),
          for (final prayer in order)
            if (result.todayPrayerTimes.containsKey(prayer))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        labels[prayer] ?? prayer,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${translate('Prayer time', 'নামাজের সময়')}: '
                          '${result.todayPrayerTimes[prayer]}',
                        ),
                        Text(
                          '${translate('Reminder', 'মনে করাবে')}: '
                          '${result.todayReminderTimes[prayer]}',
                          style: TextStyle(
                            color: colors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          const Divider(height: 24),
          Text(
            translate(
              '${result.scheduledCount} upcoming reminders are saved.',
              '${result.scheduledCount}টি আসন্ন স্মরণ সংরক্ষিত আছে।',
            ),
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          if (result.usedFallbackLocation)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                translate(
                  'A fallback location was used. Turn on location and update for local times.',
                  'বিকল্প অবস্থান ব্যবহার হয়েছে। স্থানীয় সময় পেতে অবস্থান চালু করে আবার আপডেট করুন।',
                ),
                style: TextStyle(
                  color: colors.tertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
