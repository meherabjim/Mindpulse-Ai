import 'package:flutter/material.dart';

import '../../companion/widgets/companion_dashboard_card.dart';

import '../../safety/screens/emergency_support_screen.dart';

import '../../checkin/screens/daily_checkin_screen.dart';
import '../../wellness/screens/wellness_scan_screen.dart';
import '../../wellness/services/wellness_scan_service.dart';
import '../../journal/screens/journal_screen.dart';
import '../../habit/screens/habit_screen.dart';
import '../../engagement/screens/notifications_screen.dart';
import '../../engagement/screens/achievements_screen.dart';
import '../../engagement/services/engagement_service.dart';
import '../../recovery/screens/recovery_screen.dart';
import '../../reports/screens/weekly_report_screen.dart';

import '../../ai/screens/ai_wellness_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../digital_wellbeing/screens/mindful_screen_time_screen.dart';
import '../../reminders/screens/smart_reminder_center_screen.dart';
import '../../prayer/screens/prayer_settings_screen.dart';
import '../../religion/screens/manual_faith_reminder_screen.dart';
import '../../religion/services/faith_profile_service.dart';

class MainDashboardScreen extends StatefulWidget {
  const MainDashboardScreen({super.key});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
  final FaithProfileService _faithService = const FaithProfileService();
  int _selectedIndex = 0;
  FaithProfile? _faithProfile;
  bool _faithLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFaithProfile();
  }

  Future<void> _loadFaithProfile() async {
    try {
      final profile = await _faithService.load();
      if (!mounted) return;
      setState(() {
        _faithProfile = profile;
        _faithLoading = false;
      });
    } catch (error) {
      debugPrint('MindPulse: faith profile load failed: $error');
      if (!mounted) return;
      setState(() {
        _faithProfile = const FaithProfile(
          religion: 'prefer_not_to_say',
          religionLabel: 'Prefer not to say',
          isIslam: false,
        );
        _faithLoading = false;
      });
    }
  }

  void _selectPage(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    if (_faithLoading || _faithProfile == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF7F7FC),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final faith = _faithProfile!;
    final pages = <Widget>[
      DashboardHomeTab(
        faithProfile: faith,
        onOpenAiWellness: () {
          if (!mounted) return;
          setState(() => _selectedIndex = 1);
        },
      ),
      const AiWellnessScreen(),
      faith.isIslam
          ? const PrayerSettingsScreen()
          : ManualFaithReminderScreen(faithProfile: faith),
      const ProfileScreen(),
    ];
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FC),
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _selectedIndex, children: pages),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'mindpulse_safety_fab',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => const EmergencySupportScreen(),
            ),
          );
        },
        icon: const Icon(Icons.health_and_safety_outlined),
        label: const Text('Safety'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectPage,
        height: 72,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE9E8FF),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'AI Wellness',
          ),
          if (faith.isIslam)
            const NavigationDestination(
              icon: Icon(Icons.mosque_outlined),
              selectedIcon: Icon(Icons.mosque_rounded),
              label: 'Prayer',
            )
          else
            const NavigationDestination(
              icon: Icon(Icons.alarm_outlined),
              selectedIcon: Icon(Icons.alarm_rounded),
              label: 'Reminder',
            ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class DashboardHomeTab extends StatefulWidget {
  const DashboardHomeTab({
    required this.onOpenAiWellness,
    required this.faithProfile,
    super.key,
  });

  final VoidCallback onOpenAiWellness;
  final FaithProfile faithProfile;

  @override
  State<DashboardHomeTab> createState() => _DashboardHomeTabState();
}

class _DashboardHomeTabState extends State<DashboardHomeTab>
    with WidgetsBindingObserver {
  // MINDPULSE VERIFIED TODAY SCORE V9
  final WellnessScanService _wellnessService = WellnessScanService();

  double? _wellnessScore;
  String? _riskLevel;
  bool _wellnessLoading = true;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _loadWellness();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadWellness();
    }
  }

  Future<void> _loadWellness() async {
    if (mounted) {
      setState(() {
        _wellnessLoading = true;
      });
    }

    try {
      final scan = await _wellnessService.getLatestScan();

      final dynamic timestampValue;

      if (scan == null) {
        timestampValue = null;
      } else {
        timestampValue =
            scan['completed_at'] ?? scan['created_at'] ?? scan['updated_at'];
      }

      final timestampText = timestampValue == null
          ? ''
          : timestampValue.toString();

      final parsedTimestamp = DateTime.tryParse(timestampText);

      final localTimestamp = parsedTimestamp?.toLocal();

      final isToday =
          localTimestamp != null &&
          DateUtils.isSameDay(localTimestamp, DateTime.now());

      dynamic rawScore;
      String? riskLevel;

      if (isToday && scan != null) {
        rawScore = scan['total_score'];
        riskLevel = scan['risk_level']?.toString();
      }

      final score = rawScore is num
          ? rawScore.toDouble()
          : double.tryParse(rawScore?.toString() ?? '');

      if (!mounted) {
        return;
      }

      setState(() {
        _wellnessScore = score?.clamp(0.0, 100.0).toDouble();

        _riskLevel = riskLevel;
        _wellnessLoading = false;
      });
    } catch (error) {
      debugPrint(
        'MindPulse: Dashboard wellness '
        'refresh failed: $error',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _wellnessScore = null;
        _riskLevel = null;
        _wellnessLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildHeader(context),
              const SizedBox(height: 24),
              _buildWellnessOverview(context),
              const SizedBox(height: 20),
              if (widget.faithProfile.religion != 'no_religion' &&
                  widget.faithProfile.religion != 'prefer_not_to_say') ...[
                _buildFaithCard(context),
                const SizedBox(height: 20),
              ],
              // HUMAN_COMPANION_DASHBOARD_ENTRY_V1
              const CompanionDashboardCard(),
              const SizedBox(height: 20),
              _buildAiCard(context),
              const SizedBox(height: 24),
              Text(
                'Your wellness tools',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              _buildToolsGrid(context),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildFaithCard(BuildContext context) {
    final faith = widget.faithProfile;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              faith.isIslam ? Icons.mosque_outlined : Icons.alarm_outlined,
              color: const Color(0xFF6059E8),
              size: 30,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Religion: ${faith.religionLabel}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    faith.isIslam
                        ? 'Prayer times and alarm settings are available in the Prayer tab. Alarm sound follows your On/Off choice.'
                        : 'Only reminders you create manually are available. Muslim prayer content is hidden.',
                    style: const TextStyle(height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF665DF5), Color(0xFF8A65F7)],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            Icons.psychology_alt_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),

        const SizedBox(width: 14),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MindPulse AI',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Your personal wellness companion',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF74748A),
                ),
              ),
            ],
          ),
        ),

        const _NotificationBell(),
      ],
    );
  }

  Widget _buildWellnessOverview(BuildContext context) {
    final hasTodayScore = _wellnessScore != null;

    final score = (_wellnessScore ?? 0.0).clamp(0.0, 100.0).toDouble();

    final storedRisk = _riskLevel?.trim() ?? '';

    final riskLabel = storedRisk.isNotEmpty
        ? storedRisk.toUpperCase()
        : _wellnessLoading
        ? 'LOADING'
        : 'NO DATA';

    final description = _wellnessLoading
        ? 'Checking today’s completed Wellness Scan...'
        : !hasTodayScore
        ? 'No Wellness Scan has been completed today. '
              'Complete a new scan to create today’s score.'
        : 'Higher values indicate more strain. '
              'Source: MindPulse Wellness Scan. '
              'Informational only; not a WHO score '
              'or medical diagnosis.';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5C58E8), Color(0xFF875EF0)],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Today’s MindPulse strain',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(Icons.favorite_rounded, color: Colors.white),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 12,
            runSpacing: 12,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    hasTodayScore ? score.toStringAsFixed(1) : '--',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 5),
                    child: Text(
                      '/ 100',
                      style: TextStyle(
                        color: Color(0xFFDCD9FF),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              _RiskBadge(label: riskLabel),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: hasTodayScore ? score / 100 : 0,
              minHeight: 10,
              backgroundColor: const Color(0x44FFFFFF),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 13),
          Text(
            description,
            style: const TextStyle(color: Color(0xFFEDEBFF), height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _buildAiCard(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        onTap: widget.onOpenAiWellness,
        borderRadius: BorderRadius.circular(26),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(
              colors: [Color(0xFF6059E8), Color(0xFF8B7CFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x336059E8),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),

              const SizedBox(width: 16),

              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MindPulse AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Your AI wellness companion is ready.',
                      style: TextStyle(color: Color(0xFFEDEBFF), height: 1.35),
                    ),
                  ],
                ),
              ),

              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolsGrid(BuildContext context) {
    const List<_ToolData> tools = [
      _ToolData(
        icon: Icons.edit_note_rounded,
        title: 'Journal',
        subtitle: 'Reflect safely',
      ),
      _ToolData(
        icon: Icons.monitor_heart_outlined,
        title: 'Wellness Scan',
        subtitle: 'Assess wellbeing',
      ),
      _ToolData(
        icon: Icons.check_circle_outline_rounded,
        title: 'Daily Check-in',
        subtitle: 'Track your day',
      ),
      _ToolData(
        icon: Icons.bedtime_outlined,
        title: 'Recovery',
        subtitle: 'Restore energy',
      ),
      _ToolData(
        icon: Icons.track_changes_rounded,
        title: 'Habit Tracker',
        subtitle: 'Build routines',
      ),
      _ToolData(
        icon: Icons.emoji_events_outlined,
        title: 'Achievements',
        subtitle: 'View badges',
      ),
      _ToolData(
        icon: Icons.insights_rounded,
        title: 'Weekly Report',
        subtitle: 'View progress',
      ),
      _ToolData(
        icon: Icons.phone_android_rounded,
        title: 'Mindful Screen Time',
        subtitle: 'Use phone mindfully',
      ),
      _ToolData(
        icon: Icons.notifications_active_outlined,
        title: 'Smart Reminders',
        subtitle: 'Gentle wellness reminders',
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tools.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        mainAxisExtent: 190,
      ),
      itemBuilder: (context, index) {
        final tool = tools[index];

        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey<String>('wellness-tool-${tool.title}'),
            borderRadius: BorderRadius.circular(26),
            onTap: () async {
              debugPrint('MindPulse: Tool tapped: ${tool.title}');

              if (tool.title == 'Wellness Scan') {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const WellnessScanScreen(),
                  ),
                );

                if (mounted) {
                  await _loadWellness();
                }

                return;
              }
              if (tool.title == 'Smart Reminders') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SmartReminderCenterScreen(),
                  ),
                );

                return;
              }

              if (tool.title == 'Mindful Screen Time') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const MindfulScreenTimeScreen(),
                  ),
                );

                return;
              }

              if (tool.title == 'Daily Check-in') {
                debugPrint('MindPulse: Opening DailyCheckinScreen');

                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const DailyCheckinScreen(),
                  ),
                );

                return;
              }

              if (tool.title == 'Journal') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const JournalScreen(),
                  ),
                );

                return;
              }

              if (tool.title == 'Recovery') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RecoveryScreen(),
                  ),
                );

                return;
              }
              if (tool.title == 'Weekly Report') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const WeeklyReportScreen(),
                  ),
                );

                return;
              }
              if (tool.title == 'Habit Tracker') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const HabitScreen()),
                );

                return;
              }
              if (tool.title == 'Achievements') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AchievementsScreen(),
                  ),
                );

                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${tool.title} module will be connected next.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Container(
              width: double.infinity,
              height: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: const Color(0xFFE5E4EE)),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact =
                      constraints.maxWidth < 132 || constraints.maxHeight < 145;

                  if (compact) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0EFFF),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            tool.icon,
                            color: const Color(0xFF6059E8),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tool.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tool.subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF85859A),
                                  fontSize: 12,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0EFFF),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          tool.icon,
                          color: const Color(0xFF6059E8),
                          size: 28,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        tool.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        tool.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF85859A),
                          fontSize: 12.5,
                          height: 1.2,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NotificationBell extends StatefulWidget {
  const _NotificationBell();

  @override
  State<_NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<_NotificationBell> {
  final EngagementService _service = EngagementService();

  int _unreadCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await _service.getUnreadCount();

      if (!mounted) return;

      setState(() {
        _unreadCount = count;
        _loading = false;
      });
    } catch (error) {
      debugPrint('MindPulse: Unread notification count failed: $error');

      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
    );

    if (mounted) {
      await _loadUnreadCount();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton.filledTonal(
          onPressed: _openNotifications,
          icon: const Icon(Icons.notifications_none_rounded),
          tooltip: 'Notifications',
        ),
        if (!_loading && _unreadCount > 0)
          Positioned(
            right: -3,
            top: -3,
            child: Container(
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white, width: 2),
              ),
              alignment: Alignment.center,
              child: Text(
                _unreadCount > 99 ? '99+' : '$_unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RiskBadge extends StatelessWidget {
  const _RiskBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0x33FFFFFF),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0x55FFFFFF)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ToolData {
  const _ToolData({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}
