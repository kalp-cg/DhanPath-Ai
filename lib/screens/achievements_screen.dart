import 'package:flutter/material.dart' hide Badge;
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../services/achievement_service.dart';
import '../theme/app_theme.dart';
import '../widgets/dhanpath_components.dart';

/// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
/// Achievements Screen
///
/// Gamification hub — XP, levels, badges, and progress.
/// Makes personal finance addictive (in a good way).
/// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Achievements')),
      body: Consumer<TransactionProvider>(
        builder: (context, provider, _) {
          final stats = AchievementService.calculate(provider.allTransactions);

          return ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              // ── Level Card ──
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _levelColor(stats.level.level).withOpacity(0.8),
                      _levelColor(stats.level.level),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  boxShadow: [
                    BoxShadow(
                      color: _levelColor(stats.level.level).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(stats.level.icon, size: 48, color: Colors.white),
                    const SizedBox(height: 8),
                    Text(
                      'Level ${stats.level.level}',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      stats.level.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // XP Progress Bar
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${stats.totalXP} XP',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: Colors.white.withOpacity(0.8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${stats.level.xpForNextLevel} XP needed',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: stats.level.progress,
                            minHeight: 10,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            valueColor: const AlwaysStoppedAnimation(
                              Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Quick Stats ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _QuickStat(
                      icon: Icons.local_fire_department_rounded,
                      label: 'Streak',
                      value: '${stats.currentStreak} days',
                    ),
                    const SizedBox(width: 8),
                    _QuickStat(
                      icon: Icons.emoji_events_rounded,
                      label: 'Best',
                      value: '${stats.longestStreak} days',
                    ),
                    const SizedBox(width: 8),
                    _QuickStat(
                      icon: Icons.beach_access_rounded,
                      label: 'No-Spend',
                      value: '${stats.noSpendDays} days',
                    ),
                    const SizedBox(width: 8),
                    _QuickStat(
                      icon: Icons.military_tech_rounded,
                      label: 'Badges',
                      value: '${stats.unlockedCount}/${stats.totalBadges}',
                    ),
                  ],
                ),
              ),

              // ── Next Milestone ──
              Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: cs.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.track_changes_rounded,
                      size: 20,
                      color: cs.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Next Milestone',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            stats.nextMilestone,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Recent Unlocks ──
              if (stats.recentUnlocks.isNotEmpty) ...[
                SectionHeader(title: 'Recently Unlocked'),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: stats.recentUnlocks
                        .map((b) => _RecentBadge(badge: b))
                        .toList(),
                  ),
                ),
              ],

              // ── All Badges by Category ──
              ..._buildBadgeCategories(context, stats.badges),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildBadgeCategories(BuildContext context, List<Badge> badges) {
    final widgets = <Widget>[];
    final categories = {
      BadgeCategory.tracking: 'Tracking',
      BadgeCategory.saving: 'Saving',
      BadgeCategory.streak: 'Streaks',
      BadgeCategory.milestone: 'Milestones',
      BadgeCategory.special: 'Special',
    };

    for (final entry in categories.entries) {
      final catBadges = badges.where((b) => b.category == entry.key).toList();
      if (catBadges.isEmpty) continue;

      widgets.add(SectionHeader(title: entry.value));
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: catBadges.map((b) => _BadgeCard(badge: b)).toList(),
          ),
        ),
      );
    }

    return widgets;
  }

  Color _levelColor(int level) {
    if (level < 5) return const Color(0xFF546E7A); // Grey
    if (level < 10) return const Color(0xFF2E7D32); // Green
    if (level < 20) return const Color(0xFF1565C0); // Blue
    if (level < 30) return const Color(0xFF6A1B9A); // Purple
    if (level < 40) return const Color(0xFFE65100); // Orange
    return const Color(0xFFFFD700).withOpacity(0.9); // Gold
  }
}

class _QuickStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _QuickStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? cs.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : const Color(0xFFE0E0E0),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: cs.primary),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentBadge extends StatelessWidget {
  final Badge badge;

  const _RecentBadge({required this.badge});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withOpacity(0.15),
            cs.secondary.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: cs.primary.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(badge.icon, size: 32, color: cs.primary),
          const SizedBox(height: 6),
          Text(
            badge.name,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final Badge badge;

  const _BadgeCard({required this.badge});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final width = (MediaQuery.of(context).size.width - 48) / 3;

    return GestureDetector(
      onTap: () => _showBadgeDetail(context),
      child: SizedBox(
        width: width,
        child: AnimatedContainer(
          duration: AppTheme.animFast,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: badge.isUnlocked
                ? (isDark
                      ? cs.primary.withOpacity(0.08)
                      : cs.primaryContainer.withOpacity(0.3))
                : (isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5)),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: badge.isUnlocked
                  ? cs.primary.withOpacity(0.3)
                  : (isDark
                        ? Colors.white.withOpacity(0.05)
                        : const Color(0xFFE0E0E0)),
            ),
          ),
          child: Column(
            children: [
              Icon(
                badge.icon,
                size: 28,
                color: badge.isUnlocked ? cs.primary : Colors.grey,
              ),
              const SizedBox(height: 4),
              Text(
                badge.name,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: badge.isUnlocked ? null : cs.outline,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              if (!badge.isUnlocked && badge.progress > 0) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: badge.progress,
                    minHeight: 4,
                    backgroundColor: cs.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(
                      cs.primary.withOpacity(0.5),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                if (badge.progressLabel != null)
                  Text(
                    badge.progressLabel!,
                    style: theme.textTheme.labelSmall?.copyWith(fontSize: 8),
                  ),
              ],
              if (badge.isUnlocked) _RarityDot(rarity: badge.rarity),
            ],
          ),
        ),
      ),
    );
  }

  void _showBadgeDetail(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(badge.icon, size: 56, color: cs.primary),
            const SizedBox(height: 12),
            Text(
              badge.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            _RarityLabel(rarity: badge.rarity),
            const SizedBox(height: 12),
            Text(
              badge.description,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (!badge.isUnlocked && badge.progressLabel != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: badge.progress,
                  minHeight: 8,
                  backgroundColor: cs.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(cs.primary),
                ),
              ),
              const SizedBox(height: 4),
              Text(badge.progressLabel!, style: theme.textTheme.labelSmall),
            ],
            if (badge.isUnlocked) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: AppTheme.budgetSafe,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Unlocked!',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppTheme.budgetSafe,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Nice!'),
          ),
        ],
      ),
    );
  }
}

class _RarityDot extends StatelessWidget {
  final BadgeRarity rarity;

  const _RarityDot({required this.rarity});

  @override
  Widget build(BuildContext context) {
    final color = _rarityColor(rarity);
    return Container(
      margin: const EdgeInsets.only(top: 4),
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 4)],
      ),
    );
  }

  static Color _rarityColor(BadgeRarity rarity) {
    switch (rarity) {
      case BadgeRarity.common:
        return const Color(0xFF9E9E9E);
      case BadgeRarity.uncommon:
        return const Color(0xFF4CAF50);
      case BadgeRarity.rare:
        return const Color(0xFF2196F3);
      case BadgeRarity.epic:
        return const Color(0xFF9C27B0);
      case BadgeRarity.legendary:
        return const Color(0xFFFFD700);
    }
  }
}

class _RarityLabel extends StatelessWidget {
  final BadgeRarity rarity;

  const _RarityLabel({required this.rarity});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _RarityDot._rarityColor(rarity);
    final label = rarity.name[0].toUpperCase() + rarity.name.substring(1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
