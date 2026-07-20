import 'package:flutter/material.dart';

import '../services/engagement_service.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final EngagementService _service = EngagementService();

  Map<String, dynamic>? _summary;
  Map<String, dynamic> _metrics = <String, dynamic>{};

  bool _loading = true;
  bool _syncing = false;
  bool _earnedOnly = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAchievements(sync: true);
  }

  Future<void> _loadAchievements({bool sync = false}) async {
    setState(() {
      if (sync) {
        _syncing = true;
      } else {
        _loading = true;
      }

      _errorMessage = null;
    });

    try {
      final result = sync
          ? await _service.syncAchievements()
          : await _service.getAchievements();

      final newlyEarned = _asList(result['newly_earned']).map(_asMap).toList();

      if (!mounted) return;

      setState(() {
        _summary = result;
        _metrics = _asMap(result['metrics']);
        _loading = false;
        _syncing = false;
      });

      if (newlyEarned.isNotEmpty) {
        await _showNewAchievements(newlyEarned);
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
        _loading = false;
        _syncing = false;
      });
    }
  }

  Future<void> _showNewAchievements(List<Map<String, dynamic>> badges) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.emoji_events_rounded,
            color: Colors.amber,
            size: 48,
          ),
          title: const Text('Achievement Unlocked!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: badges.map((badge) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFF4D8),
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    color: Colors.amber,
                  ),
                ),
                title: Text(
                  badge['name']?.toString() ?? 'Achievement',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '+${_integerValue(badge['points_reward'])} points',
                ),
              );
            }).toList(),
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Great!'),
            ),
          ],
        );
      },
    );
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

  List<dynamic> _asList(dynamic value) {
    return value is List ? value : <dynamic>[];
  }

  int _integerValue(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _doubleValue(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  IconData _badgeIcon(Map<String, dynamic> badge) {
    final category = badge['category']?.toString().toLowerCase() ?? '';

    final criteria = badge['criteria_type']?.toString().toLowerCase() ?? '';

    if (category.contains('journal') || criteria.contains('journal')) {
      return Icons.menu_book_rounded;
    }

    if (category.contains('habit') || criteria.contains('habit')) {
      return Icons.task_alt_rounded;
    }

    if (category.contains('sleep') || criteria.contains('sleep')) {
      return Icons.bedtime_rounded;
    }

    if (category.contains('hydration') || criteria.contains('hydration')) {
      return Icons.water_drop_rounded;
    }

    if (category.contains('recovery') || criteria.contains('recovery')) {
      return Icons.spa_rounded;
    }

    if (category.contains('checkin') || criteria.contains('checkin')) {
      return Icons.favorite_rounded;
    }

    return Icons.workspace_premium_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FC),
      appBar: AppBar(
        title: const Text('Achievements'),
        actions: [
          IconButton(
            onPressed: _syncing
                ? null
                : () {
                    _loadAchievements(sync: true);
                  },
            tooltip: 'Sync achievements',
            icon: _syncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadAchievements(sync: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                children: [
                  if (_errorMessage != null) _buildErrorBanner(),
                  if (_summary != null) _buildContent(),
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

  Widget _buildContent() {
    final summary = _summary!;

    final level = _asMap(summary['level']);

    final nextLevel = _asMap(summary['next_level']);

    final totalPoints = _integerValue(summary['total_points']);

    final earnedBadges = _integerValue(summary['earned_badges']);

    final totalBadges = _integerValue(summary['total_badges']);

    final allBadges = _asList(summary['badges']).map(_asMap).toList();

    final visibleBadges = _earnedOnly
        ? allBadges.where((badge) {
            return badge['is_completed'] == true;
          }).toList()
        : allBadges;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLevelCard(
          level: level,
          nextLevel: nextLevel,
          totalPoints: totalPoints,
          earnedBadges: earnedBadges,
          totalBadges: totalBadges,
        ),
        if (_metrics.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildMetricsCard(),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Achievement Badges',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
              ),
            ),
            FilterChip(
              selected: _earnedOnly,
              label: const Text('Earned only'),
              onSelected: (value) {
                setState(() {
                  _earnedOnly = value;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (visibleBadges.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              child: Column(
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 60,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No earned badges yet.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          )
        else
          ...visibleBadges.map(_buildBadgeCard),
      ],
    );
  }

  Widget _buildLevelCard({
    required Map<String, dynamic> level,
    required Map<String, dynamic> nextLevel,
    required int totalPoints,
    required int earnedBadges,
    required int totalBadges,
  }) {
    final currentMinimum = _integerValue(level['minimum_points']);

    final nextMinimum = _integerValue(nextLevel['minimum_points']);

    double levelProgress = 1;

    if (nextMinimum > currentMinimum) {
      levelProgress =
          ((totalPoints - currentMinimum) / (nextMinimum - currentMinimum))
              .clamp(0.0, 1.0)
              .toDouble();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5C58E8), Color(0xFF875EF0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x335C58E8),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: const Color(0x33FFFFFF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      level['name']?.toString() ?? 'MindPulse Beginner',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$totalPoints total points',
                      style: const TextStyle(
                        color: Color(0xFFEDEBFF),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '$earnedBadges of $totalBadges badges earned',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 9),
          LinearProgressIndicator(
            value: totalBadges == 0 ? 0 : earnedBadges / totalBadges,
            minHeight: 9,
            backgroundColor: const Color(0x44FFFFFF),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            borderRadius: BorderRadius.circular(10),
          ),
          if (nextLevel.isNotEmpty) ...[
            const SizedBox(height: 17),
            Text(
              '${nextLevel['points_needed'] ?? 0} points needed for ${nextLevel['name'] ?? 'next level'}',
              style: const TextStyle(color: Color(0xFFEDEBFF)),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: levelProgress,
              minHeight: 7,
              backgroundColor: const Color(0x44FFFFFF),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFFFD66B),
              ),
              borderRadius: BorderRadius.circular(10),
            ),
          ] else ...[
            const SizedBox(height: 15),
            const Text(
              'You have reached the highest available level.',
              style: TextStyle(color: Color(0xFFEDEBFF)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricsCard() {
    final metricEntries = <MapEntry<String, dynamic>>[
      MapEntry('Check-ins', _metrics['total_checkins']),
      MapEntry('Check-in streak', _metrics['checkin_streak']),
      MapEntry('Habit completions', _metrics['habit_completion_count']),
      MapEntry('Journal streak', _metrics['journal_streak']),
      MapEntry('Recovery score', _metrics['recovery_score']),
      MapEntry('Wellness scans', _metrics['wellness_scan_count']),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Activity Metrics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: metricEntries.map((entry) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0EFFF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '${entry.key}: ${entry.value ?? 0}',
                    style: const TextStyle(
                      color: Color(0xFF6059E8),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeCard(Map<String, dynamic> badge) {
    final completed = badge['is_completed'] == true;

    final progress = _doubleValue(
      badge['progress_percent'],
    ).clamp(0.0, 100.0).toDouble();

    final currentValue = _doubleValue(badge['current_value']);

    final targetValue = _doubleValue(badge['target_value']);

    final points = _integerValue(badge['points_reward']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: completed
                        ? const Color(0xFFFFF4D8)
                        : const Color(0xFFF0F0F5),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    _badgeIcon(badge),
                    color: completed ? Colors.amber.shade700 : Colors.grey,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              badge['name']?.toString() ?? 'Achievement',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (completed)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Colors.green,
                            )
                          else
                            const Icon(
                              Icons.lock_outline_rounded,
                              color: Colors.grey,
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        badge['description']?.toString() ?? '',
                        style: const TextStyle(
                          color: Color(0xFF74748A),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 6,
              children: [
                Text(
                  '${currentValue.toStringAsFixed(currentValue % 1 == 0 ? 0 : 1)} / '
                  '${targetValue.toStringAsFixed(targetValue % 1 == 0 ? 0 : 1)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '+$points points',
                  style: const TextStyle(
                    color: Color(0xFF6059E8),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress / 100,
              minHeight: 8,
              borderRadius: BorderRadius.circular(10),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${progress.toStringAsFixed(0)}%',
                style: const TextStyle(color: Color(0xFF74748A)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
