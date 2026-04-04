import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../services/spending_heatmap_service.dart';
import '../services/user_preferences_service.dart';
import '../theme/app_theme.dart';
import '../widgets/dhanpath_components.dart';

/// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
/// Spending Heatmap Screen
///
/// GitHub-style contribution grid showing daily spending
/// intensity over 6 months. Visual, beautiful, insightful.
/// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class SpendingHeatmapScreen extends StatefulWidget {
  const SpendingHeatmapScreen({super.key});

  @override
  State<SpendingHeatmapScreen> createState() => _SpendingHeatmapScreenState();
}

class _SpendingHeatmapScreenState extends State<SpendingHeatmapScreen> {
  int _selectedMonths = 6;
  HeatmapDay? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Spending Heatmap')),
      body: Consumer<TransactionProvider>(
        builder: (context, provider, _) {
          final data = SpendingHeatmapService.generate(
            provider.allTransactions,
            null,
            _selectedMonths,
          );

          return ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              // ── Month Selector ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [3, 6, 12].map((m) {
                    final isSelected = _selectedMonths == m;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('${m}M'),
                        selected: isSelected,
                        onSelected: (s) => setState(() => _selectedMonths = m),
                        selectedColor: cs.primary.withOpacity(0.2),
                        labelStyle: TextStyle(
                          color: isSelected ? cs.primary : cs.onSurface,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // ── Stats Row ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    _StatChip(
                      icon: Icons.payments_rounded,
                      label: 'Total',
                      value: CurrencyHelper.format(data.totalSpend),
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      icon: Icons.bar_chart_rounded,
                      label: 'Daily Avg',
                      value: CurrencyHelper.format(data.avgDailySpend),
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      icon: Icons.beach_access_rounded,
                      label: 'Zero Days',
                      value: '${data.zeroDays}',
                    ),
                  ],
                ),
              ),

              // ── Heatmap Grid ──
              DhanPathCard(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Spending Intensity',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${data.totalTransactions} transactions across ${data.days.length} days',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    _HeatmapGrid(
                      days: data.days,
                      isDark: isDark,
                      onDayTap: (day) => setState(() => _selectedDay = day),
                      selectedDay: _selectedDay,
                    ),
                    const SizedBox(height: 8),
                    // Legend
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('Less', style: theme.textTheme.labelSmall),
                        const SizedBox(width: 4),
                        ...HeatmapIntensity.values.map(
                          (i) => Container(
                            width: 12,
                            height: 12,
                            margin: const EdgeInsets.only(left: 2),
                            decoration: BoxDecoration(
                              color: _intensityColor(i.index, isDark),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text('More', style: theme.textTheme.labelSmall),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Selected Day Detail ──
              if (_selectedDay != null) _buildDayDetail(theme, cs),

              // ── Weekday Analysis ──
              DhanPathCard(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weekday Breakdown',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...data.weekdayAverages.map(
                      (w) => _WeekdayBar(
                        stats: w,
                        maxAvg: data.weekdayAverages
                            .map((x) => x.averageSpend)
                            .reduce((a, b) => a > b ? a : b),
                        isBusiest: w.label == data.busiestDay.substring(0, 3),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Key Insights ──
              DhanPathCard(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Key Patterns',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _PatternRow(
                      icon: Icons.local_fire_department_rounded,
                      label: 'Busiest Day',
                      value: data.busiestDay,
                    ),
                    _PatternRow(
                      icon: Icons.self_improvement_rounded,
                      label: 'Quietest Day',
                      value: data.quietestDay,
                    ),
                    _PatternRow(
                      icon: Icons.label_rounded,
                      label: 'Top Category',
                      value:
                          '${data.topCategory} (${CurrencyHelper.format(data.topCategoryAmount)})',
                    ),
                    _PatternRow(
                      icon: Icons.trending_up_rounded,
                      label: 'Max Daily Spend',
                      value: CurrencyHelper.format(data.maxDailySpend),
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

  Widget _buildDayDetail(ThemeData theme, ColorScheme cs) {
    final day = _selectedDay!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: cs.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 16, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                day.tooltip,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.primary,
                ),
              ),
            ],
          ),
          if (day.topCategory != null) ...[
            const SizedBox(height: 4),
            Text(
              'Top category: ${day.topCategory}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  static Color _intensityColor(int intensity, bool isDark) {
    switch (intensity) {
      case 0:
        return isDark ? const Color(0xFF1A1A1A) : const Color(0xFFEEEEEE);
      case 1:
        return isDark ? const Color(0xFF1B5E30) : const Color(0xFFC8E6C9);
      case 2:
        return isDark ? const Color(0xFF2E7D32) : const Color(0xFF81C784);
      case 3:
        return isDark ? const Color(0xFFE65100) : const Color(0xFFFFB74D);
      case 4:
        return isDark ? const Color(0xFFC62828) : const Color(0xFFEF5350);
      default:
        return isDark ? const Color(0xFF1A1A1A) : const Color(0xFFEEEEEE);
    }
  }
}

class _HeatmapGrid extends StatelessWidget {
  final List<HeatmapDay> days;
  final bool isDark;
  final Function(HeatmapDay) onDayTap;
  final HeatmapDay? selectedDay;

  const _HeatmapGrid({
    required this.days,
    required this.isDark,
    required this.onDayTap,
    this.selectedDay,
  });

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();

    // Build a 7-row grid (Mon-Sun), columns = weeks
    final firstDay = days.first.date;
    final startWeekday = firstDay.weekday; // 1=Mon, 7=Sun

    // Pad start with empty cells
    final paddedDays = <HeatmapDay?>[];
    for (int i = 1; i < startWeekday; i++) {
      paddedDays.add(null);
    }
    paddedDays.addAll(days);

    final weeks = (paddedDays.length / 7).ceil();
    final cellSize = 12.0;
    final cellGap = 2.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: weeks * (cellSize + cellGap),
        height: 7 * (cellSize + cellGap),
        child: CustomPaint(
          painter: _HeatmapPainter(
            paddedDays: paddedDays,
            weeks: weeks,
            cellSize: cellSize,
            cellGap: cellGap,
            isDark: isDark,
            selectedDay: selectedDay,
          ),
          child: GestureDetector(
            onTapDown: (details) {
              final col = (details.localPosition.dx / (cellSize + cellGap))
                  .floor();
              final row = (details.localPosition.dy / (cellSize + cellGap))
                  .floor();
              final idx = col * 7 + row;
              if (idx >= 0 &&
                  idx < paddedDays.length &&
                  paddedDays[idx] != null) {
                onDayTap(paddedDays[idx]!);
              }
            },
          ),
        ),
      ),
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  final List<HeatmapDay?> paddedDays;
  final int weeks;
  final double cellSize;
  final double cellGap;
  final bool isDark;
  final HeatmapDay? selectedDay;

  _HeatmapPainter({
    required this.paddedDays,
    required this.weeks,
    required this.cellSize,
    required this.cellGap,
    required this.isDark,
    this.selectedDay,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFF2ECC71);

    for (int i = 0; i < paddedDays.length; i++) {
      final day = paddedDays[i];
      final col = i ~/ 7;
      final row = i % 7;
      final x = col * (cellSize + cellGap);
      final y = row * (cellSize + cellGap);
      final rect = RRect.fromLTRBR(
        x,
        y,
        x + cellSize,
        y + cellSize,
        const Radius.circular(2),
      );

      if (day != null) {
        paint.color = _SpendingHeatmapScreenState._intensityColor(
          day.intensity,
          isDark,
        );
        canvas.drawRRect(rect, paint);

        // Highlight selected
        if (selectedDay != null &&
            day.date.year == selectedDay!.date.year &&
            day.date.month == selectedDay!.date.month &&
            day.date.day == selectedDay!.date.day) {
          canvas.drawRRect(rect, borderPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter oldDelegate) => true;
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatChip({
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
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
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
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              label,
              style: theme.textTheme.labelSmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekdayBar extends StatelessWidget {
  final HeatmapWeekStats stats;
  final double maxAvg;
  final bool isBusiest;

  const _WeekdayBar({
    required this.stats,
    required this.maxAvg,
    required this.isBusiest,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final fraction = maxAvg > 0 ? stats.averageSpend / maxAvg : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              stats.label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: isBusiest ? FontWeight.w700 : FontWeight.w400,
                color: isBusiest ? cs.primary : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 16,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(
                  isBusiest ? cs.primary : cs.primary.withOpacity(0.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: Text(
              CurrencyHelper.format(stats.averageSpend),
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _PatternRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _PatternRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Text(label, style: theme.textTheme.bodySmall),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
