import 'package:flutter/material.dart';

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
  bool _enabled = false;
  Map<String, String> _jamaatTimes = <String, String>{};
  String? _savingPrayerKey;

  PrayerAlarmStatus _status = const PrayerAlarmStatus(
    notificationPermission: false,
    exactAlarmPermission: false,
  );
  PrayerSyncResult? _lastResult;
  DateTime? _lastSync;
  String? _error;

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
      final enabled = await _service.isEnabled();
      final status = await _bridge.getStatus();
      final lastSync = await _service.lastSync();
      final jamaatTimes = await _service.loadJamaatTimes();

      if (!mounted) {
        return;
      }
      setState(() {
        _enabled = enabled;
        _status = status;
        _lastSync = lastSync;
        _jamaatTimes = jamaatTimes;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  TimeOfDay _initialTimeFor(String prayerKey) {
    final storedValue = _jamaatTimes[prayerKey];

    if (storedValue == null || storedValue.trim().isEmpty) {
      return TimeOfDay.now();
    }

    final parts = storedValue.split(':');

    if (parts.length != 2) {
      return TimeOfDay.now();
    }

    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 0,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  Future<void> _editJamaatTime(String prayerKey, String prayerLabel) async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: _initialTimeFor(prayerKey),
      helpText: 'Select $prayerLabel jamaat time',
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
      await _service.saveJamaatTimes(<String, String?>{prayerKey: storedValue});

      PrayerSyncResult? updatedResult;
      DateTime? updatedLastSync;

      if (_enabled) {
        updatedResult = await _service.syncOnlineSchedule();
        updatedLastSync = await _service.lastSync();
      }

      final updatedTimes = await _service.loadJamaatTimes();

      if (!mounted) {
        return;
      }

      setState(() {
        _jamaatTimes = updatedTimes;
        _lastResult = updatedResult ?? _lastResult;

        if (updatedLastSync != null) {
          _lastSync = updatedLastSync;
        }

        _savingPrayerKey = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$prayerLabel jamaat time saved.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _savingPrayerKey = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _resetJamaatTime(String prayerKey, String prayerLabel) async {
    setState(() {
      _savingPrayerKey = prayerKey;
    });

    try {
      await _service.saveJamaatTimes(<String, String?>{prayerKey: null});

      PrayerSyncResult? updatedResult;
      DateTime? updatedLastSync;

      if (_enabled) {
        updatedResult = await _service.syncOnlineSchedule();
        updatedLastSync = await _service.lastSync();
      }

      final updatedTimes = await _service.loadJamaatTimes();

      if (!mounted) {
        return;
      }

      setState(() {
        _jamaatTimes = updatedTimes;
        _lastResult = updatedResult ?? _lastResult;

        if (updatedLastSync != null) {
          _lastSync = updatedLastSync;
        }

        _savingPrayerKey = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$prayerLabel time reset.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _savingPrayerKey = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _requestPermissions() async {
    await _bridge.requestNotificationPermission();
    await _bridge.requestExactAlarmPermission();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Grant notification and Alarms & reminders permissions, '
          'then return and tap Refresh status.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _sync() async {
    setState(() {
      _loading = true;
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
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${result.scheduledCount} prayer alarms scheduled.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _disable() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _service.setEnabled(false);
      if (!mounted) {
        return;
      }
      setState(() {
        _enabled = false;
        _lastResult = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _test({required bool fajr}) async {
    try {
      await _bridge.testAlarm(fajr: fajr);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            fajr
                ? 'Fajr test starts in 15 seconds.'
                : 'Normal test starts in 15 seconds.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FC),
      appBar: AppBar(
        title: const Text('Smart prayer alarms'),
        backgroundColor: const Color(0xFFF7F7FC),
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Refresh status',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: <Color>[Color(0xFF6059E8), Color(0xFF8257F5)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.mosque_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                        SizedBox(height: 14),
                        Text(
                          'Hybrid daily prayer schedule',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Dhuhr and Friday Jummah are 1:30 PM by default. '
                          'Jamaat times can be edited, and saved-time alarms '
                          'will be scheduled automatically.',
                          style: TextStyle(
                            color: Color(0xFFEAE9FF),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _StatusCard(
                    enabled: _enabled,
                    status: _status,
                    lastSync: _lastSync,
                  ),
                  const SizedBox(height: 14),
                  _JamaatTimesCard(
                    times: _jamaatTimes,
                    savingPrayerKey: _savingPrayerKey,
                    onEdit: _editJamaatTime,
                    onReset: _resetJamaatTime,
                  ),
                  const SizedBox(height: 14),
                  const _BehaviourCard(),
                  if (_lastResult != null) ...[
                    const SizedBox(height: 14),
                    _TodayCard(result: _lastResult!),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Card(
                      color: const Color(0xFFFFEDED),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Color(0xFF9C2525),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _loading ? null : _requestPermissions,
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                    label: const Text('Grant alarm permissions'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: _loading ? null : _sync,
                    icon: const Icon(Icons.cloud_sync_rounded),
                    label: Text(
                      _enabled
                          ? 'Refresh prayer schedule'
                          : 'Enable prayer schedule',
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : () => _test(fajr: false),
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: const Text('Demo Dhuhr alarm in 15 seconds'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : () => _test(fajr: true),
                    icon: const Icon(Icons.bedtime_outlined),
                    label: const Text('Test Fajr alarm in 15 seconds'),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _loading || !_enabled ? null : _disable,
                    icon: const Icon(Icons.notifications_off_outlined),
                    label: const Text('Disable all prayer alarms'),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Bengali speech uses the Android speech engine. '
                    'When Bengali speech is unavailable, the message '
                    'falls back to English.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF777786),
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _JamaatTimesCard extends StatelessWidget {
  const _JamaatTimesCard({
    required this.times,
    required this.savingPrayerKey,
    required this.onEdit,
    required this.onReset,
  });

  final Map<String, String> times;
  final String? savingPrayerKey;

  final Future<void> Function(String prayerKey, String prayerLabel) onEdit;

  final Future<void> Function(String prayerKey, String prayerLabel) onReset;

  static const List<_EditablePrayer> _prayers = <_EditablePrayer>[
    _EditablePrayer(
      keyName: 'fajr',
      label: 'Fajr',
      automaticRule: 'Automatic: online waqt + 10 minutes',
    ),
    _EditablePrayer(
      keyName: 'dhuhr',
      label: 'Dhuhr',
      automaticRule: 'Default jamaat: 1:30 PM',
    ),
    _EditablePrayer(
      keyName: 'jummah',
      label: 'Jummah',
      automaticRule: 'Friday default jamaat: 1:30 PM',
    ),
    _EditablePrayer(
      keyName: 'asr',
      label: 'Asr',
      automaticRule: 'Set your mosque jamaat time',
    ),
    _EditablePrayer(
      keyName: 'maghrib',
      label: 'Maghrib',
      automaticRule: 'Automatic: online waqt - 15 minutes',
    ),
    _EditablePrayer(
      keyName: 'isha',
      label: 'Isha',
      automaticRule: 'Set your mosque jamaat time',
    ),
  ];

  String _displayTime(BuildContext context, String? storedValue) {
    if (storedValue == null || storedValue.trim().isEmpty) {
      return 'Automatic';
    }

    final parts = storedValue.split(':');

    if (parts.length != 2) {
      return storedValue;
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) {
      return storedValue;
    }

    return TimeOfDay(hour: hour, minute: minute).format(context);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mosque jamaat times',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              'Edit the jamaat time beside each prayer. '
              'Saved jamaat alarms will ring 20 minutes earlier.',
              style: TextStyle(color: Color(0xFF686878), height: 1.4),
            ),
            const SizedBox(height: 14),
            for (var index = 0; index < _prayers.length; index++) ...[
              _JamaatTimeRow(
                prayer: _prayers[index],
                displayedTime: _displayTime(
                  context,
                  times[_prayers[index].keyName],
                ),
                saving: savingPrayerKey == _prayers[index].keyName,
                onEdit: () =>
                    onEdit(_prayers[index].keyName, _prayers[index].label),
                onReset: () =>
                    onReset(_prayers[index].keyName, _prayers[index].label),
              ),
              if (index != _prayers.length - 1) const Divider(height: 22),
            ],
          ],
        ),
      ),
    );
  }
}

class _JamaatTimeRow extends StatelessWidget {
  const _JamaatTimeRow({
    required this.prayer,
    required this.displayedTime,
    required this.saving,
    required this.onEdit,
    required this.onReset,
  });

  final _EditablePrayer prayer;
  final String displayedTime;
  final bool saving;
  final VoidCallback onEdit;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                prayer.label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                prayer.automaticRule,
                style: const TextStyle(color: Color(0xFF777786), fontSize: 12),
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
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF5149D8),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Edit jamaat time',
                    visualDensity: VisualDensity.compact,
                    onPressed: onEdit,
                    icon: const Icon(Icons.access_time_rounded, size: 21),
                  ),
                  IconButton(
                    tooltip: 'Reset time',
                    visualDensity: VisualDensity.compact,
                    onPressed: onReset,
                    icon: const Icon(Icons.restart_alt_rounded, size: 21),
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }
}

class _EditablePrayer {
  const _EditablePrayer({
    required this.keyName,
    required this.label,
    required this.automaticRule,
  });

  final String keyName;
  final String label;
  final String automaticRule;
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.enabled,
    required this.status,
    required this.lastSync,
  });

  final bool enabled;
  final PrayerAlarmStatus status;
  final DateTime? lastSync;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _StatusRow(
              label: 'Prayer alarms',
              passed: enabled,
              value: enabled ? 'Enabled' : 'Disabled',
            ),
            const Divider(height: 24),
            _StatusRow(
              label: 'Notifications',
              passed: status.notificationPermission,
              value: status.notificationPermission
                  ? 'Allowed'
                  : 'Permission required',
            ),
            const Divider(height: 24),
            _StatusRow(
              label: 'Exact alarms',
              passed: status.exactAlarmPermission,
              value: status.exactAlarmPermission
                  ? 'Allowed'
                  : 'Permission required',
            ),
            const Divider(height: 24),
            _StatusRow(
              label: 'Last schedule sync',
              passed: lastSync != null,
              value: lastSync == null
                  ? 'Not synced'
                  : lastSync!.toLocal().toString().split('.').first,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.passed,
    required this.value,
  });

  final String label;
  final bool passed;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          passed ? Icons.check_circle_rounded : Icons.info_outline_rounded,
          color: passed ? const Color(0xFF18864B) : const Color(0xFFC47A13),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(color: Color(0xFF686878)),
          ),
        ),
      ],
    );
  }
}

class _BehaviourCard extends StatelessWidget {
  const _BehaviourCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFF0EFFF),
      child: const Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Demo and alarm behaviour',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 12),
            Text(
              '• Dhuhr demo: after 15 seconds, the alarm rings for 15 seconds.',
            ),
            SizedBox(height: 8),
            Text(
              '• When the alarm sound ends, the voice reads the real '
              'phone time at that moment and gives the prayer message.',
            ),
            SizedBox(height: 8),
            Text(
              '• Fajr: 30-second alarm, then the current-time voice message twice.',
            ),
            SizedBox(height: 8),
            Text(
              '• Tap Stop on the alarm notification to cut sound and voice immediately.',
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.result});

  final PrayerSyncResult result;

  @override
  Widget build(BuildContext context) {
    final order = DateTime.now().weekday == DateTime.friday
        ? <String>['Fajr', 'Jummah', 'Asr', 'Maghrib', 'Isha']
        : <String>['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Today’s prayer times',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              result.locationLabel,
              style: const TextStyle(color: Color(0xFF686878)),
            ),
            Text(
              result.timezone,
              style: const TextStyle(color: Color(0xFF686878)),
            ),
            const SizedBox(height: 12),
            for (final prayer in order)
              if (result.todayTimes.containsKey(prayer))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          prayer,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(result.todayTimes[prayer]!),
                    ],
                  ),
                ),
            const Divider(height: 24),
            Text('${result.scheduledCount} future alarm events scheduled.'),
            if (result.usedFallbackLocation)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Dhaka fallback is active. Grant location permission '
                  'and refresh for your current location.',
                  style: TextStyle(
                    color: Color(0xFFC47A13),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
