import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const String privacyPolicyUrl =
      'https://github.com/kalp-cg/DhanPath/blob/main/PRIVACY.md';

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: Text('Privacy Policy', style: theme.appBarTheme.titleTextStyle),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser_rounded),
            tooltip: 'Open in browser',
            onPressed: () => _launchUrl(privacyPolicyUrl),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    cs.primary.withOpacity(0.15),
                    cs.primary.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: cs.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.shield_rounded,
                      color: cs.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Privacy Matters',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'All data stays on your device. Period.',
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Key Points
            _buildSection(
              context,
              icon: Icons.devices_rounded,
              title: '100% On-Device Processing',
              items: [
                'No cloud servers — your data never leaves your phone',
                'No data collection, tracking, or telemetry',
                'No ads or advertising networks',
                'Works completely offline after setup',
              ],
            ),

            _buildSection(
              context,
              icon: Icons.storage_rounded,
              title: 'Data Storage',
              items: [
                'All data stored in local SQLite database',
                'Protected by Android\'s app sandboxing',
                'Uninstalling the app removes all data',
                'You can delete individual transactions anytime',
                'Export your data before uninstalling',
              ],
            ),

            _buildSection(
              context,
              icon: Icons.sms_rounded,
              title: 'SMS Permission',
              items: [
                'Read-only access to bank transaction SMS',
                'We cannot send or modify messages',
                'SMS parsing happens entirely on-device',
                'Only transaction data is extracted, not full messages',
              ],
            ),

            _buildSection(
              context,
              icon: Icons.block_rounded,
              title: 'What We DON\'T Use',
              items: [
                'No cloud APIs or external services',
                'No analytics (Google Analytics, Firebase, etc.)',
                'No crash reporting services',
                'No social media SDKs',
                'No payment processors',
              ],
            ),

            _buildSection(
              context,
              icon: Icons.lock_rounded,
              title: 'Document Vault Security',
              items: [
                'PIN-protected with SHA-256 hashing',
                'Documents stored in app\'s private directory',
                'Not accessible to other apps',
                'Security question for PIN recovery',
              ],
            ),

            _buildSection(
              context,
              icon: Icons.child_care_rounded,
              title: 'Children\'s Privacy',
              items: [
                'DhanPath is not directed at children under 13',
                'We do not knowingly collect information from children',
              ],
            ),

            const SizedBox(height: 16),

            // Open Source
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? cs.surface
                    : cs.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.06)
                      : cs.outlineVariant.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.code_rounded, color: cs.secondary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Open Source',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'DhanPath is fully open source. Review our code and verify our privacy claims yourself.',
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () =>
                        _launchUrl('https://github.com/kalp-cg/DhanPath'),
                    child: Text(
                      'View on GitHub →',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Last updated + contact
            Center(
              child: Column(
                children: [
                  Text(
                    'Last Updated: February 2026',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withOpacity(0.4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _launchUrl(
                      'https://github.com/kalp-cg/DhanPath/issues',
                    ),
                    child: Text(
                      'Questions? Open an issue on GitHub',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.primary.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required List<String> items,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: cs.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cs.primary.withOpacity(0.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: cs.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
