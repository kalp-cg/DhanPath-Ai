import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../services/budget_suggest_service.dart';
import '../services/user_preferences_service.dart';
import '../theme/app_theme.dart';
import '../widgets/dhanpath_components.dart';

/// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
/// Smart Budget Suggest Screen
///
/// Budget Recommendations per category.
/// Shows current vs suggested with projected savings.
/// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class BudgetSuggestScreen extends StatelessWidget {
  const BudgetSuggestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Smart Budget')),
      body: Consumer<TransactionProvider>(
        builder: (context, provider, _) {
          final plan = BudgetSuggestService.generate(provider.allTransactions);

          if (plan.suggestions.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.auto_fix_high_outlined,
              title: 'Not Enough Data',
              subtitle:
                  'Track expenses for at least 1 month to get personalized budget suggestions.',
            );
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              // ── Overview Card ──
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [const Color(0xFF1B5E30), const Color(0xFF2E7D32)],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 36,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your Budget Plan',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Based on your last 3 months of spending',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Savings indicators
                    Row(
                      children: [
                        Expanded(
                          child: _PlanStat(
                            label: 'Current',
                            value: CurrencyHelper.format(
                              plan.totalCurrentSpend,
                            ),
                            isHighlighted: false,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _PlanStat(
                            label: 'Suggested',
                            value: CurrencyHelper.format(
                              plan.totalSuggestedBudget,
                            ),
                            isHighlighted: true,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _PlanStat(
                            label: 'Savings/mo',
                            value: CurrencyHelper.format(
                              plan.totalCurrentSpend -
                                  plan.totalSuggestedBudget,
                            ),
                            isHighlighted: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Savings Rate Comparison ──
              DhanPathCard(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Savings Rate',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _SavingsRateBar(
                            label: 'Current',
                            rate: plan.currentSavingsRate,
                            color: plan.currentSavingsRate >= 0.2
                                ? AppTheme.budgetSafe
                                : AppTheme.budgetWarning,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _SavingsRateBar(
                            label: 'With Plan',
                            rate: plan.suggestedSavingsRate,
                            color: plan.suggestedSavingsRate >= 0.2
                                ? AppTheme.budgetSafe
                                : AppTheme.budgetWarning,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Category Suggestions ──
              SectionHeader(title: 'Category Budgets'),

              ...plan.suggestions.map((s) => _SuggestionCard(suggestion: s)),

              // ── Overall Advice ──
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: cs.primary.withOpacity(0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.track_changes_rounded,
                      size: 24,
                      color: cs.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Advisor\'s Note',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            plan.overallAdvice,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PlanStat extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlighted;

  const _PlanStat({
    required this.label,
    required this.value,
    required this.isHighlighted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(isHighlighted ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white.withOpacity(0.7),
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

class _SavingsRateBar extends StatelessWidget {
  final String label;
  final double rate;
  final Color color;

  const _SavingsRateBar({
    required this.label,
    required this.rate,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.labelSmall),
            Text(
              '${(rate * 100).round()}%',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: rate.clamp(0, 1),
            minHeight: 10,
            backgroundColor: cs.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final BudgetSuggestion suggestion;

  const _SuggestionCard({required this.suggestion});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final difficultyColor = _difficultyColor(suggestion.difficulty);
    final difficultyLabel =
        suggestion.difficulty.name[0].toUpperCase() +
        suggestion.difficulty.name.substring(1);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? cs.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : const Color(0xFFE0E0E0),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(suggestion.icon, size: 24, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        suggestion.category,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Row(
                        children: [
                          if (suggestion.isEssential) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: cs.outline.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Essential',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 9,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: difficultyColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              difficultyLabel,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 9,
                                color: difficultyColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Save ${CurrencyHelper.format(suggestion.potentialMonthlySaving)}/mo',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.budgetSafe,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Budget comparison bar
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Current', style: theme.textTheme.labelSmall),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyHelper.format(suggestion.currentAverage),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, size: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('Suggested', style: theme.textTheme.labelSmall),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyHelper.format(suggestion.suggestedBudget),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Stretch', style: theme.textTheme.labelSmall),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyHelper.format(suggestion.stretchBudget),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Rationale
            Text(
              suggestion.rationale,
              style: theme.textTheme.bodySmall?.copyWith(
                height: 1.4,
                color: cs.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _difficultyColor(BudgetDifficulty difficulty) {
    switch (difficulty) {
      case BudgetDifficulty.easy:
        return AppTheme.budgetSafe;
      case BudgetDifficulty.moderate:
        return AppTheme.budgetWarning;
      case BudgetDifficulty.stretch:
        return const Color(0xFFFF9800);
      case BudgetDifficulty.aggressive:
        return AppTheme.budgetDanger;
    }
  }
}
