import 'package:flutter_test/flutter_test.dart';
import 'package:mindpulse_ai/features/planner/models/reading_plan_models.dart';

void main() {
  test('reading plan request supports one selected item', () {
    const request = ReadingPlanRequestModel(
      profile: ReadingEducationProfile.initial(),
      items: <ReadingItemModel>[
        ReadingItemModel(
          id: 'magazine-1',
          type: 'magazine',
          title: 'Science Magazine',
          author: '',
          publisher: '',
          publishedDate: '',
          subject: 'Science',
          language: 'en',
          identifier: '',
          source: 'google_books',
          sourceUrl: '',
          userDifficulty: 'unknown',
          priority: 3,
        ),
      ],
      availability: ReadingAvailabilityModel.initial(),
      goal: 'general_reading',
      targetDate: null,
    );

    final json = request.toJson();
    expect((json['items'] as List).length, 1);
    expect(json['goal'], 'general_reading');
  });

  test('reading plan response parses explainable sessions', () {
    final response = ReadingPlanResponseModel.fromJson(<String, dynamic>{
      'plan_id': 'reading-test',
      'engine': 'mindpulse-transparent-reading-plan-v1',
      'generated_at': '2026-08-01T09:00:00Z',
      'language': 'bn',
      'summary': 'Summary',
      'overall_confidence': 0.75,
      'difficulty_assessments': <Map<String, dynamic>>[
        <String, dynamic>{
          'item_id': 'book-1',
          'label': 'unknown',
          'confidence': 0.5,
          'basis': <String>['google_books_catalogue_metadata'],
          'note': 'Not confirmed',
        },
      ],
      'sessions': <Map<String, dynamic>>[
        <String, dynamic>{
          'session_id': 'session-1',
          'day': 'mon',
          'day_label': 'সোমবার',
          'start_minutes': 1140,
          'duration_minutes': 30,
          'item_id': 'book-1',
          'title': 'Book',
          'subject': 'Physics',
          'focus': 'Focus',
          'reason': 'Reason',
          'difficulty': 'unknown',
          'confidence': 0.5,
        },
      ],
      'assumptions': <String>['Assumption'],
      'sources': <Map<String, dynamic>>[
        <String, dynamic>{
          'name': 'Google Books',
          'usage': 'Catalogue identity',
        },
      ],
      'disclaimer': 'Disclaimer',
    });

    expect(response.sessions, hasLength(1));
    expect(response.sessions.first.title, 'Book');
    expect(response.difficultyAssessments.first.label, 'unknown');
  });
}
