import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/settings/app_preferences_controller.dart';
import '../../ai/screens/ai_wellness_screen.dart';
import '../../checkin/screens/daily_checkin_screen.dart';
import '../../habit/screens/habit_screen.dart';
import '../../journal/screens/journal_screen.dart';
import '../../planner/screens/my_day_screen.dart';
import '../../prayer/screens/prayer_settings_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../recovery/screens/recovery_screen.dart';
import '../../religion/screens/manual_faith_reminder_screen.dart';
import '../../religion/services/faith_profile_service.dart';
import '../../reports/screens/weekly_report_screen.dart';
import '../../safety/screens/emergency_support_screen.dart';
import '../../wellness/screens/wellness_scan_screen.dart';
import '../../wellness/services/wellness_scan_service.dart';

class MainDashboardScreen extends StatefulWidget {
  const MainDashboardScreen({super.key});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
  final FaithProfileService _faithService = const FaithProfileService();
  final GlobalKey<_DashboardHomeTabState> _homeKey =
      GlobalKey<_DashboardHomeTabState>();

  int _selectedIndex = 0;
  FaithProfile? _faithProfile;
  bool _faithLoading = true;

  String _t(String english, String bangla) {
    return AppPreferencesController.instance.text(english, bangla);
  }

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
        _faithProfile = FaithProfile(
          religion: 'prefer_not_to_say',
          religionLabel: _t('Prefer not to say', 'বলতে চাই না'),
          isIslam: false,
        );
        _faithLoading = false;
      });
    }
  }

  void _selectPage(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
    if (index == 0) {
      _homeKey.currentState?.refreshHomeData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_faithLoading || _faithProfile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final faith = _faithProfile!;
    final hasNamedFaith =
        faith.religion != 'no_religion' &&
        faith.religion != 'prefer_not_to_say';
    final faithIcon = faith.isIslam
        ? Icons.mosque_outlined
        : hasNamedFaith
        ? Icons.self_improvement_outlined
        : Icons.notifications_none_rounded;
    final selectedFaithIcon = faith.isIslam
        ? Icons.mosque_rounded
        : hasNamedFaith
        ? Icons.self_improvement_rounded
        : Icons.notifications_rounded;
    final faithLabel = hasNamedFaith
        ? _t('Prayer', 'প্রার্থনা')
        : _t('Reminder', 'রিমাইন্ডার');

    final pages = <Widget>[
      DashboardHomeTab(
        key: _homeKey,
        onOpenMyDay: () {
          if (!mounted) return;
          setState(() => _selectedIndex = 1);
        },
        onOpenAiWellness: () {
          if (!mounted) return;
          setState(() => _selectedIndex = 2);
        },
      ),
      const MyDayScreen(),
      const AiWellnessScreen(),
      faith.isIslam
          ? const PrayerSettingsScreen()
          : ManualFaithReminderScreen(faithProfile: faith),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _selectedIndex, children: pages),
      ),
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'mindpulse_safety_fab',
        tooltip: _t('Safety support', 'নিরাপত্তা সহায়তা'),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const EmergencySupportScreen(),
            ),
          );
        },
        child: const Icon(Icons.health_and_safety_outlined),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectPage,
        height: 74,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: _t('Home', 'হোম'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.route_outlined),
            selectedIcon: const Icon(Icons.route_rounded),
            label: _t('My Day', 'আমার দিন'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.auto_awesome_outlined),
            selectedIcon: const Icon(Icons.auto_awesome_rounded),
            label: _t('AI Wellness', 'AI সুস্থতা'),
          ),
          NavigationDestination(
            icon: Icon(faithIcon),
            selectedIcon: Icon(selectedFaithIcon),
            label: faithLabel,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: const Icon(Icons.person_rounded),
            label: _t('Profile', 'প্রোফাইল'),
          ),
        ],
      ),
    );
  }
}

class DashboardHomeTab extends StatefulWidget {
  const DashboardHomeTab({
    required this.onOpenMyDay,
    required this.onOpenAiWellness,
    super.key,
  });

  final VoidCallback onOpenMyDay;
  final VoidCallback onOpenAiWellness;

  @override
  State<DashboardHomeTab> createState() => _DashboardHomeTabState();
}

