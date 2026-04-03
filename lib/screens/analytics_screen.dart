import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/transaction_provider.dart';
import '../models/category_spending.dart';
import '../models/transaction_model.dart';
import '../services/user_preferences_service.dart';
import '../theme/app_theme.dart';
import '../widgets/dhanpath_components.dart';
import 'settings_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

enum TimePeriod { thisMonth, lastMonth, allTime }

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  TimePeriod _selectedPeriod = TimePeriod.thisMonth;

  List<CategorySpending> _calculateCategorySpending(
    List<Transaction> transactions,
  ) {
    final Map<String, double> totals = {};
    double totalSpending = 0;

    for (var t in transactions) {
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

  Map<String, List<dynamic>> _calculateTopMerchants(
    List<Transaction> transactions,
  ) {
    final Map<String, double> amounts = {};
    final Map<String, int> counts = {};
    final Map<String, bool> recurring = {};

    for (var t in transactions) {
      if (t.type == TransactionType.expense ||
          t.type == TransactionType.credit) {
        final m = t.merchantName.trim();
        if (m.toLowerCase() != 'unknown' &&
            m.toLowerCase() != 'unknown merchant') {
          amounts[m] = (amounts[m] ?? 0) + t.amount;
          counts[m] = (counts[m] ?? 0) + 1;
          recurring[m] = (recurring[m] ?? false) || t.isRecurring;
        }
      }
    }

    final sorted = amounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final result = <String, List<dynamic>>{};
    for (var e in sorted.take(10)) {
      result[e.key] = [e.value, counts[e.key], recurring[e.key] ?? false];
    }
    return result;
  }

  List<Transaction> _filterByPeriod(List<Transaction> transactions) {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case TimePeriod.thisMonth:
        return transactions
            .where((t) => t.date.year == now.year && t.date.month == now.month)
            .toList();
      case TimePeriod.lastMonth:
        final last = DateTime(now.year, now.month - 1);
        return transactions
            .where(
              (t) => t.date.year == last.year && t.date.month == last.month,
            )
            .toList();
      case TimePeriod.allTime:
        return transactions;
    }
  }

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
        title: Text('Analytics', style: theme.appBarTheme.titleTextStyle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Consumer<TransactionProvider>(
        builder: (context, provider, _) {
          final filtered = _filterByPeriod(provider.transactions);
          final categories = _calculateCategorySpending(filtered);
          final merchants = _calculateTopMerchants(filtered);

          final totalSpent = filtered
              .where((t) => t.type == TransactionType.expense)
              .fold(0.0, (s, t) => s + t.amount);
          final txCount = filtered
              .where((t) => t.type == TransactionType.expense)
              .length;
          final avg = txCount > 0 ? totalSpent / txCount : 0.0;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Period filters
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildPeriodChip('This Month', TimePeriod.thisMonth),
                      const SizedBox(width: 8),
                      _buildPeriodChip('Last Month', TimePeriod.lastMonth),
                      const SizedBox(width: 8),
                      _buildPeriodChip('All Time', TimePeriod.allTime),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Summary card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark
                        ? cs.surface
                        : cs.primaryContainer.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.06)
                          : cs.primary.withOpacity(0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Spending',
                            style: theme.textTheme.labelMedium,
                          ),
                          Text(
                            '$txCount transactions',
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${CurrencyHelper.symbol}${NumberFormat('#,##,###').format(totalSpent.round())}',
                        style: theme.textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: cs.expense,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildAnalyticChip(
                            'Avg/Transaction',
                            '${CurrencyHelper.symbol}${avg.toStringAsFixed(0)}',
                            Icons.trending_flat,
                            cs.primary,
                            isDark,
                          ),
                          const SizedBox(width: 12),
                          _buildAnalyticChip(
                            'Categories',
                            '${categories.length}',
                            Icons.category_outlined,
                            cs.secondary,
                            isDark,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Category breakdown
                SectionHeader(
                  title: 'Spending by Category',
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(height: 12),
                if (categories.isEmpty)
                  _buildEmptySection('No spending data yet')
                else
                  ...categories
                      .take(8)
                      .map((cat) => _buildCategoryRow(cat, isDark)),

                const SizedBox(height: 24),

                // Top merchants
                SectionHeader(title: 'Top Merchants', padding: EdgeInsets.zero),
                const SizedBox(height: 12),
                if (merchants.isEmpty)
                  _buildEmptySection('No merchant data')
                else
                  ...merchants.entries.map(
                    (e) => _buildMerchantRow(
                      e.key,
                      e.value[0] as double,
                      e.value[1] as int,
                      e.value[2] as bool,
                      isDark,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPeriodChip(String label, TimePeriod period) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
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
      side: BorderSide(
        color: isSelected
            ? cs.primary.withOpacity(0.3)
            : cs.outline.withOpacity(0.3),
      ),
      showCheckmark: false,
    );
  }

  Widget _buildAnalyticChip(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.labelSmall, maxLines: 1),
                  Text(
                    value,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryRow(CategorySpending cat, bool isDark) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Assign colors based on index
    final colors = [
      cs.primary,
      cs.secondary,
      cs.expense,
      cs.income,
      cs.credit,
      cs.transfer,
      cs.investment,
      cs.outline,
    ];
    final categories = _calculateCategorySpending(
      _filterByPeriod(
        Provider.of<TransactionProvider>(context, listen: false).transactions,
      ),
    );
    final idx = categories.indexOf(cat);
    final color = colors[idx % colors.length];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(cat.category, style: theme.textTheme.titleSmall),
              ),
              Text(
                '${cat.percentage.toStringAsFixed(0)}%',
                style: theme.textTheme.labelSmall,
              ),
              const SizedBox(width: 8),
              Text(
                '${CurrencyHelper.symbol}${NumberFormat('#,##,###').format(cat.amount.round())}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: cat.percentage / 100,
              backgroundColor: isDark
                  ? Colors.white.withOpacity(0.06)
                  : const Color(0xFFF0F0F0),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMerchantRow(
    String name,
    double amount,
    int count,
    bool isRecurring,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? cs.surface : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: isRecurring
              ? cs.secondary.withOpacity(0.3)
              : (isDark
                    ? Colors.white.withOpacity(0.06)
                    : const Color(0xFFF0F0F0)),
          width: isRecurring ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isRecurring
                  ? cs.secondary.withOpacity(0.12)
                  : cs.surfaceContainerHighest,
            ),
            child: Icon(
              isRecurring ? Icons.sync_rounded : Icons.store_rounded,
              color: isRecurring ? cs.secondary : cs.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '$count txn${count > 1 ? 's' : ''}',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (isRecurring) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: cs.secondary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Recurring',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.secondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Text(
            '${CurrencyHelper.symbol}${NumberFormat('#,##,###').format(amount.round())}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySection(String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(child: Text(text, style: theme.textTheme.bodyMedium)),
    );
  }
}
