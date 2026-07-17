from __future__ import annotations

from datetime import datetime
from pathlib import Path
import re
import shutil


ROOT = Path(
    r"E:\project 3\MindPulse-AI"
)

MOBILE = ROOT / "mobile_app"

SERVICE_FILE = (
    MOBILE
    / "lib"
    / "features"
    / "recommendations"
    / "services"
    / "recommendation_session_service.dart"
)

FOLLOWUP_SCREEN = (
    MOBILE
    / "lib"
    / "features"
    / "recommendations"
    / "screens"
    / "recommendation_followup_screen.dart"
)

HISTORY_SCREEN = (
    MOBILE
    / "lib"
    / "features"
    / "recommendations"
    / "screens"
    / "recommendation_history_screen.dart"
)

AI_SCREEN = (
    MOBILE
    / "lib"
    / "features"
    / "ai"
    / "screens"
    / "ai_wellness_screen.dart"
)


for required in (
    SERVICE_FILE,
    FOLLOWUP_SCREEN,
    AI_SCREEN,
):
    if not required.exists():
        raise RuntimeError(
            f"Required file was not found: "
            f"{required}"
        )


if HISTORY_SCREEN.exists():
    raise RuntimeError(
        "Recommendation history screen "
        "already exists. Do not run this "
        "patch again."
    )


backup_dir = (
    ROOT
    / "backups"
    / (
        "recommendation_history_flutter_"
        + datetime.now().strftime(
            "%Y%m%d_%H%M%S"
        )
    )
)

backup_dir.mkdir(
    parents=True,
    exist_ok=True,
)


for file_path in (
    SERVICE_FILE,
    FOLLOWUP_SCREEN,
    AI_SCREEN,
):
    relative_path = file_path.relative_to(
        ROOT
    )

    destination = (
        backup_dir
        / relative_path
    )

    destination.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    shutil.copy2(
        file_path,
        destination,
    )


service_text = SERVICE_FILE.read_text(
    encoding="utf-8",
)


if (
    "Future<Map<String, dynamic>>"
    "\n      getSummary({"
    in service_text
):
    raise RuntimeError(
        "Recommendation history API "
        "methods already exist."
    )


service_marker = (
    "  Map<String, dynamic> _decodeResponse("
)

if service_marker not in service_text:
    raise RuntimeError(
        "Service insertion marker "
        "was not found."
    )


service_methods = r'''
  Future<Map<String, dynamic>>
      getSummary({
    int days = 7,
  }) async {
    final safeDays =
        days.clamp(1, 90);

    final response =
        await _client.get(
      '/recommendation-sessions/'
      'summary?days=$safeDays',
    );

    final payload =
        _decodeResponse(
      response.body,
    );

    _checkStatus(
      response.statusCode,
      payload,
    );

    final data =
        _asMap(
      payload['data'],
    );

    return _asMap(
      data['summary'],
    );
  }


  Future<Map<String, dynamic>>
      getHistory({
    int page = 1,
    int limit = 50,
  }) async {
    final safePage =
        page < 1 ? 1 : page;

    final safeLimit =
        limit.clamp(1, 100);

    final response =
        await _client.get(
      '/recommendation-sessions/'
      'history?page=$safePage'
      '&limit=$safeLimit',
    );

    final payload =
        _decodeResponse(
      response.body,
    );

    _checkStatus(
      response.statusCode,
      payload,
    );

    return _asMap(
      payload['data'],
    );
  }


'''


service_text = service_text.replace(
    service_marker,
    service_methods
    + service_marker,
    1,
)


SERVICE_FILE.write_text(
    service_text,
    encoding="utf-8",
)


HISTORY_SCREEN.parent.mkdir(
    parents=True,
    exist_ok=True,
)


