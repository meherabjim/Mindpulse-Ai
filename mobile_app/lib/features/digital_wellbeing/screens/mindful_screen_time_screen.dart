import 'package:flutter/material.dart';

import 'screen_time_insights_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/screen_time_service.dart';
import '../widgets/bangla_voice_reminder_card.dart';
import '../widgets/background_reminder_card.dart';

class MindfulScreenTimeScreen extends StatefulWidget {
  const MindfulScreenTimeScreen({super.key});

  @override
  State<MindfulScreenTimeScreen> createState() =>
      _MindfulScreenTimeScreenState();
}

class _MindfulScreenTimeScreenState extends State<MindfulScreenTimeScreen>
    with WidgetsBindingObserver {
  static const Set<String> _socialPackages = {
    'com.facebook.katana',
    'com.facebook.orca',
    'com.instagram.android',
    'com.zhiliaoapp.musically',
    'com.ss.android.ugc.trill',
    'com.google.android.youtube',
    'com.twitter.android',
    'com.snapchat.android',
    'com.reddit.frontpage',
    'org.telegram.messenger',
    'com.whatsapp',
  };

  final ScreenTimeService _service = ScreenTimeService();

  bool _loading = true;
  bool _hasPermission = false;

  String? _errorMessage;

  List<AppUsageEntry> _usage = const <AppUsageEntry>[];

  int _dailySocialLimitMinutes = 90;
  int _sessionLimitMinutes = 45;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _initialize() async {
    final preferences = await SharedPreferences.getInstance();

    _dailySocialLimitMinutes =
        preferences.getInt('mindpulse_daily_social_limit') ?? 90;

    _sessionLimitMinutes = preferences.getInt('mindpulse_session_limit') ?? 45;

    await _refresh();
  }

  Future<void> _refresh() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final permission = await _service.hasUsageAccess();

      List<AppUsageEntry> usage = const <AppUsageEntry>[];

      if (permission) {
        usage = await _service.getTodayUsage();
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _hasPermission = permission;
        _usage = usage;
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

  Future<void> _openPermissionSettings() async {
    try {
      await _service.openUsageAccessSettings();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _saveLimits() async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.setInt(
      'mindpulse_daily_social_limit',
      _dailySocialLimitMinutes,
    );

    await preferences.setInt('mindpulse_session_limit', _sessionLimitMinutes);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Screen-time limits saved.')));
  }

  List<AppUsageEntry> get _socialUsage {
    return _usage.where((entry) {
      return _socialPackages.contains(entry.packageName);
    }).toList();
  }

  int get _totalUsageMs {
    return _usage.fold<int>(0, (total, entry) => total + entry.totalTimeMs);
  }

  int get _socialUsageMs {
    return _socialUsage.fold<int>(
      0,
      (total, entry) => total + entry.totalTimeMs,
    );
  }

  AppUsageEntry? get _longestSessionApp {
    if (_usage.isEmpty) {
      return null;
    }

    final entries = List<AppUsageEntry>.from(_usage);

    entries.sort(
      (first, second) =>
          second.longestSessionMs.compareTo(first.longestSessionMs),
    );

    return entries.first;
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);

    final hours = duration.inHours;

    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }

    if (minutes > 0) {
      return '${minutes}m';
    }

    return '<1m';
  }

  String get _adviceMessage {
    final socialMinutes = Duration(milliseconds: _socialUsageMs).inMinutes;

    final longestMinutes = Duration(
      milliseconds: _longestSessionApp?.longestSessionMs ?? 0,
    ).inMinutes;

    if (socialMinutes >= _dailySocialLimitMinutes) {
      return 'You have reached today’s social-media limit. '
          'Put the phone aside and take a 10-minute recovery break.';
    }

    if (longestMinutes >= _sessionLimitMinutes) {
      return 'You have used ${_longestSessionApp?.appName ?? 'an app'} '
          'continuously for about $longestMinutes minutes. '
          'Give your eyes and mind a short rest.';
    }

    if (_totalUsageMs == 0) {
      return 'No meaningful app usage has been recorded yet today.';
    }

    return 'Your current usage is within the limits you selected. '
        'Continue taking regular breaks.';
  }

  bool get _needsBreak {
    final socialMinutes = Duration(milliseconds: _socialUsageMs).inMinutes;

    final longestMinutes = Duration(
      milliseconds: _longestSessionApp?.longestSessionMs ?? 0,
    ).inMinutes;

    return socialMinutes >= _dailySocialLimitMinutes ||
        longestMinutes >= _sessionLimitMinutes;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),

      appBar: AppBar(
        title: const Text('Mindful Screen Time'),

        actions: [
          IconButton(
            tooltip: 'Phone-use insights',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ScreenTimeInsightsScreen(),
                ),
              );
            },
            icon: const Icon(Icons.insights_outlined),
          ),

          IconButton(
            onPressed: _loading ? null : _refresh,

            tooltip: 'Refresh usage',

            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,

              child: ListView(
                padding: const EdgeInsets.all(16),

                children: [
                  if (_errorMessage != null) _buildErrorCard(),

                  if (!_hasPermission)
                    _buildPermissionCard()
                  else ...[
                    _buildOverviewCard(),

                    const SizedBox(height: 14),

                    _buildAdviceCard(),

                    const SizedBox(height: 14),

                    _buildLimitCard(),

                    const SizedBox(height: 14),

                    _buildTopAppsCard(),

                    const SizedBox(height: 14),

                    BackgroundReminderCard(
                      key: ValueKey<String>(
                        '$_dailySocialLimitMinutes-'
                        '$_sessionLimitMinutes',
                      ),
                      dailySocialLimitMinutes: _dailySocialLimitMinutes,
                      sessionLimitMinutes: _sessionLimitMinutes,
                    ),

                    const SizedBox(height: 14),

                    const BanglaVoiceReminderCard(),

                    const SizedBox(height: 14),

                    _buildPrivacyCard(),

                    const SizedBox(height: 14),

                    _buildManageAccessCard(),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildPermissionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            const Row(
              children: [
                Icon(Icons.phone_android_rounded, size: 30),

                SizedBox(width: 12),

                Expanded(
                  child: Text(
                    'Enable Usage Access',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            const Text(
              'MindPulse needs Usage Access to calculate '
              'how long selected apps stay in the foreground.',
            ),

            const SizedBox(height: 10),

            const Text(
              'It does not read messages, passwords, '
              'keyboard input, photos, or screen content.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),

            const SizedBox(height: 18),

            FilledButton.icon(
              onPressed: _openPermissionSettings,

              icon: const Icon(Icons.settings_outlined),

              label: const Text('Open Usage Access Settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard() {
    final longest = _longestSessionApp;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            const Text(
              'Today’s digital wellbeing',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _summaryItem(
                    icon: Icons.phone_android_rounded,
                    label: 'Total usage',
                    value: _formatDuration(_totalUsageMs),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: _summaryItem(
                    icon: Icons.groups_outlined,
                    label: 'Social apps',
                    value: _formatDuration(_socialUsageMs),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            _summaryItem(
              icon: Icons.hourglass_bottom_rounded,

              label: 'Longest session',

              value: longest == null
                  ? 'No data'
                  : '${longest.appName} · '
                        '${_formatDuration(longest.longestSessionMs)}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.45),

        borderRadius: BorderRadius.circular(16),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Icon(icon),

          const SizedBox(height: 9),

          Text(label, style: const TextStyle(fontSize: 12)),

          const SizedBox(height: 4),

          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildAdviceCard() {
    return Card(
      color: _needsBreak ? Colors.orange.shade50 : Colors.green.shade50,

      child: ListTile(
        contentPadding: const EdgeInsets.all(16),

        leading: Icon(
          _needsBreak
              ? Icons.self_improvement_rounded
              : Icons.verified_outlined,

          color: _needsBreak ? Colors.orange.shade800 : Colors.green.shade700,
        ),

        title: Text(
          _needsBreak ? 'Time for a break' : 'Usage looks manageable',

          style: const TextStyle(fontWeight: FontWeight.bold),
        ),

        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),

          child: Text(_adviceMessage),
        ),
      ),
    );
  }

  Widget _buildLimitCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            const Text(
              'Your usage limits',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 18),

            Text(
              'Daily social-media limit: '
              '$_dailySocialLimitMinutes minutes',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),

            Slider(
              value: _dailySocialLimitMinutes.toDouble(),

              min: 30,
              max: 240,
              divisions: 7,

              label: '$_dailySocialLimitMinutes min',

              onChanged: (value) {
                setState(() {
                  _dailySocialLimitMinutes = value.round();
                });
              },
            ),

            const SizedBox(height: 8),

            Text(
              'Continuous-session limit: '
              '$_sessionLimitMinutes minutes',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),

            Slider(
              value: _sessionLimitMinutes.toDouble(),

              min: 15,
              max: 90,
              divisions: 5,

              label: '$_sessionLimitMinutes min',

              onChanged: (value) {
                setState(() {
                  _sessionLimitMinutes = value.round();
                });
              },
            ),

            const SizedBox(height: 8),

            OutlinedButton.icon(
              onPressed: _saveLimits,

              icon: const Icon(Icons.save_outlined),

              label: const Text('Save limits'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopAppsCard() {
    final visibleEntries = _usage.take(10).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            const Text(
              'Most-used apps today',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            if (visibleEntries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),

                child: Text('No app-usage information is available yet.'),
              )
            else
              ...visibleEntries.map((entry) {
                final isSocial = _socialPackages.contains(entry.packageName);

                return ListTile(
                  contentPadding: EdgeInsets.zero,

                  leading: CircleAvatar(
                    child: Icon(
                      isSocial ? Icons.groups_outlined : Icons.apps_rounded,
                    ),
                  ),

                  title: Text(entry.appName),

                  subtitle: Text(
                    '${entry.sessionCount} sessions · '
                    'Longest ${_formatDuration(entry.longestSessionMs)}',
                  ),

                  trailing: Text(
                    _formatDuration(entry.totalTimeMs),

                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildManageAccessCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            const Row(
              children: [
                Icon(Icons.admin_panel_settings_outlined),

                SizedBox(width: 12),

                Expanded(
                  child: Text(
                    'Manage Usage Access',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            const Text(
              'To stop screen-time monitoring, open Android '
              'Usage Access settings, select MindPulse AI, '
              'and turn off Allow usage access.',
            ),

            const SizedBox(height: 16),

            OutlinedButton.icon(
              onPressed: _openPermissionSettings,

              icon: const Icon(Icons.settings_outlined),

              label: const Text('Manage / Turn Off Usage Access'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyCard() {
    return const Card(
      child: ListTile(
        contentPadding: EdgeInsets.all(16),

        leading: Icon(Icons.privacy_tip_outlined),

        title: Text(
          'Privacy-first Phase 1',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),

        subtitle: Padding(
          padding: EdgeInsets.only(top: 8),

          child: Text(
            'Usage calculations currently stay on this device. '
            'No screen content, messages, passwords, or typing data are collected.',
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      color: Colors.red.shade50,

      child: ListTile(
        leading: Icon(Icons.error_outline, color: Colors.red.shade700),

        title: const Text('Screen-time data could not be loaded'),

        subtitle: Text(_errorMessage ?? 'Unknown error'),
      ),
    );
  }
}
