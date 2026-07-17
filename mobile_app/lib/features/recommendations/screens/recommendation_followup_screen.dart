import 'dart:async';

import 'package:flutter/material.dart';

import '../services/recommendation_session_service.dart';
import 'recommendation_history_screen.dart';

class RecommendationFollowupScreen extends StatefulWidget {
  const RecommendationFollowupScreen({
    required this.category,
    required this.title,
    required this.action,
    required this.priority,
    required this.suggestedDurationSeconds,
    required this.beforeMood,
    required this.beforeStress,
    super.key,
  });

  final String category;
  final String title;
  final String action;
  final String priority;

  final int suggestedDurationSeconds;

  final int beforeMood;
  final int beforeStress;

  @override
  State<RecommendationFollowupScreen> createState() =>
      _RecommendationFollowupScreenState();
}

class _RecommendationFollowupScreenState
    extends State<RecommendationFollowupScreen>
    with WidgetsBindingObserver {
  final RecommendationSessionService _service = RecommendationSessionService();

  static const List<int> _durationOptions = <int>[120, 300, 600, 900];

  Timer? _ticker;

  DateTime? _segmentStartedAt;

  int _accumulatedSeconds = 0;
  int? _sessionId;

  late int _selectedDurationSeconds;

  bool _busy = false;
  bool _saved = false;

  String? _error;
  String? _savedMessage;

  bool get _isRunning => _segmentStartedAt != null;

  int get _elapsedSeconds {
    var seconds = _accumulatedSeconds;

    final startedAt = _segmentStartedAt;

    if (startedAt != null) {
      seconds += DateTime.now().difference(startedAt).inSeconds;
    }

    return seconds.clamp(0, 86400).toInt();
  }

  double get _progress {
    if (_selectedDurationSeconds <= 0) {
      return 0;
    }

    return (_elapsedSeconds / _selectedDurationSeconds).clamp(0.0, 1.0);
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _selectedDurationSeconds =
        _durationOptions.contains(widget.suggestedDurationSeconds)
        ? widget.suggestedDurationSeconds
        : 300;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && _isRunning) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _ticker?.cancel();

    super.dispose();
  }

  String get _clientSessionKey {
    final safeCategory = widget.category.replaceAll(
      RegExp(r'[^A-Za-z0-9_.:-]'),
      '_',
    );

    return 'mobile_'
        '${DateTime.now().microsecondsSinceEpoch}_'
        '$safeCategory';
  }

  Future<int> _ensureSessionCreated() async {
    final existing = _sessionId;

    if (existing != null) {
      return existing;
    }

    final session = await _service.startSession(
      clientSessionKey: _clientSessionKey,
      category: widget.category,
      title: widget.title,
      action: widget.action,
      priority: widget.priority,
      suggestedDurationSeconds: _selectedDurationSeconds,
      beforeMood: widget.beforeMood,
      beforeStress: widget.beforeStress,
    );

    final id = (session['id'] as num?)?.toInt() ?? 0;

    if (id <= 0) {
      throw const RecommendationSessionApiException(
        'The session could not be '
        'started.',
      );
    }

    _sessionId = id;

    return id;
  }

  void _startTicker() {
    _ticker?.cancel();

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _isRunning) {
        setState(() {});
      }
    });
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await _ensureSessionCreated();

      if (!mounted) return;

      setState(() {
        _segmentStartedAt = DateTime.now();

        _busy = false;
      });

      _startTicker();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _busy = false;
        _error = error.toString();
      });
    }
  }

  void _pause() {
    final startedAt = _segmentStartedAt;

    if (startedAt == null) {
      return;
    }

    setState(() {
      _accumulatedSeconds += DateTime.now().difference(startedAt).inSeconds;

      _segmentStartedAt = null;
    });

    _ticker?.cancel();
  }

  void _resume() {
    if (_sessionId == null || _saved || _isRunning) {
      return;
    }

    setState(() {
      _segmentStartedAt = DateTime.now();

      _error = null;
    });

    _startTicker();
  }

  void _freezeTimer() {
    final startedAt = _segmentStartedAt;

    if (startedAt != null) {
      _accumulatedSeconds += DateTime.now().difference(startedAt).inSeconds;
    }

    _segmentStartedAt = null;

    _ticker?.cancel();
  }

  Future<void> _saveTerminal({
    required String status,
    required String message,
    int? afterMood,
    int? afterStress,
    String? feedbackType,
    String? feedbackNote,
  }) async {
    setState(() {
      _freezeTimer();

      _busy = true;
      _error = null;
    });

    try {
      final sessionId = await _ensureSessionCreated();

      final saved = await _service.finishSession(
        sessionId: sessionId,
        status: status,
        actualDurationSeconds: _elapsedSeconds,
        afterMood: afterMood,
        afterStress: afterStress,
        feedbackType: feedbackType,
        feedbackNote: feedbackNote,
      );

      if (!mounted) return;

      setState(() {
        _busy = false;
        _saved = true;

        _savedMessage = message;

        _accumulatedSeconds =
            (saved['actual_duration_seconds'] as num?)?.toInt() ??
            _accumulatedSeconds;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _busy = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _complete() async {
    _pause();

    final feedback = await _collectFeedback();

    if (feedback == null || !mounted) {
      return;
    }

    await _saveTerminal(
      status: 'completed',
      message:
          'Action completed and '
          'feedback saved.',
      afterMood: feedback.afterMood,
      afterStress: feedback.afterStress,
      feedbackType: feedback.feedbackType,
      feedbackNote: feedback.note,
    );
  }

  Future<void> _saveForLater() {
    return _saveTerminal(
      status: 'remind_later',
      message:
          'Saved for later. A scheduled '
          'notification was not created.',
    );
  }

  Future<void> _abandon() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('End this activity?'),
          content: const Text(
            'The time followed so far '
            'will be saved as an '
            'unfinished activity.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Continue'),
            ),
            FilledButton.tonal(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('End activity'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await _saveTerminal(
      status: 'abandoned',
      message:
          'The unfinished activity '
          'was saved.',
    );
  }

  Future<_CompletionFeedback?> _collectFeedback() async {
    var afterMood = widget.beforeMood;

    var afterStress = widget.beforeStress;

    var includeRatings = true;

    String? feedbackType;

    final noteController = TextEditingController();

    final result = await showModalBottomSheet<_CompletionFeedback>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.viewInsetsOf(context).bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'How was this activity?',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'These questions are '
                      'optional and help '
                      'MindPulse learn which '
                      'actions are useful.',
                    ),
                    const SizedBox(height: 14),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: includeRatings,
                      onChanged: (value) {
                        setSheetState(() {
                          includeRatings = value;
                        });
                      },
                      title: const Text('Share how I feel now'),
                    ),
                    if (includeRatings) ...[
                      const Text(
                        'Mood now',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Row(
                        children: [
                          const Text('Low'),
                          Expanded(
                            child: Slider(
                              min: 1,
                              max: 5,
                              divisions: 4,
                              label: '$afterMood',
                              value: afterMood.toDouble(),
                              onChanged: (value) {
                                setSheetState(() {
                                  afterMood = value.round();
                                });
                              },
                            ),
                          ),
                          const Text('Good'),
                        ],
                      ),
                      const Text(
                        'Stress now',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Row(
                        children: [
                          const Text('Low'),
                          Expanded(
                            child: Slider(
                              min: 1,
                              max: 5,
                              divisions: 4,
                              label: '$afterStress',
                              value: afterStress.toDouble(),
                              onChanged: (value) {
                                setSheetState(() {
                                  afterStress = value.round();
                                });
                              },
                            ),
                          ),
                          const Text('High'),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    const Text(
                      'Was it useful?',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Helpful'),
                          selected: feedbackType == 'helpful',
                          onSelected: (_) {
                            setSheetState(() {
                              feedbackType = 'helpful';
                            });
                          },
                        ),
                        ChoiceChip(
                          label: const Text('About the same'),
                          selected: feedbackType == 'neutral',
                          onSelected: (_) {
                            setSheetState(() {
                              feedbackType = 'neutral';
                            });
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Not useful'),
                          selected: feedbackType == 'not_useful',
                          onSelected: (_) {
                            setSheetState(() {
                              feedbackType = 'not_useful';
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: noteController,
                      maxLength: 500,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Optional note',
                        hintText:
                            'What helped or '
                            'did not help?',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(
                                sheetContext,
                                const _CompletionFeedback(),
                              );
                            },
                            child: const Text('Skip feedback'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              Navigator.pop(
                                sheetContext,
                                _CompletionFeedback(
                                  afterMood: includeRatings ? afterMood : null,
                                  afterStress: includeRatings
                                      ? afterStress
                                      : null,
                                  feedbackType: feedbackType,
                                  note: noteController.text.trim(),
                                ),
                              );
                            },
                            child: const Text('Complete'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    noteController.dispose();

    return result;
  }

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;

    final minutes = (totalSeconds % 3600) ~/ 60;

    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '$hours:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }

    return '$minutes:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  String _durationLabel(int seconds) {
    final minutes = seconds ~/ 60;

    return '$minutes min';
  }

  @override
  Widget build(BuildContext context) {
    final canChooseDuration = _sessionId == null && !_saved && !_busy;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FC),
      appBar: AppBar(
        title: const Text('Action Follow-up'),

        actions: [
          IconButton(
            tooltip: 'Follow-up history',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const RecommendationHistoryScreen(),
                ),
              );
            },
            icon: const Icon(Icons.history_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CircleAvatar(
                        child: Icon(Icons.self_improvement_outlined),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              widget.action,
                              style: const TextStyle(height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text(widget.priority.toUpperCase())),
                      Chip(
                        avatar: const Icon(Icons.schedule_outlined, size: 18),
                        label: Text(
                          'Suggested '
                          '${_durationLabel(_selectedDurationSeconds)}',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (canChooseDuration)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(17),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Choose a manageable time',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'A shorter activity is '
                      'better than skipping it.',
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _durationOptions.map((seconds) {
                        return ChoiceChip(
                          label: Text(_durationLabel(seconds)),
                          selected: _selectedDurationSeconds == seconds,
                          onSelected: (_) {
                            setState(() {
                              _selectedDurationSeconds = seconds;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Text(
                    _formatDuration(_elapsedSeconds),
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Target: '
                    '${_durationLabel(_selectedDurationSeconds)}',
                  ),
                  const SizedBox(height: 15),
                  LinearProgressIndicator(
                    value: _progress,
                    minHeight: 11,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  if (_elapsedSeconds >= _selectedDurationSeconds &&
                      _sessionId != null &&
                      !_saved) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'You reached the selected '
                      'time. Finish when you are '
                      'ready.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                _error!,
                style: TextStyle(color: Colors.red.shade800),
              ),
            ),
          ],
          if (_saved) ...[
            const SizedBox(height: 12),
            Card(
              color: Colors.green.shade50,
              child: ListTile(
                leading: Icon(
                  Icons.check_circle_outline,
                  color: Colors.green.shade700,
                ),
                title: Text(_savedMessage ?? 'Follow-up saved.'),
                subtitle: Text(
                  'Recorded time: '
                  '${_formatDuration(_elapsedSeconds)}',
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Back to recommendations'),
            ),
          ] else ...[
            const SizedBox(height: 16),
            if (_sessionId == null)
              FilledButton.icon(
                onPressed: _busy ? null : _start,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow_rounded),
                label: Text(_busy ? 'Starting...' : 'Start activity'),
              ),
            if (_sessionId != null && _isRunning)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _pause,
                      icon: const Icon(Icons.pause_rounded),
                      label: const Text('Pause'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _complete,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Finish'),
                    ),
                  ),
                ],
              ),
            if (_sessionId != null && !_isRunning)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _resume,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Resume'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _complete,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Finish'),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _busy ? null : _saveForLater,
                    child: const Text('Save for later'),
                  ),
                ),
                if (_sessionId != null)
                  Expanded(
                    child: TextButton(
                      onPressed: _busy ? null : _abandon,
                      child: const Text('End unfinished'),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          const Text(
            'This follow-up records only the '
            'selected action, time and optional '
            'feedback. It does not access other '
            'apps, messages or screen content.',
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

class _CompletionFeedback {
  const _CompletionFeedback({
    this.afterMood,
    this.afterStress,
    this.feedbackType,
    this.note,
  });

  final int? afterMood;
  final int? afterStress;

  final String? feedbackType;
  final String? note;
}