HISTORY_SCREEN.write_text(
r'''import 'package:flutter/material.dart';

import '../services/recommendation_session_service.dart';


class RecommendationHistoryScreen
    extends StatefulWidget {
  const RecommendationHistoryScreen({
    super.key,
  });

  @override
  State<RecommendationHistoryScreen>
      createState() =>
          _RecommendationHistoryScreenState();
}


class _RecommendationHistoryScreenState
    extends State<
        RecommendationHistoryScreen> {
  final RecommendationSessionService
      _service =
      RecommendationSessionService();

  Map<String, dynamic> _summary =
      <String, dynamic>{};

  List<Map<String, dynamic>> _sessions =
      <Map<String, dynamic>>[];

  int _days = 7;

  bool _loading = true;

  String? _error;


  @override
  void initState() {
    super.initState();

    _load();
  }


  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final responses =
          await Future.wait<
              Map<String, dynamic>>(
        <Future<Map<String, dynamic>>>[
          _service.getSummary(
            days: _days,
          ),
          _service.getHistory(
            page: 1,
            limit: 50,
          ),
        ],
      );

      final summary =
          responses[0];

      final history =
          responses[1];

      final rawSessions =
          history['sessions'];

      final sessions =
          rawSessions is List
              ? rawSessions
                  .whereType<Map>()
                  .map(
                    (
                      item,
                    ) =>
                        Map<
                            String,
                            dynamic>.from(
                      item,
                    ),
                  )
                  .toList()
              : <Map<String, dynamic>>[];

      if (!mounted) return;

      setState(() {
        _summary = summary;
        _sessions = sessions;
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


  int _intValue(
    dynamic value,
  ) {
    return (
      value as num?
    )?.toInt() ??
        int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }


  String _duration(
    int totalSeconds,
  ) {
    final safeSeconds =
        totalSeconds < 0
            ? 0
            : totalSeconds;

    final hours =
        safeSeconds ~/ 3600;

    final minutes =
        (
          safeSeconds % 3600
        ) ~/
        60;

    if (hours > 0) {
      return '$hours h $minutes min';
    }

    if (minutes > 0) {
      return '$minutes min';
    }

    return '$safeSeconds sec';
  }


  String _dateTimeLabel(
    dynamic value,
  ) {
    if (value == null) {
      return 'Time unavailable';
    }

    final parsed =
        DateTime.tryParse(
      value.toString(),
    );

    if (parsed == null) {
      return value.toString();
    }

    final local =
        parsed.toLocal();

    final day =
        local.day
            .toString()
            .padLeft(2, '0');

    final month =
        local.month
            .toString()
            .padLeft(2, '0');

    final hour =
        local.hour
            .toString()
            .padLeft(2, '0');

    final minute =
        local.minute
            .toString()
            .padLeft(2, '0');

    return '$day/$month/'
        '${local.year} '
        '$hour:$minute';
  }


  String _statusLabel(
    String value,
  ) {
    switch (value) {
      case 'completed':
        return 'Completed';

      case 'abandoned':
        return 'Ended unfinished';

      case 'remind_later':
        return 'Saved for later';

      case 'started':
        return 'In progress';

      default:
        return value;
    }
  }


  String _feedbackLabel(
    String? value,
  ) {
    switch (value) {
      case 'helpful':
        return 'Helpful';

      case 'neutral':
        return 'About the same';

      case 'not_useful':
        return 'Not useful';

      default:
        return 'No feedback';
    }
  }


  IconData _statusIcon(
    String status,
  ) {
    switch (status) {
      case 'completed':
        return Icons
            .check_circle_outline;

      case 'abandoned':
        return Icons
            .stop_circle_outlined;

      case 'remind_later':
        return Icons
            .schedule_outlined;

      default:
        return Icons
            .pending_outlined;
    }
  }


  Color _statusColor(
    String status,
  ) {
    switch (status) {
      case 'completed':
        return Colors.green;

      case 'abandoned':
        return Colors.orange;

      case 'remind_later':
        return Colors.blue;

      default:
        return Colors.grey;
    }
  }


  List<Map<String, dynamic>>
      get _categories {
    final value =
        _summary['categories'];

    if (value is! List) {
      return <Map<String, dynamic>>[];
    }

    return value
        .whereType<Map>()
        .map(
          (
            item,
          ) =>
              Map<String, dynamic>.from(
            item,
          ),
        )
        .toList();
  }


  Widget _metricCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(
          15,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color:
                  colorScheme.primary,
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style:
                  const TextStyle(
                fontSize: 24,
                fontWeight:
                    FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color:
                    colorScheme
                        .onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildSummary() {
    final completed =
        _intValue(
      _summary[
        'completed_sessions'
      ],
    );

    final total =
        _intValue(
      _summary[
        'total_sessions'
      ],
    );

    final helpful =
        _intValue(
      _summary[
        'helpful_sessions'
      ],
    );

    final notUseful =
        _intValue(
      _summary[
        'not_useful_sessions'
      ],
    );

    final duration =
        _intValue(
      _summary[
        'total_duration_seconds'
      ],
    );

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          '$_days-day follow-up summary',
          style:
              const TextStyle(
            fontSize: 22,
            fontWeight:
                FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'This section summarizes '
          'recorded activity and '
          'optional self-reported '
          'feedback.',
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.35,
          shrinkWrap: true,
          physics:
              const NeverScrollableScrollPhysics(),
          children: [
            _metricCard(
              icon:
                  Icons
                      .check_circle_outline,
              value:
                  '$completed / $total',
              label:
                  'Completed actions',
            ),
            _metricCard(
              icon:
                  Icons.timer_outlined,
              value:
                  _duration(duration),
              label:
                  'Recorded follow-up time',
            ),
            _metricCard(
              icon:
                  Icons
                      .thumb_up_alt_outlined,
              value:
                  '$helpful',
              label:
                  'Marked helpful',
            ),
            _metricCard(
              icon:
                  Icons
                      .thumb_down_alt_outlined,
              value:
                  '$notUseful',
              label:
                  'Marked not useful',
            ),
          ],
        ),
      ],
    );
  }


  Widget _buildCategorySection() {
    final categories =
        _categories;

    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text(
          'Activity categories',
          style:
              TextStyle(
            fontSize: 20,
            fontWeight:
                FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        ...categories.map(
          (
            category,
          ) {
            final name =
                category['category']
                        ?.toString() ??
                    'general';

            final total =
                _intValue(
              category['total'],
            );

            final completed =
                _intValue(
              category['completed'],
            );

            final helpful =
                _intValue(
              category['helpful'],
            );

            final averageSeconds =
                _intValue(
              category[
                'average_completed_seconds'
              ],
            );

            final completion =
                total == 0
                    ? 0.0
                    : completed / total;

            return Card(
              margin:
                  const EdgeInsets.only(
                bottom: 10,
              ),
              child: Padding(
                padding:
                    const EdgeInsets.all(
                  15,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name
                                .replaceAll(
                              '_',
                              ' ',
                            )
                                .toUpperCase(),
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight
                                      .w800,
                            ),
                          ),
                        ),
                        Text(
                          '$completed / $total '
                          'completed',
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    LinearProgressIndicator(
                      value:
                          completion
                              .clamp(
                                0.0,
                                1.0,
                              ),
                      minHeight: 8,
                      borderRadius:
                          BorderRadius
                              .circular(
                        20,
                      ),
                    ),
                    const SizedBox(
                      height: 9,
                    ),
                    Text(
                      'Helpful: $helpful'
                      '  •  Average completed '
                      'time: '
                      '${_duration(averageSeconds)}',
                      style:
                          const TextStyle(
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }


  Widget _buildSessionCard(
    Map<String, dynamic> session,
  ) {
    final status =
        session['status']
                ?.toString() ??
            'unknown';

    final color =
        _statusColor(status);

    final beforeMood =
        session['before_mood'];

    final afterMood =
        session['after_mood'];

    final beforeStress =
        session['before_stress'];

    final afterStress =
        session['after_stress'];

    final duration =
        _intValue(
      session[
        'actual_duration_seconds'
      ],
    );

    final feedback =
        session['feedback_type']
            ?.toString();

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 11,
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(
          15,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor:
                      color.withValues(
                    alpha: 0.14,
                  ),
                  child: Icon(
                    _statusIcon(
                      status,
                    ),
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        session[
                          'recommendation_title'
                        ]?.toString() ??
                            'Wellness action',
                        style:
                            const TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                      const SizedBox(
                        height: 4,
                      ),
                      Text(
                        _dateTimeLabel(
                          session[
                            'started_at'
                          ],
                        ),
                        style:
                            const TextStyle(
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(
                    _statusLabel(
                      status,
                    ),
                  ),
                ),
                Chip(
                  avatar:
                      const Icon(
                    Icons.timer_outlined,
                    size: 17,
                  ),
                  label: Text(
                    _duration(
                      duration,
                    ),
                  ),
                ),
                Chip(
                  label: Text(
                    _feedbackLabel(
                      feedback,
                    ),
                  ),
                ),
              ],
            ),
            if (
              beforeMood != null &&
              afterMood != null
            ) ...[
              const SizedBox(height: 8),
              Text(
                'Mood: $beforeMood → '
                '$afterMood',
              ),
            ],
            if (
              beforeStress != null &&
              afterStress != null
            ) ...[
              const SizedBox(height: 4),
              Text(
                'Stress: '
                '$beforeStress → '
                '$afterStress',
              ),
            ],
            if (
              session['feedback_note']
                      ?.toString()
                      .trim()
                      .isNotEmpty ==
                  true
            ) ...[
              const SizedBox(height: 9),
              Text(
                session[
                  'feedback_note'
                ].toString(),
                style:
                    const TextStyle(
                  fontStyle:
                      FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }


  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F7FC),
      appBar: AppBar(
        title:
            const Text(
          'Follow-up History',
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed:
                _loading
                    ? null
                    : _load,
            icon:
                const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      body:
          _loading
              ? const Center(
                  child:
                      CircularProgressIndicator(),
                )
              : _error != null
                  ? Center(
                      child:
                          Padding(
                        padding:
                            const EdgeInsets
                                .all(
                          24,
                        ),
                        child: Column(
                          mainAxisSize:
                              MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons
                                  .cloud_off_outlined,
                              size: 48,
                            ),
                            const SizedBox(
                              height: 12,
                            ),
                            Text(
                              _error!,
                              textAlign:
                                  TextAlign
                                      .center,
                            ),
                            const SizedBox(
                              height: 14,
                            ),
                            FilledButton(
                              onPressed:
                                  _load,
                              child:
                                  const Text(
                                'Try again',
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh:
                          _load,
                      child: ListView(
                        padding:
                            const EdgeInsets
                                .fromLTRB(
                          16,
                          16,
                          16,
                          40,
                        ),
                        children: [
                          SegmentedButton<int>(
                            segments:
                                const <
                                    ButtonSegment<
                                        int>>[
                              ButtonSegment<
                                  int>(
                                value: 7,
                                label:
                                    Text(
                                  '7 days',
                                ),
                              ),
                              ButtonSegment<
                                  int>(
                                value: 30,
                                label:
                                    Text(
                                  '30 days',
                                ),
                              ),
                            ],
                            selected:
                                <int>{
                              _days,
                            },
                            onSelectionChanged:
                                (
                              selection,
                            ) {
                              final days =
                                  selection
                                      .first;

                              if (
                                days ==
                                    _days
                              ) {
                                return;
                              }

                              setState(() {
                                _days = days;
                              });

                              _load();
                            },
                          ),
                          const SizedBox(
                            height: 18,
                          ),
                          _buildSummary(),
                          _buildCategorySection(),
                          const SizedBox(
                            height: 24,
                          ),
                          const Text(
                            'Recent follow-ups',
                            style:
                                TextStyle(
                              fontSize: 20,
                              fontWeight:
                                  FontWeight
                                      .w900,
                            ),
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          if (
                            _sessions.isEmpty
                          )
                            const Card(
                              child: Padding(
                                padding:
                                    EdgeInsets
                                        .all(
                                  22,
                                ),
                                child: Text(
                                  'No follow-up '
                                  'activity has '
                                  'been recorded '
                                  'yet.',
                                  textAlign:
                                      TextAlign
                                          .center,
                                ),
                              ),
                            )
                          else
                            ..._sessions.map(
                              _buildSessionCard,
                            ),
                          const SizedBox(
                            height: 14,
                          ),
                          const Text(
                            'The displayed changes '
                            'are self-reported '
                            'observations. They do '
                            'not prove that an '
                            'activity caused a mood '
                            'or stress change and '
                            'are not a diagnosis.',
                            style:
                                TextStyle(
                              fontSize: 12,
                              fontStyle:
                                  FontStyle
                                      .italic,
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}
''',
    encoding="utf-8",
)


