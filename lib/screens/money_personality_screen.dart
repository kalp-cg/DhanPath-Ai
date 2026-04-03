import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../services/money_personality_engine.dart';
import '../theme/app_theme.dart';
import '../widgets/dhanpath_components.dart';

/// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
/// Money Personality Screen
///
/// Beautiful, shareable personality analysis screen.
/// Data-driven behavioral finance insights.
/// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class MoneyPersonalityScreen extends StatelessWidget {
  const MoneyPersonalityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Money Personality')),
      body: Consumer<TransactionProvider>(
        builder: (context, provider, _) {
          final personality = MoneyPersonalityEngine.analyze(
            provider.allTransactions,
          );

          return ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              // ── Hero Card ──
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _personalityGradient(personality.type, isDark),
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  boxShadow: [
                    BoxShadow(
                      color: _personalityGradient(
                        personality.type,
                        isDark,
                      ).first.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(personality.icon, size: 64, color: Colors.white),
                    const SizedBox(height: 12),
                    Text(
                      personality.title,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      personality.subtitle,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.analytics_outlined,
                            size: 14,
                            color: Colors.white.withOpacity(0.8),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${(personality.confidenceScore * 100).round()}% confidence • ${personality.transactionsAnalyzed} transactions',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Description ──
              DhanPathCard(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.all(16),
                child: Text(
                  personality.description,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                ),
              ),

              // ── Trait Radar (bars) ──
              if (personality.traits.isNotEmpty) ...[
                SectionHeader(title: 'Your Traits'),
                DhanPathCard(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: personality.traits
                        .map((trait) => _TraitBar(trait: trait))
                        .toList(),
                  ),
                ),
              ],

              // ── Strengths ──
              SectionHeader(title: 'Strengths'),
              DhanPathCard(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: personality.strengths.map((s) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: AppTheme.budgetSafe,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              s.trim(),
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

              // ── Watch Outs ──
              SectionHeader(title: 'Watch Out For'),
              DhanPathCard(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: personality.watchOuts.map((w) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.visibility_rounded,
                            size: 16,
                            color: AppTheme.budgetWarning,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              w.trim(),
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

              // ── Mantra ──
              Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: cs.primary.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.self_improvement_rounded,
                      size: 32,
                      color: cs.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your Financial Mantra',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      personality.financialMantra,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
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

  List<Color> _personalityGradient(PersonalityType type, bool isDark) {
    switch (type) {
      case PersonalityType.guardian:
        return [const Color(0xFF1565C0), const Color(0xFF42A5F5)];
      case PersonalityType.strategist:
        return [const Color(0xFF2E7D32), const Color(0xFF66BB6A)];
      case PersonalityType.spontaneous:
        return [const Color(0xFFE65100), const Color(0xFFFF9800)];
      case PersonalityType.achiever:
        return [const Color(0xFF4A148C), const Color(0xFFAB47BC)];
      case PersonalityType.socialSpender:
        return [const Color(0xFFC62828), const Color(0xFFEF5350)];
    }
  }
}

class _TraitBar extends StatelessWidget {
  final PersonalityTrait trait;

  const _TraitBar({required this.trait});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final color = trait.score > 70
        ? AppTheme.budgetSafe
        : (trait.score > 40 ? AppTheme.budgetWarning : AppTheme.budgetDanger);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                trait.icon,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                trait.name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${trait.score}/100',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: trait.score / 100,
              minHeight: 8,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            trait.description,
            style: theme.textTheme.bodySmall?.copyWith(height: 1.3),
          ),
        ],
      ),
    );
  }
}
