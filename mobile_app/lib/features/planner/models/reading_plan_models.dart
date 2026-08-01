class ReadingEducationProfile {
  const ReadingEducationProfile({
    required this.educationSystem,
    required this.educationLevel,
    required this.classOrYear,
    required this.stream,
    required this.boardOrCurriculum,
    required this.degree,
    required this.major,
    required this.semester,
    required this.subjects,
    required this.preferredLanguage,
  });

  const ReadingEducationProfile.initial()
    : educationSystem = 'general',
      educationLevel = 'secondary',
      classOrYear = 'class_9',
      stream = 'science',
      boardOrCurriculum = '',
      degree = '',
      major = '',
      semester = '',
      subjects = const <String>[],
      preferredLanguage = 'bn';

  final String educationSystem;
  final String educationLevel;
  final String classOrYear;
  final String stream;
  final String boardOrCurriculum;
  final String degree;
  final String major;
  final String semester;
  final List<String> subjects;
  final String preferredLanguage;

  bool get needsAcademicStream {
    return <String>{
      'class_9',
      'class_10',
      'ssc',
      'hsc_1',
      'hsc_2',
      'dakhil',
      'alim_1',
      'alim_2',
    }.contains(classOrYear);
  }

  bool get needsDegreeDetails {
    return <String>{
      'diploma',
      'bachelor',
      'masters',
      'mphil_phd',
      'professional',
    }.contains(educationLevel);
  }

  ReadingEducationProfile copyWith({
    String? educationSystem,
    String? educationLevel,
    String? classOrYear,
    String? stream,
    String? boardOrCurriculum,
    String? degree,
    String? major,
    String? semester,
    List<String>? subjects,
    String? preferredLanguage,
  }) {
    return ReadingEducationProfile(
      educationSystem: educationSystem ?? this.educationSystem,
      educationLevel: educationLevel ?? this.educationLevel,
      classOrYear: classOrYear ?? this.classOrYear,
      stream: stream ?? this.stream,
      boardOrCurriculum: boardOrCurriculum ?? this.boardOrCurriculum,
      degree: degree ?? this.degree,
      major: major ?? this.major,
      semester: semester ?? this.semester,
      subjects: subjects ?? this.subjects,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'education_system': educationSystem,
      'education_level': educationLevel,
      'class_or_year': classOrYear,
      'stream': stream,
      'board_or_curriculum': boardOrCurriculum,
      'degree': degree,
      'major': major,
      'semester': semester,
      'subjects': subjects,
      'preferred_language': preferredLanguage,
    };
  }

  factory ReadingEducationProfile.fromJson(Map<String, dynamic> json) {
    final rawSubjects = json['subjects'];
    final subjects = rawSubjects is List
        ? rawSubjects
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList()
        : <String>[];

    return ReadingEducationProfile(
      educationSystem: json['education_system']?.toString() ?? 'general',
      educationLevel: json['education_level']?.toString() ?? 'secondary',
      classOrYear: json['class_or_year']?.toString() ?? 'class_9',
      stream: json['stream']?.toString() ?? 'science',
      boardOrCurriculum: json['board_or_curriculum']?.toString() ?? '',
      degree: json['degree']?.toString() ?? '',
      major: json['major']?.toString() ?? '',
      semester: json['semester']?.toString() ?? '',
      subjects: subjects,
      preferredLanguage: json['preferred_language']?.toString() ?? 'bn',
    );
  }
}

class ReadingItemModel {
  const ReadingItemModel({
    required this.id,
    required this.type,
    required this.title,
    required this.author,
    required this.publisher,
    required this.publishedDate,
    required this.subject,
    required this.language,
    required this.identifier,
    required this.source,
    required this.sourceUrl,
    required this.userDifficulty,
    required this.priority,
  });

  final String id;
  final String type;
  final String title;
  final String author;
  final String publisher;
  final String publishedDate;
  final String subject;
  final String language;
  final String identifier;
  final String source;
  final String sourceUrl;
  final String userDifficulty;
  final int priority;

  ReadingItemModel copyWith({
    String? subject,
    String? userDifficulty,
    int? priority,
  }) {
    return ReadingItemModel(
      id: id,
      type: type,
      title: title,
      author: author,
      publisher: publisher,
      publishedDate: publishedDate,
      subject: subject ?? this.subject,
      language: language,
      identifier: identifier,
      source: source,
      sourceUrl: sourceUrl,
      userDifficulty: userDifficulty ?? this.userDifficulty,
      priority: priority ?? this.priority,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'type': type,
      'title': title,
      'author': author,
      'publisher': publisher,
      'published_date': publishedDate,
      'subject': subject,
      'language': language,
      'identifier': identifier,
      'source': source,
      'source_url': sourceUrl,
      'user_difficulty': userDifficulty,
      'priority': priority,
    };
  }

