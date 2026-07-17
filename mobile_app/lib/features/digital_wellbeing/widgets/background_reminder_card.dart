import 'package:flutter/material.dart';

import '../services/screen_time_service.dart';

class BackgroundReminderCard extends StatefulWidget {
  const BackgroundReminderCard({
    required this.dailySocialLimitMinutes,
    required this.sessionLimitMinutes,
    super.key,
  });

  final int dailySocialLimitMinutes;
  final int sessionLimitMinutes;

  @override
  State<BackgroundReminderCard> createState() => _BackgroundReminderCardState();
}

class _BackgroundReminderCardState extends State<BackgroundReminderCard> {
  final ScreenTimeService _service = ScreenTimeService();

  bool _loading = true;
  bool _enabled = false;
  bool _notificationPermission = false;

  String _lastStatus = 'not_started';

  int _lastCheckAt = 0;
  int _lastReminderAt = 0;
  int _lastSocialMinutes = 0;
  int _lastLongestMinutes = 0;

  String? _lastLongestApp;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final status = await _service.getBackgroundReminderStatus();

      if (!mounted) {
        return;
      }

      setState(() {
        _enabled = status['enabled'] == true;

        _notificationPermission = status['notification_permission'] == true;

        _lastStatus = status['last_status']?.toString() ?? 'not_started';

        _lastCheckAt = (status['last_check_at'] as num?)?.toInt() ?? 0;

        _lastReminderAt = (status['last_reminder_at'] as num?)?.toInt() ?? 0;

        _lastSocialMinutes =
            (status['last_social_minutes'] as num?)?.toInt() ?? 0;

        _lastLongestMinutes =
            (status['last_longest_minutes'] as num?)?.toInt() ?? 0;

        _lastLongestApp = status['last_longest_app']?.toString();

        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();

        _loading = false;
      });
    }
  }

  Future<bool> _ensureNotificationPermission() async {
    var permission = await _service.hasNotificationPermission();

    if (!permission) {
      permission = await _service.requestNotificationPermission();
    }

    if (!mounted) {
      return permission;
    }

    setState(() {
      _notificationPermission = permission;
    });

    return permission;
  }

  Future<void> _enable() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final notificationAllowed = await _ensureNotificationPermission();

      if (!notificationAllowed) {
        throw Exception(
          'Notification permission is required for background reminders.',
        );
      }

      await _service.enableBackgroundReminders(
        dailyLimitMinutes: widget.dailySocialLimitMinutes,

        sessionLimitMinutes: widget.sessionLimitMinutes,
      );

      await Future<void>.delayed(const Duration(seconds: 2));

      await _loadStatus();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Background reminders enabled.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();

        _loading = false;
      });
    }
  }

  Future<void> _disable() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      await _service.disableBackgroundReminders();

      await _loadStatus();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Background reminders disabled.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();

        _loading = false;
      });
    }
  }

  Future<void> _sendTest() async {
    try {
      final allowed = await _ensureNotificationPermission();

      if (!allowed) {
        throw Exception('Notification permission was not granted.');
      }

      final sent = await _service.sendTestScreenTimeReminder();

      if (!sent) {
        throw Exception('Test reminder could not be displayed.');
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Test reminder sent.')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _runNow() async {
    try {
      await _service.runBackgroundCheckNow();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Background usage check queued.')),
      );

      await Future<void>.delayed(const Duration(seconds: 4));

      await _loadStatus();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
      });
    }
  }

  String _formatTime(int milliseconds) {
    if (milliseconds <= 0) {
      return 'Not yet';
    }

    final dateTime = DateTime.fromMillisecondsSinceEpoch(milliseconds);

    final hour = dateTime.hour.toString().padLeft(2, '0');

    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '${dateTime.day}/'
        '${dateTime.month}/'
        '${dateTime.year} '
        '$hour:$minute';
  }

  String get _statusLabel {
    switch (_lastStatus) {
      case 'within_limits':
        return 'Usage is within limits';

      case 'reminder_sent':
        return 'Break reminder sent';

      case 'cooldown':
        return 'Reminder cooldown active';

      case 'usage_access_missing':
        return 'Usage Access is disabled';

      case 'notification_permission_missing':
        return 'Notification permission missing';

      case 'disabled':
        return 'Background reminders disabled';

      default:
        return 'Waiting for first check';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Row(
              children: [
                const Icon(Icons.notifications_active_outlined),

                const SizedBox(width: 12),

                const Expanded(
                  child: Text(
                    'Background Break Reminders',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),

                if (_loading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Switch(
                    value: _enabled,
                    onChanged: (value) {
                      if (value) {
                        _enable();
                      } else {
                        _disable();
                      }
                    },
                  ),
              ],
            ),

            const SizedBox(height: 10),

            const Text(
              'MindPulse checks usage periodically and sends '
              'a gentle reminder when your selected limit is reached.',
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

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    _statusLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Last check: '
                    '${_formatTime(_lastCheckAt)}',
                  ),

                  Text(
                    'Last reminder: '
                    '${_formatTime(_lastReminderAt)}',
                  ),

                  Text(
                    'Last social usage: '
                    '$_lastSocialMinutes minutes',
                  ),

                  Text(
                    'Longest session: '
                    '${_lastLongestApp ?? 'No app'} · '
                    '$_lastLongestMinutes minutes',
                  ),
                ],
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 12),

              Text(
                _errorMessage!,
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],

            const SizedBox(height: 14),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _loading ? null : _sendTest,

                  icon: const Icon(Icons.notifications_none_rounded),

                  label: const Text('Send Test Reminder'),
                ),

                OutlinedButton.icon(
                  onPressed: _loading ? null : _runNow,

                  icon: const Icon(Icons.play_arrow_rounded),

                  label: const Text('Run Check Now'),
                ),

                if (!_notificationPermission)
                  TextButton.icon(
                    onPressed: _service.openNotificationSettings,

                    icon: const Icon(Icons.settings_outlined),

                    label: const Text('Notification Settings'),
                  ),
              ],
            ),

            const SizedBox(height: 8),

            const Text(
              'Periodic checks run approximately every 15 minutes. '
              'Android may delay them to protect battery life.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}
