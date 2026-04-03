import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../services/weekly_digest_service.dart';
import '../services/user_preferences_service.dart';
import '../theme/app_theme.dart';
import '../widgets/dhanpath_components.dart';

/// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
/// Weekly Digest Screen
///
/// Beautiful weekly financial summary — like getting a
/// personal CFO report every week.
/// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class WeeklyDigestScreen extends StatelessWidget {
  const WeeklyDigestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Weekly Digest')),
      body: Consumer<TransactionProvider>(
        builder: (context, provider, _) {
          final digest = WeeklyDigestService.generate(provider.allTransactions);

          return ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              // ── Hero Header ──
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: digest.isBetterThanLastWeek
                        ? [const Color(0xFF1B5E30), const Color(0xFF2E7D32)]
                        : [const Color(0xFF4A148C), const Color(0xFF7B1FA2)],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                child: Column(
                  children: [
                    Icon(digest.headlineIcon, size: 48, color: Colors.white),
                    const SizedBox(height: 8),
                    Text(
                      digest.headline,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      digest.subHeadline,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Week ${digest.weekNumber} • ${_formatDateRange(digest.weekStart, digest.weekEnd)}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Net Flow Card ──
              _buildNetFlowCard(context, digest),

              // ── Highlight Cards Grid ──
              SectionHeader(title: 'This Week\'s Highlights'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: digest.highlights
                      .map((h) => _HighlightChip(item: h))
                      .toList(),
                ),
              ),

              // ── Daily Chart ──
              const SizedBox(height: 8),
              DhanPathCard(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Breakdown',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _DailyBarChart(
                      days: digest.dailyBreakdown,
                      peakDay: digest.peakDay,
                    ),
                  ],
                ),
              ),

              // ── Category Changes ──
              if (digest.categoryChanges.isNotEmpty) ...[
                DhanPathCard(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Category Trends',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...digest.categoryChanges.map(
                        (c) => _CategoryChangeRow(change: c),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Weekly Tip ──
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      Icons.lightbulb_outline_rounded,
                      size: 24,
                      color: cs.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tip of the Week',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            digest.weeklyTip,
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

  Widget _buildNetFlowCard(BuildContext context, WeeklyDigest digest) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isPositive = digest.netFlow >= 0;

    return DhanPathCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Net Cash Flow', style: theme.textTheme.labelMedium),
                const SizedBox(height: 4),
                Text(
                  '${isPositive ? "+" : ""}${CurrencyHelper.format(digest.netFlow)}',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isPositive ? cs.income : cs.expense,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isPositive ? cs.income : cs.expense).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPositive
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
              color: isPositive ? cs.income : cs.expense,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDateRange(DateTime start, DateTime end) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    if (start.month == end.month) {
      return '${months[start.month - 1]} ${start.day}-${end.day}';
    }
    return '${months[start.month - 1]} ${start.day} - ${months[end.month - 1]} ${end.day}';
  }
}

class _HighlightChip extends StatelessWidget {
  final WeeklyDigestItem item;

  const _HighlightChip({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: (MediaQuery.of(context).size.width - 48) / 2,
      padding: const EdgeInsets.all(14),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            item.icon,
            size: 22,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 6),
          Text(
            item.value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(item.label, style: theme.textTheme.labelSmall),
          if (item.subtext != null) ...[
            const SizedBox(height: 2),
            Text(
              item.subtext!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: item.isPositive ? cs.income : cs.expense,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _DailyBarChart extends StatelessWidget {
  final List<DailyBreakdown> days;
  final String peakDay;

  const _DailyBarChart({required this.days, required this.peakDay});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final maxAmount = days.map((d) => d.amount).reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: days.map((day) {
          final fraction = maxAmount > 0 ? day.amount / maxAmount : 0.0;
          final isPeak = day.dayName == peakDay;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (day.amount > 0)
                    Text(
                      CurrencyHelper.format(day.amount),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 8,
                        fontWeight: isPeak ? FontWeight.w700 : FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 4),
                  Container(
                    height: (fraction * 80).clamp(4, 80),
                    decoration: BoxDecoration(
                      color: isPeak ? cs.primary : cs.primary.withOpacity(0.4),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    day.dayName,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: isPeak ? FontWeight.w700 : FontWeight.w400,
                      color: isPeak ? cs.primary : null,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _CategoryChangeRow extends StatelessWidget {
  final CategoryChange change;

  const _CategoryChangeRow({required this.change});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isUp = change.changePercent > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              change.category,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              CurrencyHelper.format(change.thisWeek),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  isUp ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                  size: 16,
                  color: isUp ? cs.expense : cs.income,
                ),
                Text(
                  '${change.changePercent.abs().round()}%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isUp ? cs.expense : cs.income,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
