enum MyDayTaskStatus { pending, completed, skipped }

class MyDayTask {
  const MyDayTask({
    required this.id,
    required this.title,
    required this.date,
    required this.minutesOfDay,
    required this.durationMinutes,
    required this.category,
    required this.source,
    required this.status,
    required this.alarmEnabled,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final DateTime date;
  final int minutesOfDay;
  final int durationMinutes;
  final String category;
  final String source;
  final MyDayTaskStatus status;
  final bool alarmEnabled;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get endMinutesOfDay => minutesOfDay + durationMinutes;

  bool get completed => status == MyDayTaskStatus.completed;

  bool get skipped => status == MyDayTaskStatus.skipped;

  MyDayTask copyWith({
    String? title,
    DateTime? date,
    int? minutesOfDay,
    int? durationMinutes,
    String? category,
    String? source,
    MyDayTaskStatus? status,
    bool? alarmEnabled,
    String? notes,
    DateTime? updatedAt,
  }) {
    return MyDayTask(
      id: id,
      title: title ?? this.title,
      date: dateOnly(date ?? this.date),
      minutesOfDay: minutesOfDay ?? this.minutesOfDay,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      category: category ?? this.category,
      source: source ?? this.source,
      status: status ?? this.status,
      alarmEnabled: alarmEnabled ?? this.alarmEnabled,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  bool overlaps(MyDayTask other) {
    if (!isSameDate(date, other.date)) {
      return false;
    }

    if (skipped || completed || other.skipped || other.completed) {
      return false;
    }

    return minutesOfDay < other.endMinutesOfDay &&
        other.minutesOfDay < endMinutesOfDay;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'date': dateOnly(date).toIso8601String(),
      'minutes_of_day': minutesOfDay,
      'duration_minutes': durationMinutes,
      'category': category,
      'source': source,
      'status': status.name,
      'alarm_enabled': alarmEnabled,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      // Kept for older readers of this storage key.
      'completed': completed,
    };
  }

  factory MyDayTask.fromJson(
    Map<String, dynamic> json, {
    DateTime? fallbackDate,
  }) {
    final now = DateTime.now();
    final parsedDate = DateTime.tryParse(json['date']?.toString() ?? '');
    final createdAt =
        DateTime.tryParse(json['created_at']?.toString() ?? '') ?? now;
    final updatedAt =
        DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? createdAt;

    final rawStatus = json['status']?.toString();
    final rawId = json['id']?.toString().trim() ?? '';
    final rawTitle = json['title']?.toString().trim() ?? '';
    final rawCategory = json['category']?.toString().trim() ?? '';
    final rawSource = json['source']?.toString().trim() ?? '';
    final rawNotes = json['notes']?.toString().trim() ?? '';
    final MyDayTaskStatus status;

    if (rawStatus == 'completed' || json['completed'] == true) {
      status = MyDayTaskStatus.completed;
    } else if (rawStatus == 'skipped') {
      status = MyDayTaskStatus.skipped;
    } else {
      status = MyDayTaskStatus.pending;
    }

    return MyDayTask(
      id: rawId.isNotEmpty ? rawId : now.microsecondsSinceEpoch.toString(),
      title: rawTitle,
      date: dateOnly(parsedDate ?? fallbackDate ?? now),
      minutesOfDay: ((json['minutes_of_day'] as num?)?.toInt() ?? 540)
          .clamp(0, 1439)
          .toInt(),
      durationMinutes: ((json['duration_minutes'] as num?)?.toInt() ?? 30)
          .clamp(5, 720)
          .toInt(),
      category: rawCategory.isNotEmpty ? rawCategory : 'ব্যক্তিগত',
      source: rawSource.isNotEmpty ? rawSource : 'manual',
      status: status,
      alarmEnabled: json['alarm_enabled'] == true,
      notes: rawNotes,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static DateTime dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static bool isSameDate(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}
