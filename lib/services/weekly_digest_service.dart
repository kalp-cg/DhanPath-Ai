import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import 'user_preferences_service.dart';

/// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
/// Weekly Financial Digest Service
///
/// Generates a comprehensive weekly summary with trends,
/// comparisons, and actionable tips. Like a personal CFO
/// sending you a weekly email.
/// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class WeeklyDigestItem {
  final IconData icon;
  final String label;
  final String value;
  final String? subtext;
  final bool isPositive;

  const WeeklyDigestItem({
    required this.icon,
    required this.label,
    required this.value,
    this.subtext,
    this.isPositive = true,
  });
}

class DailyBreakdown {
  final String dayName; // "Mon", "Tue", etc.
  final double amount;
  final int count;

  const DailyBreakdown({
    required this.dayName,
    required this.amount,
    required this.count,
  });
}

class CategoryChange {
  final String category;
  final double thisWeek;
  final double lastWeek;
  final double changePercent;

  const CategoryChange({
    required this.category,
    required this.thisWeek,
    required this.lastWeek,
    required this.changePercent,
  });
}

class WeeklyDigest {
  final DateTime weekStart;
  final DateTime weekEnd;
  final int weekNumber;

  // Headlines
  final IconData headlineIcon;
  final String headline;
  final String subHeadline;

  // Core stats
  final double totalSpent;
  final double totalIncome;
  final double netFlow;
  final int transactionCount;

  // Comparison to last week
  final double? lastWeekSpent;
  final double? spendingChangePercent;
  final bool isBetterThanLastWeek;

  // Daily breakdown
  final List<DailyBreakdown> dailyBreakdown;
  final String peakDay;
  final double peakDayAmount;
  final String quietestDay;

  // Category changes
  final List<CategoryChange> categoryChanges;
  final String topCategory;
  final double topCategoryAmount;

  // Digest items (the main cards)
  final List<WeeklyDigestItem> highlights;

  // Tip of the week
  final String weeklyTip;

  const WeeklyDigest({
    required this.weekStart,
    required this.weekEnd,
    required this.weekNumber,
    required this.headlineIcon,
    required this.headline,
    required this.subHeadline,
    required this.totalSpent,
    required this.totalIncome,
    required this.netFlow,
    required this.transactionCount,
    this.lastWeekSpent,
    this.spendingChangePercent,
    required this.isBetterThanLastWeek,
    required this.dailyBreakdown,
    required this.peakDay,
    required this.peakDayAmount,
    required this.quietestDay,
    required this.categoryChanges,
    required this.topCategory,
    required this.topCategoryAmount,
    required this.highlights,
    required this.weeklyTip,
  });
}