  factory ReadingItemModel.fromJson(Map<String, dynamic> json) {
    return ReadingItemModel(
      id:
          json['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      type: json['type']?.toString() ?? 'book',
      title: json['title']?.toString() ?? '',
      author: json['author']?.toString() ?? '',
      publisher: json['publisher']?.toString() ?? '',
      publishedDate: json['published_date']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      language: json['language']?.toString() ?? '',
      identifier: json['identifier']?.toString() ?? '',
      source: json['source']?.toString() ?? 'manual',
      sourceUrl: json['source_url']?.toString() ?? '',
      userDifficulty:
          json['user_difficulty']?.toString() ??
          json['difficulty']?.toString() ??
          'unknown',
      priority: ((json['priority'] as num?)?.toInt() ?? 3).clamp(1, 5).toInt(),
    );
  }
}

class ReadingAvailabilityModel {
  const ReadingAvailabilityModel({
    required this.sessionMinutes,
    required this.sessionsPerWeek,
    required this.preferredDays,
    required this.preferredStartMinutes,
  });

  const ReadingAvailabilityModel.initial()
    : sessionMinutes = 30,
      sessionsPerWeek = 3,
      preferredDays = const <String>['mon', 'wed', 'sat'],
      preferredStartMinutes = 1140;

  final int sessionMinutes;
  final int sessionsPerWeek;
  final List<String> preferredDays;
  final int preferredStartMinutes;

  ReadingAvailabilityModel copyWith({
    int? sessionMinutes,
    int? sessionsPerWeek,
    List<String>? preferredDays,
    int? preferredStartMinutes,
  }) {
    return ReadingAvailabilityModel(
      sessionMinutes: sessionMinutes ?? this.sessionMinutes,
      sessionsPerWeek: sessionsPerWeek ?? this.sessionsPerWeek,
      preferredDays: preferredDays ?? this.preferredDays,
      preferredStartMinutes:
          preferredStartMinutes ?? this.preferredStartMinutes,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'session_minutes': sessionMinutes,
      'sessions_per_week': sessionsPerWeek,
      'preferred_days': preferredDays,
      'preferred_start_minutes': preferredStartMinutes,
    };
  }

  factory ReadingAvailabilityModel.fromJson(Map<String, dynamic> json) {
    final rawDays = json['preferred_days'];
    final days = rawDays is List
        ? rawDays.map((item) => item.toString()).toList()
        : <String>['mon', 'wed', 'sat'];

    return ReadingAvailabilityModel(
      sessionMinutes: ((json['session_minutes'] as num?)?.toInt() ?? 30)
          .clamp(10, 120)
          .toInt(),
      sessionsPerWeek: ((json['sessions_per_week'] as num?)?.toInt() ?? 3)
          .clamp(1, 14)
          .toInt(),
      preferredDays: days.isEmpty ? <String>['mon', 'wed', 'sat'] : days,
      preferredStartMinutes:
          ((json['preferred_start_minutes'] as num?)?.toInt() ?? 1140)
              .clamp(0, 1439)
              .toInt(),
    );
  }
}

class ReadingPlanRequestModel {
  const ReadingPlanRequestModel({
    required this.profile,
    required this.items,
    required this.availability,
    required this.goal,
    required this.targetDate,
  });

  final ReadingEducationProfile profile;
  final List<ReadingItemModel> items;
  final ReadingAvailabilityModel availability;
  final String goal;
  final DateTime? targetDate;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'profile': profile.toJson(),
      'items': items.map((item) => item.toJson()).toList(),
      'availability': availability.toJson(),
      'goal': goal,
      'target_date': targetDate == null
          ? null
          : '${targetDate!.year.toString().padLeft(4, '0')}-'
                '${targetDate!.month.toString().padLeft(2, '0')}-'
                '${targetDate!.day.toString().padLeft(2, '0')}',
    };
  }
}

class ReadingDifficultyAssessmentModel {
  const ReadingDifficultyAssessmentModel({
    required this.itemId,
    required this.label,
    required this.confidence,
    required this.basis,
    required this.note,
  });

  final String itemId;
  final String label;
  final double confidence;
  final List<String> basis;
  final String note;

  factory ReadingDifficultyAssessmentModel.fromJson(Map<String, dynamic> json) {
    final rawBasis = json['basis'];
    return ReadingDifficultyAssessmentModel(
      itemId: json['item_id']?.toString() ?? '',
      label: json['label']?.toString() ?? 'unknown',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      basis: rawBasis is List
          ? rawBasis.map((item) => item.toString()).toList()
          : <String>[],
      note: json['note']?.toString() ?? '',
    );
  }
}

class ReadingPlanSessionModel {
  const ReadingPlanSessionModel({
    required this.sessionId,
    required this.day,
    required this.dayLabel,
    required this.startMinutes,
    required this.durationMinutes,
    required this.itemId,
    required this.title,
    required this.subject,
    required this.focus,
    required this.reason,
    required this.difficulty,
    required this.confidence,
  });

