import 'package:flutter/material.dart';
import '../services/backup_service.dart';
import '../services/app_localizations.dart';
import '../services/app_state_service.dart';
import 'privacy_policy_screen.dart';

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
    final theme = Theme.of(context);

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
            padding: const EdgeInsets.all(16.0),
            children: [
              // ── LANGUAGE SWITCHER CARD ──
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.translate('settings_language'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ValueListenableBuilder<String>(
                        valueListenable: localeNotifier,
                        builder: (context, currentLang, _) {
                          return Row(
                            children: [
                              Expanded(
                                child: ChoiceChip(
                                  showCheckmark: false,
                                  label: const Center(child: Text('Ikinyarwanda')),
                                  selected: currentLang == 'rw',
                                  onSelected: (selected) {
                                    if (selected) {
                                      localeNotifier.value = 'rw';
                                      AppStateService.setAppLanguage('rw');
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ChoiceChip(
                                  showCheckmark: false,
                                  label: const Center(child: Text('English')),
                                  selected: currentLang == 'en',
                                  onSelected: (selected) {
                                    if (selected) {
                                      localeNotifier.value = 'en';
                                      AppStateService.setAppLanguage('en');
                                    }
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── ACCOUNT CARD ──
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.translate('settings_account'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (isSignedIn) ...[
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                              child: user.photoUrl == null ? const Icon(Icons.person) : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.displayName ?? 'Google User',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  Text(
                                    user.email,
                                    style: TextStyle(
                                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent, width: 1),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: _isSyncing ? null : _handleSignOut,
                            icon: const Icon(Icons.logout, size: 18),
                            label: Text(
                              AppLocalizations.translate('settings_signout'),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ] else ...[
                        Text(
                          AppLocalizations.translate('settings_account_desc'),
                          style: TextStyle(
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                            ),
                            onPressed: _isSyncing ? null : _handleSignIn,
                            icon: const Icon(Icons.login, size: 18),
                            label: Text(
                              AppLocalizations.translate('settings_signin'),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── BACKUP & RESTORE CARD ──
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.translate('settings_sync'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        AppLocalizations.translate('settings_sync_desc'),
                        style: TextStyle(
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor.withValues(alpha: 0.1),
                          foregroundColor: primaryColor,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          minimumSize: const Size(double.infinity, 48),
                          elevation: 0,
                        ),
                        onPressed: (!isSignedIn || _isSyncing) ? null : _handleBackup,
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: Text(
                          AppLocalizations.translate('settings_backup'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? Colors.white70 : Colors.black87,
                          side: BorderSide(
                            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        onPressed: (!isSignedIn || _isSyncing) ? null : _handleRestoreConfirm,
                        icon: const Icon(Icons.cloud_download_outlined),
                        label: Text(
                          AppLocalizations.translate('settings_restore'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (_isSyncing) ...[
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              AppLocalizations.translate('settings_sync_loading'),
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                      if (_syncStatusMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
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
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // ── PRIVACY POLICY CARD ──
              Card(
                child: ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: Text(AppLocalizations.translate('settings_privacy')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
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
