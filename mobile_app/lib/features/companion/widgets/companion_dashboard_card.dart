// HUMAN_COMPANION_PROFILE_CARD_V2

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/settings/app_preferences_controller.dart';
import '../models/daily_companion_context.dart';
import '../screens/companion_permissions_screen.dart';
import '../services/companion_data_adapter_service.dart';
import '../services/companion_feedback_service.dart';

class CompanionDashboardCard extends StatefulWidget {
  const CompanionDashboardCard({super.key});

  @override
  State<CompanionDashboardCard> createState() => _CompanionDashboardCardState();
}

class _CompanionDashboardCardState extends State<CompanionDashboardCard>
    with WidgetsBindingObserver {
  final CompanionDataAdapterService _adapter = CompanionDataAdapterService();
  final CompanionFeedbackService _feedback = CompanionFeedbackService();

  DailyCompanionContext? _context;

  bool _loading = true;
  bool _savingFeedback = false;
  bool _feedbackRecorded = false;

  String? _error;

  String _t(String english, String bangla) {
    return AppPreferencesController.instance.text(english, bangla);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
        _feedbackRecorded = false;
      });
    }

    try {
      final dailyContext = await _adapter.loadContext();

      if (!mounted) return;

      setState(() {
        _context = dailyContext;
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

  Future<void> _openPermissions() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const CompanionPermissionsScreen(),
      ),
    );

    if (!mounted) return;

    await _load();
  }

  Future<void> _recordFeedback(bool helpful) async {
    final suggestion = _context?.suggestion;

    if (suggestion == null || suggestion.id == 'none' || _savingFeedback) {
      return;
    }

    setState(() {
      _savingFeedback = true;
    });

    try {
      await _feedback.record(suggestionId: suggestion.id, helpful: helpful);

      if (!mounted) return;

      setState(() {
        _savingFeedback = false;
        _feedbackRecorded = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            helpful
                ? _t(
                    'Thank you. MindPulse will remember that this was helpful.',
                    'ধন্যবাদ। MindPulse মনে রাখবে যে পরামর্শটি সহায়ক ছিল।',
                  )
                : _t(
                    'Thank you. This suggestion will not be repeated today.',
                    'ধন্যবাদ। আজ এই পরামর্শটি আবার দেখানো হবে না।',
                  ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _savingFeedback = false;
        _error = error.toString();
      });
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'sleep':
        return Icons.bedtime_outlined;
      case 'movement':
        return Icons.directions_walk_outlined;
      case 'screen_time':
        return Icons.phone_android_outlined;
      case 'recovery':
        return Icons.self_improvement_outlined;
      case 'encouragement':
        return Icons.favorite_outline_rounded;
      case 'checkin':
        return Icons.fact_check_outlined;
      default:
        return Icons.auto_awesome_outlined;
    }
  }

  String _flagLabel(String flag) {
    switch (flag) {
      case 'extended_phone_session':
        return _t('Long phone session', 'দীর্ঘ সময় ফোন ব্যবহার');
      case 'high_late_night_usage':
        return _t('Late-night use', 'রাতে বেশি ফোন ব্যবহার');
      case 'movement_below_personal_baseline':
        return _t('Movement below baseline', 'স্বাভাবিকের তুলনায় কম নড়াচড়া');
      case 'high_stress_low_energy':
        return _t('High stress · low energy', 'বেশি চাপ · কম শক্তি');
      case 'poor_sleep_pattern':
        return _t('Limited sleep', 'ঘুম কম হয়েছে');
      case 'recovery_completed':
        return _t('Recovery completed', 'পুনরুদ্ধার কার্যক্রম সম্পন্ন');
      case 'insufficient_data':
        return _t('More context needed', 'আরও তথ্য প্রয়োজন');
      default:
        return flag.replaceAll('_', ' ');
    }
  }

  String _priorityLabel(CompanionSuggestionPriority priority) {
    switch (priority) {
      case CompanionSuggestionPriority.timely:
        return _t('Timely support', 'সময়োপযোগী সহায়তা');
      case CompanionSuggestionPriority.gentle:
        return _t('Gentle suggestion', 'সহজ পরামর্শ');
      case CompanionSuggestionPriority.none:
        return _t('No suggestion', 'কোনো পরামর্শ নেই');
    }
  }

  String _suggestionMessage(CompanionSuggestion suggestion) {
    if (!AppPreferencesController.instance.isBangla) {
      return suggestion.message;
    }

    switch (suggestion.messageKey) {
      case 'sleep_wind_down':
        return 'সাম্প্রতিক সময়ে রাতে ফোন ব্যবহার বেশি হয়েছে এবং ঘুম কম হয়েছে। '
            'ফোনটি ১০ মিনিটের জন্য পাশে রেখে শরীরকে ধীরে ধীরে বিশ্রামের সুযোগ দিন।';
      case 'one_minute_reset':
        return 'আজকের দিনটি চাপের মনে হচ্ছে এবং শক্তিও কম। এখনই সব সমাধান করতে হবে না। '
            'একটি ধীর শ্বাস, একটু পানি অথবা এক মিনিটের বিরতি নিন।';
      case 'screen_and_movement_break':
        return 'অনেকক্ষণ ফোন ব্যবহার হয়েছে এবং আপনার স্বাভাবিকের তুলনায় নড়াচড়া কম। '
            'এক থেকে দুই মিনিট হাঁটাও যথেষ্ট হতে পারে।';
      case 'screen_pause':
        return 'অনেকক্ষণ ফোন ব্যবহার হয়েছে। চোখ ও শরীরকে ছোট একটি বিরতি দিন—'
            'দাঁড়ান, পর্দা থেকে চোখ সরান এবং এক মিনিট নড়াচড়া করুন।';
      case 'gentle_movement':
        return 'আপনার স্বাভাবিকের তুলনায় নড়াচড়া কম হয়েছে। ছোট একটি হাঁটাই যথেষ্ট; '
            'নিখুঁত লক্ষ্য পূরণের চাপ নেওয়ার প্রয়োজন নেই।';
      case 'recovery_acknowledgement':
        return 'আজ আপনি একটি পুনরুদ্ধার কার্যক্রম সম্পন্ন করেছেন। এটিও গুরুত্বপূর্ণ। '
            'পরিবর্তন ছোট মনে হলেও কোন বিষয়টি সহায়তা করেছে তা লক্ষ্য করুন।';
      case 'context_invitation':
        return 'MindPulse-এর কাছে এখনো পর্যাপ্ত অনুমোদিত তথ্য নেই। '
            'একটি দ্রুত দৈনিক চেক-ইন করলে অনুমান না করে আপনাকে সহায়তা করতে পারবে।';
      case 'balanced_context':
        return 'আপনার অনুমোদিত তথ্য অনুযায়ী এখন বড় কোনো বাধা দেওয়ার প্রয়োজন দেখা যাচ্ছে না। '
            'নিজের অবস্থার খোঁজ রাখুন এবং প্রয়োজন মনে হলে ছোট একটি বিরতি নিন।';
      default:
        return suggestion.message;
    }
  }

  Widget _loadingCard() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                _t(
                  'MindPulse is preparing your private daily context.',
                  'MindPulse আপনার ব্যক্তিগত দৈনিক তথ্য প্রস্তুত করছে।',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorCard() {
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      color: colors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t(
                'Companion context is temporarily unavailable',
                'সহকারীর তথ্য সাময়িকভাবে পাওয়া যাচ্ছে না',
              ),
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: colors.onErrorContainer,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _error ??
                  _t(
                    'Some approved signals could not be loaded.',
                    'কিছু অনুমোদিত তথ্য লোড করা যায়নি।',
                  ),
              style: TextStyle(color: colors.onErrorContainer),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(_t('Try again', 'আবার চেষ্টা করুন')),
                ),
                TextButton.icon(
                  onPressed: _openPermissions,
                  icon: const Icon(Icons.tune_rounded),
                  label: Text(
                    _t('Permissions and controls', 'অনুমতি ও নিয়ন্ত্রণ'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _loadingCard();
    }

    if (_error != null) {
      return _errorCard();
    }

    final dailyContext = _context;
    final suggestion = dailyContext?.suggestion;

    if (dailyContext == null || suggestion == null) {
      return _errorCard();
    }

    final visibleFlags = dailyContext.contextFlags.take(3).toList();

    final availableSignals = <Map<String, dynamic>>[
      dailyContext.phoneUsage,
      dailyContext.movement,
      dailyContext.checkin,
      dailyContext.recovery,
    ].where((value) => value['available'] == true).length;

    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              colors.primaryContainer.withValues(alpha: 0.72),
              colors.surface,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    _categoryIcon(suggestion.category),
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t('Your companion', 'আপনার সহকারী'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _t(
                          '${_priorityLabel(suggestion.priority)}'
                              ' · $availableSignals approved signal(s)',
                          '${_priorityLabel(suggestion.priority)}'
                              ' · $availableSignalsটি অনুমোদিত সংকেত',
                        ),
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: _t(
                    'Refresh companion context',
                    'সহকারীর তথ্য হালনাগাদ করুন',
                  ),
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              _suggestionMessage(suggestion),
              style: const TextStyle(
                height: 1.45,
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (visibleFlags.isNotEmpty) ...[
              const SizedBox(height: 13),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: visibleFlags.map((flag) {
                  return Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.insights_outlined, size: 16),
                    label: Text(_flagLabel(flag)),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              _t(
                'Based only on signals you approved. '
                    'This is wellbeing support, not a diagnosis.',
                'শুধু আপনার অনুমোদিত তথ্য ব্যবহার করা হয়েছে। '
                    'এটি সুস্থতা সহায়তা, চিকিৎসা নির্ণয় নয়।',
              ),
              style: TextStyle(
                color: colors.onSurfaceVariant,
                height: 1.35,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 14),
            if (_feedbackRecorded)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _t(
                    'Feedback saved locally. This suggestion will not repeat today.',
                    'মতামত ফোনে সংরক্ষিত হয়েছে। আজ এই পরামর্শটি আবার দেখানো হবে না।',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              )
            else
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _savingFeedback
                        ? null
                        : () {
                            unawaited(_recordFeedback(true));
                          },
                    icon: const Icon(Icons.thumb_up_alt_outlined),
                    label: Text(_t('Helpful', 'সহায়ক')),
                  ),
                  OutlinedButton.icon(
                    onPressed: _savingFeedback
                        ? null
                        : () {
                            unawaited(_recordFeedback(false));
                          },
                    icon: const Icon(Icons.thumb_down_alt_outlined),
                    label: Text(_t('Not helpful', 'সহায়ক নয়')),
                  ),
                  FilledButton.icon(
                    onPressed: _savingFeedback ? null : _openPermissions,
                    icon: const Icon(Icons.tune_rounded),
                    label: Text(
                      _t('Permissions and controls', 'সব অনুমতি ও নিয়ন্ত্রণ'),
                    ),
                  ),
                ],
              ),
            if (_savingFeedback) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }
}