followup_text = (
    FOLLOWUP_SCREEN.read_text(
        encoding="utf-8",
    )
)


history_import = (
    "import "
    "'recommendation_history_screen.dart';"
)

service_import = (
    "import '../services/"
    "recommendation_session_service.dart';"
)

if history_import not in followup_text:
    if service_import not in followup_text:
        raise RuntimeError(
            "Follow-up import marker "
            "was not found."
        )

    followup_text = followup_text.replace(
        service_import,
        service_import
        + "\n\n"
        + history_import,
        1,
    )


appbar_pattern = re.compile(
    r"""appBar:\s*AppBar\(
\s*title:\s*const\s*Text\(
\s*'Action Follow-up',
\s*\),
\s*\),"""
)


appbar_replacement = r'''appBar: AppBar(
        title: const Text(
          'Action Follow-up',
        ),
        actions: [
          IconButton(
            tooltip: 'Follow-up history',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const RecommendationHistoryScreen(),
                ),
              );
            },
            icon: const Icon(
              Icons.history_rounded,
            ),
          ),
        ],
      ),'''


followup_text, appbar_count = (
    appbar_pattern.subn(
        appbar_replacement,
        followup_text,
        count=1,
    )
)


if appbar_count != 1:
    raise RuntimeError(
        "Action Follow-up AppBar "
        "could not be updated safely."
    )


