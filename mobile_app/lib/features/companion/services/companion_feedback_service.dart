// HUMAN_COMPANION_FEEDBACK_SERVICE_V1

import 'package:shared_preferences/shared_preferences.dart';

class CompanionFeedbackService {
  static const String _idsPrefix = 'companion_feedback_ids_v1';

  static const String _helpfulPrefix = 'companion_feedback_helpful_v1';

  static const String _recordedAtPrefix = 'companion_feedback_recorded_at_v1';

  Future<Set<String>> suppressedSuggestionIds({DateTime? date}) async {
    final preferences = await SharedPreferences.getInstance();

    final key = '$_idsPrefix:${_dateKey(date ?? DateTime.now())}';

    return (preferences.getStringList(key) ?? const <String>[]).toSet();
  }

  Future<void> record({
    required String suggestionId,
    required bool helpful,
    DateTime? now,
  }) async {
    final recordedAt = now ?? DateTime.now();

    final dateKey = _dateKey(recordedAt);

    final preferences = await SharedPreferences.getInstance();

    final idsKey = '$_idsPrefix:$dateKey';

    final ids = (preferences.getStringList(idsKey) ?? const <String>[]).toSet();

    ids.add(suggestionId);

    await preferences.setStringList(idsKey, ids.toList()..sort());

    await preferences.setBool(
      '$_helpfulPrefix:$dateKey:$suggestionId',
      helpful,
    );

    await preferences.setInt(
      '$_recordedAtPrefix:$dateKey:$suggestionId',
      recordedAt.millisecondsSinceEpoch,
    );
  }

  Future<bool?> helpfulValue({
    required String suggestionId,
    DateTime? date,
  }) async {
    final preferences = await SharedPreferences.getInstance();

    final dateKey = _dateKey(date ?? DateTime.now());

    return preferences.getBool('$_helpfulPrefix:$dateKey:$suggestionId');
  }

  String _dateKey(DateTime value) {
    final local = value.toLocal();

    final month = local.month.toString().padLeft(2, '0');

    final day = local.day.toString().padLeft(2, '0');

    return '${local.year}-$month-$day';
  }
}