class WeeklyDigestService {
  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  /// Generate digest for the current week (Mon-Sun)
  static WeeklyDigest generate(List<Transaction> allTransactions) {
    final now = DateTime.now();

    // Calculate current week bounds (Monday to Sunday)
    final weekday = now.weekday; // 1=Mon, 7=Sun
    final weekStart = DateTime(now.year, now.month, now.day - (weekday - 1));
    final weekEnd = weekStart.add(
      const Duration(days: 6, hours: 23, minutes: 59),
    );
    final lastWeekStart = weekStart.subtract(const Duration(days: 7));
    final lastWeekEnd = weekStart.subtract(const Duration(seconds: 1));

    // Week number (ISO 8601 approximation)
    final weekNumber = ((now.difference(DateTime(now.year, 1, 1)).inDays) / 7)
        .ceil();

    final active = allTransactions.where((t) => !t.isDeleted).toList();

    // This week's transactions
    final thisWeekTxns = active
        .where((t) => !t.date.isBefore(weekStart) && !t.date.isAfter(weekEnd))
        .toList();

    final thisWeekExpenses = thisWeekTxns
        .where((t) => t.type == TransactionType.expense)
        .toList();
    final thisWeekIncome = thisWeekTxns
        .where((t) => t.type == TransactionType.income)
        .toList();

    // Last week's transactions
    final lastWeekTxns = active
        .where(
          (t) =>
              !t.date.isBefore(lastWeekStart) && !t.date.isAfter(lastWeekEnd),
        )
        .toList();
    final lastWeekExpenses = lastWeekTxns
        .where((t) => t.type == TransactionType.expense)
        .toList();

    final totalSpent = thisWeekExpenses.fold(0.0, (s, t) => s + t.amount);
    final totalIncome = thisWeekIncome.fold(0.0, (s, t) => s + t.amount);
    final lastWeekSpent = lastWeekExpenses.fold(0.0, (s, t) => s + t.amount);

    final changePercent = lastWeekSpent > 0
        ? ((totalSpent - lastWeekSpent) / lastWeekSpent * 100)
        : null;

    final isBetter = changePercent != null ? changePercent < 0 : true;

    // Daily breakdown for the week
    final dailyAmounts = List.filled(7, 0.0);
    final dailyCounts = List.filled(7, 0);
    for (final t in thisWeekExpenses) {
      final idx = t.date.weekday - 1;
      dailyAmounts[idx] += t.amount;
      dailyCounts[idx]++;
    }

    final daily = List.generate(
      7,
      (i) => DailyBreakdown(
        dayName: _dayNames[i],
        amount: dailyAmounts[i],
        count: dailyCounts[i],
      ),
    );

    int peakIdx = 0, quietIdx = 0;
    for (int i = 1; i < 7; i++) {
      if (dailyAmounts[i] > dailyAmounts[peakIdx]) peakIdx = i;
      if (dailyAmounts[i] < dailyAmounts[quietIdx]) quietIdx = i;
    }

    // Category analysis
    final thisWeekCats = <String, double>{};
    for (final t in thisWeekExpenses) {
      thisWeekCats[t.category] = (thisWeekCats[t.category] ?? 0) + t.amount;
    }
    final lastWeekCats = <String, double>{};
    for (final t in lastWeekExpenses) {
      lastWeekCats[t.category] = (lastWeekCats[t.category] ?? 0) + t.amount;
    }

    final allCats = {...thisWeekCats.keys, ...lastWeekCats.keys};
    final categoryChanges = <CategoryChange>[];
    for (final cat in allCats) {
      final tw = thisWeekCats[cat] ?? 0;
      final lw = lastWeekCats[cat] ?? 0;
      if (tw == 0 && lw == 0) continue;
      final change = lw > 0 ? ((tw - lw) / lw * 100) : (tw > 0 ? 100.0 : 0.0);
      categoryChanges.add(
        CategoryChange(
          category: cat,
          thisWeek: tw,
          lastWeek: lw,
          changePercent: change,
        ),
      );
    }
    categoryChanges.sort((a, b) => b.thisWeek.compareTo(a.thisWeek));

    final topCat = categoryChanges.isNotEmpty
        ? categoryChanges.first.category
        : 'None';
    final topCatAmount = categoryChanges.isNotEmpty
        ? categoryChanges.first.thisWeek
        : 0.0;

    // Generate headline
    final headlineData = _generateHeadline(
      totalSpent,
      lastWeekSpent,
      changePercent,
      isBetter,
    );

    // Generate highlight items
    final highlights = _generateHighlights(
      totalSpent,
      totalIncome,
      thisWeekTxns.length,
      changePercent,
      isBetter,
      topCat,
      topCatAmount,
      dailyAmounts[peakIdx],
      _dayNames[peakIdx],
    );

    // Weekly tip
    final tip = _generateTip(changePercent, totalSpent, totalIncome, topCat);

    return WeeklyDigest(
      weekStart: weekStart,
      weekEnd: weekEnd,
      weekNumber: weekNumber,
      headlineIcon: headlineData.$1,
      headline: headlineData.$2,
      subHeadline: headlineData.$3,
      totalSpent: totalSpent,
      totalIncome: totalIncome,
      netFlow: totalIncome - totalSpent,
      transactionCount: thisWeekTxns.length,
      lastWeekSpent: lastWeekSpent > 0 ? lastWeekSpent : null,
      spendingChangePercent: changePercent,
      isBetterThanLastWeek: isBetter,
      dailyBreakdown: daily,
      peakDay: _dayNames[peakIdx],
      peakDayAmount: dailyAmounts[peakIdx],
      quietestDay: _dayNames[quietIdx],
      categoryChanges: categoryChanges.take(5).toList(),
      topCategory: topCat,
      topCategoryAmount: topCatAmount,
      highlights: highlights,
      weeklyTip: tip,
    );
  }

