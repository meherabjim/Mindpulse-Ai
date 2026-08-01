import 'package:flutter/material.dart';

import '../../../core/settings/app_preferences_controller.dart';
import '../../ai/services/ai_mobile_service.dart';
import '../models/reading_plan_models.dart';
import '../services/reading_catalog_service.dart';
import '../services/reading_plan_repository.dart';

class AiGuideV3Screen extends StatefulWidget {
  const AiGuideV3Screen({super.key});

  @override
  State<AiGuideV3Screen> createState() => _AiGuideV3ScreenState();
}

class _AiGuideV3ScreenState extends State<AiGuideV3Screen> {
  final ReadingCatalogueService _catalogue = ReadingCatalogueService();
  final ReadingPlanRepository _repository = ReadingPlanRepository();
  final AiMobileService _aiService = AiMobileService();

  final TextEditingController _boardController = TextEditingController();
  final TextEditingController _degreeController = TextEditingController();
  final TextEditingController _majorController = TextEditingController();
  final TextEditingController _semesterController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _authorController = TextEditingController();
  final TextEditingController _itemSubjectController = TextEditingController();

  ReadingEducationProfile _profile = const ReadingEducationProfile.initial();
  ReadingAvailabilityModel _availability =
      const ReadingAvailabilityModel.initial();
  List<ReadingItemModel> _items = <ReadingItemModel>[];
  List<ReadingCatalogueResult> _results = <ReadingCatalogueResult>[];
  ReadingPlanResponseModel? _plan;

  int _currentStep = 0;
  bool _loading = true;
  bool _searching = false;
  bool _generating = false;
  String _contentType = 'textbook';
  String _goal = 'exam';
  DateTime? _targetDate;
  String? _notice;
  bool _noticeIsError = false;

  String _t(String english, String bangla) {
    return AppPreferencesController.instance.text(english, bangla);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _catalogue.dispose();
    _aiService.dispose();
    _boardController.dispose();
    _degreeController.dispose();
    _majorController.dispose();
    _semesterController.dispose();
    _subjectController.dispose();
    _searchController.dispose();
    _authorController.dispose();
    _itemSubjectController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final state = await _repository.load();
    if (!mounted) return;

    setState(() {
      _profile = state.profile;
      _availability = state.availability;
      _items = state.items;
      _goal = state.goal;
      _targetDate = state.targetDate;
      _plan = state.plan;
      _boardController.text = _profile.boardOrCurriculum;
      _degreeController.text = _profile.degree;
      _majorController.text = _profile.major;
      _semesterController.text = _profile.semester;
      _loading = false;
    });
  }

  Future<void> _save() {
    final updatedProfile = _profile.copyWith(
      boardOrCurriculum: _boardController.text.trim(),
      degree: _degreeController.text.trim(),
      major: _majorController.text.trim(),
      semester: _semesterController.text.trim(),
    );
    _profile = updatedProfile;

    return _repository.save(
      profile: _profile,
      items: _items,
      availability: _availability,
      goal: _goal,
      targetDate: _targetDate,
      plan: _plan,
    );
  }

  void _showNotice(String text, {bool error = false}) {
    setState(() {
      _notice = text;
      _noticeIsError = error;
    });
  }

  void _invalidatePlan() {
    _plan = null;
  }

  Future<void> _goToStep(int step) async {
    FocusScope.of(context).unfocus();
    await _save();
    if (!mounted) return;
    setState(() {
      _currentStep = step.clamp(0, 3).toInt();
      _notice = null;
    });
  }

  List<String> get _classOptions {
    if (_profile.educationSystem == 'madrasa') {
      return <String>[
        'pre_primary',
        'ibtedayi_1',
        'ibtedayi_2',
        'ibtedayi_3',
        'ibtedayi_4',
        'ibtedayi_5',
        'dakhil_6',
        'dakhil_7',
        'dakhil_8',
        'dakhil_9',
        'dakhil_10',
        'dakhil',
        'alim_1',
        'alim_2',
        'fazil',
        'kamil',
      ];
    }

    if (_profile.educationSystem == 'technical') {
      return <String>[
        'class_6',
        'class_7',
        'class_8',
        'vocational_9',
        'vocational_10',
        'ssc_vocational',
        'diploma_year_1',
        'diploma_year_2',
        'diploma_year_3',
        'diploma_year_4',
      ];
    }

    switch (_profile.educationLevel) {
      case 'preschool':
        return <String>['pre_primary', 'class_0'];
      case 'primary':
        return <String>['class_1', 'class_2', 'class_3', 'class_4', 'class_5'];
      case 'secondary':
        return <String>[
          'class_6',
          'class_7',
          'class_8',
          'class_9',
          'class_10',
          'ssc',
        ];
      case 'higher_secondary':
        return <String>['hsc_1', 'hsc_2'];
      case 'diploma':
        return <String>[
          'diploma_year_1',
          'diploma_year_2',
          'diploma_year_3',
          'diploma_year_4',
        ];
      case 'bachelor':
        return <String>['year_1', 'year_2', 'year_3', 'year_4', 'year_5'];
      case 'masters':
        return <String>['masters_year_1', 'masters_year_2'];
      case 'mphil_phd':
        return <String>['mphil', 'phd'];
      case 'professional':
        return <String>['professional'];
      default:
        return <String>['general_reader'];
    }
  }

  bool get _needsStream {
    return <String>{
      'class_9',
      'class_10',
      'ssc',
      'hsc_1',
      'hsc_2',
      'dakhil_9',
      'dakhil_10',
      'dakhil',
      'alim_1',
      'alim_2',
    }.contains(_profile.classOrYear);
  }

