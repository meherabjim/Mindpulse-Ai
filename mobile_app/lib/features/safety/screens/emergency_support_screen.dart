import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/emergency_contact_service.dart';

class EmergencySupportScreen extends StatefulWidget {
  const EmergencySupportScreen({super.key});

  @override
  State<EmergencySupportScreen> createState() => _EmergencySupportScreenState();
}

class _EmergencySupportScreenState extends State<EmergencySupportScreen> {
  final EmergencyContactService _service = EmergencyContactService();
  List<EmergencyContact> _contacts = const <EmergencyContact>[];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final contacts = await _service.listContacts();
      if (!mounted) return;
      setState(() {
        _contacts = contacts;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _openForm([EmergencyContact? existing]) async {
    final result = await showModalBottomSheet<EmergencyContact>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ContactForm(contact: existing),
    );
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    try {
      if (existing == null) {
        await _service.create(result);
      } else {
        await _service.update(result);
      }
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null ? 'Contact added.' : 'Contact updated.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(EmergencyContact contact) async {
    final yes =
        await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete contact?'),
            content: Text('${contact.fullName} will be removed.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton.tonal(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!yes) return;
    setState(() => _busy = true);
    try {
      await _service.delete(contact.id);
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDial(String label, String number) async {
    final yes =
        await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('Open dialer for $label?'),
            content: Text(
              'The Phone app will open with $number. MindPulse will not call automatically.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.phone),
                label: const Text('Open dialer'),
              ),
            ],
          ),
        ) ??
        false;
    if (!yes) return;
    await _launch(
      Uri(scheme: 'tel', path: number),
      'No phone dialer is available.',
    );
  }

  Future<void> _confirmMessage(EmergencyContact contact) async {
    final yes =
        await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('Message ${contact.fullName}?'),
            content: const Text(
              'The Messages app will open with a prepared message. Nothing is sent automatically.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.sms_outlined),
                label: const Text('Open message'),
              ),
            ],
          ),
        ) ??
        false;
    if (!yes) return;
    await _launch(
      Uri(
        scheme: 'sms',
        path: contact.phoneNumber,
        queryParameters: const {
          'body':
              'I need support right now. Please call or check on me when you can.',
        },
      ),
      'No messaging app is available.',
    );
  }

  Future<void> _launch(Uri uri, String errorMessage) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) throw StateError(errorMessage);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FC),
      appBar: AppBar(title: const Text('Emergency & Safety Support')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : () => _openForm(),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Add contact'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.emergency_outlined,
                          color: Colors.red.shade700,
                          size: 30,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Immediate danger?',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Bangladesh National Emergency Service 999 connects police, fire and ambulance support.',
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                        ),
                        onPressed: () =>
                            _confirmDial('National Emergency Service', '999'),
                        icon: const Icon(Icons.phone_in_talk_outlined),
                        label: const Text('Open 999 in phone dialer'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'Move to a safer place when possible, contact someone you trust, and call emergency services when immediate help is needed. MindPulse does not diagnose or call anyone automatically.',
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Trusted contacts',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(30),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_contacts.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: [
                      const Icon(Icons.group_add_outlined, size: 42),
                      const SizedBox(height: 10),
                      const Text('No trusted contact added yet.'),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: () => _openForm(),
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('Add trusted contact'),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._contacts.map(
                (contact) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                child: Text(
                                  contact.fullName.isEmpty
                                      ? '?'
                                      : contact.fullName[0].toUpperCase(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            contact.fullName,
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        if (contact.isPrimary) ...[
                                          const SizedBox(width: 8),
                                          const Chip(
                                            visualDensity:
                                                VisualDensity.compact,
                                            label: Text('Primary'),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (contact.relationshipName?.isNotEmpty ==
                                        true)
                                      Text(contact.relationshipName!),
                                    Text(contact.phoneNumber),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') _openForm(contact);
                                  if (value == 'copy') {
                                    Clipboard.setData(
                                      ClipboardData(text: contact.phoneNumber),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Phone number copied.'),
                                      ),
                                    );
                                  }
                                  if (value == 'delete') _delete(contact);
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  PopupMenuItem(
                                    value: 'copy',
                                    child: Text('Copy number'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () => _confirmDial(
                                    contact.fullName,
                                    contact.phoneNumber,
                                  ),
                                  icon: const Icon(Icons.phone_outlined),
                                  label: const Text('Call'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _confirmMessage(contact),
                                  icon: const Icon(Icons.sms_outlined),
                                  label: const Text('Message'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Card(
                color: Colors.red.shade50,
                child: ListTile(
                  leading: Icon(
                    Icons.error_outline,
                    color: Colors.red.shade700,
                  ),
                  title: const Text('Safety support error'),
                  subtitle: Text(_error!),
                  trailing: IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ContactForm extends StatefulWidget {
  const _ContactForm({this.contact});
  final EmergencyContact? contact;
  @override
  State<_ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends State<_ContactForm> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _relation;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late bool _primary;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.contact?.fullName ?? '');
    _relation = TextEditingController(
      text: widget.contact?.relationshipName ?? '',
    );
    _phone = TextEditingController(text: widget.contact?.phoneNumber ?? '');
    _email = TextEditingController(text: widget.contact?.email ?? '');
    _primary = widget.contact?.isPrimary ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _relation.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_key.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      EmergencyContact(
        id: widget.contact?.id ?? 0,
        fullName: _name.text.trim(),
        relationshipName: _relation.text.trim().isEmpty
            ? null
            : _relation.text.trim(),
        phoneNumber: _phone.text.trim(),
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        isPrimary: _primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 18,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Form(
        key: _key,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.contact == null
                    ? 'Add trusted contact'
                    : 'Edit trusted contact',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.length < 2) return 'Enter at least 2 characters.';
                  if (text.length > 120) return 'Use 120 characters or fewer.';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _relation,
                decoration: const InputDecoration(
                  labelText: 'Relationship (optional)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value?.trim().length ?? 0) > 80
                    ? 'Use 80 characters or fewer.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  hintText: '+8801XXXXXXXXX',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    RegExp(
                      r'^[0-9+()\-\s]{6,30}$',
                    ).hasMatch(value?.trim() ?? '')
                    ? null
                    : 'Enter a valid phone number.',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return null;
                  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)
                      ? null
                      : 'Enter a valid email.';
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _primary,
                onChanged: (value) => setState(() => _primary = value),
                title: const Text('Primary safety contact'),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  child: Text(
                    widget.contact == null ? 'Add contact' : 'Save changes',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
