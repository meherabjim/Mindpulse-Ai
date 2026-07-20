import 'package:flutter/material.dart';

import '../services/account_service.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final AccountService _service = AccountService();

  List<Map<String, dynamic>> _contacts = <Map<String, dynamic>>[];

  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final contacts = await _service.listEmergencyContacts();

      if (!mounted) return;

      setState(() {
        _contacts = contacts;
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

  Future<void> _openEditor({Map<String, dynamic>? contact}) async {
    if (contact == null && _contacts.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A maximum of five emergency contacts is allowed.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      return;
    }

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EmergencyContactEditorScreen(contact: contact),
      ),
    );

    if (changed == true && mounted) {
      await _loadContacts();
    }
  }

  Future<void> _deleteContact(Map<String, dynamic> contact) async {
    final contactId = _integerValue(contact['id']);

    if (contactId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete contact?'),
          content: Text(
            '${contact['full_name'] ?? 'This contact'} will be permanently removed.',
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
      await _service.deleteEmergencyContact(contactId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emergency contact deleted.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      await _loadContacts();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  int? _integerValue(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FC),
      appBar: AppBar(
        title: const Text('Emergency Contacts'),
        actions: [
          IconButton(
            onPressed: _loadContacts,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _contacts.length >= 5 ? null : () => _openEditor(),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add Contact'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadContacts,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                children: [
                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade800),
                      ),
                    ),
                  _buildHeaderCard(),
                  const SizedBox(height: 16),
                  if (_contacts.isEmpty)
                    _buildEmptyState()
                  else
                    ..._contacts.map(_buildContactCard),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5C58E8), Color(0xFF875EF0)],
        ),
        borderRadius: BorderRadius.circular(23),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 27,
            backgroundColor: Color(0x33FFFFFF),
            child: Icon(Icons.health_and_safety_outlined, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_contacts.length} of 5 contacts',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'People who may be contacted during an emergency.',
                  style: TextStyle(color: Color(0xFFEDEBFF)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 50),
        child: Column(
          children: [
            const Icon(
              Icons.contact_emergency_outlined,
              size: 72,
              color: Colors.grey,
            ),
            const SizedBox(height: 14),
            const Text(
              'No emergency contacts added.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 15),
            FilledButton.icon(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add First Contact'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard(Map<String, dynamic> contact) {
    final primary = contact['is_primary'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: primary
                  ? const Color(0xFFFFF1E8)
                  : const Color(0xFFF0EFFF),
              child: Icon(
                primary ? Icons.star_rounded : Icons.person_outline_rounded,
                color: primary ? Colors.orange : const Color(0xFF6059E8),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          contact['full_name']?.toString() ?? 'Contact',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (primary)
                        const Chip(
                          label: Text('Primary'),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  if (contact['relationship_name'] != null &&
                      contact['relationship_name'].toString().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(contact['relationship_name'].toString()),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.phone_outlined,
                        size: 17,
                        color: Color(0xFF74748A),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(contact['phone_number']?.toString() ?? ''),
                      ),
                    ],
                  ),
                  if (contact['email'] != null &&
                      contact['email'].toString().isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.email_outlined,
                          size: 17,
                          color: Color(0xFF74748A),
                        ),
                        const SizedBox(width: 6),
                        Expanded(child: Text(contact['email'].toString())),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _openEditor(contact: contact);
                } else if (value == 'delete') {
                  _deleteContact(contact);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class EmergencyContactEditorScreen extends StatefulWidget {
  const EmergencyContactEditorScreen({this.contact, super.key});

  final Map<String, dynamic>? contact;

  @override
  State<EmergencyContactEditorScreen> createState() =>
      _EmergencyContactEditorScreenState();
}

class _EmergencyContactEditorScreenState
    extends State<EmergencyContactEditorScreen> {
  final AccountService _service = AccountService();

  late final TextEditingController _nameController;

  late final TextEditingController _relationshipController;

  late final TextEditingController _phoneController;

  late final TextEditingController _emailController;

  bool _isPrimary = false;
  bool _saving = false;

  String? _errorMessage;

  bool get _editing => widget.contact != null;

  int? get _contactId {
    final value = widget.contact?['id'];

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '');
  }

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: widget.contact?['full_name']?.toString() ?? '',
    );

    _relationshipController = TextEditingController(
      text: widget.contact?['relationship_name']?.toString() ?? '',
    );

    _phoneController = TextEditingController(
      text: widget.contact?['phone_number']?.toString() ?? '',
    );

    _emailController = TextEditingController(
      text: widget.contact?['email']?.toString() ?? '',
    );

    _isPrimary = widget.contact?['is_primary'] == true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _relationshipController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();

    if (name.length < 2) {
      setState(() {
        _errorMessage = 'Contact name must contain at least 2 characters.';
      });
      return;
    }

    if (!RegExp(r'^[0-9+()\-\s]{6,30}$').hasMatch(phone)) {
      setState(() {
        _errorMessage = 'Enter a valid phone number.';
      });
      return;
    }

    if (email.isNotEmpty &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() {
        _errorMessage = 'Enter a valid email address.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      if (_editing) {
        final contactId = _contactId;

        if (contactId == null) {
          throw const AccountApiException('Emergency contact ID is invalid.');
        }

        await _service.updateEmergencyContact(
          contactId,
          fullName: name,
          relationshipName: _relationshipController.text,
          phoneNumber: phone,
          email: email,
          isPrimary: _isPrimary,
        );
      } else {
        await _service.createEmergencyContact(
          fullName: name,
          relationshipName: _relationshipController.text,
          phoneNumber: phone,
          email: email,
          isPrimary: _isPrimary,
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
        title: Text(
          _editing ? 'Edit Emergency Contact' : 'Add Emergency Contact',
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Tooltip(
              message: _saving ? 'Saving...' : 'Save',
              child: MediaQuery.sizeOf(context).width < 420
                  ? Icon(
                      _saving ? Icons.sync_rounded : Icons.save_outlined,
                      semanticLabel: _saving ? 'Saving' : 'Save',
                    )
                  : Text(_saving ? 'Saving...' : 'Save'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red.shade800),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(17),
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    maxLength: 120,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _relationshipController,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Relationship',
                      hintText: 'Parent, sibling, friend...',
                      prefixIcon: Icon(Icons.people_outline),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    maxLength: 30,
                    decoration: const InputDecoration(
                      labelText: 'Phone number',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    maxLength: 191,
                    decoration: const InputDecoration(
                      labelText: 'Email (optional)',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 5),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _isPrimary,
                    onChanged: (value) {
                      setState(() {
                        _isPrimary = value;
                      });
                    },
                    title: const Text('Primary contact'),
                    subtitle: const Text('Only one contact can be primary.'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_editing ? 'Update Contact' : 'Create Contact'),
          ),
        ],
      ),
    );
  }
}
