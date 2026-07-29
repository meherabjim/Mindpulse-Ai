import 'package:flutter/material.dart';

import '../../../core/settings/app_preferences_controller.dart';
import '../../account/screens/account_settings_screen.dart';
import '../../account/screens/edit_profile_screen.dart';
import '../../account/screens/emergency_contacts_screen.dart';
import '../../account/services/account_service.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/services/auth_service.dart';
import '../../companion/screens/companion_permissions_screen.dart';
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
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

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
      setState(() => _profile = result);
    }
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const AccountSettingsScreen()),
    );

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openCompanionPermissions() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const CompanionPermissionsScreen(),
      ),
    );

    if (mounted) {
      setState(() {});
    }
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
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(_t('Cancel', 'বাতিল')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
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
      if (translated != null) return translated;
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
        title: Text(_t('My profile', 'আমার প্রোফাইল')),
        centerTitle: false,
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 42),
                children: [
                  if (_errorMessage != null) _buildCachedProfileBanner(),
                  _buildProfileHero(),
                  const SizedBox(height: 22),
                  _sectionHeading(
                    icon: Icons.dashboard_customize_outlined,
                    title: _t('Control centre', 'নিয়ন্ত্রণ কেন্দ্র'),
                    subtitle: _t(
                      'Your most important settings in one place.',
                      'সব গুরুত্বপূর্ণ সেটিংস এক জায়গায় সাজানো হয়েছে।',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildQuickActions(),
                  const SizedBox(height: 24),
                  _sectionHeading(
                    icon: Icons.auto_awesome_rounded,
                    title: _t('Your companion', 'আপনার সহকারী'),
                    subtitle: _t(
                      'Suggestions, approved signals and every companion permission.',
                      'পরামর্শ, অনুমোদিত সংকেত এবং সহকারীর সব অনুমতি।',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const CompanionDashboardCard(),
                  const SizedBox(height: 24),
                  _sectionHeading(
                    icon: Icons.person_outline_rounded,
                    title: _t('Personal information', 'ব্যক্তিগত তথ্য'),
                    subtitle: _t(
                      'Your profile details and preferred experience.',
                      'আপনার পরিচয় ও পছন্দের অভিজ্ঞতার তথ্য।',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildProfileInformation(),
                  const SizedBox(height: 24),
                  _sectionHeading(
                    icon: Icons.shield_outlined,
                    title: _t('Account and security', 'অ্যাকাউন্ট ও নিরাপত্তা'),
                    subtitle: _t(
                      'Session controls and safe account actions.',
                      'সেশন নিয়ন্ত্রণ ও নিরাপদ অ্যাকাউন্ট ব্যবস্থা।',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSecurityMenu(),
                ],
              ),
            ),
    );
  }

  Widget _buildCachedProfileBanner() {
    final colors = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, color: colors.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _t(
                'Live profile could not be loaded. Cached information is being displayed.',
                'লাইভ প্রোফাইল লোড করা যায়নি। সংরক্ষিত তথ্য দেখানো হচ্ছে।',
              ),
              style: TextStyle(color: colors.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHero() {
    final fullName = _profileText(
      'full_name',
      fallback: _t('MindPulse User', 'MindPulse ব্যবহারকারী'),
    );
    final email = _profileText('email', fallback: '');
    final userType = _displayValue(_profileText('user_type'));
    final photoUrl = _profile['profile_photo_url']?.toString().trim();

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5C58E8), Color(0xFF8A63F4)],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x335C58E8),
            blurRadius: 26,
            offset: Offset(0, 13),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: const Color(0x33FFFFFF),
                backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                    ? NetworkImage(photoUrl)
                    : null,
                child: photoUrl == null || photoUrl.isEmpty
                    ? const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 48,
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFFEDEBFF)),
                      ),
                    ],
                    const SizedBox(height: 9),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x26FFFFFF),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        userType,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: _openEditProfile,
              icon: const Icon(Icons.edit_outlined),
              label: Text(_t('Edit profile', 'প্রোফাইল সম্পাদনা')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeading({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: colors.onPrimaryContainer),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _quickAction(
              width: itemWidth,
              icon: Icons.tune_rounded,
              title: _t('App settings', 'অ্যাপ সেটিংস'),
              subtitle: _t(
                'Language, theme and alerts',
                'ভাষা, থিম ও নোটিফিকেশন',
              ),
              onTap: _openSettings,
            ),
            _quickAction(
              width: itemWidth,
              icon: Icons.admin_panel_settings_outlined,
              title: _t('Companion access', 'সহকারীর অনুমতি'),
              subtitle: _t('Signals and permissions', 'সংকেত ও সব অনুমতি'),
              onTap: _openCompanionPermissions,
            ),
            _quickAction(
              width: itemWidth,
              icon: Icons.contact_emergency_outlined,
              title: _t('Emergency contacts', 'জরুরি যোগাযোগ'),
              subtitle: _t('Trusted people', 'বিশ্বস্ত ব্যক্তিদের তালিকা'),
              onTap: _openEmergencyContacts,
            ),
            _quickAction(
              width: itemWidth,
              icon: Icons.emoji_events_outlined,
              title: _t('Achievements', 'অর্জন'),
              subtitle: _t('Badges and progress', 'ব্যাজ ও অগ্রগতি'),
              onTap: _openAchievements,
            ),
          ],
        );
      },
    );
  }

  Widget _quickAction({
    required double width,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      width: width,
      child: Material(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            constraints: const BoxConstraints(minHeight: 142),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: colors.outlineVariant),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: colors.onPrimaryContainer),
                ),
                const SizedBox(height: 13),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.onSurfaceVariant, height: 1.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileInformation() {
    final colors = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            _infoTile(
              Icons.badge_outlined,
              _t('User type', 'ব্যবহারকারীর ধরন'),
              _displayValue(_profileText('user_type')),
            ),
            const Divider(height: 1),
            _infoTile(
              Icons.work_outline_rounded,
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
              _t('Timezone', 'সময় অঞ্চল'),
              _displayValue(_profileText('timezone', fallback: 'Asia/Dhaka')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityMenu() {
    final colors = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colors.outlineVariant),
      ),
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
            title: _t('Logout from all devices', 'সব ডিভাইস থেকে লগআউট'),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          icon,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
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
    final iconColor = destructive ? colors.error : colors.primary;
    final iconBackground = destructive
        ? colors.errorContainer
        : colors.primaryContainer;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: iconBackground,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: destructive ? colors.error : null,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
