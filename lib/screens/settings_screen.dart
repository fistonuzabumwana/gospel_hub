import 'package:flutter/material.dart';
import '../services/backup_service.dart';
import '../services/app_localizations.dart';
import '../services/app_state_service.dart';
import 'privacy_policy_screen.dart';
import 'widget_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final BackupService _backupService = BackupService.instance;
  bool _isSyncing = false;
  String? _syncStatusMessage;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final accentBlue = isDark ? const Color(0xFF60A5FA) : primaryColor;

    return ValueListenableBuilder<String>(
      valueListenable: localeNotifier,
      builder: (context, currentLang, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              AppLocalizations.translate('settings_title'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          body: ValueListenableBuilder(
            valueListenable: _backupService.currentUser,
            builder: (context, user, _) {
              final isSignedIn = user != null;

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                children: [
                  // ── GENERAL SETTINGS GROUP ──
                  _SettingsGroup(
                    title: currentLang == 'rw' ? 'Rusange' : 'General',
                    children: [
                      _SettingsTile(
                        leading: const _IconBadge(
                          icon: Icons.language_outlined,
                          color: Color(0xFF6366F1), // Indigo
                        ),
                        title: AppLocalizations.translate('settings_language'),
                        subtitle: currentLang == 'rw' ? 'Ikinyarwanda' : 'English',
                        onTap: () => _showLanguagePicker(context),
                      ),
                      const Divider(height: 1, indent: 56),
                      _SettingsTile(
                        leading: const _IconBadge(
                          icon: Icons.widgets_outlined,
                          color: Color(0xFF0EA5E9), // Sky Blue
                        ),
                        title: currentLang == 'rw' ? 'Akamenyetso k\'Ibyanditswe' : 'Bible Widget Settings',
                        subtitle: currentLang == 'rw' ? 'Guhindura uko kagaragara' : 'Customize layout & opacity',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const WidgetSettingsScreen()),
                          );
                        },
                      ),
                    ],
                  ),

                  // ── ACCOUNT & BACKUP SECTION ──
                  if (isSignedIn) ...[
                    // Signed In Profile Card
                    _SettingsGroup(
                      title: AppLocalizations.translate('settings_account'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 26,
                                    backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                                    child: user.photoUrl == null
                                        ? Icon(Icons.person, size: 26, color: isDark ? Colors.white70 : Colors.black54)
                                        : null,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user.displayName ?? 'Google User',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          user.email,
                                          style: TextStyle(
                                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Divider(height: 1),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                  onPressed: _isSyncing ? null : _handleSignOut,
                                  icon: const Icon(Icons.logout, size: 16),
                                  label: Text(
                                    AppLocalizations.translate('settings_signout'),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Backup & Sync Actions
                    _SettingsGroup(
                      title: AppLocalizations.translate('settings_sync'),
                      children: [
                        _SettingsTile(
                          leading: const _IconBadge(
                            icon: Icons.cloud_upload_outlined,
                            color: Color(0xFF10B981), // Emerald
                          ),
                          title: AppLocalizations.translate('settings_backup'),
                          onTap: _isSyncing ? () {} : _handleBackup,
                        ),
                        const Divider(height: 1, indent: 56),
                        _SettingsTile(
                          leading: const _IconBadge(
                            icon: Icons.cloud_download_outlined,
                            color: Color(0xFF06B6D4), // Teal
                          ),
                          title: AppLocalizations.translate('settings_restore'),
                          onTap: _isSyncing ? () {} : _handleRestoreConfirm,
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2.0),
                      child: Text(
                        AppLocalizations.translate('settings_sync_desc'),
                        style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    // Signed Out CTA Promo Card
                    _SettingsGroup(
                      title: AppLocalizations.translate('settings_account'),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20.0),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDark
                                  ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                                  : [const Color(0xFFF0F7FF), Colors.white],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: accentBlue.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.cloud_sync, color: accentBlue, size: 26),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      AppLocalizations.translate('settings_sync'),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Text(
                                AppLocalizations.translate('settings_account_desc'),
                                style: TextStyle(
                                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: accentBlue,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    elevation: 0,
                                  ),
                                  onPressed: _isSyncing ? null : _handleSignIn,
                                  icon: const Icon(Icons.login, size: 18),
                                  label: Text(
                                    AppLocalizations.translate('settings_signin'),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Sync Status messages & spinner
                  if (_isSyncing) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            AppLocalizations.translate('settings_sync_loading'),
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_syncStatusMessage != null) ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _syncStatusMessage!.contains('Error') ||
                                _syncStatusMessage!.contains('failed') ||
                                _syncStatusMessage!.contains('byanze')
                            ? Colors.redAccent.withValues(alpha: 0.1)
                            : Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _syncStatusMessage!,
                        style: TextStyle(
                          color: _syncStatusMessage!.contains('Error') ||
                                  _syncStatusMessage!.contains('failed') ||
                                  _syncStatusMessage!.contains('byanze')
                              ? Colors.redAccent
                              : Colors.green,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],

                  // ── ABOUT / MORE SECTION ──
                  _SettingsGroup(
                    title: currentLang == 'rw' ? 'Ibindi' : 'More',
                    children: [
                      _SettingsTile(
                        leading: const _IconBadge(
                          icon: Icons.privacy_tip_outlined,
                          color: Color(0xFFF97316), // Orange
                        ),
                        title: AppLocalizations.translate('settings_privacy'),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()),
                          );
                        },
                      ),
                      const Divider(height: 1, indent: 56),
                      _SettingsTile(
                        leading: const _IconBadge(
                          icon: Icons.info_outline,
                          color: Color(0xFF64748B), // Slate Grey
                        ),
                        title: currentLang == 'rw' ? 'Verisiyo y\'App' : 'App Version',
                        trailing: const Text(
                          'v1.0.1',
                          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        onTap: () {},
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _showLanguagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return ValueListenableBuilder<String>(
          valueListenable: localeNotifier,
          builder: (context, currentLang, _) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    AppLocalizations.translate('settings_select_lang'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Text('🇷🇼', style: TextStyle(fontSize: 24)),
                    title: const Text('Ikinyarwanda', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    trailing: currentLang == 'rw' ? Icon(Icons.check_circle, color: Theme.of(context).primaryColor) : null,
                    onTap: () {
                      localeNotifier.value = 'rw';
                      AppStateService.setAppLanguage('rw');
                      Navigator.pop(context);
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Text('🇺🇸', style: TextStyle(fontSize: 24)),
                    title: const Text('English', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    trailing: currentLang == 'en' ? Icon(Icons.check_circle, color: Theme.of(context).primaryColor) : null,
                    onTap: () {
                      localeNotifier.value = 'en';
                      AppStateService.setAppLanguage('en');
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleSignIn() async {
    setState(() {
      _isSyncing = true;
      _syncStatusMessage = null;
    });
    final user = await _backupService.signIn();
    if (!mounted) return;
    setState(() {
      _isSyncing = false;
      if (user != null) {
        _syncStatusMessage = '${AppLocalizations.translate('settings_signed_in_as')}: ${user.email}';
      } else {
        _syncStatusMessage = AppLocalizations.translate('settings_backup_failed');
      }
    });
  }

  Future<void> _handleSignOut() async {
    setState(() {
      _isSyncing = true;
      _syncStatusMessage = null;
    });
    await _backupService.signOut();
    if (!mounted) return;
    setState(() {
      _isSyncing = false;
      _syncStatusMessage = AppLocalizations.translate('settings_signed_out');
    });
  }

  Future<void> _handleBackup() async {
    setState(() {
      _isSyncing = true;
      _syncStatusMessage = null;
    });
    final success = await _backupService.backupToGoogleDrive();
    if (!mounted) return;
    setState(() {
      _isSyncing = false;
      if (success) {
        _syncStatusMessage = AppLocalizations.translate('settings_backup_success');
      } else {
        _syncStatusMessage = AppLocalizations.translate('settings_backup_failed');
      }
    });
  }

  Future<void> _handleRestoreConfirm() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.translate('settings_restore_confirm_title')),
        content: Text(AppLocalizations.translate('settings_restore_confirm_desc')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.translate('settings_cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleRestore();
            },
            child: Text(
              AppLocalizations.translate('settings_restore_btn'),
              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRestore() async {
    setState(() {
      _isSyncing = true;
      _syncStatusMessage = null;
    });
    final success = await _backupService.restoreFromGoogleDrive();
    if (!mounted) return;
    setState(() {
      _isSyncing = false;
      if (success) {
        _syncStatusMessage = AppLocalizations.translate('settings_restore_success');
        _showRestartAlert();
      } else {
        _syncStatusMessage = AppLocalizations.translate('settings_restore_failed');
      }
    });
  }

  void _showRestartAlert() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.translate('settings_restart_title')),
        content: Text(AppLocalizations.translate('settings_restart_desc')),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsGroup({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 6.0, top: 12.0),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white54 : Colors.black54,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Material(
          color: isDark ? const Color(0xFF1B1D1B) : Colors.white,
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget leading;
  final Widget? trailing;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.title,
    this.subtitle,
    required this.leading,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: leading,
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14.5),
      ),
      subtitle: subtitle != null
          ? Text(subtitle!, style: const TextStyle(fontSize: 12, color: Colors.grey))
          : null,
      trailing: trailing ?? const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
      onTap: onTap,
    );
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _IconBadge({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }
}
