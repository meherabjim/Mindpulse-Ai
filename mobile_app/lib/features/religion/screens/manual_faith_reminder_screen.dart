import 'package:flutter/material.dart';

import '../services/faith_profile_service.dart';
import '../services/manual_faith_reminder_service.dart';

class ManualFaithReminderScreen extends StatefulWidget {
  const ManualFaithReminderScreen({required this.faithProfile, super.key});

  final FaithProfile faithProfile;

  @override
  State<ManualFaithReminderScreen> createState() =>
      _ManualFaithReminderScreenState();
}

class _ManualFaithReminderScreenState extends State<ManualFaithReminderScreen> {
  final ManualFaithReminderService _service = ManualFaithReminderService();
  List<ManualFaithReminder> _reminders = <ManualFaithReminder>[];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final reminders = await _service.load();
      if (!mounted) return;
      setState(() {
        _reminders = reminders;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _save(List<ManualFaithReminder> reminders) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service.save(reminders);
      if (!mounted) return;
      setState(() => _reminders = reminders);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openEditor([ManualFaithReminder? existing]) async {
    if (existing == null &&
        _reminders.length >= ManualFaithReminderService.maximumReminders) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A maximum of 10 manual reminders is supported.'),
        ),
      );
      return;
    }
    final result = await showDialog<ManualFaithReminder>(
      context: context,
      builder: (_) => _ReminderEditor(reminder: existing),
    );
    if (result == null) return;
    final updated = List<ManualFaithReminder>.from(_reminders);
    final index = updated.indexWhere((item) => item.id == result.id);
    if (index >= 0) {
      updated[index] = result;
    } else {
      updated.add(result);
    }
    await _save(updated);
  }

  Future<void> _delete(ManualFaithReminder reminder) async {
    await _save(_reminders.where((item) => item.id != reminder.id).toList());
  }

  String _time(ManualFaithReminder reminder) {
    return TimeOfDay(
      hour: reminder.hour,
      minute: reminder.minute,
    ).format(context);
  }

  String _days(ManualFaithReminder reminder) {
    if (reminder.weekdays.length == 7) return 'Every day';
    const names = <int, String>{
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };
    return reminder.weekdays.map((day) => names[day] ?? '').join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final hiddenFaith =
        widget.faithProfile.religion == 'no_religion' ||
        widget.faithProfile.religion == 'prefer_not_to_say';
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FC),
      appBar: AppBar(
        title: const Text('Manual reminders'),
        actions: [
          IconButton(
            tooltip: 'Add reminder',
            onPressed: _saving ? null : () => _openEditor(),
            icon: const Icon(Icons.add_alarm_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0EFFF),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!hiddenFaith)
                          Text(
                            'Religion: ${widget.faithProfile.religionLabel}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        if (!hiddenFaith) const SizedBox(height: 7),
                        const Text(
                          'Only reminders you create manually are shown here. Muslim prayer times, mosque and jamaat content are hidden.',
                          style: TextStyle(height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: Colors.red.shade800)),
                  ],
                  const SizedBox(height: 16),
                  if (_reminders.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          children: [
                            const Icon(Icons.alarm_add_outlined, size: 52),
                            const SizedBox(height: 12),
                            const Text(
                              'No manual reminder yet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Add a personal prayer, spiritual practice or general reminder.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 14),
                            FilledButton.icon(
                              onPressed: _saving ? null : () => _openEditor(),
                              icon: const Icon(Icons.add_alarm_rounded),
                              label: const Text('Add manual reminder'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._reminders.map(
                      (reminder) => Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.notifications_active_outlined,
                          ),
                          title: Text(
                            reminder.title,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          subtitle: Text(
                            '${_time(reminder)} • ${_days(reminder)}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch.adaptive(
                                value: reminder.enabled,
                                onChanged: _saving
                                    ? null
                                    : (value) {
                                        final updated = _reminders
                                            .map(
                                              (item) => item.id == reminder.id
                                                  ? item.copyWith(
                                                      enabled: value,
                                                    )
                                                  : item,
                                            )
                                            .toList();
                                        _save(updated);
                                      },
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') _openEditor(reminder);
                                  if (value == 'delete') _delete(reminder);
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _ReminderEditor extends StatefulWidget {
  const _ReminderEditor({this.reminder});
  final ManualFaithReminder? reminder;

  @override
  State<_ReminderEditor> createState() => _ReminderEditorState();
}

class _ReminderEditorState extends State<_ReminderEditor> {
  late final TextEditingController _titleController;
  late TimeOfDay _time;
  late Set<int> _weekdays;

  @override
  void initState() {
    super.initState();
    final reminder = widget.reminder;
    _titleController = TextEditingController(text: reminder?.title ?? '');
    _time = TimeOfDay(
      hour: reminder?.hour ?? 19,
      minute: reminder?.minute ?? 0,
    );
    _weekdays = (reminder?.weekdays ?? const <int>[1, 2, 3, 4, 5, 6, 7])
        .toSet();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(context: context, initialTime: _time);
    if (selected != null) setState(() => _time = selected);
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.length < 2 || _weekdays.isEmpty) return;
    Navigator.of(context).pop(
      ManualFaithReminder(
        id:
            widget.reminder?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        hour: _time.hour,
        minute: _time.minute,
        weekdays: _weekdays.toList()..sort(),
        enabled: widget.reminder?.enabled ?? true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const names = <int, String>{
      1: 'M',
      2: 'T',
      3: 'W',
      4: 'T',
      5: 'F',
      6: 'S',
      7: 'S',
    };
    return AlertDialog(
      title: Text(
        widget.reminder == null ? 'Add manual reminder' : 'Edit reminder',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Reminder name',
                hintText: 'Evening prayer',
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_rounded),
              title: const Text('Time'),
              subtitle: Text(_time.format(context)),
              onTap: _pickTime,
            ),
            const SizedBox(height: 8),
            const Text('Days', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              children: names.entries.map((entry) {
                final selected = _weekdays.contains(entry.key);
                return FilterChip(
                  label: Text(entry.value),
                  selected: selected,
                  onSelected: (value) {
                    setState(() {
                      if (value) {
                        _weekdays.add(entry.key);
                      } else {
                        _weekdays.remove(entry.key);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