  List<String> get _suggestedSubjects {
    if (_profile.stream == 'science') {
      return <String>[
        _t('Bangla', 'বাংলা'),
        _t('English', 'ইংরেজি'),
        _t('Mathematics', 'গণিত'),
        _t('Higher Mathematics', 'উচ্চতর গণিত'),
        _t('Physics', 'পদার্থবিজ্ঞান'),
        _t('Chemistry', 'রসায়ন'),
        _t('Biology', 'জীববিজ্ঞান'),
        _t('ICT', 'আইসিটি'),
      ];
    }

    if (_profile.stream == 'humanities') {
      return <String>[
        _t('Bangla', 'বাংলা'),
        _t('English', 'ইংরেজি'),
        _t('History', 'ইতিহাস'),
        _t('Civics', 'পৌরনীতি'),
        _t('Geography', 'ভূগোল'),
        _t('Economics', 'অর্থনীতি'),
        _t('ICT', 'আইসিটি'),
      ];
    }

    if (_profile.stream == 'business') {
      return <String>[
        _t('Bangla', 'বাংলা'),
        _t('English', 'ইংরেজি'),
        _t('Accounting', 'হিসাববিজ্ঞান'),
        _t('Finance', 'ফিন্যান্স'),
        _t('Business Organization', 'ব্যবসায় সংগঠন'),
        _t('Economics', 'অর্থনীতি'),
        _t('ICT', 'আইসিটি'),
      ];
    }

    return <String>[
      _t('Bangla', 'বাংলা'),
      _t('English', 'ইংরেজি'),
      _t('Mathematics', 'গণিত'),
      _t('General Science', 'সাধারণ বিজ্ঞান'),
      _t('ICT', 'আইসিটি'),
    ];
  }

  void _addSubject([String? value]) {
    final subject = (value ?? _subjectController.text).trim();
    if (subject.isEmpty) return;
    if (_profile.subjects.any(
      (item) => item.toLowerCase() == subject.toLowerCase(),
    )) {
      _subjectController.clear();
      return;
    }

    setState(() {
      _profile = _profile.copyWith(
        subjects: <String>[..._profile.subjects, subject],
      );
      _subjectController.clear();
      _invalidatePlan();
    });
    _save();
  }

  void _removeSubject(String subject) {
    setState(() {
      _profile = _profile.copyWith(
        subjects: _profile.subjects.where((item) => item != subject).toList(),
      );
      _invalidatePlan();
    });
    _save();
  }