class _DashboardHomeTabState extends State<DashboardHomeTab>
    with WidgetsBindingObserver {
  static const _scheduleKey = 'mindpulse_my_day_schedule_v1';
  static const _bookGuideKey = 'mindpulse_ai_guide_items_v2';

  final WellnessScanService _wellnessService = WellnessScanService();

  double? _wellnessScore;
  String? _riskLevel;
  bool _wellnessLoading = true;

  int _taskCount = 0;
  int _completedTaskCount = 0;
  int _bookCount = 0;
  String? _nextTaskTitle;
  int? _nextTaskMinutes;

  String _t(String english, String bangla) {
    return AppPreferencesController.instance.text(english, bangla);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refreshHomeData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refreshHomeData();
    }
  }

  Future<void> refreshHomeData() async {
    await Future.wait(<Future<void>>[_loadWellness(), _loadPlannerSummary()]);
  }

  Future<void> _loadPlannerSummary() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final scheduleRaw = preferences.getString(_scheduleKey);
      final bookRaw = preferences.getString(_bookGuideKey);

      var taskCount = 0;
      var completedCount = 0;
      var bookCount = 0;
      String? nextTitle;
      int? nextMinutes;

      if (scheduleRaw != null && scheduleRaw.trim().isNotEmpty) {
        final decoded = jsonDecode(scheduleRaw);
        if (decoded is List) {
          final tasks = decoded.whereType<Map>().toList();
          taskCount = tasks.length;
          completedCount = tasks
              .where((item) => item['completed'] == true)
              .length;

          final now = TimeOfDay.now();
          final nowMinutes = now.hour * 60 + now.minute;
          final upcoming =
              tasks
                  .where((item) => item['completed'] != true)
                  .map((item) => Map<String, dynamic>.from(item))
                  .where(
                    (item) =>
                        ((item['minutes_of_day'] as num?)?.toInt() ?? 0) >=
                        nowMinutes,
                  )
                  .toList()
                ..sort(
                  (a, b) => ((a['minutes_of_day'] as num?)?.toInt() ?? 0)
                      .compareTo((b['minutes_of_day'] as num?)?.toInt() ?? 0),
                );

          if (upcoming.isNotEmpty) {
            nextTitle = upcoming.first['title']?.toString();
            nextMinutes = (upcoming.first['minutes_of_day'] as num?)?.toInt();
          }
        }
      }

      if (bookRaw != null && bookRaw.trim().isNotEmpty) {
        final decoded = jsonDecode(bookRaw);
        if (decoded is List) bookCount = decoded.length;
      }

      if (!mounted) return;
      setState(() {
        _taskCount = taskCount;
        _completedTaskCount = completedCount;
        _bookCount = bookCount;
        _nextTaskTitle = nextTitle;
        _nextTaskMinutes = nextMinutes;
      });
    } catch (error) {
      debugPrint('MindPulse: planner summary load failed: $error');
    }
  }

  Future<void> _loadWellness() async {
    if (mounted) {
      setState(() => _wellnessLoading = true);
    }

    try {
      final scan = await _wellnessService.getLatestScan();
      final timestampValue = scan == null
          ? null
          : scan['completed_at'] ?? scan['created_at'] ?? scan['updated_at'];
      final timestamp = DateTime.tryParse(timestampValue?.toString() ?? '');
      final localTimestamp = timestamp?.toLocal();
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

      if (!mounted) return;
      setState(() {
        _wellnessScore = score?.clamp(0.0, 100.0).toDouble();
        _riskLevel = riskLevel;
        _wellnessLoading = false;
      });
    } catch (error) {
      debugPrint('MindPulse: dashboard wellness refresh failed: $error');
      if (!mounted) return;
      setState(() {
        _wellnessScore = null;
        _riskLevel = null;
        _wellnessLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: refreshHomeData,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildHeader(context),
                const SizedBox(height: 18),
                _buildMyDayHero(context),
                const SizedBox(height: 16),
                _buildSummaryCards(context),
                const SizedBox(height: 18),
                _buildWellnessCard(context),
                const SizedBox(height: 18),
                _buildAiInsight(context),
                const SizedBox(height: 24),
                Text(
                  _t('Essential tools', 'প্রয়োজনীয় টুলস'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 13),
                _buildToolsGrid(context),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? _t('Good morning', 'সুপ্রভাত')
        : hour < 17
        ? _t('Good afternoon', 'শুভ অপরাহ্ন')
        : _t('Good evening', 'শুভ সন্ধ্যা');

    return Row(
      children: [
        Container(
          width: 55,
          height: 55,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF514BDD), Color(0xFF8B60F4)],
            ),
            borderRadius: BorderRadius.circular(19),
            boxShadow: const [
              BoxShadow(
                color: Color(0x28514BDD),
                blurRadius: 15,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.psychology_alt_rounded,
            color: Colors.white,
            size: 31,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _t(
                  'Let MindPulse organise the next right step.',
                  'MindPulse-কে পরবর্তী সঠিক কাজটি সাজাতে দিন।',
                ),
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMyDayHero(BuildContext context) {
    final progress = _taskCount == 0 ? 0.0 : _completedTaskCount / _taskCount;
    final nextTime = _nextTaskMinutes == null
        ? null
        : _formatTime(_nextTaskMinutes!);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: widget.onOpenMyDay,
        child: Ink(
          padding: const EdgeInsets.all(23),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4D47D8), Color(0xFF8B5AF3)],
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(
                color: Color(0x354D47D8),
                blurRadius: 28,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: const Icon(
                      Icons.route_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _t('My Day', 'আমার দিন'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          _t(
                            'Schedule • AI guide • Time analysis',
                            'সময়সূচি • AI গাইড • সময় বিশ্লেষণ',
                          ),
                          style: const TextStyle(color: Color(0xFFEDE9FF)),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                _nextTaskTitle == null
                    ? _t(
                        'Create your first realistic daily route',
                        'আপনার প্রথম বাস্তবসম্মত দৈনিক পথ তৈরি করুন',
                      )
                    : _t('Next activity', 'পরবর্তী কাজ'),
                style: const TextStyle(
                  color: Color(0xFFDCD6FF),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _nextTaskTitle ?? _t('Open My Day', 'আমার দিন খুলুন'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (nextTime != null) ...[
                const SizedBox(height: 4),
                Text(
                  _t('Starts at $nextTime', 'শুরু হবে $nextTime'),
                  style: const TextStyle(color: Color(0xFFF1EEFF)),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 9,
                        color: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _taskCount == 0 ? '0%' : '${(progress * 100).round()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: width,
              child: _HomeSummaryCard(
                icon: Icons.calendar_month_rounded,
                iconColor: const Color(0xFF5B55E8),
                title: _t('Schedule', 'সময়সূচি'),
                value: _taskCount == 0
                    ? _t('Not created', 'তৈরি হয়নি')
                    : _t(
                        '$_completedTaskCount / $_taskCount complete',
                        '$_taskCountটির মধ্যে $_completedTaskCountটি',
                      ),
                onTap: widget.onOpenMyDay,
              ),
            ),
            SizedBox(
              width: width,
              child: _HomeSummaryCard(
                icon: Icons.menu_book_rounded,
                iconColor: const Color(0xFF0D9E91),
                title: _t('AI guide', 'AI গাইড'),
                value: _bookCount == 0
                    ? _t('Create reading guide', 'পাঠ গাইড তৈরি করুন')
                    : _t(
                        '$_bookCount reading items selected',
                        '$_bookCountটি পাঠ্য নির্বাচিত',
                      ),
                onTap: widget.onOpenMyDay,
              ),
            ),
            SizedBox(
              width: constraints.maxWidth,
              child: _HomeSummaryCard(
                icon: Icons.hourglass_bottom_rounded,
                iconColor: const Color(0xFFE46B75),
                title: _t('Where did time go?', 'সময় কোথায় গেল?'),
                value: _t(
                  'Review planned time and phone-use patterns',
                  'পরিকল্পিত সময় ও ফোন ব্যবহারের ধরন দেখুন',
                ),
                onTap: widget.onOpenMyDay,
                horizontal: true,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWellnessCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasScore = _wellnessScore != null;
    final score = (_wellnessScore ?? 0).clamp(0.0, 100.0).toDouble();
    final risk = (_riskLevel ?? '').trim();

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(27),
      child: InkWell(
        borderRadius: BorderRadius.circular(27),
        onTap: () async {
          await Navigator.of(context).push<void>(
            MaterialPageRoute<void>(builder: (_) => const WellnessScanScreen()),
          );
          await _loadWellness();
        },
        child: Container(
          padding: const EdgeInsets.all(19),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(27),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCF8F1),
                  borderRadius: BorderRadius.circular(19),
                ),
                child: const Icon(
                  Icons.monitor_heart_rounded,
                  color: Color(0xFF0B8F82),
                  size: 30,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('Today’s MindPulse strain', 'আজকের MindPulse চাপ'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _wellnessLoading
                          ? _t(
                              'Checking today’s scan...',
                              'আজকের scan দেখা হচ্ছে...',
                            )
                          : hasScore
                          ? _t(
                              '${score.toStringAsFixed(1)} / 100 • ${risk.isEmpty ? 'Available' : risk.toUpperCase()}',
                              '${score.toStringAsFixed(1)} / ১০০ • ${risk.isEmpty ? 'তথ্য পাওয়া গেছে' : risk.toUpperCase()}',
                            )
                          : _t(
                              'No completed scan today',
                              'আজ কোনো scan সম্পন্ন হয়নি',
                            ),
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiInsight(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(27),
      child: InkWell(
        borderRadius: BorderRadius.circular(27),
        onTap: widget.onOpenAiWellness,
        child: Ink(
          padding: const EdgeInsets.all(19),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF15172A), Color(0xFF2C3152)],
            ),
            borderRadius: BorderRadius.circular(27),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(19),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFFB8A9FF),
                  size: 29,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('MindPulse insight', 'MindPulse পরামর্শ'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _t(
                        'Use your approved signals to review today’s wellness guidance.',
                        'অনুমোদিত signal দিয়ে আজকের wellness নির্দেশনা দেখুন।',
                      ),
                      style: const TextStyle(
                        color: Color(0xFFD7D9EB),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolsGrid(BuildContext context) {
    final tools = <_ToolData>[
      _ToolData(
        icon: Icons.edit_note_rounded,
        title: _t('Journal', 'জার্নাল'),
        subtitle: _t('Write safely', 'নিরাপদে লিখুন'),
        color: const Color(0xFF6A5CE7),
        builder: (_) => const JournalScreen(),
      ),
      _ToolData(
        icon: Icons.monitor_heart_outlined,
        title: _t('Wellness Scan', 'ওয়েলনেস স্ক্যান'),
        subtitle: _t('Check wellbeing', 'সুস্থতা যাচাই'),
        color: const Color(0xFF0D9E91),
        builder: (_) => const WellnessScanScreen(),
      ),
      _ToolData(
        icon: Icons.check_circle_outline_rounded,
        title: _t('Daily Check-in', 'দৈনিক চেক-ইন'),
        subtitle: _t('Record today', 'আজকের দিন লিখুন'),
        color: const Color(0xFF4B80E8),
        builder: (_) => const DailyCheckinScreen(),
      ),
      _ToolData(
        icon: Icons.bedtime_outlined,
        title: _t('Recovery', 'পুনরুদ্ধার'),
        subtitle: _t('Restore energy', 'শক্তি ফিরে পান'),
        color: const Color(0xFF6B72D9),
        builder: (_) => const RecoveryScreen(),
      ),
      _ToolData(
        icon: Icons.track_changes_rounded,
        title: _t('Habits', 'অভ্যাস'),
        subtitle: _t('Build routines', 'রুটিন গড়ুন'),
        color: const Color(0xFFE38A45),
        builder: (_) => const HabitScreen(),
      ),
      _ToolData(
        icon: Icons.insights_rounded,
        title: _t('Weekly Report', 'সাপ্তাহিক রিপোর্ট'),
        subtitle: _t('Review progress', 'অগ্রগতি দেখুন'),
        color: const Color(0xFFE15B86),
        builder: (_) => const WeeklyReportScreen(),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tools.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 136,
      ),
      itemBuilder: (context, index) {
        final tool = tools[index];
        return Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () async {
              await Navigator.of(
                context,
              ).push<void>(MaterialPageRoute<void>(builder: tool.builder));
              if (index == 1) await _loadWellness();
            },
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 43,
                    height: 43,
                    decoration: BoxDecoration(
                      color: tool.color.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(tool.icon, color: tool.color),
                  ),
                  const Spacer(),
                  Text(
                    tool.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    tool.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HomeSummaryCard extends StatelessWidget {
  const _HomeSummaryCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.onTap,
    this.horizontal = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final VoidCallback onTap;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(23),
      child: InkWell(
        borderRadius: BorderRadius.circular(23),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(23),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: horizontal
              ? Row(
                  children: [
                    _iconBox(),
                    const SizedBox(width: 13),
                    Expanded(child: _textBlock(context)),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _iconBox(),
                    const SizedBox(height: 12),
                    _textBlock(context),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _iconBox() {
    return Container(
      width: 43,
      height: 43,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: iconColor),
    );
  }

  Widget _textBlock(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: horizontal ? 2 : 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: 12,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

class _ToolData {
  const _ToolData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.builder,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final WidgetBuilder builder;
}

String _formatTime(int minutesOfDay) {
  final hour = (minutesOfDay ~/ 60).clamp(0, 23).toInt();
  final minute = (minutesOfDay % 60).clamp(0, 59).toInt();
  final period = hour >= 12 ? 'PM' : 'AM';
  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
}