  static (IconData, String, String) _generateHeadline(
    double spent,
    double lastWeek,
    double? change,
    bool isBetter,
  ) {
    if (spent == 0) {
      return (
        Icons.beach_access_rounded,
        'Zero spending week!',
        'You didn\'t spend anything this week. Impressive!',
      );
    }
    if (change == null) {
      return (
        Icons.bar_chart_rounded,
        'Week in review',
        'You spent ${CurrencyHelper.format(spent)} this week.',
      );
    }
    if (isBetter && change.abs() > 20) {
      return (
        Icons.celebration_rounded,
        'Great week!',
        'Spending down ${change.abs().round()}% vs last week',
      );
    }
    if (isBetter) {
      return (
        Icons.check_circle_rounded,
        'Steady improvement',
        'Slightly better than last week',
      );
    }
    if (change > 50) {
      return (
        Icons.warning_amber_rounded,
        'Big spending week',
        'Spending up ${change.round()}% vs last week',
      );
    }
    return (
      Icons.trending_up_rounded,
      'Spending increased',
      'Up ${change.round()}% from last week',
    );
  }

  static List<WeeklyDigestItem> _generateHighlights(
    double totalSpent,
    double totalIncome,
    int txnCount,
    double? change,
    bool isBetter,
    String topCat,
    double topCatAmount,
    double peakAmount,
    String peakDay,
  ) {
    final items = <WeeklyDigestItem>[];

    items.add(
      WeeklyDigestItem(
        icon: Icons.payments_rounded,
        label: 'Total Spent',
        value: CurrencyHelper.format(totalSpent),
        subtext: change != null
            ? '${isBetter ? "↓" : "↑"} ${change.abs().round()}% vs last week'
            : null,
        isPositive: isBetter,
      ),
    );

    if (totalIncome > 0) {
      items.add(
        WeeklyDigestItem(
          icon: Icons.account_balance_wallet_rounded,
          label: 'Income Received',
          value: CurrencyHelper.format(totalIncome),
          subtext: totalIncome > totalSpent
              ? 'Surplus: ${CurrencyHelper.format(totalIncome - totalSpent)}'
              : 'Deficit: ${CurrencyHelper.format(totalSpent - totalIncome)}',
          isPositive: totalIncome > totalSpent,
        ),
      );
    }

    items.add(
      WeeklyDigestItem(
        icon: Icons.label_rounded,
        label: 'Top Category',
        value: topCat,
        subtext: CurrencyHelper.format(topCatAmount),
      ),
    );

    items.add(
      WeeklyDigestItem(
        icon: Icons.calendar_today_rounded,
        label: 'Peak Day',
        value: peakDay,
        subtext: CurrencyHelper.format(peakAmount),
        isPositive: false,
      ),
    );

    items.add(
      WeeklyDigestItem(
        icon: Icons.format_list_numbered_rounded,
        label: 'Transactions',
        value: txnCount.toString(),
        subtext: totalSpent > 0
            ? 'Avg: ${CurrencyHelper.format(totalSpent / txnCount.clamp(1, 9999))}'
            : null,
      ),
    );

    return items;
  }

  static String _generateTip(
    double? change,
    double spent,
    double income,
    String topCat,
  ) {
    if (spent == 0) {
      return 'Amazing zero-spend week! Consider putting any savings toward your financial goals.';
    }
    if (change != null && change > 50) {
      return 'Spending surged this week. Try setting a daily budget for next week — even a loose target helps reduce impulse buys by 20%.';
    }
    if (change != null && change < -20) {
      return 'Great discipline this week! Consistency is key — studies show it takes 66 days to form a habit. Keep it going!';
    }
    if (income > 0 && spent > income) {
      return 'You spent more than you earned this week. Review your $topCat spending — small daily cuts add up fast.';
    }
    return 'Track every expense, no matter how small. Research shows that awareness alone reduces overspending by 15%.';
  }
}
