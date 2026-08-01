import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/my_day_task.dart';

class MyDayRepository {
  const MyDayRepository();

  static const String storageKey = 'mindpulse_my_day_schedule_v1';

  Future<List<MyDayTask>> loadTasks() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(storageKey);

    if (raw == null || raw.trim().isEmpty) {
      return <MyDayTask>[];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return <MyDayTask>[];
    }

    final fallbackDate = MyDayTask.dateOnly(DateTime.now());
    final tasks = <MyDayTask>[];

    for (final item in decoded.whereType<Map>()) {
      try {
        final task = MyDayTask.fromJson(
          Map<String, dynamic>.from(item),
          fallbackDate: fallbackDate,
        );

        if (task.title.isNotEmpty) {
          tasks.add(task);
        }
      } catch (_) {
        // A malformed legacy task must not block the rest of the day.
      }
    }

    tasks.sort(compareTasks);

    // Saving once upgrades legacy entries to the current schema.
    await saveTasks(tasks);
    return tasks;
  }

  Future<void> saveTasks(List<MyDayTask> tasks) async {
    final preferences = await SharedPreferences.getInstance();
    final sorted = <MyDayTask>[...tasks]..sort(compareTasks);

    await preferences.setString(
      storageKey,
      jsonEncode(sorted.map((task) => task.toJson()).toList()),
    );
  }

  Future<List<MyDayTask>> upsert(List<MyDayTask> tasks, MyDayTask task) async {
    final updated = <MyDayTask>[...tasks];
    final index = updated.indexWhere((item) => item.id == task.id);

    if (index == -1) {
      updated.add(task);
    } else {
      updated[index] = task;
    }

    updated.sort(compareTasks);
    await saveTasks(updated);
    return updated;
  }

  Future<List<MyDayTask>> delete(List<MyDayTask> tasks, String taskId) async {
    final updated = tasks.where((task) => task.id != taskId).toList()
      ..sort(compareTasks);

    await saveTasks(updated);
    return updated;
  }

  static List<MyDayTask> forDate(List<MyDayTask> tasks, DateTime date) {
    final result =
        tasks.where((task) => MyDayTask.isSameDate(task.date, date)).toList()
          ..sort(compareTasks);

    return result;
  }

  static Set<String> conflictIds(List<MyDayTask> tasks) {
    final result = <String>{};

    for (var firstIndex = 0; firstIndex < tasks.length; firstIndex++) {
      for (
        var secondIndex = firstIndex + 1;
        secondIndex < tasks.length;
        secondIndex++
      ) {
        final first = tasks[firstIndex];
        final second = tasks[secondIndex];

        if (first.overlaps(second)) {
          result
            ..add(first.id)
            ..add(second.id);
        }
      }
    }

    return result;
  }

  static int compareTasks(MyDayTask first, MyDayTask second) {
    final dateCompare = first.date.compareTo(second.date);
    if (dateCompare != 0) {
      return dateCompare;
    }

    final timeCompare = first.minutesOfDay.compareTo(second.minutesOfDay);
    if (timeCompare != 0) {
      return timeCompare;
    }

    return first.createdAt.compareTo(second.createdAt);
  }
}
