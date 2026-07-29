import 'package:flutter/material.dart';

import '../../../core/settings/app_preferences_controller.dart';
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
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _t(String english, String bangla) {
    return AppPreferencesController.instance.text(english, bangla);
  }

  Future<void> _load() async {
    try {
      final reminders = await _service.load();
      if (!mounted) return;
      setState(() {
        _reminders = reminders;
        _loading = false;
        _error = null;
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
      _status = null;
    });

    try {
      final scheduled = await _service.save(reminders);
      if (!mounted) return;
      setState(() {
        _reminders = reminders;
        _status = scheduled > 0
            ? _t(
                '$scheduled upcoming alarms scheduled.',
                'সামনের $scheduledটি অ্যালার্ম নির্ধারিত হয়েছে।',
              )
            : _t(
                'Reminder saved. No future alarm matched the selected time and days.',
                'রিমাইন্ডার সংরক্ষিত হয়েছে। নির্বাচিত সময় ও দিনের মধ্যে ভবিষ্যতের কোনো অ্যালার্ম পাওয়া যায়নি।',
              );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _test(ManualFaithReminder reminder) async {
    setState(() {
      _saving = true;
      _error = null;
      _status = null;
    });

    try {
      final scheduled = await _service.scheduleTest(reminder);
      if (!mounted) return;

      final message = scheduled > 0
          ? _t(
              'Test alarm scheduled. It should ring in about 30 seconds.',
              'টেস্ট অ্যালার্ম নির্ধারিত হয়েছে। প্রায় ৩০ সেকেন্ডের মধ্যে বাজবে।',
            )
          : _t(
              'Android did not accept the test alarm. Check notification and exact-alarm permission.',
              'Android টেস্ট অ্যালার্ম গ্রহণ করেনি। নোটিফিকেশন ও Exact Alarm অনুমতি পরীক্ষা করুন।',
            );

      setState(() => _status = message);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
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
        SnackBar(
          content: Text(
            _t(
              'A maximum of 10 manual reminders is supported.',
              'সর্বোচ্চ ১০টি ম্যানুয়াল রিমাইন্ডার রাখা যাবে।',
            ),
          ),
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
    if (reminder.weekdays.length == 7) {
      return _t('Every day', 'প্রতিদিন');
    }

    final names = AppPreferencesController.instance.isBangla
        ? const <int, String>{
            1: 'সোম',
            2: 'মঙ্গল',
            3: 'বুধ',
            4: 'বৃহঃ',
            5: 'শুক্র',
            6: 'শনি',
            7: 'রবি',
          }
        : const <int, String>{
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
      appBar: AppBar(
        title: Text(_t('Manual reminders', 'ম্যানুয়াল রিমাইন্ডার')),
        actions: [
          IconButton(
            tooltip: _t('Add reminder', 'রিমাইন্ডার যোগ করুন'),
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
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!hiddenFaith)
                          Text(
                            _t(
                              'Religion: ${widget.faithProfile.religionLabel}',
                              'ধর্ম: ${widget.faithProfile.religionLabel}',
                            ),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        if (!hiddenFaith) const SizedBox(height: 7),
                        Text(
                          _t(
                            'Only reminders you create are shown here. Nothing is added automatically.',
                            'এখানে শুধু আপনার তৈরি রিমাইন্ডার দেখা যাবে। কোনো কনটেন্ট বা অ্যালার্ম নিজে থেকে যোগ হবে না।',
                          ),
                          style: const TextStyle(height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  if (_status != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(_status!),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
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
                            Text(
                              _t(
                                'No manual reminder yet',
                                'এখনও কোনো ম্যানুয়াল রিমাইন্ডার নেই',
                              ),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _t(
                                'Add a personal, spiritual or general reminder.',
                                'ব্যক্তিগত, আধ্যাত্মিক বা সাধারণ রিমাইন্ডার যোগ করুন।',
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 14),
                            FilledButton.icon(
                              onPressed: _saving ? null : () => _openEditor(),
                              icon: const Icon(Icons.add_alarm_rounded),
                              label: Text(
                                _t(
                                  'Add manual reminder',
                                  'ম্যানুয়াল রিমাইন্ডার যোগ করুন',
                                ),
                              ),
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
                                  if (value == 'test') {
                                    _test(reminder);
                                  } else if (value == 'edit') {
                                    _openEditor(reminder);
                                  } else if (value == 'delete') {
                                    _delete(reminder);
                                  }
                                },
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: 'test',
                                    child: Text(
                                      _t(
                                        'Test in 30 seconds',
                                        '৩০ সেকেন্ডে টেস্ট করুন',
                                      ),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text(_t('Edit', 'সম্পাদনা')),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text(_t('Delete', 'মুছুন')),
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
  late bool _enabled;

  String _t(String english, String bangla) {
    return AppPreferencesController.instance.text(english, bangla);
  }

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
    _enabled = reminder?.enabled ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(context: context, initialTime: _time);
    if (selected != null) {
      setState(() => _time = selected);
    }
  }

  void _submit() {
    final title = _titleController.text.trim();

    if (title.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('Enter a reminder name.', 'রিমাইন্ডারের নাম লিখুন।'),
          ),
        ),
      );
      return;
    }

    if (_weekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('Choose at least one day.', 'অন্তত একটি দিন নির্বাচন করুন।'),
          ),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      ManualFaithReminder(
        id:
            widget.reminder?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        hour: _time.hour,
        minute: _time.minute,
        weekdays: _weekdays.toList()..sort(),
        enabled: _enabled,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final names = AppPreferencesController.instance.isBangla
        ? const <int, String>{
            1: 'সোম',
            2: 'মঙ্গল',
            3: 'বুধ',
            4: 'বৃহঃ',
            5: 'শুক্র',
            6: 'শনি',
            7: 'রবি',
          }
        : const <int, String>{
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
        widget.reminder == null
            ? _t('Add manual reminder', 'ম্যানুয়াল রিমাইন্ডার যোগ করুন')
            : _t('Edit reminder', 'রিমাইন্ডার সম্পাদনা করুন'),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              maxLength: 80,
              decoration: InputDecoration(
                labelText: _t('Reminder name', 'রিমাইন্ডারের নাম'),
                hintText: _t('Evening reflection', 'সন্ধ্যার ধ্যান বা ভাবনা'),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_rounded),
              title: Text(_t('Time', 'সময়')),
              subtitle: Text(_time.format(context)),
              onTap: _pickTime,
            ),
            const SizedBox(height: 8),
            Text(
              _t('Days', 'দিন'),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
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
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
              title: Text(_t('Alarm enabled', 'অ্যালার্ম চালু')),
              subtitle: Text(
                _t(
                  'Notification and exact-alarm permission are required for sound.',
                  'শব্দের জন্য নোটিফিকেশন ও Exact Alarm অনুমতি প্রয়োজন।',
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_t('Cancel', 'বাতিল')),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_t('Save', 'সংরক্ষণ করুন')),
        ),
      ],
    );
  }
}
