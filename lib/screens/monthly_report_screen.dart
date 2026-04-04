import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/database_helper.dart';
import '../services/user_preferences_service.dart';
import '../utils/category_icons.dart';

/// Monthly spending report with weekly chart, top categories, and tips.
class MonthlyReportScreen extends StatefulWidget {
  final bool autoLoad;

  const MonthlyReportScreen({super.key, this.autoLoad = true});

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  bool _isLoading = true;
  List<double> _weeklyData = [];
  Map<String, double> _topCategories = {};
  double _totalExpense = 0;
  double _totalIncome = 0;
  int _transactionCount = 0;
  double _avgTransaction = 0;
  double _largestExpense = 0;
  String _largestCategory = '';
  int _noSpendDays = 0;

  @override
  void initState() {
    super.initState();
    if (widget.autoLoad) {
      _loadReport();
    } else {
      _isLoading = false;
    }
  }

  Future<void> _loadReport() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, 1);
      final endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      final db = await DatabaseHelper.instance.database;

      // Get all expenses this month
      final expenses = await db.query(
        'transactions',
        where: "type = 'expense' AND is_deleted = 0 AND date BETWEEN ? AND ?",
        whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
      );

      // Get income this month
      final incomeResult = await db.rawQuery(
        "SELECT SUM(amount) as total FROM transactions WHERE type = 'income' AND is_deleted = 0 AND date BETWEEN ? AND ?",
        [startDate.toIso8601String(), endDate.toIso8601String()],
      );

      _totalIncome = (incomeResult.first['total'] as num?)?.toDouble() ?? 0.0;

      // Calculate weekly breakdown
      _weeklyData = [0, 0, 0, 0, 0];
      _topCategories = {};
      _totalExpense = 0;
      _transactionCount = expenses.length;
      _largestExpense = 0;
      _largestCategory = '';

      final daysWithExpenses = <int>{};

      for (var row in expenses) {
        final amount = (row['amount'] as num).toDouble();
        final date = DateTime.parse(row['date'] as String);
        final category = row['category'] as String;

        _totalExpense += amount;
        daysWithExpenses.add(date.day);

        // Weekly bucket
        final weekIndex = ((date.day - 1) / 7).floor().clamp(0, 4);
        _weeklyData[weekIndex] += amount;

        // Category totals
        _topCategories[category] = (_topCategories[category] ?? 0) + amount;

        // Largest single expense
        if (amount > _largestExpense) {
          _largestExpense = amount;
          _largestCategory = category;
        }
      }

      _avgTransaction = _transactionCount > 0
          ? _totalExpense / _transactionCount
          : 0;

      // No-spend days
      _noSpendDays = now.day - daysWithExpenses.length;
      if (_noSpendDays < 0) _noSpendDays = 0;

      // Sort categories by spending
      final sorted = _topCategories.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      _topCategories = Map.fromEntries(sorted.take(8));
    } catch (e) {
      debugPrint('Report error: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  String _fmt(double amount) {
    if (amount >= 100000) {
      return '${CurrencyHelper.symbol}${(amount / 100000).toStringAsFixed(1)}L';
    }
    if (amount >= 1000) {
      return '${CurrencyHelper.symbol}${NumberFormat('#,##,###').format(amount.round())}';
    }
    return '${CurrencyHelper.symbol}${amount.toStringAsFixed(amount == amount.roundToDouble() ? 0 : 2)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('MMMM yyyy').format(DateTime.now())),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadReport,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Summary Cards ──
                  Row(
                    children: [
                      _buildSummaryTile(
                        'Total Spent',
                        _fmt(_totalExpense),
                        Icons.arrow_downward_rounded,
                        cs.error,
                        isDark,
                      ),
                      const SizedBox(width: 12),
                      _buildSummaryTile(
                        'Total Income',
                        _fmt(_totalIncome),
                        Icons.arrow_upward_rounded,
                        cs.primary,
                        isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildSummaryTile(
                        'Transactions',
                        '$_transactionCount',
                        Icons.receipt_long_rounded,
                        cs.secondary,
                        isDark,
                      ),
                      const SizedBox(width: 12),
                      _buildSummaryTile(
                        'Avg / Txn',
                        _fmt(_avgTransaction),
                        Icons.analytics_rounded,
                        const Color(0xFFE67E22),
                        isDark,
                      ),
                    ],
                  ),

                  // ── Weekly Chart ──
                  const SizedBox(height: 28),
                  Text(
                    'WEEKLY SPENDING',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: cs.outline,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 200,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? cs.surface : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.06)
                            : const Color(0xFFF0F0F0),
                      ),
                    ),
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: _weeklyData.isNotEmpty
                            ? _weeklyData.reduce((a, b) => a > b ? a : b) * 1.2
                            : 100,
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              return BarTooltipItem(
                                _fmt(rod.toY),
                                TextStyle(
                                  color: cs.onSurface,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final labels = ['W1', 'W2', 'W3', 'W4', 'W5'];
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    labels[value.toInt()],
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: cs.outline,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: const FlGridData(show: false),
                        barGroups: _weeklyData.asMap().entries.map((entry) {
                          return BarChartGroupData(
                            x: entry.key,
                            barRods: [
                              BarChartRodData(
                                toY: entry.value,
                                color: cs.primary.withOpacity(0.7),
                                width: 28,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(8),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  // ── Top Categories ──
                  const SizedBox(height: 28),
                  Text(
                    'TOP CATEGORIES',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: cs.outline,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._topCategories.entries.map((entry) {
                    final percent = _totalExpense > 0
                        ? entry.value / _totalExpense
                        : 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? cs.surface : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withOpacity(0.06)
                                : const Color(0xFFF0F0F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              CategoryIcons.getIcon(entry.key),
                              size: 24,
                              color: cs.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.key,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value: percent,
                                      minHeight: 5,
                                      backgroundColor: isDark
                                          ? Colors.white.withOpacity(0.06)
                                          : Colors.grey.withOpacity(0.1),
                                      valueColor: AlwaysStoppedAnimation(
                                        cs.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _fmt(entry.value),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: cs.onSurface,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  '${(percent * 100).toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurface.withOpacity(0.4),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  // ── Insights ──
                  const SizedBox(height: 28),
                  Text(
                    'INSIGHTS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: cs.outline,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInsightCard(
                    Icons.emoji_events_rounded,
                    'Biggest Expense',
                    '${_fmt(_largestExpense)} on $_largestCategory',
                    cs,
                    isDark,
                  ),
                  const SizedBox(height: 8),
                  _buildInsightCard(
                    Icons.do_not_disturb_on_rounded,
                    'No-Spend Days',
                    '$_noSpendDays days with no expenses',
                    cs,
                    isDark,
                  ),
                  const SizedBox(height: 8),
                  _buildInsightCard(
                    Icons.savings_rounded,
                    'Savings Potential',
                    _totalIncome > _totalExpense
                        ? 'You saved ${_fmt(_totalIncome - _totalExpense)} this month!'
                        : 'You overspent by ${_fmt(_totalExpense - _totalIncome)}',
                    cs,
                    isDark,
                  ),

                  // ── Student Tips ──
                  const SizedBox(height: 28),
                  _buildTipsCard(cs, isDark),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryTile(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? cs.surface : color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : color.withOpacity(0.12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(isDark ? 0.2 : 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withOpacity(0.5),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightCard(
    IconData icon,
    String title,
    String subtitle,
    ColorScheme cs,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? cs.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : const Color(0xFFF0F0F0),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 28, color: cs.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsCard(ColorScheme cs, bool isDark) {
    final tips = <String>[
      'Cook at home 2x a week to save ~30% on food',
      'Use student discounts on public transport',
      'Share subscriptions with roommates',
      'Buy second-hand textbooks or use library copies',
      'Set weekly spending limits, not just monthly',
      'Track every small expense — they add up fast',
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1A2520), const Color(0xFF0D1117)]
              : [cs.primary.withOpacity(0.06), cs.primary.withOpacity(0.02)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? cs.primary.withOpacity(0.15)
              : cs.primary.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outlined, color: cs.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'STUDENT MONEY TIPS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...tips.map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '•',
                    style: TextStyle(
                      color: cs.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tip,
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withOpacity(0.7),
                        height: 1.3,
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
