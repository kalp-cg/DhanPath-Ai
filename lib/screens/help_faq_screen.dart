import 'package:flutter/material.dart';
import '../services/user_preferences_service.dart';

class HelpFaqScreen extends StatelessWidget {
  const HelpFaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Help & FAQ')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection('Getting Started'),
          _buildFaqItem(
            'How does DhanPath track my expenses?',
            'DhanPath automatically reads your bank SMS messages to detect '
                'transactions. It parses the amount, merchant, and other details '
                'to create transaction records. You can also add transactions manually.',
          ),
          _buildFaqItem(
            'Why do I need to grant SMS permission?',
            'SMS permission is required to read your bank messages and automatically '
                'detect transactions. DhanPath only processes financial SMS from known '
                'bank senders - personal messages are never read or stored.',
          ),

          const SizedBox(height: 16),
          _buildSection('Transactions'),
          _buildFaqItem(
            'Why is a transaction showing the wrong category?',
            'You can tap on any transaction to edit its category. You can also '
                'create automation rules in Settings → Automation Rules to automatically '
                'categorize future transactions based on merchant name or other criteria.',
          ),
          _buildFaqItem(
            'What does "Unrecognized SMS" mean?',
            'Sometimes SMS messages from banks have unusual formats that DhanPath '
                'cannot parse automatically. These are saved in Settings → Unrecognized SMS '
                'for review. We continuously improve our parsing to handle more formats.',
          ),

          const SizedBox(height: 16),
          _buildSection('Budgets'),
          _buildFaqItem(
            'How do I set a budget?',
            'Go to the Monthly Budget screen (from Home or Settings) and tap the + button. '
                'You can set budgets for specific categories like Food, Shopping, etc. '
                'The app will track your spending against these budgets.',
          ),
          _buildFaqItem(
            'What is Budget Rollover?',
            'When Budget Rollover is enabled in Budget Settings, any unspent budget '
                'from the previous month carries forward to the next month. For example, '
                'if you have ${CurrencyHelper.symbol}2,000 left in your Food budget, it adds to next month\'s limit.',
          ),
          _buildFaqItem(
            'How do Budget Alerts work?',
            'When enabled, you\'ll receive a notification when your spending reaches '
                'the alert threshold (default 80%) of your budget. You can customize this '
                'threshold in Settings → Budget Settings.',
          ),

          const SizedBox(height: 16),
          _buildSection('Security'),
          _buildFaqItem(
            'How do I enable App Lock?',
            'Go to Settings → App Lock and toggle it on. You\'ll be asked to set '
                'a 4-digit PIN. If your device supports it, you can also enable fingerprint '
                'or face unlock for faster access.',
          ),
          _buildFaqItem(
            'Is my financial data secure?',
            'Yes! All data is stored locally on your device. Your PIN is hashed and '
                'stored securely. We never upload your financial data to any server.',
          ),

          const SizedBox(height: 16),
          _buildSection('Data & Backup'),
          _buildFaqItem(
            'How do I backup my data?',
            'Go to Settings → Backup Data. This creates a backup file of your entire '
                'database that you can save to cloud storage or share. To restore, use '
                'Settings → Restore Data and select a backup file.',
          ),
          _buildFaqItem(
            'Can I export my transactions?',
            'Yes! Go to Settings → Export Transactions. You can export to CSV format '
                '(for spreadsheets) or PDF format (for reports). Choose a date range '
                'to export specific transactions.',
          ),

          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                Text(
                  'DhanPath v1.0.0',
                  style: TextStyle(color: cs.outline, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'Made with ❤️ for smart money management',
                  style: TextStyle(color: cs.outline, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Builder(
        builder: (context) => Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            answer,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
