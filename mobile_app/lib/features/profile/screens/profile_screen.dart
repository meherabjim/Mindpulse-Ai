import 'package:flutter/material.dart';

import '../../account/screens/account_settings_screen.dart';
import '../../account/screens/edit_profile_screen.dart';
import '../../account/screens/emergency_contacts_screen.dart';
import '../../account/services/account_service.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/services/auth_service.dart';
import '../../engagement/screens/achievements_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final AccountService _accountService = AccountService();

  Map<String, dynamic> _profile = <String, dynamic>{};

  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final profile = await _accountService.getProfile();

      if (!mounted) return;

      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (error) {
      final cachedUser = await _authService.getUser();

      if (!mounted) return;

      setState(() {
        _profile = cachedUser;
        _errorMessage = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openEditProfile() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute<Map<String, dynamic>>(
        builder: (_) => EditProfileScreen(profile: _profile),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _profile = result;
      });
    }
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const AccountSettingsScreen()),
    );
  }

  Future<void> _openEmergencyContacts() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const EmergencyContactsScreen()),
    );
  }

  Future<void> _openAchievements() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const AchievementsScreen()),
    );
  }

  Future<void> _logout() async {
    final confirmed = await _confirmAction(
      title: 'Logout',
      message: 'Are you sure you want to logout from this device?',
      actionLabel: 'Logout',
    );

    if (confirmed != true) return;

    await _authService.logout();

    if (!mounted) return;

    _goToLogin();
  }

  Future<void> _logoutAllDevices() async {
    final confirmed = await _confirmAction(
      title: 'Logout from all devices',
      message: 'All active MindPulse sessions will be closed.',
      actionLabel: 'Logout All',
    );

    if (confirmed != true) return;

    try {
      await _accountService.logoutAllDevices();

      if (!mounted) return;

      _goToLogin();
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

  Future<bool?> _confirmAction({
    required String title,
    required String message,
    required String actionLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
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
              child: Text(actionLabel),
            ),
          ],
        );
      },
    );
  }

  void _goToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  String _profileText(String key, {String fallback = 'Not provided'}) {
    final value = _profile[key]?.toString().trim();

    if (value == null || value.isEmpty) {
      return fallback;
    }

    return value;
  }

  String _displayValue(String value) {
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) {
          return '${word[0].toUpperCase()}${word.substring(1)}';
        })
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FC),
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _openEditProfile,
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit profile',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                children: [
                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        'Live profile could not be loaded. Cached information is being displayed.',
                        style: TextStyle(color: Colors.orange.shade900),
                      ),
                    ),
                  _buildProfileHeader(),
                  const SizedBox(height: 16),
                  _buildProfileInformation(),
                  const SizedBox(height: 16),
                  _buildAccountMenu(),
                  const SizedBox(height: 16),
                  _buildSecurityMenu(),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    final fullName = _profileText('full_name', fallback: 'MindPulse User');

    final email = _profileText('email', fallback: '');

    final photoUrl = _profile['profile_photo_url']?.toString().trim();

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5C58E8), Color(0xFF875EF0)],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x335C58E8),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 52,
            backgroundColor: const Color(0x33FFFFFF),
            backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                ? NetworkImage(photoUrl)
                : null,
            child: photoUrl == null || photoUrl.isEmpty
                ? const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 58,
                  )
                : null,
          ),
          const SizedBox(height: 15),
          Text(
            fullName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            email,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFEDEBFF)),
          ),
          const SizedBox(height: 15),
          FilledButton.tonalIcon(
            onPressed: _openEditProfile,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit Profile'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInformation() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Personal Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            _infoTile(
              Icons.badge_outlined,
              'User type',
              _displayValue(_profileText('user_type')),
            ),
            const Divider(height: 1),
            _infoTile(
              Icons.work_outline,
              'Occupation',
              _profileText('occupation'),
            ),
            const Divider(height: 1),
            _infoTile(
              Icons.flag_outlined,
              'Wellness goal',
              _profileText('wellness_goal'),
            ),
            const Divider(height: 1),
            _infoTile(
              Icons.language_rounded,
              'Language',
              _profileText('preferred_language', fallback: 'en'),
            ),
            const Divider(height: 1),
            _infoTile(
              Icons.public_rounded,
              'Timezone',
              _profileText('timezone', fallback: 'Asia/Dhaka'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountMenu() {
    return Card(
      child: Column(
        children: [
          _menuTile(
            icon: Icons.settings_outlined,
            title: 'Account Settings',
            subtitle: 'Privacy, analysis and notifications',
            onTap: _openSettings,
          ),
          const Divider(height: 1),
          _menuTile(
            icon: Icons.contact_emergency_outlined,
            title: 'Emergency Contacts',
            subtitle: 'Manage trusted emergency contacts',
            onTap: _openEmergencyContacts,
          ),
          const Divider(height: 1),
          _menuTile(
            icon: Icons.emoji_events_outlined,
            title: 'Achievements',
            subtitle: 'View badges, points and level',
            onTap: _openAchievements,
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityMenu() {
    return Card(
      child: Column(
        children: [
          _menuTile(
            icon: Icons.logout_rounded,
            title: 'Logout',
            subtitle: 'Logout from this device',
            onTap: _logout,
          ),
          const Divider(height: 1),
          _menuTile(
            icon: Icons.devices_other_outlined,
            title: 'Logout from All Devices',
            subtitle: 'Close every active session',
            onTap: _logoutAllDevices,
            destructive: true,
          ),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String title, String value) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: const Color(0xFF6059E8)),
      title: Text(title),
      subtitle: Text(value),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    final color = destructive ? Colors.red : const Color(0xFF6059E8);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: destructive
            ? Colors.red.shade50
            : const Color(0xFFF0EFFF),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: destructive ? Colors.red : null,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
