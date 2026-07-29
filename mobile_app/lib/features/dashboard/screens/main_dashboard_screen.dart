import 'package:flutter/material.dart';

import '../../../core/settings/app_preferences_controller.dart';
import '../../safety/screens/emergency_support_screen.dart';

import '../../checkin/screens/daily_checkin_screen.dart';
import '../../wellness/screens/wellness_scan_screen.dart';
import '../../wellness/services/wellness_scan_service.dart';
import '../../journal/screens/journal_screen.dart';
import '../../habit/screens/habit_screen.dart';
import '../../engagement/screens/achievements_screen.dart';
import '../../recovery/screens/recovery_screen.dart';
import '../../reports/screens/weekly_report_screen.dart';

import '../../ai/screens/ai_wellness_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../digital_wellbeing/screens/mindful_screen_time_screen.dart';
import '../../reminders/screens/smart_reminder_center_screen.dart';
import '../../prayer/screens/prayer_settings_screen.dart';
import '../../religion/screens/manual_faith_reminder_screen.dart';
import '../../religion/services/faith_profile_service.dart';
import '../../religion/services/manual_faith_reminder_service.dart';

// MINDPULSE NON ISLAM REMINDER DASHBOARD V3
class MainDashboardScreen extends StatefulWidget {
  const MainDashboardScreen({super.key});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
  final FaithProfileService _faithService = const FaithProfileService();
  int _selectedIndex = 0;
  final GlobalKey<_DashboardHomeTabState> _homeKey =
      GlobalKey<_DashboardHomeTabState>();
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
      _homeKey.currentState?.refreshFaithData();
    }
  }

  String _t(String english, String bangla) {
    return AppPreferencesController.instance.text(english, bangla);
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
        ? Icons.self_improvement_rounded
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
        faithProfile: faith,
        onOpenAiWellness: () {
          if (!mounted) return;
          setState(() => _selectedIndex = 1);
        },
        onOpenFaith: () {
          if (!mounted) return;
          setState(() => _selectedIndex = 2);
        },
      ),
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
        label: Text(_t('Safety', 'নিরাপত্তা')),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectPage,
        height: 72,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: _t('Home', 'হোম'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.auto_awesome_outlined),
            selectedIcon: const Icon(Icons.auto_awesome),
            label: _t('AI Wellness', 'এআই সুস্থতা'),
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
    required this.onOpenAiWellness,
    required this.onOpenFaith,
    required this.faithProfile,
    super.key,
  });

  final VoidCallback onOpenAiWellness;
  final VoidCallback onOpenFaith;
  final FaithProfile faithProfile;

  @override
  State<DashboardHomeTab> createState() => _DashboardHomeTabState();
}

