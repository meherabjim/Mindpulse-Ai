import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/settings/app_preferences_controller.dart';

class AiGuideV2Screen extends StatefulWidget {
  const AiGuideV2Screen({super.key});

  @override
  State<AiGuideV2Screen> createState() => _AiGuideV2ScreenState();
}

class _AiGuideV2ScreenState extends State<AiGuideV2Screen> {
  static const _profileStorageKey = 'mindpulse_ai_guide_profile_v2';
  static const _itemsStorageKey = 'mindpulse_ai_guide_items_v2';
  static const _settingsStorageKey = 'mindpulse_ai_guide_settings_v2';
  static const _planReadyStorageKey = 'mindpulse_ai_guide_plan_ready_v2';

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _authorController = TextEditingController();

  _GuideProfile _profile = const _GuideProfile(
    educationLevel: 'general',
    stream: 'none',
    field: '',
    preferredLanguage: 'both',
    purpose: 'general_reading',
  );

  List<_GuideReadingItem> _items = <_GuideReadingItem>[];
  List<_GuideSearchResult> _searchResults = <_GuideSearchResult>[];

  bool _loading = true;
  bool _searching = false;
  bool _planReady = false;
  String _selectedContentType = 'book';
  int _sessionMinutes = 25;
  int _sessionsPerWeek = 3;
  String? _message;

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
    _titleController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();

    final profileRaw = preferences.getString(_profileStorageKey);
    final itemsRaw = preferences.getString(_itemsStorageKey);
    final settingsRaw = preferences.getString(_settingsStorageKey);

    var profile = _profile;
    final items = <_GuideReadingItem>[];
    var sessionMinutes = _sessionMinutes;
    var sessionsPerWeek = _sessionsPerWeek;

    try {
      if (profileRaw != null && profileRaw.trim().isNotEmpty) {
        final decoded = jsonDecode(profileRaw);
        if (decoded is Map) {
          profile = _GuideProfile.fromJson(Map<String, dynamic>.from(decoded));
        }
      }

      if (itemsRaw != null && itemsRaw.trim().isNotEmpty) {
        final decoded = jsonDecode(itemsRaw);
        if (decoded is List) {
          for (final item in decoded.whereType<Map>()) {
            items.add(
              _GuideReadingItem.fromJson(Map<String, dynamic>.from(item)),
            );
          }
        }
      }

      if (settingsRaw != null && settingsRaw.trim().isNotEmpty) {
        final decoded = jsonDecode(settingsRaw);
        if (decoded is Map) {
          final settings = Map<String, dynamic>.from(decoded);
          sessionMinutes = (settings['session_minutes'] as num?)?.toInt() ?? 25;
          sessionsPerWeek =
              (settings['sessions_per_week'] as num?)?.toInt() ?? 3;
        }
      }
    } catch (_) {
      // Corrupted local planner data is ignored instead of showing
      // unverified or partially decoded information.
    }

    if (!mounted) return;
    setState(() {
      _profile = profile;
      _items = items;
      _sessionMinutes = sessionMinutes.clamp(10, 90).toInt();
      _sessionsPerWeek = sessionsPerWeek.clamp(1, 7).toInt();
      _planReady = preferences.getBool(_planReadyStorageKey) ?? false;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(
      _profileStorageKey,
      jsonEncode(_profile.toJson()),
    );

    await preferences.setString(
      _itemsStorageKey,
      jsonEncode(_items.map((item) => item.toJson()).toList()),
    );

    await preferences.setString(
      _settingsStorageKey,
      jsonEncode(<String, dynamic>{
        'session_minutes': _sessionMinutes,
        'sessions_per_week': _sessionsPerWeek,
      }),
    );

    await preferences.setBool(_planReadyStorageKey, _planReady);
  }

  Future<void> _editProfile() async {
    final result = await showModalBottomSheet<_GuideProfile>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _GuideProfileEditorSheet(profile: _profile),
    );

    if (result == null || !mounted) return;
    setState(() {
      _profile = result;
      _planReady = false;
      _message = _t(
        'Profile updated. Rebuild the draft when your list is ready.',
        'প্রোফাইল হালনাগাদ হয়েছে। তালিকা প্রস্তুত হলে খসড়া গাইড আবার তৈরি করুন।',
      );
    });
    await _save();
  }

