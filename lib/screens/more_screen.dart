import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'settings_screen.dart';
import 'achievements_screen.dart';
import 'money_personality_screen.dart';
import 'spending_story_screen.dart';
import 'monthly_report_screen.dart';
import 'help_faq_screen.dart';
import 'spending_heatmap_screen.dart';
import 'budget_suggest_screen.dart';
import 'weekly_digest_screen.dart';
import 'savings_goals_screen.dart';
import 'recurring_bills_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

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
        title: Text('More', style: theme.appBarTheme.titleTextStyle),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ── Reports & Analysis ──
          _sectionLabel('Reports & Analysis', theme),
          const SizedBox(height: 8),
          _buildTile(
            context,
            icon: Icons.assessment_rounded,
            label: 'Monthly Report',
            subtitle: 'Full breakdown of your spending',
            color: const Color(0xFF6C5CE7),
            isDark: isDark,
            cs: cs,
            onTap: () => _navigate(context, const MonthlyReportScreen()),
          ),
          _buildTile(
            context,
            icon: Icons.auto_stories_rounded,
            label: 'Spending Story',
            subtitle: 'Your monthly spending recap',
            color: const Color(0xFFE17055),
            isDark: isDark,
            cs: cs,
            onTap: () => _navigate(context, const SpendingStoryScreen()),
          ),
          _buildTile(
            context,
            icon: Icons.calendar_view_month_rounded,
            label: 'Spending Calendar',
            subtitle: 'See daily spending on a heatmap',
            color: const Color(0xFF00B894),
            isDark: isDark,
            cs: cs,
            onTap: () => _navigate(context, const SpendingHeatmapScreen()),
          ),
          _buildTile(
            context,
            icon: Icons.summarize_rounded,
            label: 'Weekly Summary',
            subtitle: 'How your week went',
            color: const Color(0xFF0984E3),
            isDark: isDark,
            cs: cs,
            onTap: () => _navigate(context, const WeeklyDigestScreen()),
          ),

          const SizedBox(height: 20),

          // ── Tools ──
          _sectionLabel('Tools', theme),
          const SizedBox(height: 8),
          _buildTile(
            context,
            icon: Icons.track_changes_rounded,
            label: 'Savings Goals',
            subtitle: 'Track your targets for big purchases',
            color: const Color(0xFF00B894),
            isDark: isDark,
            cs: cs,
            onTap: () => _navigate(context, const SavingsGoalsScreen()),
          ),
          _buildTile(
            context,
            icon: Icons.autorenew_rounded,
            label: 'Recurring Bills',
            subtitle: 'Manage subscriptions & regular payments',
            color: const Color(0xFFE17055),
            isDark: isDark,
            cs: cs,
            onTap: () => _navigate(context, const RecurringBillsScreen()),
          ),
          _buildTile(
            context,
            icon: Icons.account_balance_wallet_rounded,
            label: 'Budget Planner',
            subtitle: 'Suggested budgets based on your spending',
            color: cs.primary,
            isDark: isDark,
            cs: cs,
            onTap: () => _navigate(context, const BudgetSuggestScreen()),
          ),

          const SizedBox(height: 20),

          // ── Fun ──
          _sectionLabel('Fun', theme),
          const SizedBox(height: 8),
          _buildTile(
            context,
            icon: Icons.psychology_rounded,
            label: 'Your Spending Style',
            subtitle: 'Discover your money personality',
            color: const Color(0xFF6C5CE7),
            isDark: isDark,
            cs: cs,
            onTap: () => _navigate(context, const MoneyPersonalityScreen()),
          ),
          _buildTile(
            context,
            icon: Icons.emoji_events_rounded,
            label: 'Milestones',
            subtitle: 'Badges and achievements earned',
            color: const Color(0xFFFFBE0B),
            isDark: isDark,
            cs: cs,
            onTap: () => _navigate(context, const AchievementsScreen()),
          ),

          const SizedBox(height: 20),

          // ── App ──
          _sectionLabel('App', theme),
          const SizedBox(height: 8),
          _buildTile(
            context,
            icon: Icons.settings_rounded,
            label: 'Settings',
            subtitle: 'Theme, security, data, and more',
            color: cs.onSurfaceVariant,
            isDark: isDark,
            cs: cs,
            onTap: () => _navigate(context, const SettingsScreen()),
          ),
          _buildTile(
            context,
            icon: Icons.help_outline_rounded,
            label: 'Help & FAQ',
            subtitle: 'Common questions answered',
            color: cs.onSurfaceVariant,
            isDark: isDark,
            cs: cs,
            onTap: () => _navigate(context, const HelpFaqScreen()),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, ThemeData theme) {
    return Text(
      text,
      style: theme.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required bool isDark,
    required ColorScheme cs,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withOpacity(isDark ? 0.15 : 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 22, color: color),
        ),
        title: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: cs.onSurfaceVariant,
          size: 20,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
      ),
    );
  }

  void _navigate(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}
