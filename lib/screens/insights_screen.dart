import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/transaction_provider.dart';
import '../models/category_spending.dart';
import '../models/transaction_model.dart';
import '../services/smart_insights_engine.dart';
import '../services/user_preferences_service.dart';
import '../theme/app_theme.dart';
import '../widgets/dhanpath_components.dart';
import '../utils/category_icons.dart';

/// Merged Insights screen with 3 tabs: Tips, Breakdown, Trends
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: Text('Insights', style: theme.appBarTheme.titleTextStyle),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Tips'),
            Tab(text: 'Breakdown'),
            Tab(text: 'Trends'),
          ],
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          indicatorSize: TabBarIndicatorSize.label,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_TipsTab(), _BreakdownTab(), _TrendsTab()],
      ),
    );
  }
}

// Tips Tab — personalized financial tips
class _TipsTab extends StatelessWidget {
  const _TipsTab();

  Color _severityColor(InsightSeverity severity, ColorScheme cs) {
    switch (severity) {
      case InsightSeverity.critical:
        return cs.error;
      case InsightSeverity.warning:
        return AppTheme.budgetWarning;
      case InsightSeverity.neutral:
        return cs.primary;
      default:
        return cs.outline;
    }
  }

  IconData _severityIcon(InsightSeverity severity) {
    switch (severity) {
      case InsightSeverity.critical:
        return Icons.warning_amber_rounded;
      case InsightSeverity.warning:
        return Icons.info_rounded;
      case InsightSeverity.neutral:
        return Icons.lightbulb_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<TransactionProvider>(
      builder: (context, provider, _) {
        final insights = SmartInsightsEngine.analyze(provider.allTransactions);

        if (insights.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.lightbulb_outlined,
            title: 'No Tips Yet',
            subtitle: 'Keep tracking your spending and tips will appear here.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: insights.length,
          itemBuilder: (context, index) {
            final insight = insights[index];
            final color = _severityColor(insight.severity, cs);
            final icon = _severityIcon(insight.severity);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isDark ? cs.surface : Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border(left: BorderSide(color: color, width: 4)),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(isDark ? 0.15 : 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(icon, size: 20, color: color),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            insight.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            insight.body,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// Breakdown Tab — category spending + top merchants
class _BreakdownTab extends StatefulWidget {
  const _BreakdownTab();

  @override
  State<_BreakdownTab> createState() => _BreakdownTabState();
}

enum _TimePeriod { thisMonth, lastMonth, allTime }

class _BreakdownTabState extends State<_BreakdownTab> {
  _TimePeriod _selectedPeriod = _TimePeriod.thisMonth;

  List<Transaction> _filterByPeriod(List<Transaction> transactions) {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case _TimePeriod.thisMonth:
        return transactions
            .where((t) => t.date.year == now.year && t.date.month == now.month)
            .toList();
      case _TimePeriod.lastMonth:
        final last = DateTime(now.year, now.month - 1);
        return transactions
            .where(
              (t) => t.date.year == last.year && t.date.month == last.month,
            )
            .toList();
      case _TimePeriod.allTime:
        return transactions;
    }
  }

  List<CategorySpending> _calcCategorySpendings(List<Transaction> txns) {
    final Map<String, double> totals = {};
    double totalSpending = 0;

    for (var t in txns) {
      if (t.type == TransactionType.expense) {
        totals[t.category] = (totals[t.category] ?? 0) + t.amount;
        totalSpending += t.amount;
      }
    }

    return totals.entries
        .map(
          (e) => CategorySpending(
            category: e.key,
            amount: e.value,
            percentage: totalSpending > 0 ? (e.value / totalSpending * 100) : 0,
          ),
        )
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
  }

  Map<String, List<dynamic>> _calcTopMerchants(List<Transaction> txns) {
    final Map<String, double> amounts = {};
    final Map<String, int> counts = {};

    for (var t in txns) {
      if (t.type == TransactionType.expense ||
          t.type == TransactionType.credit) {
        final m = t.merchantName.trim();
        if (m.toLowerCase() != 'unknown' &&
            m.toLowerCase() != 'unknown merchant') {
          amounts[m] = (amounts[m] ?? 0) + t.amount;
          counts[m] = (counts[m] ?? 0) + 1;
        }
      }
    }

    final sorted = amounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final result = <String, List<dynamic>>{};
    for (var e in sorted.take(8)) {
      result[e.key] = [e.value, counts[e.key]];
    }
    return result;
  }

  String _formatAmount(double amount) {
    if (amount >= 100000) {
      return '${CurrencyHelper.symbol}${(amount / 100000).toStringAsFixed(1)}L';
    }
    if (amount >= 1000) {
      return '${CurrencyHelper.symbol}${NumberFormat('#,##,###').format(amount.round())}';
    }
    return '${CurrencyHelper.symbol}${amount.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<TransactionProvider>(
      builder: (context, provider, _) {
        final filtered = _filterByPeriod(provider.transactions);
        final categories = _calcCategorySpendings(filtered);
        final merchants = _calcTopMerchants(filtered);

        final totalSpent = filtered
            .where((t) => t.type == TransactionType.expense)
            .fold(0.0, (s, t) => s + t.amount);
        final txCount = filtered
            .where((t) => t.type == TransactionType.expense)
            .length;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Period chips
              Row(
                children: [
                  _periodChip('This Month', _TimePeriod.thisMonth),
                  const SizedBox(width: 8),
                  _periodChip('Last Month', _TimePeriod.lastMonth),
                  const SizedBox(width: 8),
                  _periodChip('All', _TimePeriod.allTime),
                ],
              ),
              const SizedBox(height: 16),

              // Summary card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark
                      ? cs.surface
                      : cs.primaryContainer.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.06)
                        : cs.primary.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total spent', style: theme.textTheme.labelMedium),
                        const SizedBox(height: 4),
                        Text(
                          _formatAmount(totalSpent),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.expense,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$txCount transactions',
                          style: theme.textTheme.labelSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${categories.length} categories',
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Category breakdown
              Text(
                'Where your money went',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              if (categories.isEmpty)
                _emptySection('No spending data yet')
              else
                ...categories.take(8).map((cat) {
                  final catIcon = CategoryIcons.getIcon(cat.category);
                  return _buildCategoryRow(cat, catIcon, isDark);
                }),
              const SizedBox(height: 24),

              // Top merchants
              Text(
                'Where you spend most',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              if (merchants.isEmpty)
                _emptySection('No merchant data')
              else
                ...merchants.entries.map(
                  (e) => _buildMerchantRow(
                    e.key,
                    e.value[0] as double,
                    e.value[1] as int,
                    isDark,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _periodChip(String label, _TimePeriod period) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = _selectedPeriod == period;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedPeriod = period),
      selectedColor: cs.primaryContainer,
      labelStyle: TextStyle(
        color: isSelected ? cs.onPrimaryContainer : cs.onSurface,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        fontSize: 13,
      ),
      showCheckmark: false,
    );
  }

  Widget _buildCategoryRow(CategorySpending cat, IconData icon, bool isDark) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cs.primaryContainer.withOpacity(isDark ? 0.3 : 0.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(icon, size: 18, color: cs.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      cat.category,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _formatAmount(cat.amount),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: cat.percentage / 100,
                    backgroundColor: isDark
                        ? Colors.white.withOpacity(0.06)
                        : const Color(0xFFF0F0F0),
                    valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                    minHeight: 5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${cat.percentage.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMerchantRow(String name, double amount, int count, bool isDark) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? cs.surface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : const Color(0xFFF0F0F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.surfaceContainerHighest,
            ),
            child: Icon(Icons.store_rounded, color: cs.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$count transaction${count > 1 ? 's' : ''}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            _formatAmount(amount),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptySection(String text) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Trends Tab — spending over time
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _TrendsTab extends StatelessWidget {
  const _TrendsTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<TransactionProvider>(
      builder: (context, provider, _) {
        final transactions = provider.transactions;
        final now = DateTime.now();

        // Last 7 days spending
        final weeklySpending = List.generate(7, (i) {
          final day = DateTime(now.year, now.month, now.day - (6 - i));
          final nextDay = day.add(const Duration(days: 1));
          return transactions
              .where(
                (t) =>
                    t.type == TransactionType.expense &&
                    !t.date.isBefore(day) &&
                    t.date.isBefore(nextDay),
              )
              .fold(0.0, (sum, t) => sum + t.amount);
        });

        final maxSpending = weeklySpending.reduce((a, b) => a > b ? a : b);

        // Monthly comparison
        final thisMonthSpent = transactions
            .where(
              (t) =>
                  t.type == TransactionType.expense &&
                  t.date.year == now.year &&
                  t.date.month == now.month,
            )
            .fold(0.0, (sum, t) => sum + t.amount);

        final lastMonthDate = DateTime(now.year, now.month - 1);
        final lastMonthSpent = transactions
            .where(
              (t) =>
                  t.type == TransactionType.expense &&
                  t.date.year == lastMonthDate.year &&
                  t.date.month == lastMonthDate.month,
            )
            .fold(0.0, (sum, t) => sum + t.amount);

        final changePercent = lastMonthSpent > 0
            ? ((thisMonthSpent - lastMonthSpent) / lastMonthSpent * 100)
            : 0.0;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Month comparison card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark
                      ? cs.surface
                      : cs.primaryContainer.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.06)
                        : cs.primary.withOpacity(0.1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Month-over-Month',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _monthBox(
                            'Last month',
                            _formatAmount(lastMonthSpent),
                            isDark,
                            cs,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _monthBox(
                            'This month',
                            _formatAmount(thisMonthSpent),
                            isDark,
                            cs,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: changePercent <= 0
                            ? cs.primary.withOpacity(0.1)
                            : cs.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        changePercent <= 0
                            ? '${changePercent.abs().toStringAsFixed(0)}% less than last month'
                            : '${changePercent.toStringAsFixed(0)}% more than last month',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: changePercent <= 0 ? cs.primary : cs.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Weekly spending bar chart
              Text(
                'Last 7 Days',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 180,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (i) {
                    final day = DateTime(
                      now.year,
                      now.month,
                      now.day - (6 - i),
                    );
                    final amount = weeklySpending[i];
                    final fraction = maxSpending > 0
                        ? amount / maxSpending
                        : 0.0;
                    final isToday = i == 6;

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (amount > 0)
                              Text(
                                _compactAmount(amount),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: isToday
                                      ? cs.primary
                                      : cs.onSurfaceVariant,
                                ),
                              ),
                            const SizedBox(height: 4),
                            Container(
                              height: (fraction * 120).clamp(4, 120),
                              decoration: BoxDecoration(
                                color: isToday
                                    ? cs.primary
                                    : cs.primary.withOpacity(
                                        isDark ? 0.3 : 0.2,
                                      ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              DateFormat('E').format(day).substring(0, 2),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isToday
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: isToday
                                    ? cs.primary
                                    : cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _monthBox(String label, String amount, bool isDark, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.04)
            : cs.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 100000) {
      return '${CurrencyHelper.symbol}${(amount / 100000).toStringAsFixed(1)}L';
    }
    if (amount >= 1000) {
      return '${CurrencyHelper.symbol}${NumberFormat('#,##,###').format(amount.round())}';
    }
    return '${CurrencyHelper.symbol}${amount.toStringAsFixed(0)}';
  }

  String _compactAmount(double amount) {
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return amount.toStringAsFixed(0);
  }
}
