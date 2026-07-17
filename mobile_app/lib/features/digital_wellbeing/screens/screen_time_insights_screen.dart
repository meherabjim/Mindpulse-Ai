import 'package:flutter/material.dart';

import '../../insights/screens/human_benefit_center_screen.dart';

import '../services/screen_time_insight_service.dart';

class ScreenTimeInsightsScreen extends StatefulWidget {
  const ScreenTimeInsightsScreen({super.key});

  @override
  State<ScreenTimeInsightsScreen> createState() =>
      _ScreenTimeInsightsScreenState();
}

class _ScreenTimeInsightsScreenState extends State<ScreenTimeInsightsScreen>
    with WidgetsBindingObserver {
  final ScreenTimeInsightService _service = ScreenTimeInsightService();

  bool _loading = true;
  bool _hasUsageAccess = false;
  String? _error;

  Map<String, dynamic> _insights = <String, dynamic>{};

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
        _error = null;
      });
    }

    try {
      final hasAccess = await _service.hasUsageAccess();

      if (!hasAccess) {
        if (!mounted) return;

        setState(() {
          _hasUsageAccess = false;
          _insights = <String, dynamic>{};
          _loading = false;
        });

        return;
      }

      final insights = await _service.getInsights();

      if (!mounted) return;

      setState(() {
        _hasUsageAccess = insights['has_usage_access'] == true;
        _insights = insights;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _openUsageSettings() async {
    try {
      await _service.openUsageAccessSettings();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enable Usage Access for MindPulse, '
            'then return to this screen.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
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

  List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) {
      return <Map<String, dynamic>>[];
    }

    return value.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  int _integer(dynamic value) {
    return (value as num?)?.toInt() ??
        int.tryParse(value?.toString() ?? '') ??
        0;
  }

  String _duration(int minutes) {
    final safeMinutes = minutes < 0 ? 0 : minutes;
    final hours = safeMinutes ~/ 60;
    final remainingMinutes = safeMinutes % 60;

    if (hours == 0) {
      return '$remainingMinutes min';
    }

    if (remainingMinutes == 0) {
      return '$hours h';
    }

    return '$hours h $remainingMinutes min';
  }

  String _comparison(int difference) {
    if (difference == 0) {
      return 'About the same as your 7-day average';
    }

    final amount = _duration(difference.abs());

    if (difference > 0) {
      return '$amount above your 7-day average';
    }

    return '$amount below your 7-day average';
  }

  String _friendlyDate(String value) {
    final parsed = DateTime.tryParse(value);

    if (parsed == null) {
      return value;
    }

    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${parsed.day} ${months[parsed.month - 1]}';
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

  Widget _permissionContent() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 40),
      children: [
        const Icon(Icons.phone_android_outlined, size: 70),
        const SizedBox(height: 18),
        const Text(
          'See your phone-use pattern',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        const Text(
          'Android Usage Access lets MindPulse calculate '
          'daily use, approximate sessions, longest session, '
          'morning use and late-night use.',
          textAlign: TextAlign.center,
          style: TextStyle(height: 1.45),
        ),
        const SizedBox(height: 16),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'MindPulse does not read messages, passwords, '
              'typing, notification content or screen content. '
              'Only aggregate statistics are shown, and no raw '
              'app list is sent to the backend.',
              style: TextStyle(height: 1.4),
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _openUsageSettings,
          icon: const Icon(Icons.settings_outlined),
          label: const Text('Open Usage Access settings'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _load,
          child: const Text('Refresh permission status'),
        ),
      ],
    );
  }

  Widget _errorContent() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 52),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Phone-use insights could not be loaded.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            FilledButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }

  Widget _insightContent() {
    final today = _map(_insights['today']);
    final history = _mapList(_insights['history']);

    final total = _integer(today['total_minutes']);
    final sessionCount = _integer(today['session_count']);
    final longest = _integer(today['longest_session_minutes']);
    final morning = _integer(today['morning_minutes']);
    final lateNight = _integer(today['late_night_minutes']);
    final mindPulse = _integer(today['mindpulse_minutes']);
    final average = _integer(_insights['seven_day_average_minutes']);
    final difference = _integer(_insights['difference_from_average_minutes']);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          const Text(
            'Today',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(_comparison(difference)),
          const SizedBox(height: 14),
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
                value: _duration(total),
                label: 'Total phone use',
              ),
              _metricCard(
                icon: Icons.touch_app_outlined,
                value: '$sessionCount',
                label: 'Approximate sessions',
              ),
              _metricCard(
                icon: Icons.timelapse_outlined,
                value: _duration(longest),
                label: 'Longest session',
              ),
              _metricCard(
                icon: Icons.insights_outlined,
                value: _duration(average),
                label: '7-day average',
              ),
              _metricCard(
                icon: Icons.wb_sunny_outlined,
                value: _duration(morning),
                label: 'Morning use (6–10)',
              ),
              _metricCard(
                icon: Icons.bedtime_outlined,
                value: _duration(lateNight),
                label: 'Late-night use (22–6)',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              leading: const Icon(Icons.favorite_outline),
              title: const Text('MindPulse use today'),
              trailing: Text(
                _duration(mindPulse),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Previous 7 days',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          if (history.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text('No recent phone-use history is available.'),
              ),
            )
          else
            ...history.map((day) {
              final date = day['date']?.toString() ?? '';
              final minutes = _integer(day['total_minutes']);
              final sessions = _integer(day['session_count']);

              return Card(
                margin: const EdgeInsets.only(bottom: 9),
                child: ListTile(
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: Text(_friendlyDate(date)),
                  subtitle: Text('$sessions approximate session(s)'),
                  trailing: Text(
                    _duration(minutes),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              );
            }),
          const SizedBox(height: 16),
          Card(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'These statistics are approximate personal '
                'patterns, not a diagnosis. They do not prove '
                'that phone use caused a change in mood, stress, '
                'sleep or health.',
                style: TextStyle(height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;

    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = _errorContent();
    } else if (!_hasUsageAccess) {
      body = _permissionContent();
    } else {
      body = _insightContent();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FC),
      appBar: AppBar(
        title: const Text('Phone-use Insights'),
        actions: [
          IconButton(
            tooltip: 'Human benefit summary',

            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const HumanBenefitCenterScreen(),
                ),
              );
            },

            icon: const Icon(Icons.favorite_border_rounded),
          ),

          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: body,
    );
  }
}
