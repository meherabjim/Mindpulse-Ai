import 'package:flutter/material.dart';

import '../services/journal_service.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final JournalService _service = JournalService();

  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _journals = <Map<String, dynamic>>[];

  bool _loading = true;
  bool _favoriteOnly = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadJournals();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadJournals() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final journals = await _service.listJournals(
        search: _searchController.text,
        favorite: _favoriteOnly ? true : null,
      );

      if (!mounted) return;

      setState(() {
        _journals = journals;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openEditor({Map<String, dynamic>? journal}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => JournalEditorScreen(journal: journal),
      ),
    );

    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            journal == null
                ? 'Journal entry created successfully.'
                : 'Journal entry updated successfully.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      await _loadJournals();
    }
  }

  Future<void> _toggleFavorite(Map<String, dynamic> journal) async {
    final journalId = _integerValue(journal['id']);

    if (journalId == null) return;

    final current = journal['is_favorite'] == true;

    try {
      await _service.updateFavorite(journalId, !current);

      await _loadJournals();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteJournal(Map<String, dynamic> journal) async {
    final journalId = _integerValue(journal['id']);

    if (journalId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete journal entry?'),
          content: const Text(
            'This entry will be removed from '
            'your journal history.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _service.deleteJournal(journalId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Journal entry deleted.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      await _loadJournals();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  int? _integerValue(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '');
  }

  String _titleOf(Map<String, dynamic> journal) {
    final title = journal['title']?.toString().trim() ?? '';

    return title.isEmpty ? 'Untitled reflection' : title;
  }

  String _contentPreview(Map<String, dynamic> journal) {
    final content = journal['content']?.toString().trim() ?? '';

    if (content.length <= 150) {
      return content;
    }

    return '${content.substring(0, 150)}...';
  }

  String _moodEmoji(int? mood) {
    switch (mood) {
      case 1:
        return '😞';
      case 2:
        return '😕';
      case 3:
        return '😐';
      case 4:
        return '🙂';
      case 5:
        return '😄';
      default:
        return '📝';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FC),
      appBar: AppBar(
        title: const Text('Journal'),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _favoriteOnly = !_favoriteOnly;
              });

              _loadJournals();
            },
            icon: Icon(
              _favoriteOnly ? Icons.star_rounded : Icons.star_outline_rounded,
            ),
            tooltip: 'Favourite entries',
          ),
          IconButton(
            onPressed: _loading ? null : _loadJournals,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New entry'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _loadJournals(),
              decoration: InputDecoration(
                hintText: 'Search journal entries...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          _loadJournals();
                        },
                        icon: const Icon(Icons.clear_rounded),
                      ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (_favoriteOnly)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                  const SizedBox(width: 7),
                  const Text(
                    'Showing favourite entries',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _favoriteOnly = false;
                      });

                      _loadJournals();
                    },
                    child: const Text('Show all'),
                  ),
                ],
              ),
            ),
          if (_errorMessage != null) _buildErrorBanner(),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red.shade800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_journals.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadJournals,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 100),
          children: [
            Icon(
              _favoriteOnly
                  ? Icons.star_border_rounded
                  : Icons.menu_book_outlined,
              size: 76,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 18),
            Center(
              child: Text(
                _favoriteOnly
                    ? 'No favourite journal entries.'
                    : 'No journal entries yet.',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Use New entry to record '
                'your thoughts and reflections.',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadJournals,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
        itemCount: _journals.length,
        itemBuilder: (context, index) {
          return _buildJournalCard(_journals[index]);
        },
      ),
    );
  }

  Widget _buildJournalCard(Map<String, dynamic> journal) {
    final mood = _integerValue(journal['mood_score']);

    final tagsValue = journal['tags'];

    final tags = tagsValue is List
        ? tagsValue
              .whereType<Map>()
              .map((tag) => tag['name']?.toString() ?? '')
              .where((name) => name.isNotEmpty)
              .toList()
        : <String>[];

    final isFavorite = journal['is_favorite'] == true;

    final isPrivate = journal['is_private'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          _openEditor(journal: journal);
        },
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFFF0EFFF),
                    child: Text(
                      _moodEmoji(mood),
                      style: const TextStyle(fontSize: 23),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _titleOf(journal),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          journal['entry_date']?.toString() ?? '',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'favorite') {
                        _toggleFavorite(journal);
                      } else if (value == 'edit') {
                        _openEditor(journal: journal);
                      } else if (value == 'delete') {
                        _deleteJournal(journal);
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'favorite',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            isFavorite
                                ? Icons.star_outline_rounded
                                : Icons.star_rounded,
                          ),
                          title: Text(
                            isFavorite
                                ? 'Remove favourite'
                                : 'Add to favourites',
                          ),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Edit'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.delete_outline),
                          title: Text('Delete'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                _contentPreview(journal),
                style: const TextStyle(height: 1.5),
              ),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: tags
                      .map(
                        (tag) => Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(tag),
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    isPrivate ? Icons.lock_outline : Icons.public_outlined,
                    size: 18,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isPrivate ? 'Private' : 'Visible',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const Spacer(),
                  if (isFavorite)
                    const Icon(
                      Icons.star_rounded,
                      color: Colors.amber,
                      size: 21,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class JournalEditorScreen extends StatefulWidget {
  const JournalEditorScreen({this.journal, super.key});

  final Map<String, dynamic>? journal;

  @override
  State<JournalEditorScreen> createState() => _JournalEditorScreenState();
}

class _JournalEditorScreenState extends State<JournalEditorScreen> {
  final JournalService _service = JournalService();

  late final TextEditingController _titleController;

  late final TextEditingController _contentController;

  late final TextEditingController _tagsController;

  late DateTime _entryDate;

  int? _moodScore;
  bool _isPrivate = true;
  bool _isFavorite = false;
  bool _saving = false;
  String? _errorMessage;

  bool get _isEditing => widget.journal != null;

  int? get _journalId {
    final value = widget.journal?['id'];

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '');
  }

  @override
  void initState() {
    super.initState();

    final journal = widget.journal ?? <String, dynamic>{};

    _titleController = TextEditingController(
      text: journal['title']?.toString() ?? '',
    );

    _contentController = TextEditingController(
      text: journal['content']?.toString() ?? '',
    );

    final tagsValue = journal['tags'];

    final tagNames = tagsValue is List
        ? tagsValue
              .whereType<Map>()
              .map((tag) => tag['name']?.toString() ?? '')
              .where((name) => name.isNotEmpty)
              .toList()
        : <String>[];

    _tagsController = TextEditingController(text: tagNames.join(', '));

    _entryDate =
        DateTime.tryParse(journal['entry_date']?.toString() ?? '') ??
        DateTime.now();

    final mood = journal['mood_score'];

    if (mood is num) {
      _moodScore = mood.toInt();
    } else {
      _moodScore = int.tryParse(mood?.toString() ?? '');
    }

    _isPrivate = journal['is_private'] == null
        ? true
        : journal['is_private'] == true;

    _isFavorite = journal['is_favorite'] == true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  String _dateString(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');

    final month = date.month.toString().padLeft(2, '0');

    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  List<String> _parseTags() {
    final result = <String>[];
    final normalizedNames = <String>{};

    for (final item in _tagsController.text.split(',')) {
      final name = item.trim().replaceAll(RegExp(r'\s+'), ' ');

      if (name.isEmpty) continue;

      final normalized = name.toLowerCase();

      if (!normalizedNames.contains(normalized)) {
        normalizedNames.add(normalized);
        result.add(name);
      }
    }

    return result;
  }

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _entryDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _entryDate = selected;
    });
  }

  Future<void> _save() async {
    final content = _contentController.text.trim();

    if (content.isEmpty) {
      setState(() {
        _errorMessage = 'Journal content is required.';
      });

      return;
    }

    final tags = _parseTags();

    if (tags.length > 10) {
      setState(() {
        _errorMessage = 'A journal may contain a maximum of 10 tags.';
      });

      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      if (_isEditing) {
        final journalId = _journalId;

        if (journalId == null) {
          throw const JournalApiException('Journal ID is invalid.');
        }

        await _service.updateJournal(
          journalId,
          title: _titleController.text,
          content: content,
          entryDate: _dateString(_entryDate),
          moodScore: _moodScore,
          isPrivate: _isPrivate,
          isFavorite: _isFavorite,
          tags: tags,
        );
      } else {
        await _service.createJournal(
          title: _titleController.text,
          content: content,
          entryDate: _dateString(_entryDate),
          moodScore: _moodScore,
          isPrivate: _isPrivate,
          isFavorite: _isFavorite,
          tags: tags,
        );
      }

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FC),
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Journal' : 'New Journal'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving...' : 'Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red.shade800),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _titleController,
                    maxLength: 180,
                    decoration: const InputDecoration(
                      labelText: 'Title (optional)',
                      prefixIcon: Icon(Icons.title_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _contentController,
                    minLines: 9,
                    maxLines: 18,
                    decoration: const InputDecoration(
                      labelText: 'Your reflection',
                      hintText:
                          'Write about your thoughts, feelings, experiences or progress...',
                      alignLabelWithHint: true,
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(bottom: 180),
                        child: Icon(Icons.edit_note_rounded),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'How did you feel?',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Not set'),
                        selected: _moodScore == null,
                        onSelected: (_) {
                          setState(() {
                            _moodScore = null;
                          });
                        },
                      ),
                      ...List.generate(5, (index) {
                        final score = index + 1;

                        const emojis = ['😞', '😕', '😐', '🙂', '😄'];

                        return ChoiceChip(
                          label: Text('${emojis[index]} $score'),
                          selected: _moodScore == score,
                          onSelected: (_) {
                            setState(() {
                              _moodScore = score;
                            });
                          },
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: const Text('Entry date'),
                  subtitle: Text(_dateString(_entryDate)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _selectDate,
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  value: _isPrivate,
                  onChanged: (value) {
                    setState(() {
                      _isPrivate = value;
                    });
                  },
                  secondary: const Icon(Icons.lock_outline),
                  title: const Text('Private entry'),
                  subtitle: const Text('Keep this reflection private.'),
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  value: _isFavorite,
                  onChanged: (value) {
                    setState(() {
                      _isFavorite = value;
                    });
                  },
                  secondary: const Icon(Icons.star_outline_rounded),
                  title: const Text('Favourite'),
                  subtitle: const Text('Add this entry to favourites.'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _tagsController,
                maxLength: 610,
                decoration: const InputDecoration(
                  labelText: 'Tags',
                  hintText: 'Study, Stress, Progress',
                  helperText: 'Separate tags using commas. Maximum 10 tags.',
                  prefixIcon: Icon(Icons.sell_outlined),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(
              _saving
                  ? 'Saving...'
                  : _isEditing
                  ? 'Update Journal'
                  : 'Save Journal',
            ),
          ),
        ],
      ),
    );
  }
}