  Future<void> _searchCatalogue() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      _showNotice(
        _t(
          'Enter a book, magazine, article, paper title, ISBN or DOI.',
          'বই, ম্যাগাজিন, প্রবন্ধ, গবেষণাপত্রের নাম, ISBN অথবা DOI লিখুন।',
        ),
        error: true,
      );
      return;
    }

    setState(() {
      _searching = true;
      _results = <ReadingCatalogueResult>[];
      _notice = null;
    });

    try {
      final results = await _catalogue.search(
        query: query,
        author: _authorController.text.trim(),
        contentType: _contentType,
      );
      if (!mounted) return;
      setState(() {
        _results = results;
        _noticeIsError = results.isEmpty;
        _notice = results.isEmpty
            ? _t(
                'No reliable catalogue match was found. Check the spelling or add the item manually.',
                'নির্ভরযোগ্য ক্যাটালগ মিল পাওয়া যায়নি। বানান যাচাই করুন অথবা নিজে item যোগ করুন।',
              )
            : _t(
                'Select the exact result. MindPulse will not choose the first result automatically.',
                'সঠিক ফলাফলটি নিজে নির্বাচন করুন। MindPulse প্রথম ফলাফল স্বয়ংক্রিয়ভাবে নেবে না।',
              );
      });
    } catch (error) {
      if (!mounted) return;
      _showNotice(
        _t(
          'The online catalogue is unavailable. No identity or difficulty was guessed. $error',
          'অনলাইন ক্যাটালগ পাওয়া যাচ্ছে না। কোনো পরিচয় বা কঠিনতা অনুমান করা হয়নি। $error',
        ),
        error: true,
      );
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _addResult(ReadingCatalogueResult result) async {
    if (_items.length >= 30) {
      _showNotice(
        _t(
          'You can select up to 30 reading items.',
          'সর্বোচ্চ ৩০টি reading item নির্বাচন করা যাবে।',
        ),
        error: true,
      );
      return;
    }

    final duplicate = _items.any(
      (item) =>
          item.id == '${result.source}_${result.id}' ||
          (item.title.toLowerCase() == result.title.toLowerCase() &&
              item.author.toLowerCase() == result.author.toLowerCase()),
    );
    if (duplicate) {
      _showNotice(
        _t('This item is already selected.', 'এই item আগে থেকেই নির্বাচিত।'),
        error: true,
      );
      return;
    }

    setState(() {
      _items.add(
        result.toReadingItem(subject: _itemSubjectController.text.trim()),
      );
      _results = <ReadingCatalogueResult>[];
      _searchController.clear();
      _authorController.clear();
      _itemSubjectController.clear();
      _invalidatePlan();
      _notice = _t(
        'Verified catalogue metadata added. Difficulty remains unknown until you rate it.',
        'যাচাইকৃত ক্যাটালগ metadata যোগ হয়েছে। আপনি rating না দেওয়া পর্যন্ত কঠিনতা অনির্ধারিত থাকবে।',
      );
      _noticeIsError = false;
    });
    await _save();
  }

  Future<void> _addManualItem() async {
    final titleController = TextEditingController(text: _searchController.text);
    final authorController = TextEditingController(
      text: _authorController.text,
    );
    final subjectController = TextEditingController(
      text: _itemSubjectController.text,
    );
    final publisherController = TextEditingController();
    final identifierController = TextEditingController();
    String selectedSource = _contentType == 'textbook' ? 'nctb' : 'manual';

    final item = await showDialog<ReadingItemModel>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(_t('Add reading item', 'Reading item যোগ করুন')),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          labelText: _t('Title *', 'নাম *'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: authorController,
                        decoration: InputDecoration(
                          labelText: _t('Author', 'লেখক'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: subjectController,
                        decoration: InputDecoration(
                          labelText: _t('Subject or topic', 'বিষয় বা topic'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: publisherController,
                        decoration: InputDecoration(
                          labelText: _t('Publisher', 'প্রকাশক'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: identifierController,
                        decoration: InputDecoration(
                          labelText: _t(
                            'ISBN, DOI or identifier',
                            'ISBN, DOI বা identifier',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey<String>(selectedSource),
                        initialValue: selectedSource,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: _t('Information source', 'তথ্যের উৎস'),
                        ),
                        items: const <String>['manual', 'nctb']
                            .map(
                              (value) => DropdownMenuItem<String>(
                                value: value,
                                child: Text(_sourceLabel(value)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => selectedSource = value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(_t('Cancel', 'বাতিল')),
                ),
                FilledButton(
                  onPressed: () {
                    final title = titleController.text.trim();
                    if (title.isEmpty) return;
                    Navigator.of(context).pop(
                      ReadingItemModel(
                        id: 'manual_${DateTime.now().microsecondsSinceEpoch}',
                        type: _contentType,
                        title: title,
                        author: authorController.text.trim(),
                        publisher: publisherController.text.trim(),
                        publishedDate: '',
                        subject: subjectController.text.trim(),
                        language: '',
                        identifier: identifierController.text.trim(),
                        source: selectedSource,
                        sourceUrl: '',
                        userDifficulty: 'unknown',
                        priority: 3,
                      ),
                    );
                  },
                  child: Text(_t('Add', 'যোগ করুন')),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    authorController.dispose();
    subjectController.dispose();
    publisherController.dispose();
    identifierController.dispose();

    if (item == null || !mounted) return;
    if (_items.length >= 30) {
      _showNotice(
        _t('Maximum 30 items are supported.', 'সর্বোচ্চ ৩০টি item রাখা যাবে।'),
        error: true,
      );
      return;
    }

    setState(() {
      _items.add(item);
      _invalidatePlan();
      _notice = _t('Reading item added.', 'Reading item যোগ হয়েছে।');
      _noticeIsError = false;
    });
    await _save();
  }

  Future<void> _updateItem(
    ReadingItemModel item, {
    String? difficulty,
    int? priority,
  }) async {
    final index = _items.indexWhere((candidate) => candidate.id == item.id);
    if (index < 0) return;
    setState(() {
      _items[index] = item.copyWith(
        userDifficulty: difficulty,
        priority: priority,
      );
      _invalidatePlan();
    });
    await _save();
  }

  Future<void> _removeItem(ReadingItemModel item) async {
    setState(() {
      _items.removeWhere((candidate) => candidate.id == item.id);
      _invalidatePlan();
    });
    await _save();
  }

  Future<void> _pickTargetDate() async {
    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (result == null || !mounted) return;
    setState(() {
      _targetDate = result;
      _invalidatePlan();
    });
    await _save();
  }

  Future<void> _pickStartTime() async {
    final current = TimeOfDay(
      hour: _availability.preferredStartMinutes ~/ 60,
      minute: _availability.preferredStartMinutes % 60,
    );
    final result = await showTimePicker(context: context, initialTime: current);
    if (result == null || !mounted) return;
    setState(() {
      _availability = _availability.copyWith(
        preferredStartMinutes: result.hour * 60 + result.minute,
      );
      _invalidatePlan();
    });
    await _save();
  }

  void _toggleDay(String day) {
    final days = <String>[..._availability.preferredDays];
    if (days.contains(day)) {
      if (days.length == 1) {
        _showNotice(
          _t('Keep at least one reading day.', 'কমপক্ষে একটি পড়ার দিন রাখুন।'),
          error: true,
        );
        return;
      }
      days.remove(day);
    } else {
      days.add(day);
    }

    setState(() {
      _availability = _availability.copyWith(preferredDays: days);
      _invalidatePlan();
    });
    _save();
  }

  Future<void> _generatePlan() async {
    FocusScope.of(context).unfocus();

    if (_items.isEmpty) {
      _showNotice(
        _t(
          'Select at least one book, magazine, article, paper or own material.',
          'কমপক্ষে একটি বই, ম্যাগাজিন, প্রবন্ধ, গবেষণাপত্র অথবা নিজের material নির্বাচন করুন।',
        ),
        error: true,
      );
      return;
    }

    if (_profile.subjects.isEmpty &&
        _profile.educationLevel != 'general_reader') {
      _showNotice(
        _t(
          'Add at least one subject so the plan can explain its priorities.',
          'পরিকল্পনার অগ্রাধিকার ব্যাখ্যা করার জন্য কমপক্ষে একটি বিষয় যোগ করুন।',
        ),
        error: true,
      );
      return;
    }

    setState(() {
      _generating = true;
      _notice = null;
    });

    try {
      await _save();
      final plan = await _aiService.generateReadingPlan(
        ReadingPlanRequestModel(
          profile: _profile,
          items: _items,
          availability: _availability,
          goal: _goal,
          targetDate: _targetDate,
        ),
      );
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _notice = _t(
          'A transparent plan was generated. Review the reasons and assumptions before using it.',
          'একটি স্বচ্ছ পরিকল্পনা তৈরি হয়েছে। ব্যবহার করার আগে কারণ ও assumptions যাচাই করুন।',
        );
        _noticeIsError = false;
      });
      await _save();
    } catch (error) {
      if (!mounted) return;
      _showNotice(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _addNextSessionToMyDay() async {
    final plan = _plan;
    if (plan == null || plan.sessions.isEmpty) return;

    const weekdayCodes = <int, String>{
      DateTime.monday: 'mon',
      DateTime.tuesday: 'tue',
      DateTime.wednesday: 'wed',
      DateTime.thursday: 'thu',
      DateTime.friday: 'fri',
      DateTime.saturday: 'sat',
      DateTime.sunday: 'sun',
    };
    final today = weekdayCodes[DateTime.now().weekday];
    final session = plan.sessions.firstWhere(
      (item) => item.day == today,
      orElse: () => plan.sessions.first,
    );

    await _repository.addSessionToMyDay(session);
    if (!mounted) return;
    _showNotice(
      _t(
        'The next suitable session was added to My Day.',
        'পরবর্তী উপযুক্ত সেশন My Day-এ যোগ হয়েছে।',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('AI Reading Guide', 'AI পড়াশোনা গাইড')),
        actions: [
          IconButton(
            tooltip: _t('Save', 'সংরক্ষণ'),
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildProgressHeader(context),
            if (_notice != null) _buildNotice(context),
            Expanded(
              child: IndexedStack(
                index: _currentStep,
                children: [
                  _buildProfileStep(context),
                  _buildMaterialsStep(context),
                  _buildTimeStep(context),
                  _buildPlanStep(context),
                ],
              ),
            ),
            _buildBottomActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressHeader(BuildContext context) {
    final labels = <String>[
      _t('Profile', 'প্রোফাইল'),
      _t('Materials', 'পাঠ্য'),
      _t('Time', 'সময়'),
      _t('Plan', 'পরিকল্পনা'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: List<Widget>.generate(labels.length, (index) {
          final selected = index == _currentStep;
          final completed = index < _currentStep;
          return Expanded(
            child: InkWell(
              onTap: () => _goToStep(index),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 5,
                      decoration: BoxDecoration(
                        color: selected || completed
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      labels[index],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNotice(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Material(
        color: _noticeIsError
            ? colorScheme.errorContainer
            : colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _noticeIsError
                    ? Icons.error_outline_rounded
                    : Icons.info_outline_rounded,
                color: _noticeIsError
                    ? colorScheme.onErrorContainer
                    : colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(_notice!)),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _notice = null),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepScroll(List<Widget> children) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: children,
    );
  }

  Widget _buildProfileStep(BuildContext context) {
    final classOptions = _classOptions;
    final classValue = classOptions.contains(_profile.classOrYear)
        ? _profile.classOrYear
        : classOptions.first;

    return _stepScroll([
      _introCard(
        context,
        icon: Icons.school_outlined,
        title: _t('Tell us how you learn', 'আপনার শিক্ষার ধরন জানান'),
        body: _t(
          'Class, curriculum, subjects and degree details are stored separately so the plan does not confuse SSC, HSC, BSc or general reading.',
          'শ্রেণি, শিক্ষাক্রম, বিষয় এবং degree আলাদাভাবে রাখা হয়—যাতে SSC, HSC, BSc বা সাধারণ পাঠ একসঙ্গে গুলিয়ে না যায়।',
        ),
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        key: ValueKey<String>('system_${_profile.educationSystem}'),
        initialValue: _profile.educationSystem,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: _t('Education system', 'শিক্ষাব্যবস্থা'),
        ),
        items:
            const <String>[
                  'general',
                  'madrasa',
                  'technical',
                  'international',
                  'higher_education',
                  'professional',
                  'self_learning',
                ]
                .map(
                  (value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(_educationSystemLabel(value)),
                  ),
                )
                .toList(),
        onChanged: (value) {
          if (value == null) return;
          setState(() {
            _profile = _profile.copyWith(educationSystem: value);
            final options = _classOptions;
            if (!options.contains(_profile.classOrYear)) {
              _profile = _profile.copyWith(classOrYear: options.first);
            }
            _invalidatePlan();
          });
          _save();
        },
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        key: ValueKey<String>('level_${_profile.educationLevel}'),
        initialValue: _profile.educationLevel,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: _t('Education level', 'শিক্ষার ধাপ'),
        ),
        items:
            const <String>[
                  'preschool',
                  'primary',
                  'secondary',
                  'higher_secondary',
                  'diploma',
                  'bachelor',
                  'masters',
                  'mphil_phd',
                  'professional',
                  'general_reader',
                ]
                .map(
                  (value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(_educationLevelLabel(value)),
                  ),
                )
                .toList(),
        onChanged: (value) {
          if (value == null) return;
          setState(() {
            _profile = _profile.copyWith(educationLevel: value);
            final options = _classOptions;
            _profile = _profile.copyWith(classOrYear: options.first);
            _invalidatePlan();
          });
          _save();
        },
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        key: ValueKey<String>('class_$classValue'),
        initialValue: classValue,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: _t(
            'Current class, year or stage',
            'বর্তমান শ্রেণি, বর্ষ বা ধাপ',
          ),
        ),
        items: classOptions
            .map(
              (value) => DropdownMenuItem<String>(
                value: value,
                child: Text(_classLabel(value)),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value == null) return;
          setState(() {
            _profile = _profile.copyWith(classOrYear: value);
            _invalidatePlan();
          });
          _save();
        },
      ),
      if (_needsStream) ...[
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey<String>('stream_${_profile.stream}'),
          initialValue:
              <String>[
                'science',
                'humanities',
                'business',
                'general',
              ].contains(_profile.stream)
              ? _profile.stream
              : 'science',
          isExpanded: true,
          decoration: InputDecoration(
            labelText: _t('Group or stream', 'বিভাগ বা শাখা'),
          ),
          items: const <String>['science', 'humanities', 'business', 'general']
              .map(
                (value) => DropdownMenuItem<String>(
                  value: value,
                  child: Text(_streamLabel(value)),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _profile = _profile.copyWith(stream: value);
              _invalidatePlan();
            });
            _save();
          },
        ),
      ],
      const SizedBox(height: 12),
      TextField(
        controller: _boardController,
        decoration: InputDecoration(
          labelText: _t('Board or curriculum', 'বোর্ড বা শিক্ষাক্রম'),
          hintText: _t(
            'Example: Dhaka Board, NCTB, Cambridge',
            'যেমন: ঢাকা বোর্ড, NCTB, Cambridge',
          ),
        ),
        onChanged: (_) {
          _invalidatePlan();
          _save();
        },
      ),
      if (_profile.needsDegreeDetails) ...[
        const SizedBox(height: 12),
        TextField(
          controller: _degreeController,
          decoration: InputDecoration(
            labelText: _t('Degree or programme', 'ডিগ্রি বা programme'),
            hintText: _t('Example: BSc, BA, MSc', 'যেমন: BSc, BA, MSc'),
          ),
          onChanged: (_) {
            _invalidatePlan();
            _save();
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _majorController,
          decoration: InputDecoration(
            labelText: _t('Major or department', 'Major বা বিভাগ'),
            hintText: _t('Example: CSE, Physics', 'যেমন: CSE, Physics'),
          ),
          onChanged: (_) {
            _invalidatePlan();
            _save();
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _semesterController,
          decoration: InputDecoration(
            labelText: _t(
              'Semester or year details',
              'Semester বা বর্ষের বিস্তারিত',
            ),
          ),
          onChanged: (_) {
            _invalidatePlan();
            _save();
          },
        ),
      ],
      const SizedBox(height: 18),
      Text(
        _t('Subjects', 'বিষয়সমূহ'),
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _subjectController,
              textInputAction: TextInputAction.done,
              onSubmitted: _addSubject,
              decoration: InputDecoration(
                hintText: _t('Add a subject', 'একটি বিষয় যোগ করুন'),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: _addSubject,
            icon: const Icon(Icons.add_rounded),
            label: Text(_t('Add', 'যোগ')),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _profile.subjects
            .map(
              (subject) => InputChip(
                label: Text(subject),
                onDeleted: () => _removeSubject(subject),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 12),
      Text(
        _t('Suggestions', 'পরামর্শ'),
        style: Theme.of(context).textTheme.labelLarge,
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _suggestedSubjects
            .where((item) => !_profile.subjects.contains(item))
            .map(
              (subject) => ActionChip(
                label: Text(subject),
                avatar: const Icon(Icons.add_rounded, size: 18),
                onPressed: () => _addSubject(subject),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        key: ValueKey<String>('language_${_profile.preferredLanguage}'),
        initialValue: _profile.preferredLanguage,
        decoration: InputDecoration(
          labelText: _t('Plan language', 'পরিকল্পনার ভাষা'),
        ),
        items: const <String>['bn', 'en', 'both']
            .map(
              (value) => DropdownMenuItem<String>(
                value: value,
                child: Text(_languageLabel(value)),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value == null) return;
          setState(() {
            _profile = _profile.copyWith(preferredLanguage: value);
            _invalidatePlan();
          });
          _save();
        },
      ),
    ]);
  }

  Widget _buildMaterialsStep(BuildContext context) {
    return _stepScroll([
      _introCard(
        context,
        icon: Icons.menu_book_outlined,
        title: _t(
          'Choose exactly what you will read',
          'আপনি যা পড়বেন ঠিক সেটিই নির্বাচন করুন',
        ),
        body: _t(
          'Select 1–30 textbooks, books, novels, magazines, articles, research papers or your own material. No random filler is added.',
          '১–৩০টি পাঠ্যবই, বই, উপন্যাস, ম্যাগাজিন, প্রবন্ধ, গবেষণাপত্র বা নিজের material নির্বাচন করুন। কোনো random item যোগ হবে না।',
        ),
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        key: ValueKey<String>('content_$_contentType'),
        initialValue: _contentType,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: _t('Content type', 'পাঠ্যের ধরন'),
        ),
        items:
            const <String>[
                  'textbook',
                  'supplementary',
                  'book',
                  'novel',
                  'magazine',
                  'article',
                  'research_paper',
                  'own_material',
                ]
                .map(
                  (value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(_contentTypeLabel(value)),
                  ),
                )
                .toList(),
        onChanged: (value) {
          if (value == null) return;
          setState(() {
            _contentType = value;
            _results = <ReadingCatalogueResult>[];
          });
        },
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _searchController,
        decoration: InputDecoration(
          labelText: _t('Title, ISBN or DOI', 'নাম, ISBN অথবা DOI'),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _authorController,
        decoration: InputDecoration(
          labelText: _t('Author (optional)', 'লেখক (ঐচ্ছিক)'),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _itemSubjectController,
        decoration: InputDecoration(
          labelText: _t('Subject or topic', 'বিষয় বা topic'),
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          FilledButton.icon(
            onPressed: _searching || _contentType == 'own_material'
                ? null
                : _searchCatalogue,
            icon: _searching
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search_rounded),
            label: Text(
              <String>{'article', 'research_paper'}.contains(_contentType)
                  ? _t('Search Crossref', 'Crossref-এ খুঁজুন')
                  : _t('Search Google Books', 'Google Books-এ খুঁজুন'),
            ),
          ),
          OutlinedButton.icon(
            onPressed: _addManualItem,
            icon: const Icon(Icons.edit_note_rounded),
            label: Text(_t('Add manually', 'নিজে যোগ করুন')),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _sourceExplanation(context),
      if (_results.isNotEmpty) ...[
        const SizedBox(height: 18),
        Text(
          _t('Catalogue results', 'ক্যাটালগ ফলাফল'),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ..._results.map((result) => _resultCard(context, result)),
      ],
      const SizedBox(height: 20),
      Row(
        children: [
          Expanded(
            child: Text(
              _t(
                'Selected items (${_items.length})',
                'নির্বাচিত item (${_items.length})',
              ),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Text(_t('User decides the count', 'সংখ্যা user ঠিক করবেন')),
        ],
      ),
      const SizedBox(height: 8),
      if (_items.isEmpty)
        _emptyCard(
          context,
          _t(
            'No item selected yet. One item is enough to create a plan.',
            'এখনো কোনো item নির্বাচন করা হয়নি। একটি item দিয়েও plan তৈরি হবে।',
          ),
        )
      else
        ..._items.map((item) => _selectedItemCard(context, item)),
    ]);
  }

  Widget _buildTimeStep(BuildContext context) {
    const days = <String>['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    return _stepScroll([
      _introCard(
        context,
        icon: Icons.schedule_outlined,
        title: _t('Set a realistic rhythm', 'বাস্তবসম্মত পড়ার ছন্দ ঠিক করুন'),
        body: _t(
          'The service uses your chosen days, time, session length, priorities and target date. It does not invent free time.',
          'Service আপনার নির্বাচিত দিন, সময়, session length, priority ও target date ব্যবহার করে। এটি নিজে থেকে free time বানায় না।',
        ),
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        key: ValueKey<String>('goal_$_goal'),
        initialValue: _goal,
        isExpanded: true,
        decoration: InputDecoration(labelText: _t('Main goal', 'মূল লক্ষ্য')),
        items:
            const <String>[
                  'exam',
                  'syllabus',
                  'university',
                  'skill',
                  'research',
                  'general_reading',
                  'enjoyment',
                ]
                .map(
                  (value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(_goalLabel(value)),
                  ),
                )
                .toList(),
        onChanged: (value) {
          if (value == null) return;
          setState(() {
            _goal = value;
            _invalidatePlan();
          });
          _save();
        },
      ),
      const SizedBox(height: 12),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.event_outlined),
        title: Text(_t('Target date', 'Target date')),
        subtitle: Text(
          _targetDate == null
              ? _t('Not set', 'দেওয়া হয়নি')
              : _formatDate(_targetDate!),
        ),
        trailing: Wrap(
          spacing: 4,
          children: [
            if (_targetDate != null)
              IconButton(
                tooltip: _t('Clear date', 'তারিখ মুছুন'),
                onPressed: () {
                  setState(() {
                    _targetDate = null;
                    _invalidatePlan();
                  });
                  _save();
                },
                icon: const Icon(Icons.close_rounded),
              ),
            FilledButton.tonal(
              onPressed: _pickTargetDate,
              child: Text(_t('Choose', 'বাছুন')),
            ),
          ],
        ),
      ),
      const Divider(),
      Text(
        _t(
          'Session length: ${_availability.sessionMinutes} minutes',
          'প্রতি session: ${_availability.sessionMinutes} মিনিট',
        ),
        style: Theme.of(context).textTheme.titleSmall,
      ),
      Slider(
        value: _availability.sessionMinutes.toDouble(),
        min: 10,
        max: 120,
        divisions: 22,
        label: '${_availability.sessionMinutes}',
        onChanged: (value) {
          setState(() {
            _availability = _availability.copyWith(
              sessionMinutes: value.round(),
            );
            _invalidatePlan();
          });
        },
        onChangeEnd: (_) => _save(),
      ),
      Text(
        _t(
          'Sessions per week: ${_availability.sessionsPerWeek}',
          'সপ্তাহে session: ${_availability.sessionsPerWeek}',
        ),
        style: Theme.of(context).textTheme.titleSmall,
      ),
      Slider(
        value: _availability.sessionsPerWeek.toDouble(),
        min: 1,
        max: 14,
        divisions: 13,
        label: '${_availability.sessionsPerWeek}',
        onChanged: (value) {
          setState(() {
            _availability = _availability.copyWith(
              sessionsPerWeek: value.round(),
            );
            _invalidatePlan();
          });
        },
        onChangeEnd: (_) => _save(),
      ),
      const SizedBox(height: 8),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.access_time_rounded),
        title: Text(_t('Preferred start time', 'পছন্দের শুরুর সময়')),
        subtitle: Text(_formatClock(_availability.preferredStartMinutes)),
        trailing: FilledButton.tonal(
          onPressed: _pickStartTime,
          child: Text(_t('Change', 'পরিবর্তন')),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        _t('Reading days', 'পড়ার দিন'),
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: days
            .map(
              (day) => FilterChip(
                label: Text(_dayLabel(day)),
                selected: _availability.preferredDays.contains(day),
                onSelected: (_) => _toggleDay(day),
              ),
            )
            .toList(),
      ),
    ]);
  }

  Widget _buildPlanStep(BuildContext context) {
    final plan = _plan;
    return _stepScroll([
      _introCard(
        context,
        icon: Icons.auto_awesome_rounded,
        title: _t('Explainable plan', 'ব্যাখ্যাযোগ্য পরিকল্পনা'),
        body: _t(
          'The backend creates a transparent schedule from your inputs. Google Books and Crossref verify catalogue identity; they are not presented as personal difficulty ratings.',
          'Backend আপনার input থেকে স্বচ্ছ schedule তৈরি করে। Google Books ও Crossref catalogue পরিচয় যাচাই করে; এগুলোকে ব্যক্তিগত difficulty rating হিসেবে দেখানো হয় না।',
        ),
      ),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _generating ? null : _generatePlan,
          icon: _generating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome_rounded),
          label: Text(
            _generating
                ? _t('Generating...', 'তৈরি হচ্ছে...')
                : _t(
                    'Generate my reading plan',
                    'আমার পড়ার পরিকল্পনা তৈরি করুন',
                  ),
          ),
        ),
      ),
      const SizedBox(height: 16),
      if (plan == null)
        _emptyCard(
          context,
          _t(
            'Complete the first three steps and generate a plan. The number of sessions and items comes from your choices.',
            'প্রথম তিনটি ধাপ পূরণ করে plan তৈরি করুন। item ও session-এর সংখ্যা আপনার পছন্দ থেকে আসবে।',
          ),
        )
      else ...[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_outlined),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _t('Plan summary', 'পরিকল্পনার সারাংশ'),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Chip(
                      label: Text(
                        '${(plan.overallConfidence * 100).round()}% ${_t('evidence', 'evidence')}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(plan.summary),
                const SizedBox(height: 8),
                Text(
                  plan.disclaimer,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _t('Weekly sessions', 'সাপ্তাহিক session'),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ...plan.sessions.map((session) => _sessionCard(context, session)),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _addNextSessionToMyDay,
            icon: const Icon(Icons.today_outlined),
            label: Text(
              _t(
                'Add next suitable session to My Day',
                'পরবর্তী উপযুক্ত session My Day-এ যোগ করুন',
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        _detailExpansion(
          context,
          title: _t('Difficulty evidence', 'Difficulty evidence'),
          children: plan.difficultyAssessments
              .map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_difficultyLabel(item.label)),
                  subtitle: Text(item.note),
                  trailing: Text('${(item.confidence * 100).round()}%'),
                ),
              )
              .toList(),
        ),
        _detailExpansion(
          context,
          title: _t('Assumptions', 'Assumptions'),
          children: plan.assumptions
              .map(
                (item) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.check_circle_outline_rounded),
                  title: Text(item),
                ),
              )
              .toList(),
        ),
        _detailExpansion(
          context,
          title: _t('Metadata sources', 'Metadata sources'),
          children: plan.sources
              .map(
                (source) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(source.name),
                  subtitle: Text(source.usage),
                ),
              )
              .toList(),
        ),
      ],
    ]);
  }

  Widget _buildBottomActions(BuildContext context) {
    return Material(
      elevation: 6,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              if (_currentStep > 0)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _goToStep(_currentStep - 1),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: Text(_t('Back', 'পেছনে')),
                  ),
                ),
              if (_currentStep > 0) const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _currentStep < 3
                      ? () => _goToStep(_currentStep + 1)
                      : _generatePlan,
                  icon: Icon(
                    _currentStep < 3
                        ? Icons.arrow_forward_rounded
                        : Icons.auto_awesome_rounded,
                  ),
                  label: Text(
                    _currentStep < 3
                        ? _t('Save and continue', 'সংরক্ষণ করে এগিয়ে যান')
                        : _t('Generate again', 'আবার তৈরি করুন'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _introCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String body,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colors.onPrimaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    body,
                    style: TextStyle(color: colors.onPrimaryContainer),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sourceExplanation(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          <String>{'article', 'research_paper'}.contains(_contentType)
              ? _t(
                  'Crossref verifies scholarly metadata such as DOI, title, author and publisher. It does not rate personal difficulty.',
                  'Crossref DOI, নাম, লেখক ও প্রকাশকের scholarly metadata যাচাই করে। এটি ব্যক্তিগত কঠিনতার rating দেয় না।',
                )
              : _t(
                  'Google Books verifies catalogue metadata such as title, author, edition identifiers and book/magazine type. It does not provide an authoritative personal difficulty rating.',
                  'Google Books নাম, লেখক, edition identifier এবং বই/ম্যাগাজিনের ধরন যাচাই করে। এটি নির্ভরযোগ্য ব্যক্তিগত difficulty rating দেয় না।',
                ),
        ),
      ),
    );
  }

  Widget _resultCard(BuildContext context, ReadingCatalogueResult result) {
    final details = <String>[
      if (result.author.isNotEmpty) result.author,
      if (result.publisher.isNotEmpty) result.publisher,
      if (result.publishedDate.isNotEmpty) result.publishedDate,
      if (result.identifier.isNotEmpty) result.identifier,
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    result.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Chip(label: Text(_sourceLabel(result.source))),
              ],
            ),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(details.join(' • ')),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: () => _addResult(result),
                icon: const Icon(Icons.add_rounded),
                label: Text(_t('Select this result', 'এই ফলাফল নির্বাচন করুন')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectedItemCard(BuildContext context, ReadingItemModel item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_contentTypeIcon(item.type)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (item.author.isNotEmpty) Text(item.author),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          Chip(label: Text(_contentTypeLabel(item.type))),
                          Chip(label: Text(_sourceLabel(item.source))),
                          if (item.subject.isNotEmpty)
                            Chip(label: Text(item.subject)),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: _t('Remove', 'সরান'),
                  onPressed: () => _removeItem(item),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey<String>('${item.id}_${item.userDifficulty}'),
                    initialValue: item.userDifficulty,
                    decoration: InputDecoration(
                      labelText: _t('Your difficulty', 'আপনার কাছে কঠিনতা'),
                      isDense: true,
                    ),
                    items: const <String>['unknown', 'easy', 'medium', 'hard']
                        .map(
                          (value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(_difficultyLabel(value)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        _updateItem(item, difficulty: value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: ValueKey<String>(
                      'priority_${item.id}_${item.priority}',
                    ),
                    initialValue: item.priority,
                    decoration: InputDecoration(
                      labelText: _t('Priority', 'অগ্রাধিকার'),
                      isDense: true,
                    ),
                    items: List<DropdownMenuItem<int>>.generate(
                      5,
                      (index) => DropdownMenuItem<int>(
                        value: index + 1,
                        child: Text('${index + 1} / 5'),
                      ),
                    ),
                    onChanged: (value) {
                      if (value != null) {
                        _updateItem(item, priority: value);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sessionCard(BuildContext context, ReadingPlanSessionModel session) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Text(
                    session.dayLabel.isEmpty
                        ? '?'
                        : session.dayLabel.substring(0, 1),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${session.dayLabel} • ${_formatClock(session.startMinutes)}',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      Text(
                        session.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    '${session.durationMinutes} ${_t('min', 'মিনিট')}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(session.focus),
            const SizedBox(height: 6),
            Text(session.reason, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                Chip(label: Text(_difficultyLabel(session.difficulty))),
                Chip(
                  label: Text(
                    '${(session.confidence * 100).round()}% ${_t('evidence', 'evidence')}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailExpansion(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: children,
      ),
    );
  }

  Widget _emptyCard(BuildContext context, String text) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.inbox_outlined),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }

  String _educationSystemLabel(String value) {
    const values = <String, List<String>>{
      'general': ['General education', 'সাধারণ শিক্ষা'],
      'madrasa': ['Madrasa education', 'মাদ্রাসা শিক্ষা'],
      'technical': ['Technical or vocational', 'কারিগরি বা ভোকেশনাল'],
      'international': ['International curriculum', 'আন্তর্জাতিক শিক্ষাক্রম'],
      'higher_education': ['Higher education', 'উচ্চশিক্ষা'],
      'professional': ['Professional education', 'পেশাগত শিক্ষা'],
      'self_learning': ['Self-learning', 'স্বশিক্ষা'],
    };
    return _pair(values[value] ?? <String>[value, value]);
  }

  String _educationLevelLabel(String value) {
    const values = <String, List<String>>{
      'preschool': ['Pre-primary / Class 0', 'প্রাক-প্রাথমিক / শ্রেণি ০'],
      'primary': ['Primary', 'প্রাথমিক'],
      'secondary': ['Secondary / SSC', 'মাধ্যমিক / SSC'],
      'higher_secondary': ['Higher secondary / HSC', 'উচ্চ মাধ্যমিক / HSC'],
      'diploma': ['Diploma', 'ডিপ্লোমা'],
      'bachelor': ['Bachelor / BSc / BA', 'স্নাতক / BSc / BA'],
      'masters': ['Masters / MSc / MA', 'স্নাতকোত্তর / MSc / MA'],
      'mphil_phd': ['MPhil / PhD', 'MPhil / PhD'],
      'professional': ['Professional programme', 'পেশাগত programme'],
      'general_reader': ['General reader', 'সাধারণ পাঠক'],
    };
    return _pair(values[value] ?? <String>[value, value]);
  }

  String _classLabel(String value) {
    final numericClass = RegExp(r'^class_(\d+)$').firstMatch(value);
    if (numericClass != null) {
      final number = numericClass.group(1)!;
      return _t('Class $number', 'শ্রেণি $number');
    }

    const values = <String, List<String>>{
      'pre_primary': ['Pre-primary', 'প্রাক-প্রাথমিক'],
      'ssc': ['SSC candidate', 'SSC পরীক্ষার্থী'],
      'hsc_1': ['HSC first year', 'HSC প্রথম বর্ষ'],
      'hsc_2': ['HSC second year', 'HSC দ্বিতীয় বর্ষ'],
      'general_reader': ['General reader', 'সাধারণ পাঠক'],
      'professional': ['Professional stage', 'পেশাগত ধাপ'],
      'mphil': ['MPhil', 'MPhil'],
      'phd': ['PhD', 'PhD'],
      'dakhil': ['Dakhil candidate', 'দাখিল পরীক্ষার্থী'],
      'alim_1': ['Alim first year', 'আলিম প্রথম বর্ষ'],
      'alim_2': ['Alim second year', 'আলিম দ্বিতীয় বর্ষ'],
      'fazil': ['Fazil', 'ফাজিল'],
      'kamil': ['Kamil', 'কামিল'],
      'ssc_vocational': ['SSC Vocational', 'SSC ভোকেশনাল'],
      'vocational_9': ['Vocational Class 9', 'ভোকেশনাল শ্রেণি ৯'],
      'vocational_10': ['Vocational Class 10', 'ভোকেশনাল শ্রেণি ১০'],
      'masters_year_1': ['Masters first year', 'মাস্টার্স প্রথম বর্ষ'],
      'masters_year_2': ['Masters second year', 'মাস্টার্স দ্বিতীয় বর্ষ'],
    };

    final yearMatch = RegExp(r'^(?:diploma_)?year_(\d+)$').firstMatch(value);
    if (yearMatch != null) {
      final number = yearMatch.group(1)!;
      return _t('Year $number', 'বর্ষ $number');
    }

    final diplomaMatch = RegExp(r'^diploma_year_(\d+)$').firstMatch(value);
    if (diplomaMatch != null) {
      final number = diplomaMatch.group(1)!;
      return _t('Diploma year $number', 'ডিপ্লোমা বর্ষ $number');
    }

    final ibtedayiMatch = RegExp(r'^ibtedayi_(\d+)$').firstMatch(value);
    if (ibtedayiMatch != null) {
      final number = ibtedayiMatch.group(1)!;
      return _t('Ibtedayi $number', 'ইবতেদায়ী $number');
    }

    final dakhilMatch = RegExp(r'^dakhil_(\d+)$').firstMatch(value);
    if (dakhilMatch != null) {
      final number = dakhilMatch.group(1)!;
      return _t('Dakhil Class $number', 'দাখিল শ্রেণি $number');
    }

    return _pair(values[value] ?? <String>[value, value]);
  }

  String _streamLabel(String value) {
    const values = <String, List<String>>{
      'science': ['Science', 'বিজ্ঞান'],
      'humanities': ['Humanities', 'মানবিক'],
      'business': ['Business studies', 'ব্যবসায় শিক্ষা'],
      'general': ['General', 'সাধারণ'],
    };
    return _pair(values[value] ?? <String>[value, value]);
  }

  String _languageLabel(String value) {
    const values = <String, List<String>>{
      'bn': ['Bangla', 'বাংলা'],
      'en': ['English', 'ইংরেজি'],
      'both': ['Bangla and English', 'বাংলা ও ইংরেজি'],
    };
    return _pair(values[value] ?? <String>[value, value]);
  }

  String _contentTypeLabel(String value) {
    const values = <String, List<String>>{
      'textbook': ['Textbook', 'পাঠ্যবই'],
      'supplementary': ['Supplementary book', 'সহায়ক বই'],
      'book': ['General book', 'সাধারণ বই'],
      'novel': ['Novel or story', 'উপন্যাস বা গল্প'],
      'magazine': ['Magazine', 'ম্যাগাজিন'],
      'article': ['Article', 'প্রবন্ধ'],
      'research_paper': ['Research paper', 'গবেষণাপত্র'],
      'own_material': ['Own PDF or notes', 'নিজের PDF বা note'],
    };
    return _pair(values[value] ?? <String>[value, value]);
  }

  IconData _contentTypeIcon(String value) {
    switch (value) {
      case 'textbook':
        return Icons.school_outlined;
      case 'supplementary':
        return Icons.library_books_outlined;
      case 'novel':
        return Icons.auto_stories_outlined;
      case 'magazine':
        return Icons.newspaper_outlined;
      case 'article':
        return Icons.article_outlined;
      case 'research_paper':
        return Icons.science_outlined;
      case 'own_material':
        return Icons.upload_file_outlined;
      default:
        return Icons.menu_book_outlined;
    }
  }

  String _sourceLabel(String value) {
    const values = <String, List<String>>{
      'google_books': ['Google Books', 'Google Books'],
      'crossref': ['Crossref', 'Crossref'],
      'open_library': ['Open Library', 'Open Library'],
      'nctb': ['NCTB / official', 'NCTB / সরকারি'],
      'manual': ['User provided', 'নিজের দেওয়া তথ্য'],
    };
    return _pair(values[value] ?? <String>[value, value]);
  }

  String _difficultyLabel(String value) {
    const values = <String, List<String>>{
      'unknown': ['Not confirmed', 'এখনো নিশ্চিত নয়'],
      'easy': ['Easy for me', 'আমার কাছে সহজ'],
      'medium': ['Moderate for me', 'আমার কাছে মাঝারি'],
      'hard': ['Hard for me', 'আমার কাছে কঠিন'],
    };
    return _pair(values[value] ?? <String>[value, value]);
  }

  String _goalLabel(String value) {
    const values = <String, List<String>>{
      'exam': ['Exam preparation', 'পরীক্ষার প্রস্তুতি'],
      'syllabus': ['Complete syllabus', 'সিলেবাস শেষ করা'],
      'university': ['University study', 'বিশ্ববিদ্যালয়ের পড়াশোনা'],
      'skill': ['Build a skill', 'দক্ষতা তৈরি'],
      'research': ['Research', 'গবেষণা'],
      'general_reading': ['General reading', 'সাধারণ পাঠ'],
      'enjoyment': ['Reading for enjoyment', 'আনন্দের জন্য পড়া'],
    };
    return _pair(values[value] ?? <String>[value, value]);
  }

  String _dayLabel(String value) {
    const values = <String, List<String>>{
      'mon': ['Mon', 'সোম'],
      'tue': ['Tue', 'মঙ্গল'],
      'wed': ['Wed', 'বুধ'],
      'thu': ['Thu', 'বৃহস্পতি'],
      'fri': ['Fri', 'শুক্র'],
      'sat': ['Sat', 'শনি'],
      'sun': ['Sun', 'রবি'],
    };
    return _pair(values[value] ?? <String>[value, value]);
  }

  String _pair(List<String> pair) {
    return AppPreferencesController.instance.isBangla ? pair[1] : pair[0];
  }

  String _formatClock(int minutes) {
    final hour = (minutes ~/ 60).clamp(0, 23).toInt();
    final minute = (minutes % 60).clamp(0, 59).toInt();
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '${displayHour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')} $period';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}
