import 'package:flutter/material.dart';

import '../../../core/settings/app_preferences_controller.dart';
import '../../account/screens/account_settings_screen.dart';
import '../../account/screens/edit_profile_screen.dart';
import '../../account/screens/emergency_contacts_screen.dart';
import '../../account/services/account_service.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/services/auth_service.dart';
import '../../companion/widgets/companion_dashboard_card.dart';
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

  String _t(String english, String bangla) {
    return AppPreferencesController.instance.text(english, bangla);
  }

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
      title: _t('Logout', 'লগআউট'),
      message: _t(
        'Are you sure you want to logout from this device?',
        'আপনি কি এই ডিভাইস থেকে লগআউট করতে চান?',
      ),
      actionLabel: _t('Logout', 'লগআউট'),
    );

    if (confirmed != true) return;

    await _authService.logout();

    if (!mounted) return;

    _goToLogin();
  }

  Future<void> _logoutAllDevices() async {
    final confirmed = await _confirmAction(
      title: _t('Logout from all devices', 'সব ডিভাইস থেকে লগআউট'),
      message: _t(
        'All active MindPulse sessions will be closed.',
        'MindPulse-এর সব সক্রিয় সেশন বন্ধ হয়ে যাবে।',
      ),
      actionLabel: _t('Logout All', 'সব জায়গা থেকে লগআউট'),
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
              child: Text(_t('Cancel', 'বাতিল')),
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

  String _profileText(String key, {String? fallback}) {
    final value = _profile[key]?.toString().trim();

    if (value == null || value.isEmpty) {
      return fallback ?? _t('Not provided', 'প্রদান করা হয়নি');
    }

    return value;
  }

  String _displayValue(String value) {
    final normalized = value.trim().toLowerCase().replaceAll(' ', '_');

    if (AppPreferencesController.instance.isBangla) {
      const banglaValues = <String, String>{
        'student': 'শিক্ষার্থী',
        'employed': 'চাকরিজীবী',
        'self_employed': 'স্বনিযুক্ত',
        'unemployed': 'বর্তমানে কর্মরত নন',
        'retired': 'অবসরপ্রাপ্ত',
        'homemaker': 'গৃহস্থালি কাজ',
        'other': 'অন্যান্য',
        'bn': 'বাংলা',
        'en': 'ইংরেজি',
        'asia/dhaka': 'এশিয়া/ঢাকা',
      };

      final translated = banglaValues[normalized];
      if (translated != null) {
        return translated;
      }
    }

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
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(_t('Profile', 'প্রোফাইল')),
        actions: [
          IconButton(
            onPressed: _loading ? null : _openEditProfile,
            icon: const Icon(Icons.edit_outlined),
            tooltip: _t('Edit profile', 'প্রোফাইল সম্পাদনা'),
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
                        color: colors.errorContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        _t(
                          'Live profile could not be loaded. Cached information is being displayed.',
                          'লাইভ প্রোফাইল লোড করা যায়নি। সংরক্ষিত তথ্য দেখানো হচ্ছে।',
                        ),
                        style: TextStyle(color: colors.onErrorContainer),
                      ),
                    ),
                  _buildProfileHeader(),
                  const SizedBox(height: 20),
                  Text(
                    _t('Your companion', 'আপনার সহকারী'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _t(
                      'Suggestions, approved signals and every companion permission are together here.',
                      'পরামর্শ, অনুমোদিত সংকেত এবং সহকারীর সব অনুমতি এখানে একসঙ্গে রয়েছে।',
                    ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const CompanionDashboardCard(),
                  const SizedBox(height: 20),
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
    final fullName = _profileText(
      'full_name',
      fallback: _t('MindPulse User', 'MindPulse ব্যবহারকারী'),
    );

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
          if (email.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              email,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFEDEBFF)),
            ),
          ],
          const SizedBox(height: 15),
          FilledButton.tonalIcon(
            onPressed: _openEditProfile,
            icon: const Icon(Icons.edit_outlined),
            label: Text(_t('Edit Profile', 'প্রোফাইল সম্পাদনা')),
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
            Text(
              _t('Personal Information', 'ব্যক্তিগত তথ্য'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            _infoTile(
              Icons.badge_outlined,
              _t('User type', 'ব্যবহারকারীর ধরন'),
              _displayValue(_profileText('user_type')),
            ),
            const Divider(height: 1),
            _infoTile(
              Icons.work_outline,
              _t('Occupation', 'পেশা'),
              _displayValue(_profileText('occupation')),
            ),
            const Divider(height: 1),
            _infoTile(
              Icons.flag_outlined,
              _t('Wellness goal', 'সুস্থতার লক্ষ্য'),
              _displayValue(_profileText('wellness_goal')),
            ),
            const Divider(height: 1),
            _infoTile(
              Icons.language_rounded,
              _t('Language', 'ভাষা'),
              _displayValue(_profileText('preferred_language', fallback: 'en')),
            ),
            const Divider(height: 1),
            _infoTile(
              Icons.public_rounded,
              _t('Timezone', 'সময়সীমা'),
              _displayValue(_profileText('timezone', fallback: 'Asia/Dhaka')),
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
            title: _t('App and account settings', 'অ্যাপ ও অ্যাকাউন্ট সেটিংস'),
            subtitle: _t(
              'Language, theme, privacy and notifications',
              'ভাষা, থিম, গোপনীয়তা ও নোটিফিকেশন',
            ),
            onTap: _openSettings,
          ),
          const Divider(height: 1),
          _menuTile(
            icon: Icons.contact_emergency_outlined,
            title: _t('Emergency Contacts', 'জরুরি যোগাযোগ'),
            subtitle: _t(
              'Manage trusted emergency contacts',
              'বিশ্বস্ত জরুরি যোগাযোগ পরিচালনা করুন',
            ),
            onTap: _openEmergencyContacts,
          ),
          const Divider(height: 1),
          _menuTile(
            icon: Icons.emoji_events_outlined,
            title: _t('Achievements', 'অর্জন'),
            subtitle: _t(
              'View badges, points and level',
              'ব্যাজ, পয়েন্ট ও স্তর দেখুন',
            ),
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
            title: _t('Logout', 'লগআউট'),
            subtitle: _t(
              'Logout from this device',
              'এই ডিভাইস থেকে লগআউট করুন',
            ),
            onTap: _logout,
          ),
          const Divider(height: 1),
          _menuTile(
            icon: Icons.devices_other_outlined,
            title: _t('Logout from All Devices', 'সব ডিভাইস থেকে লগআউট'),
            subtitle: _t(
              'Close every active session',
              'সব সক্রিয় সেশন বন্ধ করুন',
            ),
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
    final colors = Theme.of(context).colorScheme;
    final color = destructive ? colors.error : const Color(0xFF6059E8);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: destructive
            ? colors.errorContainer
            : colors.primaryContainer,
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: destructive ? colors.error : null,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
