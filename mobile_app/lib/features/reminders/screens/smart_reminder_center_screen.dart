import 'dart:async';

import 'package:flutter/material.dart';

import '../services/smart_reminder_service.dart';
import '../widgets/reminder_adaptive_controls.dart';

class SmartReminderCenterScreen extends StatefulWidget {
  const SmartReminderCenterScreen({super.key});

  @override
  State<SmartReminderCenterScreen> createState() =>
      _SmartReminderCenterScreenState();
}

class _SmartReminderCenterScreenState extends State<SmartReminderCenterScreen> {
  final SmartReminderService _service = SmartReminderService();

  bool _loading = true;
  bool _saving = false;
  bool _hasPendingSave = false;
  bool _saveInProgress = false;

  Timer? _autoSaveTimer;

  String? _errorMessage;

  late Map<String, dynamic> _configuration;

  Map<String, dynamic> _status = <String, dynamic>{};

  Map<String, dynamic> get _defaultConfiguration {
    return <String, dynamic>{
      'master_enabled': false,
      'wake_up_minutes': 420,
      'morning_delay_minutes': 20,
      'quiet_start_minutes': 1320,
      'quiet_end_minutes': 420,
      'max_daily_reminders': 4,
      'reminders': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'morning_checkin',
          'type': 'daily',
          'enabled': false,
          'title_bn': 'সকালের মাইন্ডপালস চেক-ইন',
          'message_bn':
              'সুপ্রভাত। আজকের মুড, স্ট্রেস এবং শক্তির অবস্থা জানাতে একটি ছোট চেক-ইন সম্পন্ন করুন।',
          'hour': 7,
          'minute': 0,
          'voice': false,
          'vibration': false,
          'icon': 'morning',
        },
        <String, dynamic>{
          'id': 'water',
          'type': 'interval',
          'enabled': false,
          'title_bn': 'পানি পান করার সময়',
          'message_bn':
              'আপনার শরীরের যত্ন নিতে এখন এক গ্লাস পানি পান করতে পারেন।',
          'interval_minutes': 180,
          'active_start_minutes': 480,
          'active_end_minutes': 1200,
          'voice': false,
          'vibration': false,
          'icon': 'water',
        },
        <String, dynamic>{
          'id': 'exercise',
          'type': 'daily',
          'enabled': false,
          'title_bn': 'ছোট ব্যায়ামের সময়',
          'message_bn':
              'শরীরকে সক্রিয় রাখতে কয়েক মিনিট হাঁটা বা হালকা স্ট্রেচিং করতে পারেন।',
          'hour': 18,
          'minute': 0,
          'voice': false,
          'vibration': false,
          'icon': 'exercise',
        },
        <String, dynamic>{
          'id': 'bedtime',
          'type': 'daily',
          'enabled': false,
          'title_bn': 'ঘুমের প্রস্তুতির সময়',
          'message_bn':
              'এখন ধীরে ধীরে ফোনটি পাশে রেখে শরীর ও মনকে বিশ্রামের জন্য প্রস্তুত করতে পারেন।',
          'hour': 22,
          'minute': 30,
          'voice': false,
          'vibration': false,
          'icon': 'bedtime',
        },
        <String, dynamic>{
          'id': 'journal',
          'type': 'daily',
          'enabled': false,
          'title_bn': 'দিনের অনুভূতি লিখে রাখুন',
          'message_bn':
              'আজকের দিনটি কেমন গেল, তা কয়েকটি বাক্যে লিখে রাখতে পারেন।',
          'hour': 21,
          'minute': 30,
          'voice': false,
          'vibration': false,
          'icon': 'journal',
        },
        <String, dynamic>{
          'id': 'wellness_scan',
          'type': 'daily',
          'enabled': false,
          'title_bn': 'ওয়েলনেস স্ক্যান',
          'message_bn':
              'নিজের বর্তমান মানসিক ও শারীরিক অবস্থার দিকে নজর দিতে একটি ওয়েলনেস স্ক্যান করতে পারেন।',
          'hour': 19,
          'minute': 0,
          'voice': false,
          'vibration': false,
          'icon': 'wellness',
        },
      ],
    };
  }

  @override
  void initState() {
    super.initState();

    _configuration = _defaultConfiguration;

    _load();
  }

  Future<void> _load() async {
    try {
      final stored = await _service.getConfiguration();

      final status = await _service.getStatus();

      if (!mounted) {
        return;
      }

      setState(() {
        _configuration = stored ?? _defaultConfiguration;

        _ensureMorningRoutineConfiguration();

        _status = status;
        _loading = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _errorMessage = error.toString();
      });
    }
  }

  List<Map<String, dynamic>> get _reminders {
    final value = _configuration['reminders'];

    if (value is! List) {
      return <Map<String, dynamic>>[];
    }

    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  void _updateConfiguration(VoidCallback update) {
    setState(update);
    _scheduleAutoSave();
  }

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();

    _hasPendingSave = true;

    if (mounted && !_saving) {
      setState(() {
        _saving = true;
      });
    }

    _autoSaveTimer = Timer(
      const Duration(milliseconds: 350),
      _saveAutomatically,
    );
  }

  Future<void> _saveAutomatically() async {
    if (_saveInProgress) {
      _hasPendingSave = true;
      return;
    }

    _saveInProgress = true;

    try {
      do {
        _hasPendingSave = false;

        await _service.saveConfiguration(_configuration);
      } while (_hasPendingSave);

      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
        _errorMessage = null;
      });
    } catch (error) {
      _hasPendingSave = false;

      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
        _errorMessage =
            'Reminder settings could not be saved: '
            '$error';
      });
    } finally {
      _saveInProgress = false;
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();

    /*
     * Save the latest selection when the user
     * leaves the screen immediately after a change.
     */
    if (_hasPendingSave) {
      unawaited(_service.saveConfiguration(_configuration));
    }

    super.dispose();
  }

  Future<void> _runNow() async {
    try {
      await _service.runCheckNow();

      await Future<void>.delayed(const Duration(seconds: 4));

      final status = await _service.getStatus();

      if (!mounted) {
        return;
      }

      setState(() {
        _status = status;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reminder check completed.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _testReminder(Map<String, dynamic> reminder) async {
    try {
      final permission = await _service.hasNotificationPermission();

      if (!permission) {
        await _service.openNotificationSettings();

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Notification permission চালু করে আবার পরীক্ষা করুন।',
            ),
          ),
        );

        return;
      }

      final sent = await _service.sendTestReminder(
        id: '${reminder['id']}_test',

        title: reminder['title_bn']?.toString() ?? 'মাইন্ডপালস',

        message:
            reminder['message_bn']?.toString() ??
            'এটি একটি রিমাইন্ডার পরীক্ষা।',

        voice: reminder['voice'] == true,

        vibration: reminder['vibration'] == true,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sent
                ? 'Test reminder sent.'
                : 'Notification permission is unavailable.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _pickReminderTime(int index) async {
    final reminder = _reminders[index];

    final current = TimeOfDay(
      hour: (reminder['hour'] as num?)?.toInt() ?? 7,

      minute: (reminder['minute'] as num?)?.toInt() ?? 0,
    );

    final selected = await showTimePicker(
      context: context,
      initialTime: current,
    );

    if (selected == null || !mounted) {
      return;
    }

    _updateConfiguration(() {
      final reminders = _reminders;

      reminders[index]['hour'] = selected.hour;

      reminders[index]['minute'] = selected.minute;

      _configuration['reminders'] = reminders;
    });
  }

  Future<void> _pickQuietTime({required bool start}) async {
    final currentMinutes =
        (_configuration[start ? 'quiet_start_minutes' : 'quiet_end_minutes']
                as num?)
            ?.toInt() ??
        (start ? 1320 : 420);

    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: currentMinutes ~/ 60,

        minute: currentMinutes % 60,
      ),
    );

    if (selected == null || !mounted) {
      return;
    }

    _updateConfiguration(() {
      _configuration[start ? 'quiet_start_minutes' : 'quiet_end_minutes'] =
          selected.hour * 60 + selected.minute;
    });
  }

  String _formatMinutes(int minutes) {
    final value = TimeOfDay(hour: (minutes ~/ 60) % 24, minute: minutes % 60);

    return MaterialLocalizations.of(context).formatTimeOfDay(value);
  }

  String _formatTimestamp(dynamic value) {
    final milliseconds = (value as num?)?.toInt() ?? 0;

    if (milliseconds <= 0) {
      return 'Not yet';
    }

    final dateTime = DateTime.fromMillisecondsSinceEpoch(milliseconds);

    final time = TimeOfDay.fromDateTime(dateTime);

    return '${dateTime.day}/'
        '${dateTime.month}/'
        '${dateTime.year} '
        '${MaterialLocalizations.of(context).formatTimeOfDay(time)}';
  }

  IconData _iconFor(String value) {
    switch (value) {
      case 'morning':
        return Icons.wb_sunny_outlined;

      case 'water':
        return Icons.water_drop_outlined;

      case 'exercise':
        return Icons.directions_walk_outlined;

      case 'bedtime':
        return Icons.bedtime_outlined;

      case 'journal':
        return Icons.menu_book_outlined;

      case 'wellness':
        return Icons.favorite_outline;

      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),

      appBar: AppBar(
        title: const Text('Smart Reminder Center'),

        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _saving ? Icons.sync_rounded : Icons.cloud_done_outlined,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(_saving ? 'Saving...' : 'Auto-saved'),
                ],
              ),
            ),
          ),
        ],
      ),

      body: ListView(
        padding: const EdgeInsets.all(16),

        children: [
          _buildHumanCentredCard(),

          const SizedBox(height: 14),

          _buildMasterCard(),

          const SizedBox(height: 14),

          _buildMorningRoutineCard(),

          const SizedBox(height: 14),

          _buildQuietHoursCard(),

          const SizedBox(height: 14),

          _buildDailyLimitCard(),

          const SizedBox(height: 14),

          ..._buildReminderCards(),

          _buildStatusCard(),

          if (_errorMessage != null) ...[
            const SizedBox(height: 14),

            Card(
              color: Colors.red.shade50,

              child: ListTile(
                leading: Icon(Icons.error_outline, color: Colors.red.shade700),

                title: const Text('Reminder error'),

                subtitle: Text(_errorMessage!),
              ),
            ),
          ],

          const SizedBox(height: 18),

          OutlinedButton.icon(
            onPressed: _runNow,

            icon: const Icon(Icons.play_arrow_rounded),

            label: const Text('Run Reminder Check Now'),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  void _ensureMorningRoutineConfiguration() {
    _configuration.putIfAbsent('wake_up_minutes', () => 420);

    _configuration.putIfAbsent('morning_delay_minutes', () => 20);

    _applyMorningSchedule();
  }

  int _configurationMinutes(
    String key,
    int fallback,
    int minimum,
    int maximum,
  ) {
    final value = (_configuration[key] as num?)?.toInt() ?? fallback;

    return value.clamp(minimum, maximum).toInt();
  }

  void _applyMorningSchedule() {
    final wakeUpMinutes = _configurationMinutes(
      'wake_up_minutes',
      420,
      0,
      1439,
    );

    final delayMinutes = _configurationMinutes(
      'morning_delay_minutes',
      20,
      0,
      120,
    );

    final scheduledMinutes = (wakeUpMinutes + delayMinutes) % 1440;

    final reminders = _reminders;

    final morningIndex = reminders.indexWhere(
      (reminder) => reminder['id'] == 'morning_checkin',
    );

    if (morningIndex < 0) {
      return;
    }

    reminders[morningIndex]['hour'] = scheduledMinutes ~/ 60;

    reminders[morningIndex]['minute'] = scheduledMinutes % 60;

    _configuration['reminders'] = reminders;
  }

  Future<void> _pickWakeUpTime() async {
    final currentMinutes = _configurationMinutes(
      'wake_up_minutes',
      420,
      0,
      1439,
    );

    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: currentMinutes ~/ 60,
        minute: currentMinutes % 60,
      ),
      helpText: 'আপনি সাধারণত কয়টায় ঘুম থেকে ওঠেন?',
    );

    if (selected == null || !mounted) {
      return;
    }

    _updateConfiguration(() {
      _configuration['wake_up_minutes'] = selected.hour * 60 + selected.minute;

      _applyMorningSchedule();
    });
  }

  Widget _buildMorningRoutineCard() {
    final wakeUpMinutes = _configurationMinutes(
      'wake_up_minutes',
      420,
      0,
      1439,
    );

    final delayMinutes = _configurationMinutes(
      'morning_delay_minutes',
      20,
      0,
      120,
    );

    final checkInMinutes = (wakeUpMinutes + delayMinutes) % 1440;

    const supportedDelays = <int>[10, 20, 30, 45, 60];

    final selectedDelay = supportedDelays.contains(delayMinutes)
        ? delayMinutes
        : 20;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.wb_sunny_outlined),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Morning Routine',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'আপনি কখন ঘুম থেকে ওঠেন সেটি নির্বাচন করুন। '
              'MindPulse আপনার পছন্দ অনুযায়ী কিছুক্ষণ পরে '
              'gentle Morning Check-in reminder দেবে।',
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickWakeUpTime,
              icon: const Icon(Icons.alarm_outlined),
              label: Text(
                'Wake-up time: '
                '${_formatMinutes(wakeUpMinutes)}',
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<int>(
              key: ValueKey<int>(selectedDelay),
              initialValue: selectedDelay,
              decoration: const InputDecoration(
                labelText: 'Check-in reminder delay',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem<int>(
                  value: 10,
                  child: Text('ঘুম থেকে ওঠার 10 মিনিট পরে'),
                ),
                DropdownMenuItem<int>(
                  value: 20,
                  child: Text('ঘুম থেকে ওঠার 20 মিনিট পরে'),
                ),
                DropdownMenuItem<int>(
                  value: 30,
                  child: Text('ঘুম থেকে ওঠার 30 মিনিট পরে'),
                ),
                DropdownMenuItem<int>(
                  value: 45,
                  child: Text('ঘুম থেকে ওঠার 45 মিনিট পরে'),
                ),
                DropdownMenuItem<int>(
                  value: 60,
                  child: Text('ঘুম থেকে ওঠার 1 ঘণ্টা পরে'),
                ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                _updateConfiguration(() {
                  _configuration['morning_delay_minutes'] = value;

                  _applyMorningSchedule();
                });
              },
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Morning Check-in প্রায় '
                '${_formatMinutes(checkInMinutes)}-এ আসবে।',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'এটি wake-up alarm নয়। Morning Check-in '
              'চালু থাকলে gentle notification এবং '
              'আপনার নির্বাচিত voice বা vibration ব্যবহার হবে।',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHumanCentredCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            const Row(
              children: [
                Icon(Icons.volunteer_activism_outlined),

                SizedBox(width: 12),

                Expanded(
                  child: Text(
                    'Helpful, not annoying',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            const Text(
              'সব reminder defaultভাবে বন্ধ। '
              'আপনি প্রয়োজনীয় reminder, সময়, voice '
              'ও vibration নিজে নির্বাচন করবেন। '
              'পরিবর্তনগুলো স্বয়ংক্রিয়ভাবে save হবে।',
            ),

            const SizedBox(height: 8),

            Text(
              'একটি background check-এ সর্বোচ্চ একটি reminder পাঠানো হবে।',
              style: TextStyle(
                color: Colors.green.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMasterCard() {
    final enabled = _configuration['master_enabled'] == true;

    return Card(
      child: SwitchListTile(
        value: enabled,

        onChanged: (value) {
          _updateConfiguration(() {
            _configuration['master_enabled'] = value;
          });
        },

        secondary: const Icon(Icons.notifications_active_outlined),

        title: const Text(
          'Enable Smart Reminders',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),

        subtitle: const Text(
          'Master switch for all scheduled wellness reminders.',
        ),
      ),
    );
  }

  Widget _buildQuietHoursCard() {
    final start =
        (_configuration['quiet_start_minutes'] as num?)?.toInt() ?? 1320;

    final end = (_configuration['quiet_end_minutes'] as num?)?.toInt() ?? 420;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            const Text(
              'Quiet Hours',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            const Text(
              'এই সময় notification silent থাকবে। '
              'Voice ও vibration বাজবে না।',
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _pickQuietTime(start: true);
                    },

                    icon: const Icon(Icons.nights_stay_outlined),

                    label: Text(
                      'Start: '
                      '${_formatMinutes(start)}',
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _pickQuietTime(start: false);
                    },

                    icon: const Icon(Icons.wb_sunny_outlined),

                    label: Text(
                      'End: '
                      '${_formatMinutes(end)}',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyLimitCard() {
    final value = (_configuration['max_daily_reminders'] as num?)?.toInt() ?? 4;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Text(
              'Maximum reminders per day: $value',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),

            Slider(
              value: value.toDouble(),
              min: 1,
              max: 6,
              divisions: 5,
              label: '$value',

              onChanged: (newValue) {
                _updateConfiguration(() {
                  _configuration['max_daily_reminders'] = newValue.round();
                });
              },
            ),

            const Text('কম reminder সাধারণত বেশি কার্যকর ও কম বিরক্তিকর।'),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildReminderCards() {
    final reminders = _reminders;

    final widgets = <Widget>[];

    for (var index = 0; index < reminders.length; index++) {
      final reminder = reminders[index];

      widgets.add(_buildReminderCard(index, reminder));

      widgets.add(const SizedBox(height: 12));
    }

    return widgets;
  }

  Widget _buildReminderCard(int index, Map<String, dynamic> reminder) {
    final isInterval = reminder['type'] == 'interval';

    final isMorningCheckIn = reminder['id'] == 'morning_checkin';

    final enabled = reminder['enabled'] == true;

    final reminderHour = (reminder['hour'] as num?)?.toInt() ?? 7;

    final reminderMinute = (reminder['minute'] as num?)?.toInt() ?? 0;

    final reminderTimeText = _formatMinutes(reminderHour * 60 + reminderMinute);

    return Card(
      child: ExpansionTile(
        initiallyExpanded: enabled,

        leading: Icon(_iconFor(reminder['icon']?.toString() ?? '')),

        title: Text(
          reminder['title_bn']?.toString() ?? 'Reminder',

          style: const TextStyle(fontWeight: FontWeight.bold),
        ),

        subtitle: Text(enabled ? 'Enabled' : 'Disabled'),

        trailing: Switch(
          value: enabled,

          onChanged: (value) {
            _updateConfiguration(() {
              final reminders = _reminders;

              reminders[index]['enabled'] = value;

              _configuration['reminders'] = reminders;
            });
          },
        ),

        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),

        children: [
          Align(
            alignment: Alignment.centerLeft,

            child: Text(reminder['message_bn']?.toString() ?? ''),
          ),

          const SizedBox(height: 14),

          if (isInterval)
            DropdownButtonFormField<int>(
              initialValue:
                  (reminder['interval_minutes'] as num?)?.toInt() ?? 180,

              decoration: const InputDecoration(
                labelText: 'Reminder interval',
                border: OutlineInputBorder(),
              ),

              items: const [
                DropdownMenuItem<int>(value: 120, child: Text('Every 2 hours')),
                DropdownMenuItem<int>(value: 180, child: Text('Every 3 hours')),
                DropdownMenuItem<int>(value: 240, child: Text('Every 4 hours')),
              ],

              onChanged: (value) {
                if (value == null) {
                  return;
                }

                _updateConfiguration(() {
                  final reminders = _reminders;

                  reminders[index]['interval_minutes'] = value;

                  _configuration['reminders'] = reminders;
                });
              },
            )
          else if (isMorningCheckIn)
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Morning Check-in time',
                helperText: 'Automatically set from Morning Routine',
                border: OutlineInputBorder(),
              ),
              child: Text(
                reminderTimeText,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: () {
                _pickReminderTime(index);
              },

              icon: const Icon(Icons.schedule_outlined),

              label: Text('Time: $reminderTimeText'),
            ),

          const SizedBox(height: 12),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,

            value: reminder['voice'] == true,

            onChanged: (value) {
              _updateConfiguration(() {
                final reminders = _reminders;

                reminders[index]['voice'] = value;

                _configuration['reminders'] = reminders;
              });
            },

            secondary: const Icon(Icons.volume_up_outlined),

            title: const Text('Bangla voice'),

            subtitle: const Text('Quiet Hours ও silent mode-এ voice বাজবে না।'),
          ),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,

            value: reminder['vibration'] == true,

            onChanged: (value) {
              _updateConfiguration(() {
                final reminders = _reminders;

                reminders[index]['vibration'] = value;

                _configuration['reminders'] = reminders;
              });
            },

            secondary: const Icon(Icons.vibration_outlined),

            title: const Text('Vibration'),

            subtitle: const Text('Important reminder হলে ব্যবহার করুন।'),
          ),

          ReminderAdaptiveControls(
            frequencyLevel: (reminder['frequency_level'] as num?)?.toInt() ?? 0,
            pauseUntil: (reminder['pause_until'] as num?)?.toInt() ?? 0,
            helpfulCount: (reminder['helpful_count'] as num?)?.toInt() ?? 0,
            lastFeedback: reminder['last_feedback']?.toString() ?? 'none',
            onHelpful: () {
              _updateConfiguration(() {
                final reminders = _reminders;

                final currentCount =
                    (reminders[index]['helpful_count'] as num?)?.toInt() ?? 0;

                reminders[index]['helpful_count'] = currentCount + 1;

                reminders[index]['last_feedback'] = 'helpful';

                _configuration['reminders'] = reminders;
              });
            },
            onRemindLess: () {
              _updateConfiguration(() {
                final reminders = _reminders;

                final currentLevel =
                    (reminders[index]['frequency_level'] as num?)?.toInt() ?? 0;

                reminders[index]['frequency_level'] = (currentLevel + 1)
                    .clamp(0, 2)
                    .toInt();

                reminders[index]['last_feedback'] = 'remind_less';

                _configuration['reminders'] = reminders;
              });
            },
            onPauseThreeDays: () {
              _updateConfiguration(() {
                final reminders = _reminders;

                reminders[index]['pause_until'] = DateTime.now()
                    .add(const Duration(days: 3))
                    .millisecondsSinceEpoch;

                reminders[index]['last_feedback'] = 'paused_3_days';

                _configuration['reminders'] = reminders;
              });
            },
            onResumeNormal: () {
              _updateConfiguration(() {
                final reminders = _reminders;

                reminders[index]['frequency_level'] = 0;

                reminders[index]['pause_until'] = 0;

                reminders[index]['last_feedback'] = 'normal';

                _configuration['reminders'] = reminders;
              });
            },
          ),

          const SizedBox(height: 8),

          Align(
            alignment: Alignment.centerLeft,

            child: TextButton.icon(
              onPressed: () {
                _testReminder(reminder);
              },

              icon: const Icon(Icons.play_circle_outline),

              label: const Text('Test this reminder'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            const Text(
              'Reminder Engine Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            Text(
              'Status: '
              '${_status['last_status'] ?? 'not_started'}',
            ),

            Text(
              'Today sent: '
              '${_status['daily_count'] ?? 0}',
            ),

            Text(
              'Last check: '
              '${_formatTimestamp(_status['last_check_at'])}',
            ),

            Text(
              'Last reminder: '
              '${_status['last_reminder_title'] ?? 'Not yet'}',
            ),

            Text(
              'Last reminder time: '
              '${_formatTimestamp(_status['last_reminder_at'])}',
            ),
          ],
        ),
      ),
    );
  }
}