  Future<void> _searchOnline() async {
    final title = _titleController.text.trim();
    final author = _authorController.text.trim();

    if (title.isEmpty) {
      setState(() {
        _message = _t(
          'Enter a title, magazine name or ISBN first.',
          'আগে বইয়ের নাম, ম্যাগাজিনের নাম অথবা ISBN লিখুন।',
        );
      });
      return;
    }

    setState(() {
      _searching = true;
      _searchResults = <_GuideSearchResult>[];
      _message = null;
    });

    try {
      final compactIdentifier = title.replaceAll(RegExp(r'[^0-9Xx]'), '');
      final looksLikeIsbn =
          compactIdentifier.length == 10 || compactIdentifier.length == 13;

      final queryParts = <String>[
        looksLikeIsbn ? 'isbn:$compactIdentifier' : 'intitle:"$title"',
      ];
      if (author.isNotEmpty) {
        queryParts.add('inauthor:"$author"');
      }

      final printType = _selectedContentType == 'magazine'
          ? 'magazines'
          : 'all';

      final uri =
          Uri.https('www.googleapis.com', '/books/v1/volumes', <String, String>{
            'q': queryParts.join(' '),
            'maxResults': '8',
            'orderBy': 'relevance',
            'printType': printType,
            'projection': 'full',
          });

      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Google Books returned ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw FormatException('Invalid Google Books response.');
      }

      final rawItems = decoded['items'];
      final results = <_GuideSearchResult>[];

      if (rawItems is List) {
        for (final raw in rawItems.whereType<Map>()) {
          final result = _GuideSearchResult.fromGoogle(
            Map<String, dynamic>.from(raw),
          );
          if (result.title.trim().isNotEmpty) {
            results.add(result);
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _message = results.isEmpty
            ? _t(
                'No reliable match was found. Check the spelling, add the author or add the item manually.',
                'নির্ভরযোগ্য মিল পাওয়া যায়নি। বানান যাচাই করুন, লেখকের নাম দিন অথবা নিজে তথ্য যোগ করুন।',
              )
            : _t(
                'Choose the correct catalogue result. MindPulse will not select the first result automatically.',
                'সঠিক ক্যাটালগ ফলাফল নির্বাচন করুন। MindPulse নিজে থেকে প্রথম ফলাফল বেছে নেবে না।',
              );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = _t(
          'Online catalogue could not be reached. No difficulty or book details were guessed. You can try again or add the item manually.',
          'অনলাইন ক্যাটালগ পাওয়া যায়নি। কোনো কঠিনতা বা বইয়ের তথ্য অনুমান করা হয়নি। আবার চেষ্টা করুন অথবা নিজে তথ্য যোগ করুন।',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _searching = false);
      }
    }
  }

  Future<void> _addSearchResult(_GuideSearchResult result) async {
    final duplicate = _items.any(
      (item) =>
          (result.sourceId.isNotEmpty && item.sourceId == result.sourceId) ||
          (item.title.trim().toLowerCase() ==
                  result.title.trim().toLowerCase() &&
              item.author.trim().toLowerCase() ==
                  result.author.trim().toLowerCase()),
    );

    if (duplicate) {
      setState(() {
        _message = _t(
          'This item is already in your list.',
          'এই বই বা পাঠ্যটি তালিকায় আগে থেকেই আছে।',
        );
      });
      return;
    }

    if (_items.length >= 30) {
      setState(() {
        _message = _t(
          'The first version supports up to 30 selected items.',
          'প্রথম সংস্করণে সর্বোচ্চ ৩০টি পাঠ্য নির্বাচন করা যাবে।',
        );
      });
      return;
    }

    setState(() {
      _items.add(result.toReadingItem(preferredType: _selectedContentType));
      _searchResults = <_GuideSearchResult>[];
      _titleController.clear();
      _authorController.clear();
      _planReady = false;
      _message = _t(
        'Selected catalogue metadata added. Difficulty remains unconfirmed until you provide feedback.',
        'আপনার নির্বাচিত ক্যাটালগ তথ্য যোগ হয়েছে। আপনার মতামত না পাওয়া পর্যন্ত কঠিনতা অনির্ধারিত থাকবে।',
      );
    });
    await _save();
  }

  Future<void> _addManualItem() async {
    final result = await showModalBottomSheet<_GuideReadingItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ManualGuideItemSheet(
        initialType: _selectedContentType,
        initialTitle: _titleController.text.trim(),
      ),
    );

    if (result == null || !mounted) return;

    final duplicate = _items.any(
      (item) =>
          item.title.trim().toLowerCase() ==
              result.title.trim().toLowerCase() &&
          item.author.trim().toLowerCase() ==
              result.author.trim().toLowerCase(),
    );

    if (duplicate) {
      setState(() {
        _message = _t(
          'This item is already in your list.',
          'এই পাঠ্যটি তালিকায় আগে থেকেই আছে।',
        );
      });
      return;
    }

    if (_items.length >= 30) {
      setState(() {
        _message = _t(
          'The first version supports up to 30 selected items.',
          'প্রথম সংস্করণে সর্বোচ্চ ৩০টি পাঠ্য নির্বাচন করা যাবে।',
        );
      });
      return;
    }

    setState(() {
      _items.add(result);
      _titleController.clear();
      _authorController.clear();
      _searchResults = <_GuideSearchResult>[];
      _planReady = false;
      _message = _t(
        'Your item was added as user-provided information.',
        'আপনার দেওয়া তথ্য হিসেবে পাঠ্যটি যোগ হয়েছে।',
      );
    });
    await _save();
  }

  Future<void> _removeItem(_GuideReadingItem item) async {
    setState(() {
      _items.removeWhere((candidate) => candidate.id == item.id);
      _planReady = false;
    });
    await _save();
  }

  Future<void> _moveItem(int index, int delta) async {
    final target = index + delta;
    if (target < 0 || target >= _items.length) return;

    setState(() {
      final item = _items.removeAt(index);
      _items.insert(target, item);
      _planReady = false;
    });
    await _save();
  }

