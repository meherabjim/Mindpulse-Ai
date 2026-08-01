import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/my_day_task.dart';
import '../models/reading_plan_models.dart';
import 'my_day_repository.dart';

class ReadingPlanSavedState {
  const ReadingPlanSavedState({
    required this.profile,
    required this.items,
    required this.availability,
    required this.goal,
    required this.targetDate,
    required this.plan,
  });

  final ReadingEducationProfile profile;
  final List<ReadingItemModel> items;
  final ReadingAvailabilityModel availability;
  final String goal;
  final DateTime? targetDate;
  final ReadingPlanResponseModel? plan;
}

class ReadingPlanRepository {
  static const profileKey = 'mindpulse_ai_guide_profile_v3';
  static const legacyProfileKey = 'mindpulse_ai_guide_profile_v2';
  static const itemsKey = 'mindpulse_ai_guide_items_v2';
  static const settingsKey = 'mindpulse_ai_guide_settings_v3';
  static const planKey = 'mindpulse_ai_guide_plan_v3';

  Future<ReadingPlanSavedState> load() async {
    final preferences = await SharedPreferences.getInstance();

    var profile = const ReadingEducationProfile.initial();
    var items = <ReadingItemModel>[];
    var availability = const ReadingAvailabilityModel.initial();
    var goal = 'general_reading';
    DateTime? targetDate;
    ReadingPlanResponseModel? plan;

    try {
      final profileRaw =
          preferences.getString(profileKey) ??
          preferences.getString(legacyProfileKey);
      if (profileRaw != null && profileRaw.trim().isNotEmpty) {
        final decoded = jsonDecode(profileRaw);
        if (decoded is Map) {
          final map = Map<String, dynamic>.from(decoded);
          if (map.containsKey('education_system')) {
            profile = ReadingEducationProfile.fromJson(map);
          } else {
            final legacyLevel = map['education_level']?.toString() ?? 'general';
            final level = <String>{'preschool', 'class_0'}.contains(legacyLevel)
                ? 'preschool'
                : <String>{
                    'class_1',
                    'class_2',
                    'class_3',
                    'class_4',
                    'class_5',
                  }.contains(legacyLevel)
                ? 'primary'
                : <String>{
                    'class_6',
                    'class_7',
                    'class_8',
                    'class_9',
                    'class_10',
                    'ssc',
                  }.contains(legacyLevel)
                ? 'secondary'
                : <String>{'hsc_1', 'hsc_2'}.contains(legacyLevel)
                ? 'higher_secondary'
                : legacyLevel == 'general'
                ? 'general_reader'
                : legacyLevel;

            profile = ReadingEducationProfile(
              educationSystem: 'general',
              educationLevel: level,
              classOrYear: legacyLevel == 'general'
                  ? 'general_reader'
                  : legacyLevel,
              stream: map['stream']?.toString() ?? 'general',
              boardOrCurriculum: '',
              degree: map['field']?.toString() ?? '',
              major: map['field']?.toString() ?? '',
              semester: '',
              subjects: const <String>[],
              preferredLanguage:
                  map['preferred_language']?.toString() == 'english'
                  ? 'en'
                  : map['preferred_language']?.toString() == 'both'
                  ? 'both'
                  : 'bn',
            );
          }
        }
      }

      final itemsRaw = preferences.getString(itemsKey);
      if (itemsRaw != null && itemsRaw.trim().isNotEmpty) {
        final decoded = jsonDecode(itemsRaw);
        if (decoded is List) {
          items = decoded
              .whereType<Map>()
              .map(
                (item) =>
                    ReadingItemModel.fromJson(Map<String, dynamic>.from(item)),
              )
              .where((item) => item.title.trim().isNotEmpty)
              .toList();
        }
      }

      final settingsRaw = preferences.getString(settingsKey);
      if (settingsRaw != null && settingsRaw.trim().isNotEmpty) {
        final decoded = jsonDecode(settingsRaw);
        if (decoded is Map) {
          final settings = Map<String, dynamic>.from(decoded);
          final availabilityRaw = settings['availability'];
          if (availabilityRaw is Map) {
            availability = ReadingAvailabilityModel.fromJson(
              Map<String, dynamic>.from(availabilityRaw),
            );
          }
          goal = settings['goal']?.toString() ?? 'general_reading';
          targetDate = DateTime.tryParse(
            settings['target_date']?.toString() ?? '',
          );
        }
      }

      final planRaw = preferences.getString(planKey);
      if (planRaw != null && planRaw.trim().isNotEmpty) {
        final decoded = jsonDecode(planRaw);
        if (decoded is Map) {
          plan = ReadingPlanResponseModel.fromJson(
            Map<String, dynamic>.from(decoded),
          );
        }
      }
    } catch (_) {
      // Invalid local planner data is ignored rather than partially trusted.
    }

    return ReadingPlanSavedState(
      profile: profile,
      items: items,
      availability: availability,
      goal: goal,
      targetDate: targetDate,
      plan: plan,
    );
  }

