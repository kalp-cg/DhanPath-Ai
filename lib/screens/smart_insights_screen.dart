import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../services/smart_insights_engine.dart';
import '../theme/app_theme.dart';
import '../widgets/dhanpath_components.dart';

/// Smart Insights Screen
///
/// Personalized financial insights with minimal, professional UI.
/// Displays severity-based cards and categorization.

class SmartInsightsScreen extends StatelessWidget {
  const SmartInsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Smart Insights'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => _showInfoDialog(context),
          ),
        ],
      ),
      body: Consumer<TransactionProvider>(
        builder: (context, provider, _) {
          final insights = SmartInsightsEngine.analyze(
            provider.allTransactions,
          );

          if (insights.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.psychology_outlined,
              title: 'No Insights Yet',
              subtitle:
                  'Keep tracking your transactions and insights will appear here automatically.',
            );
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.psychology_rounded,
                        color: cs.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${insights.length} Insights Found',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Powered by your transaction data',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              _buildSeverityChips(context, insights),

              const SizedBox(height: 8),

              ...insights.map((insight) => _InsightCard(insight: insight)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSeverityChips(
    BuildContext context,
    List<SmartInsight> insights,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final counts = <InsightSeverity, int>{};
    for (final i in insights) {
      counts[i.severity] = (counts[i.severity] ?? 0) + 1;
    }

    final chipData = [
      if (counts[InsightSeverity.critical] != null)
        (
          Icons.error_rounded,
          'Critical',
          counts[InsightSeverity.critical]!,
          AppTheme.expenseDark,
        ),
      if (counts[InsightSeverity.warning] != null)
        (
          Icons.warning_rounded,
          'Warning',
          counts[InsightSeverity.warning]!,
          AppTheme.budgetWarning,
        ),
      if (counts[InsightSeverity.positive] != null)
        (
          Icons.check_circle_rounded,
          'Positive',
          counts[InsightSeverity.positive]!,
          AppTheme.budgetSafe,
        ),
      if (counts[InsightSeverity.neutral] != null)
        (
          Icons.info_rounded,
          'Info',
          counts[InsightSeverity.neutral]!,
          cs.outline,
        ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: chipData.map((data) {
          return Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: data.$4.withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: data.$4.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(data.$1, size: 14, color: data.$4),
                const SizedBox(width: 4),
                Text(
                  '${data.$3} ${data.$2}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: data.$4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.psychology_rounded),
            SizedBox(width: 8),
            Text('About Smart Insights'),
          ],
        ),
        content: const Text(
          'DhanPath analyzes your transaction patterns using 10 different algorithms:\n\n'
          '• Spending anomaly detection\n'
          '• Category trend analysis\n'
          '• Merchant loyalty detection\n'
          '• Savings opportunity finder\n'
          '• Income pattern analysis\n'
          '• Weekend vs weekday patterns\n'
          '• Time-of-day patterns\n'
          '• Recurring payment detection\n'
          '• Cash flow velocity\n'
          '• Category concentration risk\n\n'
          'All analysis happens on your device. Your data never leaves your phone.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final SmartInsight insight;

  const _InsightCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final severityColor = _severityColor(insight.severity);
    final categoryIcon = _categoryIcon(insight.category);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? cs.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : const Color(0xFFE0E0E0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: severityColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusLg),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(insight.iconData, size: 28, color: severityColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            insight.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(categoryIcon, size: 12, color: cs.outline),
                              const SizedBox(width: 4),
                              Text(
                                insight.category.name.toUpperCase(),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: cs.outline,
                                  letterSpacing: 1.0,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: severityColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        insight.severity.name,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: severityColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Text(
                  insight.body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                    color: cs.onSurface.withOpacity(0.85),
                  ),
                ),

                if (insight.impactAmount != null &&
                    insight.impactAmount! > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: severityColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          insight.severity == InsightSeverity.positive
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          size: 16,
                          color: severityColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Impact: ${_formatCurrency(insight.impactAmount!)}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: severityColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _severityColor(InsightSeverity severity) {
    switch (severity) {
      case InsightSeverity.critical:
        return AppTheme.expenseDark;
      case InsightSeverity.warning:
        return AppTheme.budgetWarning;
      case InsightSeverity.positive:
        return AppTheme.budgetSafe;
      case InsightSeverity.neutral:
        return const Color(0xFF42A5F5); // Blue
    }
  }

  IconData _categoryIcon(InsightCategory category) {
    switch (category) {
      case InsightCategory.spending:
        return Icons.shopping_bag_outlined;
      case InsightCategory.saving:
        return Icons.savings_outlined;
      case InsightCategory.income:
        return Icons.account_balance_wallet_outlined;
      case InsightCategory.pattern:
        return Icons.insights_rounded;
      case InsightCategory.alert:
        return Icons.warning_amber_rounded;
      case InsightCategory.tip:
        return Icons.lightbulb_outline_rounded;
    }
  }

  String _formatCurrency(double amount) {
    if (amount >= 10000000)
      return '₹${(amount / 10000000).toStringAsFixed(1)}Cr';
    if (amount >= 100000) return '₹${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '₹${(amount / 1000).toStringAsFixed(1)}K';
    return '₹${amount.toStringAsFixed(0)}';
  }
}