  final String sessionId;
  final String day;
  final String dayLabel;
  final int startMinutes;
  final int durationMinutes;
  final String itemId;
  final String title;
  final String subject;
  final String focus;
  final String reason;
  final String difficulty;
  final double confidence;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'session_id': sessionId,
      'day': day,
      'day_label': dayLabel,
      'start_minutes': startMinutes,
      'duration_minutes': durationMinutes,
      'item_id': itemId,
      'title': title,
      'subject': subject,
      'focus': focus,
      'reason': reason,
      'difficulty': difficulty,
      'confidence': confidence,
    };
  }

  factory ReadingPlanSessionModel.fromJson(Map<String, dynamic> json) {
    return ReadingPlanSessionModel(
      sessionId: json['session_id']?.toString() ?? '',
      day: json['day']?.toString() ?? 'mon',
      dayLabel: json['day_label']?.toString() ?? '',
      startMinutes: (json['start_minutes'] as num?)?.toInt() ?? 1140,
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 30,
      itemId: json['item_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      focus: json['focus']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      difficulty: json['difficulty']?.toString() ?? 'unknown',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ReadingPlanSourceModel {
  const ReadingPlanSourceModel({required this.name, required this.usage});

  final String name;
  final String usage;

  factory ReadingPlanSourceModel.fromJson(Map<String, dynamic> json) {
    return ReadingPlanSourceModel(
      name: json['name']?.toString() ?? '',
      usage: json['usage']?.toString() ?? '',
    );
  }
}

class ReadingPlanResponseModel {
  const ReadingPlanResponseModel({
    required this.planId,
    required this.engine,
    required this.generatedAt,
    required this.language,
    required this.summary,
    required this.overallConfidence,
    required this.difficultyAssessments,
    required this.sessions,
    required this.assumptions,
    required this.sources,
    required this.disclaimer,
  });

  final String planId;
  final String engine;
  final DateTime? generatedAt;
  final String language;
  final String summary;
  final double overallConfidence;
  final List<ReadingDifficultyAssessmentModel> difficultyAssessments;
  final List<ReadingPlanSessionModel> sessions;
  final List<String> assumptions;
  final List<ReadingPlanSourceModel> sources;
  final String disclaimer;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'plan_id': planId,
      'engine': engine,
      'generated_at': generatedAt?.toIso8601String(),
      'language': language,
      'summary': summary,
      'overall_confidence': overallConfidence,
      'difficulty_assessments': difficultyAssessments
          .map(
            (item) => <String, dynamic>{
              'item_id': item.itemId,
              'label': item.label,
              'confidence': item.confidence,
              'basis': item.basis,
              'note': item.note,
            },
          )
          .toList(),
      'sessions': sessions.map((session) => session.toJson()).toList(),
      'assumptions': assumptions,
      'sources': sources
          .map(
            (source) => <String, dynamic>{
              'name': source.name,
              'usage': source.usage,
            },
          )
          .toList(),
      'disclaimer': disclaimer,
    };
  }

  factory ReadingPlanResponseModel.fromJson(Map<String, dynamic> json) {
    final rawAssessments = json['difficulty_assessments'];
    final rawSessions = json['sessions'];
    final rawAssumptions = json['assumptions'];
    final rawSources = json['sources'];

    return ReadingPlanResponseModel(
      planId: json['plan_id']?.toString() ?? '',
      engine: json['engine']?.toString() ?? '',
      generatedAt: DateTime.tryParse(json['generated_at']?.toString() ?? ''),
      language: json['language']?.toString() ?? 'bn',
      summary: json['summary']?.toString() ?? '',
      overallConfidence: (json['overall_confidence'] as num?)?.toDouble() ?? 0,
      difficultyAssessments: rawAssessments is List
          ? rawAssessments
                .whereType<Map>()
                .map(
                  (item) => ReadingDifficultyAssessmentModel.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : <ReadingDifficultyAssessmentModel>[],
      sessions: rawSessions is List
          ? rawSessions
                .whereType<Map>()
                .map(
                  (item) => ReadingPlanSessionModel.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : <ReadingPlanSessionModel>[],
      assumptions: rawAssumptions is List
          ? rawAssumptions.map((item) => item.toString()).toList()
          : <String>[],
      sources: rawSources is List
          ? rawSources
                .whereType<Map>()
                .map(
                  (item) => ReadingPlanSourceModel.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : <ReadingPlanSourceModel>[],
      disclaimer: json['disclaimer']?.toString() ?? '',
    );
  }
}

class ReadingCatalogueResult {
  const ReadingCatalogueResult({
    required this.id,
    required this.type,
    required this.title,
    required this.author,
    required this.publisher,
    required this.publishedDate,
    required this.language,
    required this.identifier,
    required this.source,
    required this.sourceUrl,
  });

  final String id;
  final String type;
  final String title;
  final String author;
  final String publisher;
  final String publishedDate;
  final String language;
  final String identifier;
  final String source;
  final String sourceUrl;

  ReadingItemModel toReadingItem({required String subject}) {
    return ReadingItemModel(
      id: '${source}_$id',
      type: type,
      title: title,
      author: author,
      publisher: publisher,
      publishedDate: publishedDate,
      subject: subject,
      language: language,
      identifier: identifier,
      source: source,
      sourceUrl: sourceUrl,
      userDifficulty: 'unknown',
      priority: 3,
    );
  }
}