class _DashboardHomeTabState extends State<DashboardHomeTab>
    with WidgetsBindingObserver {
  // MINDPULSE VERIFIED TODAY SCORE V9
  final WellnessScanService _wellnessService = WellnessScanService();
  final ManualFaithReminderService _manualReminderService =
      ManualFaithReminderService();

  double? _wellnessScore;
  String? _riskLevel;
  bool _wellnessLoading = true;
  List<ManualFaithReminder> _manualReminders = <ManualFaithReminder>[];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _loadWellness();
    _loadManualReminders();
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

  Future<void> refreshFaithData() async {
    await Future.wait<void>([_loadWellness(), _loadManualReminders()]);
  }

  Future<void> _loadManualReminders() async {
    if (widget.faithProfile.isIslam) {
      if (mounted) {
        setState(() => _manualReminders = <ManualFaithReminder>[]);
      }
      return;
    }
    try {
      final reminders = await _manualReminderService.load();
      if (!mounted) return;
      setState(() => _manualReminders = reminders);
    } catch (error) {
      debugPrint('MindPulse: manual reminder load failed: $error');
    }
  }

  ManualFaithReminder? get _nextManualReminder {
    final active = _manualReminders.where((item) => item.enabled).toList();
    if (active.isEmpty) return null;
    final now = DateTime.now();
    ManualFaithReminder? selected;
    DateTime? selectedTime;
    for (final reminder in active) {
      for (var offset = 0; offset < 8; offset++) {
        final day = DateTime(
          now.year,
          now.month,
          now.day,
        ).add(Duration(days: offset));
        if (!reminder.weekdays.contains(day.weekday)) continue;
        final candidate = DateTime(
          day.year,
          day.month,
          day.day,
          reminder.hour,
          reminder.minute,
        );
        if (!candidate.isAfter(now)) continue;
        if (selectedTime == null || candidate.isBefore(selectedTime)) {
          selected = reminder;
          selectedTime = candidate;
        }
        break;
      }
    }
    return selected;
  }

  String _t(String english, String bangla) {
    return AppPreferencesController.instance.text(english, bangla);
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
              _buildAiCard(context),
              const SizedBox(height: 24),
              Text(
                _t('Your wellness tools', 'আপনার সুস্থতার টুলস'),
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
    final hasNamedFaith =
        faith.religion != 'no_religion' &&
        faith.religion != 'prefer_not_to_say';
    final faithIcon = faith.isIslam
        ? Icons.mosque_outlined
        : hasNamedFaith
        ? Icons.self_improvement_rounded
        : Icons.notifications_none_rounded;
    final reminder = _nextManualReminder;
    final timeText = reminder == null
        ? null
        : TimeOfDay(
            hour: reminder.hour,
            minute: reminder.minute,
          ).format(context);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: widget.onOpenFaith,
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(faithIcon, color: const Color(0xFF6059E8), size: 30),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t(
                        'Religion: ${faith.religionLabel}',
                        'ধর্ম: ${faith.religionLabel}',
                      ),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (faith.isIslam)
                      Text(
                        _t(
                          'Prayer times and alarm settings are available in the Prayer tab. Alarm sound follows your On/Off choice.',
                          'নামাজের সময় ও অ্যালার্ম সেটিংস প্রার্থনা ট্যাবে দেখা যাবে। আপনার On/Off পছন্দ অনুযায়ী অ্যালার্ম বাজবে।',
                        ),
                        style: const TextStyle(height: 1.4),
                      )
                    else if (reminder != null)
                      Text(
                        hasNamedFaith
                            ? _t(
                                'Next prayer reminder: ${reminder.title} • $timeText',
                                'পরবর্তী প্রার্থনার রিমাইন্ডার: ${reminder.title} • $timeText',
                              )
                            : _t(
                                'Next reminder: ${reminder.title} • $timeText',
                                'পরবর্তী রিমাইন্ডার: ${reminder.title} • $timeText',
                              ),
                        style: const TextStyle(height: 1.4),
                      )
                    else
                      Text(
                        hasNamedFaith
                            ? _t(
                                'No active prayer reminder. Open Prayer to create or enable one.',
                                'কোনো চালু প্রার্থনার রিমাইন্ডার নেই। তৈরি বা চালু করতে প্রার্থনা ট্যাব খুলুন।',
                              )
                            : _t(
                                'No active reminder. Open Reminder to create or enable one.',
                                'কোনো চালু রিমাইন্ডার নেই। তৈরি বা চালু করতে রিমাইন্ডার ট্যাব খুলুন।',
                              ),
                        style: const TextStyle(height: 1.4),
                      ),
                    const SizedBox(height: 10),
                    Text(
                      hasNamedFaith
                          ? _t('Open Prayer', 'প্রার্থনা খুলুন')
                          : _t('Open Reminder', 'রিমাইন্ডার খুলুন'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
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
                _t(
                  'Your personal wellness companion',
                  'আপনার ব্যক্তিগত ওয়েলনেস সহকারী',
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
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
        ? _t('LOADING', 'লোড হচ্ছে')
        : _t('NO DATA', 'তথ্য নেই');

    final description = _wellnessLoading
        ? _t(
            'Checking today’s completed Wellness Scan...',
            'আজকের সুস্থতা যাচাই করা হচ্ছে...',
          )
        : !hasTodayScore
        ? _t(
            'No Wellness Scan has been completed today. Complete a new scan to create today’s score.',
            'আজ কোনো সুস্থতা যাচাই সম্পন্ন হয়নি। আজকের স্কোর তৈরি করতে নতুন একটি যাচাই সম্পন্ন করুন।',
          )
        : _t(
            'Higher values indicate more strain. Source: MindPulse Wellness Scan. Informational only; not a WHO score or medical diagnosis.',
            'বেশি স্কোর মানে বেশি মানসিক চাপের ইঙ্গিত। উৎস: MindPulse Wellness Scan। এটি শুধু তথ্যের জন্য; WHO স্কোর বা চিকিৎসা নির্ণয় নয়।',
          );

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
          Row(
            children: [
              Expanded(
                child: Text(
                  _t('Today’s MindPulse strain', 'আজকের MindPulse চাপ'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Icon(Icons.favorite_rounded, color: Colors.white),
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

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MindPulse AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _t(
                        'Your AI wellness companion is ready.',
                        'আপনার AI ওয়েলনেস সহকারী প্রস্তুত।',
                      ),
                      style: const TextStyle(
                        color: Color(0xFFEDEBFF),
                        height: 1.35,
                      ),
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
    final List<_ToolData> tools = [
      _ToolData(
        icon: Icons.edit_note_rounded,
        title: _t('Journal', 'জার্নাল'),
        subtitle: _t('Reflect safely', 'নিরাপদে অনুভূতি লিখুন'),
      ),
      _ToolData(
        icon: Icons.monitor_heart_outlined,
        title: _t('Wellness Scan', 'ওয়েলনেস স্ক্যান'),
        subtitle: _t('Assess wellbeing', 'সুস্থতা যাচাই করুন'),
      ),
      _ToolData(
        icon: Icons.check_circle_outline_rounded,
        title: _t('Daily Check-in', 'দৈনিক চেক-ইন'),
        subtitle: _t('Track your day', 'আজকের দিন নথিভুক্ত করুন'),
      ),
      _ToolData(
        icon: Icons.bedtime_outlined,
        title: _t('Recovery', 'পুনরুদ্ধার'),
        subtitle: _t('Restore energy', 'শক্তি ফিরিয়ে আনুন'),
      ),
      _ToolData(
        icon: Icons.track_changes_rounded,
        title: _t('Habit Tracker', 'অভ্যাস ট্র্যাকার'),
        subtitle: _t('Build routines', 'নিয়মিত অভ্যাস গড়ুন'),
      ),
      _ToolData(
        icon: Icons.emoji_events_outlined,
        title: _t('Achievements', 'অর্জন'),
        subtitle: _t('View badges', 'ব্যাজ দেখুন'),
      ),
      _ToolData(
        icon: Icons.insights_rounded,
        title: _t('Weekly Report', 'সাপ্তাহিক রিপোর্ট'),
        subtitle: _t('View progress', 'অগ্রগতি দেখুন'),
      ),
      _ToolData(
        icon: Icons.phone_android_rounded,
        title: _t('Mindful Screen Time', 'সচেতন স্ক্রিন টাইম'),
        subtitle: _t('Use phone mindfully', 'সচেতনভাবে ফোন ব্যবহার করুন'),
      ),
      _ToolData(
        icon: Icons.notifications_active_outlined,
        title: _t('Smart Reminders', 'স্মার্ট রিমাইন্ডার'),
        subtitle: _t('Gentle wellness reminders', 'সহজ ওয়েলনেস রিমাইন্ডার'),
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
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(26),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey<String>('wellness-tool-${tool.title}'),
            borderRadius: BorderRadius.circular(26),
            onTap: () async {
              debugPrint('MindPulse: Tool tapped: ${tool.title}');

              if (index == 1) {
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
              if (index == 8) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SmartReminderCenterScreen(),
                  ),
                );

                return;
              }

              if (index == 7) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const MindfulScreenTimeScreen(),
                  ),
                );

                return;
              }

              if (index == 2) {
                debugPrint('MindPulse: Opening DailyCheckinScreen');

                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const DailyCheckinScreen(),
                  ),
                );

                return;
              }

              if (index == 0) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const JournalScreen(),
                  ),
                );

                return;
              }

              if (index == 3) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RecoveryScreen(),
                  ),
                );

                return;
              }
              if (index == 6) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const WeeklyReportScreen(),
                  ),
                );

                return;
              }
              if (index == 4) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const HabitScreen()),
                );

                return;
              }
              if (index == 5) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AchievementsScreen(),
                  ),
                );

                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _t(
                      '${tool.title} module will be connected next.',
                      '${tool.title} মডিউলটি পরবর্তী ধাপে যুক্ত হবে।',
                    ),
                  ),
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
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
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
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
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
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
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
                          color: Theme.of(context).colorScheme.primaryContainer,
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
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