  Future<void> save({
    required ReadingEducationProfile profile,
    required List<ReadingItemModel> items,
    required ReadingAvailabilityModel availability,
    required String goal,
    required DateTime? targetDate,
    required ReadingPlanResponseModel? plan,
  }) async {
    final preferences = await SharedPreferences.getInstance();

    await Future.wait<bool>(<Future<bool>>[
      preferences.setString(profileKey, jsonEncode(profile.toJson())),
      preferences.setString(
        itemsKey,
        jsonEncode(items.map((item) => item.toJson()).toList()),
      ),
      preferences.setString(
        settingsKey,
        jsonEncode(<String, dynamic>{
          'availability': availability.toJson(),
          'goal': goal,
          'target_date': targetDate?.toIso8601String(),
        }),
      ),
      if (plan == null)
        preferences.remove(planKey)
      else
        preferences.setString(planKey, jsonEncode(plan.toJson())),
    ]);
  }

  Future<void> addSessionToMyDay(ReadingPlanSessionModel session) async {
    const repository = MyDayRepository();
    final tasks = await repository.loadTasks();
    final taskId = 'reading_plan_${session.sessionId}';

    if (tasks.any((task) => task.id == taskId)) {
      return;
    }

    final now = DateTime.now();
    final scheduledDate = _nextDateForDay(
      session.day,
      now,
      session.startMinutes,
    );

    await repository.upsert(
      tasks,
      MyDayTask(
        id: taskId,
        title: session.subject.trim().isEmpty
            ? session.title
            : '${session.subject}: ${session.title}',
        date: scheduledDate,
        minutesOfDay: session.startMinutes,
        durationMinutes: session.durationMinutes,
        category: 'পড়াশোনা',
        source: 'ai_guide',
        status: MyDayTaskStatus.pending,
        alarmEnabled: false,
        notes: <String>[
          if (session.focus.trim().isNotEmpty) session.focus.trim(),
          if (session.reason.trim().isNotEmpty) session.reason.trim(),
        ].join(' • '),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  DateTime _nextDateForDay(
    String rawDay,
    DateTime from,
    int sessionStartMinutes,
  ) {
    const weekdays = <String, int>{
      'mon': DateTime.monday,
      'tue': DateTime.tuesday,
      'wed': DateTime.wednesday,
      'thu': DateTime.thursday,
      'fri': DateTime.friday,
      'sat': DateTime.saturday,
      'sun': DateTime.sunday,
    };

    final targetWeekday = weekdays[rawDay.trim().toLowerCase()];
    final start = MyDayTask.dateOnly(from);

    if (targetWeekday == null) {
      return start;
    }

    var delta = (targetWeekday - start.weekday + 7) % 7;
    final currentMinutes = (from.hour * 60) + from.minute;

    if (delta == 0 && sessionStartMinutes <= currentMinutes + 10) {
      delta = 7;
    }

    return start.add(Duration(days: delta));
  }
}