FOLLOWUP_SCREEN.write_text(
    followup_text,
    encoding="utf-8",
)


ai_text = AI_SCREEN.read_text(
    encoding="utf-8",
)


ai_history_import = (
    "import '../../recommendations/"
    "screens/"
    "recommendation_history_screen.dart';"
)

ai_import_marker = (
    "import '../../recommendations/"
    "screens/"
    "recommendation_followup_screen.dart';"
)

if ai_history_import not in ai_text:
    if ai_import_marker not in ai_text:
        raise RuntimeError(
            "AI recommendation import "
            "marker was not found."
        )

    ai_text = ai_text.replace(
        ai_import_marker,
        ai_import_marker
        + "\n"
        + ai_history_import,
        1,
    )


method_start = ai_text.find(
    "  Widget _buildWellnessResult()"
)

method_end = ai_text.find(
    "  int _recommendationDuration(",
    method_start,
)

if (
    method_start == -1
    or method_end == -1
):
    raise RuntimeError(
        "AI wellness result section "
        "was not found."
    )


before = ai_text[:method_start]

method = ai_text[
    method_start:method_end
]

after = ai_text[method_end:]


if (
    "'View follow-up history'"
    not in method
):
    list_pattern = re.compile(
        r"""(
\s*\.\.\.recommendations
\.map\(\(item\)\s*\{
.*?
\s*\}\),
)
(\s*const\s+SizedBox
\(height:\s*6\),)""",
        re.DOTALL,
    )

    history_block = r'''
        const SizedBox(height: 4),
        Card(
          child: ListTile(
            leading: const Icon(
              Icons.history_rounded,
            ),
            title: const Text(
              'View follow-up history',
            ),
            subtitle: const Text(
              'Review recorded time, '
              'completion and optional '
              'feedback.',
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const RecommendationHistoryScreen(),
                ),
              );
            },
          ),
        ),
'''

    method, list_count = (
        list_pattern.subn(
            lambda match: (
                match.group(1)
                + history_block
                + match.group(2)
            ),
            method,
            count=1,
        )
    )

    if list_count != 1:
        raise RuntimeError(
            "AI recommendation history "
            "entry could not be inserted."
        )


AI_SCREEN.write_text(
    before + method + after,
    encoding="utf-8",
)


print(
    "Recommendation history Flutter "
    "integration completed successfully."
)

print(
    f"Backup created: {backup_dir}"
)

print(
    f"Updated: {SERVICE_FILE}"
)

print(
    f"Created: {HISTORY_SCREEN}"
)

print(
    f"Updated: {FOLLOWUP_SCREEN}"
)

print(
    f"Updated: {AI_SCREEN}"
)

print(
    "No phone or sensor permission "
    "was added."
)

print(
    "The summary does not calculate "
    "a clinical effectiveness score."
)
