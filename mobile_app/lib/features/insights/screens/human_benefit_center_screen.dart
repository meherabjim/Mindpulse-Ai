import 'package:flutter/material.dart';

import '../../companion/screens/companion_permissions_screen.dart';

import '../../digital_wellbeing/services/screen_time_insight_service.dart';
import '../../recommendations/services/recommendation_session_service.dart';

class HumanBenefitCenterScreen extends StatefulWidget {
  const HumanBenefitCenterScreen({super.key});

  @override
  State<HumanBenefitCenterScreen> createState() =>
      _HumanBenefitCenterScreenState();
}

class _HumanBenefitCenterScreenState extends State<HumanBenefitCenterScreen>
    with WidgetsBindingObserver {
  final ScreenTimeInsightService _screenTimeService =
      ScreenTimeInsightService();

  final RecommendationSessionService _recommendationService =
      RecommendationSessionService();

  bool _loading = true;
  bool _hasUsageAccess = false;

  int _days = 7;

  String? _screenTimeError;
  String? _followUpError;

  Map<String, dynamic> _screenTime = <String, dynamic>{};
  Map<String, dynamic> _followUpSummary = <String, dynamic>{};

  List<Map<String, dynamic>> _sessions = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
    }
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _screenTimeError = null;
        _followUpError = null;
      });
    }

    var hasUsageAccess = false;
    var screenTime = <String, dynamic>{};
    String? screenTimeError;

    try {
      hasUsageAccess = await _screenTimeService.hasUsageAccess();

      if (hasUsageAccess) {
        screenTime = await _screenTimeService.getInsights();
      }
    } catch (error) {
      screenTimeError = error.toString();
    }

    var summary = <String, dynamic>{};
    var sessions = <Map<String, dynamic>>[];
    String? followUpError;

    try {
      final responses = await Future.wait<Map<String, dynamic>>(
        <Future<Map<String, dynamic>>>[
          _recommendationService.getSummary(days: _days),
          _recommendationService.getHistory(page: 1, limit: 100),
        ],
      );

      summary = responses[0];

      final rawSessions = responses[1]['sessions'];

      final allSessions = rawSessions is List
          ? rawSessions.whereType<Map>().map(Map<String, dynamic>.from).toList()
          : <Map<String, dynamic>>[];

      sessions = allSessions.where(_isWithinSelectedPeriod).toList();
    } catch (error) {
      followUpError = error.toString();
    }

    if (!mounted) return;

    setState(() {
      _hasUsageAccess = hasUsageAccess;
      _screenTime = screenTime;
      _screenTimeError = screenTimeError;

      _followUpSummary = summary;
      _sessions = sessions;
      _followUpError = followUpError;

      _loading = false;
    });
  }

  bool _isWithinSelectedPeriod(Map<String, dynamic> session) {
    final raw = session['started_at']?.toString();

    if (raw == null || raw.isEmpty) {
      return false;
    }

    final parsed = DateTime.tryParse(raw);

    if (parsed == null) {
      return false;
    }

    final cutoff = DateTime.now().subtract(Duration(days: _days));

    return parsed.toLocal().isAfter(cutoff);
  }

  Future<void> _openUsageAccessSettings() async {
    try {
      await _screenTimeService.openUsageAccessSettings();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _screenTimeError = error.toString();
      });
    }
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }

  int _integer(dynamic value) {
    return (value as num?)?.toInt() ??
        int.tryParse(value?.toString() ?? '') ??
        0;
  }

  String _minutes(int value) {
    final safe = value < 0 ? 0 : value;

    final hours = safe ~/ 60;
    final minutes = safe % 60;

    if (hours == 0) {
      return '$minutes min';
    }

    if (minutes == 0) {
      return '$hours h';
    }

    return '$hours h $minutes min';
  }

  String _seconds(int value) {
    final safe = value < 0 ? 0 : value;

    final hours = safe ~/ 3600;
    final minutes = (safe % 3600) ~/ 60;

    if (hours > 0) {
      return '$hours h $minutes min';
    }

    if (minutes > 0) {
      return '$minutes min';
    }

    return '$safe sec';
  }

  List<Map<String, dynamic>> get _completedSessions {
    return _sessions.where((session) {
      return session['status']?.toString() == 'completed';
    }).toList();
  }

  int get _moodImprovedCount {
    return _completedSessions.where((session) {
      final before = _integer(session['before_mood']);
      final after = _integer(session['after_mood']);

      return before > 0 && after > before;
    }).length;
  }

  int get _stressLowerCount {
    return _completedSessions.where((session) {
      final before = _integer(session['before_stress']);
      final after = _integer(session['after_stress']);

      return before > 0 && after > 0 && after < before;
    }).length;
  }

  int get _ratedSessionCount {
    return _completedSessions.where((session) {
      return session['feedback_type'] != null;
    }).length;
  }

  Widget _metricCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colors.primary),
            const Spacer(),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorCard({required String title, required String message}) {
    return Card(
      color: Colors.red.shade50,
      child: ListTile(
        leading: Icon(Icons.error_outline, color: Colors.red.shade700),
        title: Text(title),
        subtitle: Text(message),
      ),
    );
  }

  Widget _phoneUseSection() {
    if (_screenTimeError != null) {
      return _errorCard(
        title: 'Phone-use data could not be loaded',
        message: _screenTimeError!,
      );
    }

    if (!_hasUsageAccess) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Phone-use pattern',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'Usage Access is optional. Enable it to see local '
                'aggregate phone-use patterns. MindPulse does not '
                'read messages, typing, passwords, notification '
                'content or screen content.',
                style: TextStyle(height: 1.4),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _openUsageAccessSettings,
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Manage Usage Access'),
              ),
            ],
          ),
        ),
      );
    }

    final today = _map(_screenTime['today']);

    final total = _integer(today['total_minutes']);
    final average = _integer(_screenTime['seven_day_average_minutes']);
    final longest = _integer(today['longest_session_minutes']);
    final lateNight = _integer(today['late_night_minutes']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Phone-use pattern',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        const Text('Local aggregate observations from this device.'),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.25,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _metricCard(
              icon: Icons.smartphone_outlined,
              value: _minutes(total),
              label: 'Use today',
            ),
            _metricCard(
              icon: Icons.insights_outlined,
              value: _minutes(average),
              label: '7-day average',
            ),
            _metricCard(
              icon: Icons.timelapse_outlined,
              value: _minutes(longest),
              label: 'Longest session',
            ),
            _metricCard(
              icon: Icons.bedtime_outlined,
              value: _minutes(lateNight),
              label: 'Late-night use',
            ),
          ],
        ),
      ],
    );
  }

  Widget _followUpSection() {
    if (_followUpError != null) {
      return _errorCard(
        title: 'Follow-up summary could not be loaded',
        message: _followUpError!,
      );
    }

    final total = _integer(_followUpSummary['total_sessions']);
    final completed = _integer(_followUpSummary['completed_sessions']);
    final helpful = _integer(_followUpSummary['helpful_sessions']);
    final notUseful = _integer(_followUpSummary['not_useful_sessions']);
    final duration = _integer(_followUpSummary['total_duration_seconds']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$_days-day wellness follow-up',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        const Text(
          'Recorded activity and voluntary feedback from your account.',
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.25,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _metricCard(
              icon: Icons.check_circle_outline,
              value: '$completed / $total',
              label: 'Completed actions',
            ),
            _metricCard(
              icon: Icons.timer_outlined,
              value: _seconds(duration),
              label: 'Recorded action time',
            ),
            _metricCard(
              icon: Icons.thumb_up_alt_outlined,
              value: '$helpful',
              label: 'Marked helpful',
            ),
            _metricCard(
              icon: Icons.thumb_down_alt_outlined,
              value: '$notUseful',
              label: 'Marked not useful',
            ),
          ],
        ),
      ],
    );
  }

  Widget _observationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Self-reported after-action observations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.mood_outlined),
              title: Text('Mood rated higher: $_moodImprovedCount'),
              subtitle: const Text(
                'Count of completed actions where the optional '
                'after-rating was higher than the before-rating.',
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.air_outlined),
              title: Text('Stress rated lower: $_stressLowerCount'),
              subtitle: const Text(
                'Count of completed actions where the optional '
                'after-rating was lower than the before-rating.',
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.rate_review_outlined),
              title: Text(
                'Sessions with usefulness feedback: $_ratedSessionCount',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'These are personal observations, not proof that an '
              'activity caused a change. They are not a diagnosis '
              'or a clinical effectiveness score.',
              style: TextStyle(
                fontSize: 12.5,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // HUMAN_COMPANION_PERMISSIONS_METHODS_V1
  Future<void> _openCompanionPermissions() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const CompanionPermissionsScreen(),
      ),
    );

    if (mounted) {
      await _load();
    }
  }

  Widget _companionPermissionsCard() {
    return Card(
      color: const Color(0xFFEDEBFF),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.tune_rounded, color: Color(0xFF5750D8)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Companion permissions',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Choose which signals MindPulse may use '
              'for supportive daily context. Phone use, '
              'movement, check-in, recovery, AI wording '
              'and reminders can be controlled separately.',
              style: TextStyle(height: 1.4),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _openCompanionPermissions,
              icon: const Icon(Icons.manage_accounts_outlined),
              label: const Text('Manage companion permissions'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _privacySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.privacy_tip_outlined),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Data and privacy',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.phone_android_outlined),
              title: Text('Phone-use aggregates stay on this device'),
              subtitle: Text(
                'The Human Benefit Center does not upload a raw app list.',
              ),
            ),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.cloud_outlined),
              title: Text('Follow-up records are stored in your account'),
              subtitle: Text(
                'This includes selected action, recorded timer duration '
                'and optional before/after feedback.',
              ),
            ),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.visibility_off_outlined),
              title: Text('Sensitive screen content is not collected'),
              subtitle: Text(
                'MindPulse does not read messages, passwords, typing, '
                'notification content or what is displayed on screen.',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _openUsageAccessSettings,
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Manage Usage Access'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FC),
      appBar: AppBar(
        title: const Text('Human Benefit & Privacy'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                children: [
                  SegmentedButton<int>(
                    segments: const <ButtonSegment<int>>[
                      ButtonSegment<int>(value: 7, label: Text('7 days')),
                      ButtonSegment<int>(value: 30, label: Text('30 days')),
                    ],
                    selected: <int>{_days},
                    onSelectionChanged: (selection) {
                      final selectedDays = selection.first;

                      if (selectedDays == _days) {
                        return;
                      }

                      setState(() {
                        _days = selectedDays;
                      });

                      _load();
                    },
                  ),
                  const SizedBox(height: 18),
                  _phoneUseSection(),
                  const SizedBox(height: 24),
                  _followUpSection(),
                  const SizedBox(height: 16),
                  _observationSection(),
                  const SizedBox(height: 16),
                  // HUMAN_COMPANION_PERMISSIONS_ENTRY_V1
                  _companionPermissionsCard(),
                  const SizedBox(height: 16),
                  _privacySection(),
                ],
              ),
            ),
    );
  }
}
