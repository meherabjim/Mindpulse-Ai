import 'package:flutter_test/flutter_test.dart';
import 'package:mindpulse_ai/features/planner/models/my_day_task.dart';
import 'package:mindpulse_ai/features/planner/services/my_day_repository.dart';

MyDayTask task({
  required String id,
  required int start,
  int duration = 30,
  MyDayTaskStatus status = MyDayTaskStatus.pending,
}) {
  final now = DateTime(2026, 8, 2, 10);
  return MyDayTask(
    id: id,
    title: id,
    date: DateTime(2026, 8, 2),
    minutesOfDay: start,
    durationMinutes: duration,
    category: 'পড়াশোনা',
    source: 'manual',
    status: status,
    alarmEnabled: false,
    notes: '',
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('My Day task model', () {
    test('migrates legacy completed tasks', () {
      final result = MyDayTask.fromJson(<String, dynamic>{
        'id': 'legacy',
        'title': 'Legacy task',
        'minutes_of_day': 600,
        'duration_minutes': 30,
        'category': 'কাজ',
        'alarm_enabled': true,
        'completed': true,
      }, fallbackDate: DateTime(2026, 8, 2));

      expect(result.status, MyDayTaskStatus.completed);
      expect(result.date, DateTime(2026, 8, 2));
      expect(result.source, 'manual');
    });

    test('round-trips the current task schema', () {
      final original = task(id: 'round-trip', start: 750, duration: 45);
      final restored = MyDayTask.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.date, original.date);
      expect(restored.minutesOfDay, original.minutesOfDay);
      expect(restored.durationMinutes, original.durationMinutes);
      expect(restored.status, MyDayTaskStatus.pending);
    });

    test('finds overlapping pending tasks', () {
      final first = task(id: 'a', start: 600, duration: 45);
      final second = task(id: 'b', start: 630, duration: 30);

      expect(first.overlaps(second), isTrue);
      expect(MyDayRepository.conflictIds(<MyDayTask>[first, second]), <String>{
        'a',
        'b',
      });
    });

    test('does not mark completed or skipped tasks as conflicts', () {
      final pending = task(id: 'a', start: 600, duration: 45);
      final completed = task(
        id: 'b',
        start: 630,
        status: MyDayTaskStatus.completed,
      );
      final skipped = task(
        id: 'c',
        start: 620,
        status: MyDayTaskStatus.skipped,
      );

      expect(pending.overlaps(completed), isFalse);
      expect(pending.overlaps(skipped), isFalse);
      expect(
        MyDayRepository.conflictIds(<MyDayTask>[pending, completed, skipped]),
        isEmpty,
      );
    });
  });
}