  Future<void> _setDifficulty(_GuideReadingItem item) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text(
            _t('How difficult is it for you?', 'আপনার কাছে এটি কেমন কঠিন?'),
          ),
          children: <Widget>[
            _difficultyDialogOption(
              context,
              value: 'unknown',
              english: 'Not sure yet',
              bangla: 'এখনো নিশ্চিত নই',
            ),
            _difficultyDialogOption(
              context,
              value: 'easy',
              english: 'Easy for me',
              bangla: 'আমার জন্য সহজ',
            ),
            _difficultyDialogOption(
              context,
              value: 'moderate',
              english: 'Moderate for me',
              bangla: 'আমার জন্য মাঝারি',
            ),
            _difficultyDialogOption(
              context,
              value: 'hard',
              english: 'Difficult for me',
              bangla: 'আমার জন্য কঠিন',
            ),
          ],
        );
      },
    );

    if (result == null || !mounted) return;

    setState(() {
      final index = _items.indexWhere((candidate) => candidate.id == item.id);
      if (index >= 0) {
        _items[index] = item.copyWith(difficulty: result);
        _planReady = false;
      }
    });
    await _save();
  }

  Widget _difficultyDialogOption(
    BuildContext context, {
    required String value,
    required String english,
    required String bangla,
  }) {
    return SimpleDialogOption(
      onPressed: () => Navigator.of(context).pop(value),
      child: Text(_t(english, bangla)),
    );
  }

  Future<void> _buildDraft() async {
    if (_items.isEmpty) {
      setState(() {
        _message = _t(
          'Add at least one textbook, book, magazine or other reading item.',
          'কমপক্ষে একটি পাঠ্যবই, বই, ম্যাগাজিন অথবা অন্য পাঠ্য যোগ করুন।',
        );
      });
      return;
    }

    setState(() {
      _planReady = true;
      _message = _t(
        'A draft was created for ${_items.length} selected item(s). It uses your chosen order and reading rhythm. Your learning profile is saved for later personalized guidance, and no reading level is invented.',
        'আপনার নির্বাচিত ${_items.length}টি পাঠ্যের জন্য একটি খসড়া তৈরি হয়েছে। এতে আপনার নির্বাচিত ক্রম ও পড়ার ছন্দ ব্যবহার করা হয়েছে। ভবিষ্যৎ ব্যক্তিগত নির্দেশনার জন্য শিক্ষা প্রোফাইল সংরক্ষিত আছে; কোনো পড়ার স্তর বানিয়ে বলা হয়নি।',
      );
    });
    await _save();
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(_t('Clear reading guide?', 'পাঠ গাইড মুছবেন?')),
          content: Text(
            _t(
              'This will remove the selected list and draft from this device.',
              'এই ডিভাইস থেকে নির্বাচিত তালিকা ও খসড়া মুছে যাবে।',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(_t('Cancel', 'বাতিল')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(_t('Clear', 'মুছুন')),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _items = <_GuideReadingItem>[];
      _searchResults = <_GuideSearchResult>[];
      _planReady = false;
      _message = null;
    });
    await _save();
  }

  String _daysForIndex(int index) {
    const englishDays = <String>[
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];
    const banglaDays = <String>[
      'সোম',
      'মঙ্গল',
      'বুধ',
      'বৃহস্পতি',
      'শুক্র',
      'শনি',
      'রবি',
    ];

    final days = AppPreferencesController.instance.isBangla
        ? banglaDays
        : englishDays;

    final selected = <String>[];
    for (var offset = 0; offset < _sessionsPerWeek; offset++) {
      selected.add(days[(index + offset * 2) % days.length]);
    }
    return selected.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('Study and reading guide', 'পড়াশোনা ও পাঠ গাইড')),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              tooltip: _t('Clear guide', 'গাইড মুছুন'),
              onPressed: _clearAll,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
              children: [
                _buildHeader(context),
                const SizedBox(height: 16),
                _buildProfileCard(context),
                const SizedBox(height: 16),
                _buildSearchCard(context),
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  _GuideNotice(message: _message!),
                ],
                if (_searchResults.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    _t('Choose the correct result', 'সঠিক ফলাফল বেছে নিন'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ..._searchResults.map(
                    (result) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _GuideSearchResultCard(
                        result: result,
                        onAdd: () => _addSearchResult(result),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _t(
                          'My reading list (${_items.length})',
                          'আমার পাঠ তালিকা (${_items.length})',
                        ),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      _t('1–30 items', '১–৩০টি পাঠ্য'),
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_items.isEmpty)
                  _GuideEmptyList(onAddManual: _addManualItem)
                else
                  ..._items.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _GuideSelectedItemCard(
                        index: entry.key,
                        item: entry.value,
                        onDifficulty: () => _setDifficulty(entry.value),
                        onMoveUp: entry.key == 0
                            ? null
                            : () => _moveItem(entry.key, -1),
                        onMoveDown: entry.key == _items.length - 1
                            ? null
                            : () => _moveItem(entry.key, 1),
                        onDelete: () => _removeItem(entry.value),
                      ),
                    ),
                  ),
                if (_items.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildPlanSettings(context),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _buildDraft,
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: Text(
                        _planReady
                            ? _t('Rebuild my guide', 'আমার গাইড আবার তৈরি করুন')
                            : _t('Create my guide', 'আমার গাইড তৈরি করুন'),
                      ),
                    ),
                  ),
                ],
                if (_planReady && _items.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Text(
                    _t('Your draft plan', 'আপনার খসড়া পরিকল্পনা'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ..._items.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _GuideDraftCard(
                        number: entry.key + 1,
                        item: entry.value,
                        days: _daysForIndex(entry.key),
                        sessionMinutes: _sessionMinutes,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _GuideNotice(
                    message: _t(
                      'Online catalogue data helps identify a title using available author, publisher, date and identifier. Difficulty is personal and is only shown from your own feedback.',
                      'অনলাইন ক্যাটালগের লেখক, প্রকাশক, তারিখ ও শনাক্তকারী দিয়ে সঠিক পাঠ্য বেছে নিতে সাহায্য করা হয়। কঠিনতা ব্যক্তিভেদে আলাদা, তাই শুধু আপনার মতামত থেকেই দেখানো হয়।',
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF087F76), Color(0xFF32BDA6)],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.school_rounded, color: Colors.white, size: 34),
          const SizedBox(height: 14),
          Text(
            _t('A guide built around you', 'আপনাকে কেন্দ্র করে পাঠ গাইড'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _t(
              'Choose your education level, purpose and exact reading materials. MindPulse will never force a fixed number of books or invent missing facts.',
              'শিক্ষার স্তর, উদ্দেশ্য ও সঠিক পাঠ্য বেছে নিন। MindPulse নির্দিষ্ট সংখ্যক বই চাপিয়ে দেবে না এবং না পাওয়া তথ্য বানিয়ে বলবে না।',
            ),
            style: const TextStyle(color: Color(0xFFE9FFF9), height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.person_search_rounded, color: colors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _t('Learning profile', 'শিক্ষা ও পাঠ প্রোফাইল'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _editProfile,
                icon: const Icon(Icons.edit_rounded),
                label: Text(_t('Edit', 'পরিবর্তন')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _GuideTag(text: _educationLevelLabel(_profile.educationLevel)),
              if (_profile.stream != 'none')
                _GuideTag(text: _streamLabel(_profile.stream)),
              if (_profile.field.trim().isNotEmpty)
                _GuideTag(text: _profile.field.trim()),
              _GuideTag(text: _languageLabel(_profile.preferredLanguage)),
              _GuideTag(text: _purposeLabel(_profile.purpose)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const types = <String>[
      'textbook',
      'guidebook',
      'book',
      'magazine',
      'article',
      'research',
      'own',
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('Add reading material', 'পাঠ্য যোগ করুন'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            _t(
              'Textbooks, general books, magazines and your own materials are all supported.',
              'পাঠ্যবই, সাধারণ বই, ম্যাগাজিন এবং নিজের পাঠ্য—সবই যোগ করা যাবে।',
            ),
            style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: types
                .map(
                  (type) => ChoiceChip(
                    selected: _selectedContentType == type,
                    onSelected: (_) {
                      setState(() {
                        _selectedContentType = type;
                        _searchResults = <_GuideSearchResult>[];
                        _message = null;
                      });
                    },
                    label: Text(_contentTypeLabel(type)),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _titleController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) {
              if (_supportsGoogleBooks(_selectedContentType)) {
                _searchOnline();
              } else {
                _addManualItem();
              }
            },
            decoration: InputDecoration(
              labelText: _t(
                'Title, magazine name or ISBN',
                'বই বা ম্যাগাজিনের নাম অথবা ISBN',
              ),
              prefixIcon: const Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _authorController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: _t('Author (optional)', 'লেখক (ঐচ্ছিক)'),
              prefixIcon: const Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (_supportsGoogleBooks(_selectedContentType))
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _searching ? null : _searchOnline,
                    icon: _searching
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.travel_explore_rounded),
                    label: Text(
                      _searching
                          ? _t('Searching...', 'খোঁজা হচ্ছে...')
                          : _t('Search catalogue', 'ক্যাটালগে খুঁজুন'),
                    ),
                  ),
                ),
              if (_supportsGoogleBooks(_selectedContentType))
                const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addManualItem,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(_t('Add manually', 'নিজে যোগ করুন')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _t(
              'Search results are candidates. Use the author, publisher, date and identifier to choose the correct result before anything is saved.',
              'অনলাইন ফলাফল শুধু সম্ভাব্য মিল। সংরক্ষণের আগে লেখক, প্রকাশক, তারিখ ও শনাক্তকারী দেখে সঠিক ফলাফল আপনি বেছে নেবেন।',
            ),
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanSettings(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('Reading rhythm', 'পড়ার ছন্দ'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _sessionMinutes,
            decoration: InputDecoration(
              labelText: _t('Minutes per session', 'প্রতি সেশনে সময়'),
            ),
            items: const <int>[10, 15, 20, 25, 30, 45, 60, 90]
                .map(
                  (minutes) => DropdownMenuItem<int>(
                    value: minutes,
                    child: Text(_t('$minutes minutes', '$minutes মিনিট')),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _sessionMinutes = value;
                _planReady = false;
              });
              _save();
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            initialValue: _sessionsPerWeek,
            decoration: InputDecoration(
              labelText: _t('Sessions per week', 'সপ্তাহে সেশন'),
            ),
            items: List<int>.generate(7, (index) => index + 1)
                .map(
                  (count) => DropdownMenuItem<int>(
                    value: count,
                    child: Text(_t('$count session(s)', '$countটি সেশন')),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _sessionsPerWeek = value;
                _planReady = false;
              });
              _save();
            },
          ),
        ],
      ),
    );
  }
}

class _GuideProfileEditorSheet extends StatefulWidget {
  const _GuideProfileEditorSheet({required this.profile});

  final _GuideProfile profile;

  @override
  State<_GuideProfileEditorSheet> createState() =>
      _GuideProfileEditorSheetState();
}

class _GuideProfileEditorSheetState extends State<_GuideProfileEditorSheet> {
  late String _educationLevel;
  late String _stream;
  late String _preferredLanguage;
  late String _purpose;
  late final TextEditingController _fieldController;

  String _t(String english, String bangla) {
    return AppPreferencesController.instance.text(english, bangla);
  }

  @override
  void initState() {
    super.initState();
    _educationLevel = widget.profile.educationLevel;
    _stream = widget.profile.stream;
    _preferredLanguage = widget.profile.preferredLanguage;
    _purpose = widget.profile.purpose;
    _fieldController = TextEditingController(text: widget.profile.field);
  }

  @override
  void dispose() {
    _fieldController.dispose();
    super.dispose();
  }

  bool get _needsStream {
    return <String>{
      'class_9',
      'class_10',
      'ssc',
      'hsc_1',
      'hsc_2',
    }.contains(_educationLevel);
  }

  bool get _needsField {
    return <String>{
      'diploma',
      'bachelor',
      'masters',
      'mphil_phd',
      'professional',
    }.contains(_educationLevel);
  }

  void _submit() {
    Navigator.of(context).pop(
      _GuideProfile(
        educationLevel: _educationLevel,
        stream: _needsStream ? _stream : 'none',
        field: _needsField ? _fieldController.text.trim() : '',
        preferredLanguage: _preferredLanguage,
        purpose: _purpose,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const levels = <String>[
      'preschool',
      'class_0',
      'class_1',
      'class_2',
      'class_3',
      'class_4',
      'class_5',
      'class_6',
      'class_7',
      'class_8',
      'class_9',
      'class_10',
      'ssc',
      'hsc_1',
      'hsc_2',
      'diploma',
      'bachelor',
      'masters',
      'mphil_phd',
      'professional',
      'general',
    ];

    const streams = <String>[
      'science',
      'humanities',
      'business',
      'vocational',
      'madrasa',
      'other',
    ];

    const languages = <String>['bangla', 'english', 'both', 'other'];

    const purposes = <String>[
      'exam',
      'school_college',
      'university',
      'skill',
      'career',
      'religious',
      'general_reading',
      'fiction',
      'magazine',
      'research',
      'enjoyment',
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t('Learning profile', 'শিক্ষা ও পাঠ প্রোফাইল'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _educationLevel,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: _t('Education level', 'শিক্ষার স্তর'),
              ),
              items: levels
                  .map(
                    (level) => DropdownMenuItem<String>(
                      value: level,
                      child: Text(_educationLevelLabel(level)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _educationLevel = value;
                  if (_needsStream && !streams.contains(_stream)) {
                    _stream = streams.first;
                  }
                });
              },
            ),
            if (_needsStream) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: streams.contains(_stream)
                    ? _stream
                    : streams.first,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: _t('Group or stream', 'বিভাগ বা শাখা'),
                ),
                items: streams
                    .map(
                      (stream) => DropdownMenuItem<String>(
                        value: stream,
                        child: Text(_streamLabel(stream)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _stream = value);
                  }
                },
              ),
            ],
            if (_needsField) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _fieldController,
                decoration: InputDecoration(
                  labelText: _t(
                    'Degree, department or professional field',
                    'ডিগ্রি, বিভাগ অথবা পেশার ক্ষেত্র',
                  ),
                  hintText: _t(
                    'Example: BSc in CSE, Diploma in Civil',
                    'যেমন: BSc in CSE, Diploma in Civil',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _preferredLanguage,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: _t(
                  'Preferred reading language',
                  'পছন্দের পাঠের ভাষা',
                ),
              ),
              items: languages
                  .map(
                    (language) => DropdownMenuItem<String>(
                      value: language,
                      child: Text(_languageLabel(language)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _preferredLanguage = value);
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _purpose,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: _t('Main purpose', 'মূল উদ্দেশ্য'),
              ),
              items: purposes
                  .map(
                    (purpose) => DropdownMenuItem<String>(
                      value: purpose,
                      child: Text(_purposeLabel(purpose)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _purpose = value);
                }
              },
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.check_rounded),
                label: Text(_t('Save profile', 'প্রোফাইল সংরক্ষণ করুন')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualGuideItemSheet extends StatefulWidget {
  const _ManualGuideItemSheet({
    required this.initialType,
    required this.initialTitle,
  });

  final String initialType;
  final String initialTitle;

  @override
  State<_ManualGuideItemSheet> createState() => _ManualGuideItemSheetState();
}

class _ManualGuideItemSheetState extends State<_ManualGuideItemSheet> {
  late String _type;
  late final TextEditingController _titleController;
  late final TextEditingController _authorController;
  late final TextEditingController _publisherController;
  late final TextEditingController _identifierController;

  String _t(String english, String bangla) {
    return AppPreferencesController.instance.text(english, bangla);
  }

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _titleController = TextEditingController(text: widget.initialTitle);
    _authorController = TextEditingController();
    _publisherController = TextEditingController();
    _identifierController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _publisherController.dispose();
    _identifierController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    Navigator.of(context).pop(
      _GuideReadingItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        sourceId: '',
        type: _type,
        title: title,
        author: _authorController.text.trim(),
        publisher: _publisherController.text.trim(),
        publishedDate: '',
        language: '',
        identifier: _identifierController.text.trim(),
        source: 'manual',
        difficulty: 'unknown',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const types = <String>[
      'textbook',
      'guidebook',
      'book',
      'magazine',
      'article',
      'research',
      'own',
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t('Add your reading material', 'নিজের পাঠ্য যোগ করুন'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: types.contains(_type) ? _type : 'book',
              isExpanded: true,
              decoration: InputDecoration(
                labelText: _t('Content type', 'পাঠ্যের ধরন'),
              ),
              items: types
                  .map(
                    (type) => DropdownMenuItem<String>(
                      value: type,
                      child: Text(_contentTypeLabel(type)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _type = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: InputDecoration(labelText: _t('Title', 'নাম')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _authorController,
              decoration: InputDecoration(
                labelText: _t(
                  'Author or creator (optional)',
                  'লেখক বা নির্মাতা (ঐচ্ছিক)',
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _publisherController,
              decoration: InputDecoration(
                labelText: _t(
                  'Publisher or source (optional)',
                  'প্রকাশক বা উৎস (ঐচ্ছিক)',
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _identifierController,
              decoration: InputDecoration(
                labelText: _t(
                  'ISBN, ISSN or reference (optional)',
                  'ISBN, ISSN অথবা রেফারেন্স (ঐচ্ছিক)',
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.add_rounded),
                label: Text(_t('Add to my list', 'আমার তালিকায় যোগ করুন')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideSearchResultCard extends StatelessWidget {
  const _GuideSearchResultCard({required this.result, required this.onAdd});

  final _GuideSearchResult result;
  final VoidCallback onAdd;

  String _t(String english, String bangla) {
    return AppPreferencesController.instance.text(english, bangla);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 58,
            decoration: BoxDecoration(
              color: colors.secondaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              result.type == 'magazine'
                  ? Icons.newspaper_rounded
                  : Icons.menu_book_rounded,
              color: colors.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (result.author.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    result.author,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: 7),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    const _GuideTag(text: 'Google Books'),
                    _GuideTag(text: _contentTypeLabel(result.type)),
                    if (result.publisher.isNotEmpty)
                      _GuideTag(text: result.publisher),
                    if (result.publishedDate.isNotEmpty)
                      _GuideTag(text: result.publishedDate),
                    if (result.language.isNotEmpty)
                      _GuideTag(text: result.language.toUpperCase()),
                    if (result.identifier.isNotEmpty)
                      _GuideTag(text: result.identifier),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _t(
                    'Catalogue match • difficulty not confirmed',
                    'ক্যাটালগে মিল পাওয়া গেছে • কঠিনতা নিশ্চিত নয়',
                  ),
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: _t('Add this result', 'এই ফলাফল যোগ করুন'),
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _GuideSelectedItemCard extends StatelessWidget {
  const _GuideSelectedItemCard({
    required this.index,
    required this.item,
    required this.onDifficulty,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
  });

  final int index;
  final _GuideReadingItem item;
  final VoidCallback onDifficulty;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback onDelete;

  String _t(String english, String bangla) {
    return AppPreferencesController.instance.text(english, bangla);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: colors.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (item.author.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.author,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _GuideTag(text: _contentTypeLabel(item.type)),
                    _GuideTag(
                      text: item.source == 'google_books'
                          ? _t('Catalogue match', 'ক্যাটালগ মিল')
                          : _t('User provided', 'ব্যবহারকারীর তথ্য'),
                    ),
                    ActionChip(
                      onPressed: onDifficulty,
                      avatar: const Icon(Icons.speed_rounded, size: 16),
                      label: Text(_difficultyLabel(item.difficulty)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'up') {
                onMoveUp?.call();
              } else if (value == 'down') {
                onMoveDown?.call();
              } else if (value == 'difficulty') {
                onDifficulty();
              } else if (value == 'delete') {
                onDelete();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem<String>(
                value: 'up',
                enabled: onMoveUp != null,
                child: Text(_t('Move up', 'উপরে নিন')),
              ),
              PopupMenuItem<String>(
                value: 'down',
                enabled: onMoveDown != null,
                child: Text(_t('Move down', 'নিচে নিন')),
              ),
              PopupMenuItem<String>(
                value: 'difficulty',
                child: Text(_t('Set my difficulty', 'আমার কঠিনতা ঠিক করুন')),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Text(_t('Remove', 'সরান')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GuideDraftCard extends StatelessWidget {
  const _GuideDraftCard({
    required this.number,
    required this.item,
    required this.days,
    required this.sessionMinutes,
  });

  final int number;
  final _GuideReadingItem item;
  final String days;
  final int sessionMinutes;

  String _t(String english, String bangla) {
    return AppPreferencesController.instance.text(english, bangla);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: colors.primaryContainer,
            foregroundColor: colors.onPrimaryContainer,
            child: Text('$number'),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$days • $sessionMinutes ${_t('minutes', 'মিনিট')}',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                Text(
                  _t(
                    'Personal difficulty: ${_difficultyLabel(item.difficulty)}',
                    'ব্যক্তিগত কঠিনতা: ${_difficultyLabel(item.difficulty)}',
                  ),
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideEmptyList extends StatelessWidget {
  const _GuideEmptyList({required this.onAddManual});

  final VoidCallback onAddManual;

  String _t(String english, String bangla) {
    return AppPreferencesController.instance.text(english, bangla);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(Icons.library_add_rounded, size: 42, color: colors.primary),
          const SizedBox(height: 12),
          Text(
            _t('No reading material selected', 'কোনো পাঠ্য নির্বাচন করা হয়নি'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            _t(
              'Add one item or many. MindPulse will plan only what you choose.',
              'একটি অথবা অনেকগুলো যোগ করুন। MindPulse শুধু আপনার নির্বাচিত পাঠ্য নিয়েই পরিকল্পনা করবে।',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onAddManual,
            icon: const Icon(Icons.add_rounded),
            label: Text(_t('Add my first item', 'প্রথম পাঠ্য যোগ করুন')),
          ),
        ],
      ),
    );
  }
}

class _GuideNotice extends StatelessWidget {
  const _GuideNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.onPrimaryContainer, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideTag extends StatelessWidget {
  const _GuideTag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: colors.onSurfaceVariant,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

bool _supportsGoogleBooks(String type) {
  return <String>{'textbook', 'guidebook', 'book', 'magazine'}.contains(type);
}

String _educationLevelLabel(String value) {
  final isBangla = AppPreferencesController.instance.isBangla;
  const labels = <String, List<String>>{
    'preschool': <String>['Pre-primary', 'প্রাক-প্রাথমিক'],
    'class_0': <String>['Class 0', 'শ্রেণি ০'],
    'class_1': <String>['Class 1', 'শ্রেণি ১'],
    'class_2': <String>['Class 2', 'শ্রেণি ২'],
    'class_3': <String>['Class 3', 'শ্রেণি ৩'],
    'class_4': <String>['Class 4', 'শ্রেণি ৪'],
    'class_5': <String>['Class 5', 'শ্রেণি ৫'],
    'class_6': <String>['Class 6', 'শ্রেণি ৬'],
    'class_7': <String>['Class 7', 'শ্রেণি ৭'],
    'class_8': <String>['Class 8', 'শ্রেণি ৮'],
    'class_9': <String>['Class 9', 'শ্রেণি ৯'],
    'class_10': <String>['Class 10', 'শ্রেণি ১০'],
    'ssc': <String>['SSC candidate', 'SSC পরীক্ষার্থী'],
    'hsc_1': <String>['HSC first year', 'HSC প্রথম বর্ষ'],
    'hsc_2': <String>['HSC second year', 'HSC দ্বিতীয় বর্ষ'],
    'diploma': <String>['Diploma or technical', 'ডিপ্লোমা বা কারিগরি'],
    'bachelor': <String>[
      'Bachelor / BSc / BA / BBA',
      'Bachelor / BSc / BA / BBA',
    ],
    'masters': <String>['Masters', 'মাস্টার্স'],
    'mphil_phd': <String>['MPhil or PhD', 'MPhil অথবা PhD'],
    'professional': <String>['Professional learner', 'পেশাগত শিক্ষার্থী'],
    'general': <String>['General reader', 'সাধারণ পাঠক'],
  };

  final pair = labels[value] ?? labels['general']!;
  return isBangla ? pair[1] : pair[0];
}

String _streamLabel(String value) {
  final isBangla = AppPreferencesController.instance.isBangla;
  const labels = <String, List<String>>{
    'science': <String>['Science', 'বিজ্ঞান'],
    'humanities': <String>['Humanities', 'মানবিক'],
    'business': <String>['Business studies', 'ব্যবসায় শিক্ষা'],
    'vocational': <String>['Technical or vocational', 'কারিগরি বা ভোকেশনাল'],
    'madrasa': <String>['Madrasa curriculum', 'মাদ্রাসা শিক্ষা'],
    'other': <String>['Other', 'অন্যান্য'],
    'none': <String>['Not required', 'প্রযোজ্য নয়'],
  };

  final pair = labels[value] ?? labels['other']!;
  return isBangla ? pair[1] : pair[0];
}

String _languageLabel(String value) {
  final isBangla = AppPreferencesController.instance.isBangla;
  const labels = <String, List<String>>{
    'bangla': <String>['Bangla', 'বাংলা'],
    'english': <String>['English', 'ইংরেজি'],
    'both': <String>['Bangla and English', 'বাংলা ও ইংরেজি'],
    'other': <String>['Other language', 'অন্য ভাষা'],
  };

  final pair = labels[value] ?? labels['both']!;
  return isBangla ? pair[1] : pair[0];
}

String _purposeLabel(String value) {
  final isBangla = AppPreferencesController.instance.isBangla;
  const labels = <String, List<String>>{
    'exam': <String>['Exam preparation', 'পরীক্ষার প্রস্তুতি'],
    'school_college': <String>[
      'School or college study',
      'স্কুল বা কলেজের পড়াশোনা',
    ],
    'university': <String>['University course', 'বিশ্ববিদ্যালয়ের কোর্স'],
    'skill': <String>['Learn a skill', 'দক্ষতা শেখা'],
    'career': <String>['Career preparation', 'চাকরি বা পেশার প্রস্তুতি'],
    'religious': <String>['Religious learning', 'ধর্মীয় শিক্ষা'],
    'general_reading': <String>['General reading', 'সাধারণ পাঠ'],
    'fiction': <String>['Story or novel', 'গল্প বা উপন্যাস'],
    'magazine': <String>['Magazine reading', 'ম্যাগাজিন পাঠ'],
    'research': <String>['Research', 'গবেষণা'],
    'enjoyment': <String>['Reading for enjoyment', 'আনন্দের জন্য পড়া'],
  };

  final pair = labels[value] ?? labels['general_reading']!;
  return isBangla ? pair[1] : pair[0];
}

String _contentTypeLabel(String value) {
  final isBangla = AppPreferencesController.instance.isBangla;
  const labels = <String, List<String>>{
    'textbook': <String>['Textbook', 'পাঠ্যবই'],
    'guidebook': <String>['Guide or reference book', 'সহায়ক বা রেফারেন্স বই'],
    'book': <String>['General book', 'সাধারণ বই'],
    'magazine': <String>['Magazine', 'ম্যাগাজিন'],
    'article': <String>['Article', 'প্রবন্ধ'],
    'research': <String>['Research paper', 'গবেষণাপত্র'],
    'own': <String>['My own material', 'নিজের পাঠ্য'],
  };

  final pair = labels[value] ?? labels['book']!;
  return isBangla ? pair[1] : pair[0];
}

String _difficultyLabel(String value) {
  final isBangla = AppPreferencesController.instance.isBangla;
  const labels = <String, List<String>>{
    'unknown': <String>['Not rated yet', 'এখনো নির্ধারিত নয়'],
    'easy': <String>['Easy for me', 'আমার জন্য সহজ'],
    'moderate': <String>['Moderate for me', 'আমার জন্য মাঝারি'],
    'hard': <String>['Difficult for me', 'আমার জন্য কঠিন'],
  };

  final pair = labels[value] ?? labels['unknown']!;
  return isBangla ? pair[1] : pair[0];
}

class _GuideProfile {
  const _GuideProfile({
    required this.educationLevel,
    required this.stream,
    required this.field,
    required this.preferredLanguage,
    required this.purpose,
  });

  final String educationLevel;
  final String stream;
  final String field;
  final String preferredLanguage;
  final String purpose;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'education_level': educationLevel,
      'stream': stream,
      'field': field,
      'preferred_language': preferredLanguage,
      'purpose': purpose,
    };
  }

  factory _GuideProfile.fromJson(Map<String, dynamic> json) {
    return _GuideProfile(
      educationLevel: json['education_level']?.toString() ?? 'general',
      stream: json['stream']?.toString() ?? 'none',
      field: json['field']?.toString() ?? '',
      preferredLanguage: json['preferred_language']?.toString() ?? 'both',
      purpose: json['purpose']?.toString() ?? 'general_reading',
    );
  }
}

class _GuideReadingItem {
  const _GuideReadingItem({
    required this.id,
    required this.sourceId,
    required this.type,
    required this.title,
    required this.author,
    required this.publisher,
    required this.publishedDate,
    required this.language,
    required this.identifier,
    required this.source,
    required this.difficulty,
  });

  final String id;
  final String sourceId;
  final String type;
  final String title;
  final String author;
  final String publisher;
  final String publishedDate;
  final String language;
  final String identifier;
  final String source;
  final String difficulty;

  _GuideReadingItem copyWith({String? difficulty}) {
    return _GuideReadingItem(
      id: id,
      sourceId: sourceId,
      type: type,
      title: title,
      author: author,
      publisher: publisher,
      publishedDate: publishedDate,
      language: language,
      identifier: identifier,
      source: source,
      difficulty: difficulty ?? this.difficulty,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'source_id': sourceId,
      'type': type,
      'title': title,
      'author': author,
      'publisher': publisher,
      'published_date': publishedDate,
      'language': language,
      'identifier': identifier,
      'source': source,
      'difficulty': difficulty,
    };
  }

  factory _GuideReadingItem.fromJson(Map<String, dynamic> json) {
    return _GuideReadingItem(
      id:
          json['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      sourceId: json['source_id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'book',
      title: json['title']?.toString() ?? '',
      author: json['author']?.toString() ?? '',
      publisher: json['publisher']?.toString() ?? '',
      publishedDate: json['published_date']?.toString() ?? '',
      language: json['language']?.toString() ?? '',
      identifier: json['identifier']?.toString() ?? '',
      source: json['source']?.toString() ?? 'manual',
      difficulty: json['difficulty']?.toString() ?? 'unknown',
    );
  }
}

class _GuideSearchResult {
  const _GuideSearchResult({
    required this.sourceId,
    required this.type,
    required this.title,
    required this.author,
    required this.publisher,
    required this.publishedDate,
    required this.language,
    required this.identifier,
  });

  final String sourceId;
  final String type;
  final String title;
  final String author;
  final String publisher;
  final String publishedDate;
  final String language;
  final String identifier;

  factory _GuideSearchResult.fromGoogle(Map<String, dynamic> json) {
    final volumeInfoRaw = json['volumeInfo'];
    final volumeInfo = volumeInfoRaw is Map
        ? Map<String, dynamic>.from(volumeInfoRaw)
        : <String, dynamic>{};

    final authorsRaw = volumeInfo['authors'];
    final authors = authorsRaw is List
        ? authorsRaw.map((item) => item.toString()).join(', ')
        : '';

    final identifiersRaw = volumeInfo['industryIdentifiers'];
    var identifier = '';

    if (identifiersRaw is List) {
      for (final entry in identifiersRaw.whereType<Map>()) {
        final value = entry['identifier']?.toString().trim() ?? '';
        if (value.isNotEmpty) {
          identifier = value;
          break;
        }
      }
    }

    final printType = volumeInfo['printType']?.toString().toUpperCase() ?? '';

    return _GuideSearchResult(
      sourceId: json['id']?.toString() ?? '',
      type: printType == 'MAGAZINE' ? 'magazine' : 'book',
      title: volumeInfo['title']?.toString().trim() ?? '',
      author: authors,
      publisher: volumeInfo['publisher']?.toString().trim() ?? '',
      publishedDate: volumeInfo['publishedDate']?.toString().trim() ?? '',
      language: volumeInfo['language']?.toString().trim() ?? '',
      identifier: identifier,
    );
  }

  _GuideReadingItem toReadingItem({required String preferredType}) {
    final selectedType = type == 'magazine' ? 'magazine' : preferredType;

    return _GuideReadingItem(
      id: sourceId.isNotEmpty
          ? 'google_books_$sourceId'
          : DateTime.now().microsecondsSinceEpoch.toString(),
      sourceId: sourceId,
      type: selectedType,
      title: title,
      author: author,
      publisher: publisher,
      publishedDate: publishedDate,
      language: language,
      identifier: identifier,
      source: 'google_books',
      difficulty: 'unknown',
    );
  }
}
