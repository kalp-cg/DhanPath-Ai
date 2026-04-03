import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/cloud_sync_service.dart';
import '../services/secure_storage_service.dart';
import '../services/user_preferences_service.dart';
import '../theme/app_theme.dart';

/// One place to set dashboard URL, open the web family workspace, and sync SMS data.
class CloudSetupScreen extends StatefulWidget {
  const CloudSetupScreen({super.key});

  @override
  State<CloudSetupScreen> createState() => _CloudSetupScreenState();
}

class _CloudSetupScreenState extends State<CloudSetupScreen> {
  final _urlCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _secureStorage = SecureStorageService();
  bool _loading = true;
  bool _syncing = false;
  String? _familyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = UserPreferencesService();
    final url = await prefs.getEffectiveCloudDashboardUrl();
    final fid = await prefs.getCloudFamilyId();
    final savedEmail = await _secureStorage.getCloudSyncEmail();
    final savedPassword = await _secureStorage.getCloudSyncPassword();
    setState(() {
      _urlCtrl.text = url;
      _emailCtrl.text = savedEmail ?? '';
      _passwordCtrl.text = savedPassword ?? '';
      _familyId = fid.isEmpty ? null : fid;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _openDashboard() async {
    final base = _urlCtrl.text.trim();
    if (base.isEmpty) return;
    final uri = Uri.parse(base.endsWith('/') ? '${base}family' : '$base/family');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open browser. Check the URL.')),
      );
    }
  }

  Future<void> _saveUrl() async {
    final prefs = UserPreferencesService();
    final raw = _urlCtrl.text.trim();
    if (raw.isEmpty) {
      await prefs.setCloudDashboardUrl('');
      return;
    }
    await prefs.setCloudDashboardUrl(raw);
  }

  Future<void> _syncNow() async {
    HapticFeedback.mediumImpact();
    final email = _emailCtrl.text.trim().toLowerCase();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter website email and password once for one-tap sync.'),
        ),
      );
      return;
    }

    await _saveUrl();
    final prefs = UserPreferencesService();
    final dashboardUrl = await prefs.getEffectiveCloudDashboardUrl();

    setState(() => _syncing = true);
    try {
      final token = await CloudSyncService.loginAndGetToken(
        dashboardUrl: dashboardUrl,
        email: email,
        password: password,
      );
      await _secureStorage.setCloudSyncCredentials(
        email: email,
        password: password,
      );
      await _secureStorage.setCloudSyncToken(token);

      final syncer = CloudSyncService(
        dashboardUrl: dashboardUrl,
        accessToken: token,
      );
      final summary = await syncer.verifyMembership();
      final resolvedFamilyId =
          (summary['familyId'] as String?)?.trim() ?? '';
      if (resolvedFamilyId.isEmpty) {
        throw Exception(
          'No family workspace for this email yet. Open the dashboard, '
          'create a workspace or accept an invite, then try again.',
        );
      }

      await prefs.setCloudFamilyId(resolvedFamilyId);
      await prefs.setCloudEmail(email);

      final count = await syncer.syncAll();
      if (mounted) {
        setState(() => _familyId = resolvedFamilyId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              count == 0
                  ? 'Up to date (no new transactions to upload).'
                  : 'Synced $count transactions to the family dashboard.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sync failed. Check website credentials and family membership.\n$e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Family & cloud')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Connect your phone to the web dashboard so family spending stays in one place.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _urlCtrl,
            decoration: InputDecoration(
              labelText: 'Dashboard URL',
              hintText: UserPreferencesService.defaultCloudDashboardUrl,
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
          ),
          const SizedBox(height: 8),
          Text(
            'Use the same email here and on the website. Default matches your deployed app.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailCtrl,
            decoration: const InputDecoration(
              labelText: 'Website email',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordCtrl,
            decoration: const InputDecoration(
              labelText: 'Website password',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
            autocorrect: false,
          ),
          if (_familyId != null) ...[
            const SizedBox(height: 8),
            Text(
              'Family ID: $_familyId',
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _syncing ? null : _syncNow,
            icon: _syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_rounded),
            label: Text(_syncing ? 'Syncing…' : 'One-tap sync to website'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _openDashboard,
            icon: const Icon(Icons.open_in_browser_rounded),
            label: const Text('Open family dashboard'),
          ),
          const SizedBox(height: 28),
          Text(
            'Setup',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '1. Tap “Open family dashboard” and sign in with the same email.\n'
            '2. Create a workspace or accept an invite.\n'
            '3. Enter the same website email/password once.\n'
            '4. Tap “One-tap sync to website”.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppTheme.spacingXxl),
        ],
      ),
    );
  }
}
