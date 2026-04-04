import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../screens/manage_accounts_screen.dart';
import '../widgets/export_dialog.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/transaction_provider.dart';
import '../services/backup_service.dart';
import '../services/secure_storage_service.dart';
import '../services/user_preferences_service.dart';
import '../screens/manage_categories_screen.dart';
import '../screens/rules_screen.dart';
import '../screens/unrecognized_sms_screen.dart';
import '../screens/app_lock_screen.dart';
import '../screens/help_faq_screen.dart';
import '../screens/privacy_policy_screen.dart';
import '../screens/notification_settings_screen.dart';
import '../screens/pdf_upload_screen.dart';
import '../screens/cloud_setup_screen.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _appLockEnabled = false;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  bool _isLoadingLock = true;
  bool _simpleModeEnabled = false;
  final _secureStorage = SecureStorageService();

  @override
  void initState() {
    super.initState();
    _loadAppLockState();
  }

  Future<void> _loadAppLockState() async {
    final enabled = await _secureStorage.isAppLockEnabled();
    final biometricEnabled = await _secureStorage.isBiometricEnabled();

    bool bioAvailable = false;
    try {
      final localAuth = LocalAuthentication();
      bioAvailable =
          await localAuth.canCheckBiometrics ||
          await localAuth.isDeviceSupported();
    } catch (_) {}

    final simpleMode = await UserPreferencesService().isSimpleMode();

    if (mounted) {
      setState(() {
        _appLockEnabled = enabled;
        _biometricEnabled = biometricEnabled;
        _biometricAvailable = bioAvailable;
        _simpleModeEnabled = simpleMode;
        _isLoadingLock = false;
      });
    }
  }

  Future<void> _handleAppLockToggle(bool enable) async {
    if (enable) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const AppLockScreen(isSettingUp: true),
        ),
      );
      if (result == true) {
        await _secureStorage.setAppLockEnabled(true);
        setState(() => _appLockEnabled = true);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('App Lock enabled')));
        }
      }
    } else {
      final verified = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => const AppLockScreen(isSettingUp: false),
        ),
      );
      if (verified == true) {
        await _secureStorage.setAppLockEnabled(false);
        await _secureStorage.deletePin();
        setState(() => _appLockEnabled = false);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('App Lock disabled')));
        }
      }
    }
  }

  void _showClearDataDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return AlertDialog(
          icon: Icon(Icons.warning_rounded, color: cs.error, size: 32),
          title: const Text('Clear All Transactions?'),
          content: const Text(
            'This will permanently delete ALL transactions. '
            'You can rescan your inbox to re-import them.\n\n'
            'This action cannot be undone!',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: cs.error,
                foregroundColor: cs.onError,
              ),
              child: const Text('Clear All'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      try {
        await Provider.of<TransactionProvider>(
          context,
          listen: false,
        ).clearAllTransactions();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All transactions cleared')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
        children: [
          _SectionHeader(title: 'Family & cloud'),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.groups_rounded,
                iconColor: const Color(0xFF1E88E5),
                title: 'Family workspace & sync',
                subtitle: 'Dashboard URL, open web app, upload transactions',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CloudSetupScreen()),
                ),
              ),
            ],
          ),
          // ── Preferences ──
          _SectionHeader(title: 'Preferences'),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.brightness_6_rounded,
                iconColor: const Color(0xFFE17055),
                title: 'Simple Mode',
                subtitle: 'Hide advanced charts & metrics',
                trailing: Switch.adaptive(
                  value: _simpleModeEnabled,
                  onChanged: (val) async {
                    await UserPreferencesService().setSimpleMode(val);
                    setState(() => _simpleModeEnabled = val);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            val
                                ? 'Simple Mode enabled'
                                : 'Simple Mode disabled',
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
              const _TileDivider(),
              // Theme selector
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMd,
                  vertical: AppTheme.spacingMd,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingSm),
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Icon(
                        Icons.palette_rounded,
                        color: cs.primary,
                        size: AppTheme.iconSizeSm,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Theme',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Choose app appearance',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spacingMd,
                  0,
                  AppTheme.spacingMd,
                  AppTheme.spacingMd,
                ),
                child: Consumer<ThemeProvider>(
                  builder: (context, themeProvider, _) {
                    return SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.brightness_auto_rounded, size: 18),
                          label: Text('Auto'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode_rounded, size: 18),
                          label: Text('Light'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode_rounded, size: 18),
                          label: Text('Dark'),
                        ),
                      ],
                      selected: {themeProvider.themeMode},
                      onSelectionChanged: (set) {
                        themeProvider.setThemeMode(set.first);
                      },
                      style: SegmentedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          // ── Budget ──
          _SectionHeader(title: 'Budget'),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.category_rounded,
                iconColor: const Color(0xFF7C4DFF),
                title: 'Categories',
                subtitle: 'Manage expense & income categories',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ManageCategoriesScreen(),
                  ),
                ),
              ),
              const _TileDivider(),
              _SettingsTile(
                icon: Icons.auto_fix_high_rounded,
                iconColor: cs.primary,
                title: 'Automation Rules',
                subtitle: 'Auto-categorize transactions',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RulesScreen()),
                ),
              ),
              const _TileDivider(),
              _SettingsTile(
                icon: Icons.account_balance_rounded,
                iconColor: const Color(0xFF00897B),
                title: 'Manage Accounts',
                subtitle: 'Add and manage bank accounts',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ManageAccountsScreen(),
                  ),
                ),
              ),
            ],
          ),

          // ── Notifications ──
          _SectionHeader(title: 'Notifications'),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.notifications_rounded,
                iconColor: const Color(0xFFBB86FC),
                title: 'Notification Settings',
                subtitle: 'Alerts, reminders & smart tips',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationSettingsScreen(),
                  ),
                ),
              ),
            ],
          ),

          // ── Security ──
          _SectionHeader(title: 'Security'),
          _SettingsCard(
            children: [
              // App Lock
              _SettingsTile(
                icon: Icons.lock_rounded,
                iconColor: const Color(0xFFF4511E),
                title: 'App Lock',
                subtitle: _appLockEnabled
                    ? 'PIN enabled'
                    : 'PIN or fingerprint security',
                trailing: _isLoadingLock
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Switch.adaptive(
                        value: _appLockEnabled,
                        onChanged: _handleAppLockToggle,
                      ),
              ),
              // Biometric toggle
              if (_appLockEnabled && _biometricAvailable) ...[
                const _TileDivider(),
                _SettingsTile(
                  icon: Icons.fingerprint_rounded,
                  iconColor: const Color(0xFF00897B),
                  title: 'Fingerprint Unlock',
                  subtitle: 'Use fingerprint to unlock app',
                  trailing: Switch.adaptive(
                    value: _biometricEnabled,
                    onChanged: (val) async {
                      await _secureStorage.setBiometricEnabled(val);
                      setState(() => _biometricEnabled = val);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              val
                                  ? 'Fingerprint unlock enabled'
                                  : 'Fingerprint unlock disabled',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ],
          ),

          // ── Data ──
          _SectionHeader(title: 'Data'),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.document_scanner_rounded,
                iconColor: Colors.teal,
                title: 'Import Bank Statement (OCR)',
                subtitle: 'Offline AI PDF Parser',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PdfUploadScreen()),
                ),
              ),
              const _TileDivider(),
              _SettingsTile(
                icon: Icons.file_download_rounded,
                iconColor: cs.primary,
                title: 'Export Transactions',
                subtitle: 'Export to CSV or PDF',
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => const ExportDialog(),
                  );
                },
              ),
              const _TileDivider(),
              _SettingsTile(
                icon: Icons.backup_rounded,
                iconColor: const Color(0xFF43A047),
                title: 'Backup Data',
                subtitle: 'Save a copy of your data',
                onTap: () async {
                  try {
                    await BackupService().createBackup();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Backup failed: $e')),
                      );
                    }
                  }
                },
              ),
              const _TileDivider(),
              _SettingsTile(
                icon: Icons.restore_rounded,
                iconColor: Theme.of(context).colorScheme.primary,
                title: 'Restore Data',
                subtitle: 'Restore from a backup file',
                onTap: () async {
                  try {
                    bool success = await BackupService().restoreBackup();
                    if (success && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Restore successful!')),
                      );
                      Provider.of<TransactionProvider>(
                        context,
                        listen: false,
                      ).loadTransactions();
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Restore failed: $e')),
                      );
                    }
                  }
                },
              ),
              const _TileDivider(),
              _SettingsTile(
                icon: Icons.sms_failed_outlined,
                iconColor: cs.secondary,
                title: 'Unrecognized SMS',
                subtitle: 'View SMS that failed parsing',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const UnrecognizedSmsScreen(),
                  ),
                ),
              ),
              const _TileDivider(),
              _SettingsTile(
                icon: Icons.delete_forever_rounded,
                iconColor: cs.error,
                title: 'Clear All Transactions',
                subtitle: 'Delete all data and rescan inbox',
                isDestructive: true,
                onTap: _showClearDataDialog,
              ),
            ],
          ),

          // ── About ──
          _SectionHeader(title: 'About'),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.info_outline_rounded,
                iconColor: cs.onSurfaceVariant,
                title: 'Version',
                subtitle: '1.0.0',
                trailing: Text(
                  'DhanPath',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const _TileDivider(),
              _SettingsTile(
                icon: Icons.help_outline_rounded,
                iconColor: cs.primary,
                title: 'Help & FAQ',
                subtitle: 'Get help using DhanPath',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HelpFaqScreen()),
                ),
              ),
              const _TileDivider(),
              _SettingsTile(
                icon: Icons.shield_outlined,
                iconColor: cs.secondary,
                title: 'Privacy Policy',
                subtitle: 'How we protect your data',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PrivacyPolicyScreen(),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppTheme.spacingXxl),
        ],
      ),
    );
  }
}

// ━━━ Section Header ━━━
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingLg,
        AppTheme.spacingLg,
        AppTheme.spacingLg,
        AppTheme.spacingSm,
      ),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ━━━ Settings Card (grouped container) ━━━
class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(children: children),
    );
  }
}

// ━━━ Single Settings Tile ━━━
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool isDestructive;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = isDestructive ? cs.error : iconColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMd,
          vertical: AppTheme.spacingMd,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingSm),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Icon(icon, color: color, size: AppTheme.iconSizeSm),
            ),
            const SizedBox(width: AppTheme.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: isDestructive ? cs.error : null,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            trailing ??
                (onTap != null
                    ? Icon(
                        Icons.chevron_right_rounded,
                        color: cs.onSurfaceVariant,
                        size: 20,
                      )
                    : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}

// ━━━ Divider between tiles ━━━
class _TileDivider extends StatelessWidget {
  const _TileDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent:
          AppTheme.spacingMd + 36 + AppTheme.spacingMd, // icon container + gap
      endIndent: AppTheme.spacingMd,
      color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
    );
  }
}
