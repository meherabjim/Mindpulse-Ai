// HUMAN_COMPANION_DASHBOARD_CARD_V1

import 'dart:async';

import 'package:flutter/material.dart';

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
      final context = await _adapter.loadContext();

      if (!mounted) {
        return;
      }

      setState(() {
        _context = context;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

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

    if (!mounted) {
      return;
    }

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

      if (!mounted) {
        return;
      }

      setState(() {
        _savingFeedback = false;
        _feedbackRecorded = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            helpful
                ? 'Thank you. MindPulse will remember that this was helpful.'
                : 'Thank you. This suggestion will not be repeated today.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

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
        return 'Long phone session';

      case 'high_late_night_usage':
        return 'Late-night use';

      case 'movement_below_personal_baseline':
        return 'Movement below baseline';

      case 'high_stress_low_energy':
        return 'High stress · low energy';

      case 'poor_sleep_pattern':
        return 'Limited sleep';

      case 'recovery_completed':
        return 'Recovery completed';

      case 'insufficient_data':
        return 'More context needed';

      default:
        return flag.replaceAll('_', ' ');
    }
  }

  String _priorityLabel(CompanionSuggestionPriority priority) {
    switch (priority) {
      case CompanionSuggestionPriority.timely:
        return 'Timely support';

      case CompanionSuggestionPriority.gentle:
        return 'Gentle suggestion';

      case CompanionSuggestionPriority.none:
        return 'No suggestion';
    }
  }

  Widget _loadingCard() {
    return Card(
      margin: EdgeInsets.zero,
      child: const Padding(
        padding: EdgeInsets.all(20),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Text('MindPulse is preparing your private daily context.'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorCard() {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Companion context is temporarily unavailable',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(_error ?? 'Some approved signals could not be loaded.'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
                TextButton(
                  onPressed: _openPermissions,
                  child: const Text('Permissions'),
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

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[Color(0xFFF1F0FF), Color(0xFFFFFFFF)],
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
                    color: const Color(0xFFE3E0FF),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    _categoryIcon(suggestion.category),
                    color: const Color(0xFF5750D8),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your companion',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_priorityLabel(suggestion.priority)}'
                        ' · $availableSignals approved signal(s)',
                        style: const TextStyle(
                          color: Color(0xFF74748A),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh companion context',
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              suggestion.message,
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
            const Text(
              'Based only on signals you approved. '
              'This is wellbeing support, not a diagnosis.',
              style: TextStyle(
                color: Color(0xFF74748A),
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
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Feedback saved locally. This suggestion will not repeat today.',
                  style: TextStyle(fontWeight: FontWeight.w700),
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
                    label: const Text('Helpful'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _savingFeedback
                        ? null
                        : () {
                            unawaited(_recordFeedback(false));
                          },
                    icon: const Icon(Icons.thumb_down_alt_outlined),
                    label: const Text('Not helpful'),
                  ),
                  TextButton.icon(
                    onPressed: _savingFeedback ? null : _openPermissions,
                    icon: const Icon(Icons.tune_rounded),
                    label: const Text('Permissions'),
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
