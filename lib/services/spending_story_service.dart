import 'package:flutter/material.dart';
import '../models/transaction_model.dart';

/// A single insight card for the spending story
class StoryInsight {
  final IconData icon;
  final String title;
  final String body;
  final StoryInsightType type;

  const StoryInsight({
    required this.icon,
    required this.title,
    required this.body,
    required this.type,
  });
}

enum StoryInsightType {
  headline, // big summary card
  topCategory, // biggest spending category
  topMerchant, // where you spent most
  comparison, // vs last month
  streak, // consistency streak
  noSpend, // no-spend day count
  biggestDay, // highest single-day spend
  savingsRate, // savings percentage
}

/// The complete monthly story
class MonthlyStory {
  final String monthLabel; // e.g. "February 2026"
  final double totalIncome;
  final double totalExpenses;
  final double savings;
  final double savingsRate; // 0..1
  final int transactionCount;
  final int activeDays;
  final int noSpendDays;
  final List<StoryInsight> insights;

  const MonthlyStory({
    required this.monthLabel,
    required this.totalIncome,
    required this.totalExpenses,
    required this.savings,
    required this.savingsRate,
    required this.transactionCount,
    required this.activeDays,
    required this.noSpendDays,
    required this.insights,
  });
}

/// Generates a human-readable, shareable monthly spending story
class SpendingStoryService {
  /// Build the story from raw transaction data for a given month
  static MonthlyStory generate({
    required List<Transaction> allTransactions,
    required DateTime month,
    List<Transaction>? lastMonthTransactions,
  }) {
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final now = DateTime.now();
    final isCurrentMonth = month.year == now.year && month.month == now.month;
    final daysSoFar = isCurrentMonth ? now.day : daysInMonth;

    // Filter to this month's active transactions
    final txns = allTransactions
        .where(
          (t) =>
              !t.isDeleted &&
              !t.date.isBefore(monthStart) &&
              t.date.isBefore(monthEnd.add(const Duration(seconds: 1))),
        )
        .toList();

    final income = txns
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (s, t) => s + t.amount);
    final expenses = txns
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (s, t) => s + t.amount);
    final savings = income - expenses;
    final savingsRate = income > 0 ? (savings / income).clamp(0.0, 1.0) : 0.0;

    // Active days with any transaction
    final activeDaySet = <String>{};
    for (final t in txns) {
      activeDaySet.add('${t.date.year}-${t.date.month}-${t.date.day}');
    }
    final activeDays = activeDaySet.length;
    final noSpendDays = daysSoFar - activeDays;

    final insights = <StoryInsight>[];

    // ── 1. Headline ──
    insights.add(_headlineInsight(expenses, income, savings, isCurrentMonth));

    // ── 2. Top Category ──
    final catInsight = _topCategoryInsight(txns);
    if (catInsight != null) insights.add(catInsight);

    // ── 3. Top Merchant ──
    final merchantInsight = _topMerchantInsight(txns);
    if (merchantInsight != null) insights.add(merchantInsight);

    // ── 4. vs Last Month ──
    if (lastMonthTransactions != null && lastMonthTransactions.isNotEmpty) {
      final compInsight = _comparisonInsight(expenses, lastMonthTransactions);
      if (compInsight != null) insights.add(compInsight);
    }

    // ── 5. Biggest Single Day ──
    final bigDayInsight = _biggestDayInsight(txns);
    if (bigDayInsight != null) insights.add(bigDayInsight);

    // ── 6. No-Spend Days ──
    if (noSpendDays > 0) {
      insights.add(_noSpendInsight(noSpendDays, daysSoFar));
    }

    // ── 7. Savings Rate ──
    if (income > 0) {
      insights.add(_savingsInsight(savingsRate, savings));
    }

    // Month label
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final label = '${months[month.month - 1]} ${month.year}';

    return MonthlyStory(
      monthLabel: label,
      totalIncome: income,
      totalExpenses: expenses,
      savings: savings,
      savingsRate: savingsRate,
      transactionCount: txns.length,
      activeDays: activeDays,
      noSpendDays: noSpendDays > 0 ? noSpendDays : 0,
      insights: insights,
    );
  }

  // ────────────────── Insight Generators ──────────────────

  static StoryInsight _headlineInsight(
    double expenses,
    double income,
    double savings,
    bool isCurrentMonth,
  ) {
    final verb = isCurrentMonth ? "You've spent" : 'You spent';
    final period = isCurrentMonth ? 'so far this month' : 'this month';

    String body;
    IconData icon;
    if (savings > 0 && income > 0) {
      final pct = (savings / income * 100).round();
      body =
          '$verb ${_currFmt}${_fmt(expenses)} $period and saved $pct% of your income. Keep it up!';
      icon = Icons.track_changes_rounded;
    } else if (savings < 0) {
      body =
          '$verb ${_currFmt}${_fmt(expenses)} $period — that\'s ${_currFmt}${_fmt(-savings)} more than you earned. Time to cut back.';
      icon = Icons.warning_rounded;
    } else {
      body = '$verb ${_currFmt}${_fmt(expenses)} $period.';
      icon = Icons.bar_chart_rounded;
    }

    return StoryInsight(
      icon: icon,
      title: 'The Big Picture',
      body: body,
      type: StoryInsightType.headline,
    );
  }

  static StoryInsight? _topCategoryInsight(List<Transaction> txns) {
    final expenseTxns = txns
        .where((t) => t.type == TransactionType.expense)
        .toList();
    if (expenseTxns.isEmpty) return null;

    final catMap = <String, double>{};
    for (final t in expenseTxns) {
      catMap[t.category] = (catMap[t.category] ?? 0) + t.amount;
    }
    final sorted = catMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final top = sorted.first;
    final totalExp = expenseTxns.fold(0.0, (s, t) => s + t.amount);
    final pct = (top.value / totalExp * 100).round();

    return StoryInsight(
      icon: _categoryIcon(top.key),
      title: 'Top Category',
      body:
          '${top.key} took $pct% of your spending at ${_currFmt}${_fmt(top.value)}.',
      type: StoryInsightType.topCategory,
    );
  }

  static StoryInsight? _topMerchantInsight(List<Transaction> txns) {
    final expenseTxns = txns
        .where((t) => t.type == TransactionType.expense)
        .toList();
    if (expenseTxns.length < 3) return null;

    final merchantMap = <String, double>{};
    final merchantCount = <String, int>{};
    for (final t in expenseTxns) {
      final name = t.merchantName;
      merchantMap[name] = (merchantMap[name] ?? 0) + t.amount;
      merchantCount[name] = (merchantCount[name] ?? 0) + 1;
    }
    final sorted = merchantMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final top = sorted.first;
    final count = merchantCount[top.key] ?? 1;

    return StoryInsight(
      icon: Icons.store_rounded,
      title: 'Favourite Spot',
      body:
          'You visited ${top.key} $count ${count == 1 ? 'time' : 'times'}, spending ${_currFmt}${_fmt(top.value)} in total.',
      type: StoryInsightType.topMerchant,
    );
  }

  static StoryInsight? _comparisonInsight(
    double thisMonthExpenses,
    List<Transaction> lastMonthTxns,
  ) {
    final lastExp = lastMonthTxns
        .where((t) => t.type == TransactionType.expense && !t.isDeleted)
        .fold(0.0, (s, t) => s + t.amount);
    if (lastExp <= 0) return null;

    final diff = thisMonthExpenses - lastExp;
    final pct = (diff.abs() / lastExp * 100).round();

    if (diff > 0) {
      return StoryInsight(
        icon: Icons.trending_up_rounded,
        title: 'vs Last Month',
        body:
            'You spent $pct% more than last month — that\'s ${_currFmt}${_fmt(diff)} extra.',
        type: StoryInsightType.comparison,
      );
    } else if (diff < 0) {
      return StoryInsight(
        icon: Icons.trending_down_rounded,
        title: 'vs Last Month',
        body:
            'Nice! You spent $pct% less than last month, saving ${_currFmt}${_fmt(-diff)}.',
        type: StoryInsightType.comparison,
      );
    }
    return null;
  }

  static StoryInsight? _biggestDayInsight(List<Transaction> txns) {
    final expenseTxns = txns
        .where((t) => t.type == TransactionType.expense)
        .toList();
    if (expenseTxns.length < 3) return null;

    final dayMap = <String, double>{};
    final dayDates = <String, DateTime>{};
    for (final t in expenseTxns) {
      final key = '${t.date.year}-${t.date.month}-${t.date.day}';
      dayMap[key] = (dayMap[key] ?? 0) + t.amount;
      dayDates[key] = t.date;
    }
    final sorted = dayMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final top = sorted.first;
    final dt = dayDates[top.key]!;
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayName = dayNames[dt.weekday - 1];

    return StoryInsight(
      icon: Icons.payments_rounded,
      title: 'Biggest Spending Day',
      body:
          '$dayName, ${dt.day}${_daySuffix(dt.day)} was your heaviest day at ${_currFmt}${_fmt(top.value)}.',
      type: StoryInsightType.biggestDay,
    );
  }

  static StoryInsight _noSpendInsight(int noSpendDays, int totalDays) {
    final pct = (noSpendDays / totalDays * 100).round();
    String body;
    if (pct >= 50) {
      body =
          'Impressive! $noSpendDays out of $totalDays days were zero-spend days. That\'s real discipline.';
    } else if (noSpendDays >= 5) {
      body = 'You had $noSpendDays no-spend days this month. Solid effort!';
    } else {
      body =
          'Only $noSpendDays no-spend ${noSpendDays == 1 ? 'day' : 'days'} this month. Try a no-spend challenge?';
    }
    return StoryInsight(
      icon: Icons.self_improvement_rounded,
      title: 'No-Spend Days',
      body: body,
      type: StoryInsightType.noSpend,
    );
  }

  static StoryInsight _savingsInsight(double rate, double amount) {
    final pct = (rate * 100).round();
    String body;
    IconData icon;
    if (pct >= 30) {
      body =
          'You saved $pct% of your income (${_currFmt}${_fmt(amount)}). Outstanding!';
      icon = Icons.emoji_events_rounded;
    } else if (pct >= 15) {
      body =
          'You saved $pct% of your income (${_currFmt}${_fmt(amount)}). Good going!';
      icon = Icons.fitness_center_rounded;
    } else if (pct > 0) {
      body =
          'You saved $pct% of your income (${_currFmt}${_fmt(amount)}). Aim for 20% next month!';
      icon = Icons.eco_rounded;
    } else {
      body = 'Your savings rate is $pct%. Time to review your spending.';
      icon = Icons.bolt_rounded;
    }
    return StoryInsight(
      icon: icon,
      title: 'Savings Score',
      body: body,
      type: StoryInsightType.savingsRate,
    );
  }

  // ────────────────── Helpers ──────────────────

  static String _fmt(double amount) {
    if (amount >= 10000000)
      return '${(amount / 10000000).toStringAsFixed(1)}Cr';
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) {
      return _indianFormat(amount.round());
    }
    return amount.toStringAsFixed(amount == amount.roundToDouble() ? 0 : 2);
  }

  static String _indianFormat(int number) {
    if (number < 0) return '-${_indianFormat(-number)}';
    final str = number.toString();
    if (str.length <= 3) return str;
    final last3 = str.substring(str.length - 3);
    var rest = str.substring(0, str.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    return '${parts.join(',')},$last3';
  }

  static String _daySuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  static const _currFmt = '\u20B9';

  static IconData _categoryIcon(String category) {
    const map = {
      'Food & Dining': Icons.restaurant_rounded,
      'Transportation': Icons.directions_car_rounded,
      'Shopping': Icons.shopping_cart_rounded,
      'Entertainment': Icons.movie_rounded,
      'Utilities': Icons.lightbulb_outline_rounded,
      'Healthcare': Icons.local_hospital_rounded,
      'Education': Icons.school_rounded,
      'Fitness': Icons.fitness_center_rounded,
      'Banking': Icons.account_balance_rounded,
      'Groceries': Icons.local_grocery_store_rounded,
      'Tuition': Icons.school_rounded,
      'Hostel & Rent': Icons.home_rounded,
      'Mess & Canteen': Icons.restaurant_menu_rounded,
      'Mobile & Internet': Icons.smartphone_rounded,
      'Subscription': Icons.notifications_rounded,
    };
    return map[category] ?? Icons.inventory_2_rounded;
  }
}
