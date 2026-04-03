import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import 'user_preferences_service.dart';

/// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
/// Smart Insights Engine
///
/// Analyzes transaction patterns to generate actionable,
/// human-readable financial insights no competitor offers.
///
/// ALGORITHMS:
///  1. Spending Anomaly Detection (z-score based)
///  2. Category Trend Analysis (month-over-month)
///  3. Merchant Loyalty Detection
///  4. Savings Opportunity Finder
///  5. Income Irregularity Warning
///  6. Weekend vs Weekday Pattern
///  7. Time-of-Day Spending Pattern
///  8. Recurring Payment Detection
///  9. Cash Flow Velocity (burn rate)
/// 10. Category Concentration Risk
/// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

enum InsightSeverity { positive, neutral, warning, critical }

enum InsightCategory { spending, saving, income, pattern, alert, tip }

class SmartInsight {
  final String id;
  final IconData icon;
  final String title;
  final String body;
  final InsightSeverity severity;
  final InsightCategory category;
  final double? impactAmount; // optional — how much it affects
  final DateTime generatedAt;

  const SmartInsight({
    required this.id,
    required this.icon,
    required this.title,
    required this.body,
    required this.severity,
    required this.category,
    this.impactAmount,
    required this.generatedAt,
  });
}

class SmartInsightsEngine {
  /// Generate all insights from transaction data
  static List<SmartInsight> analyze(List<Transaction> allTransactions) {
    final now = DateTime.now();
    final insights = <SmartInsight>[];

    final active = allTransactions.where((t) => !t.isDeleted).toList();
    if (active.length < 5) {
      insights.add(
        SmartInsight(
          id: 'need_data',
          icon: Icons.bar_chart_rounded,
          title: 'Keep tracking!',
          body:
              'Add more transactions to unlock powerful insights about your spending patterns.',
          severity: InsightSeverity.neutral,
          category: InsightCategory.tip,
          generatedAt: now,
        ),
      );
      return insights;
    }

    final expenses = active
        .where((t) => t.type == TransactionType.expense)
        .toList();
    final incomes = active
        .where((t) => t.type == TransactionType.income)
        .toList();

    // ── 1. Spending Anomaly Detection ──
    final anomaly = _detectSpendingAnomaly(expenses, now);
    if (anomaly != null) insights.add(anomaly);

    // ── 2. Category Trend Analysis ──
    insights.addAll(_analyzeCategoryTrends(expenses, now));

    // ── 3. Merchant Loyalty ──
    final loyalty = _detectMerchantLoyalty(expenses, now);
    if (loyalty != null) insights.add(loyalty);

    // ── 4. Savings Opportunity ──
    final savings = _findSavingsOpportunity(expenses, incomes, now);
    if (savings != null) insights.add(savings);

    // ── 5. Income Irregularity ──
    final incomeInsight = _analyzeIncomePattern(incomes, now);
    if (incomeInsight != null) insights.add(incomeInsight);

    // ── 6. Weekend vs Weekday Pattern ──
    final weekendInsight = _analyzeWeekendPattern(expenses, now);
    if (weekendInsight != null) insights.add(weekendInsight);

    // ── 7. Time-of-Day Pattern ──
    final timeInsight = _analyzeTimeOfDayPattern(expenses, now);
    if (timeInsight != null) insights.add(timeInsight);

    // ── 8. Recurring Payment Detection ──
    insights.addAll(_detectRecurringPayments(expenses, now));

    // ── 9. Cash Flow Velocity ──
    final velocity = _analyzeCashFlowVelocity(expenses, incomes, now);
    if (velocity != null) insights.add(velocity);

    // ── 10. Category Concentration Risk ──
    final concentration = _analyzeCategoryConcentration(expenses, now);
    if (concentration != null) insights.add(concentration);

    // Sort: critical first, then warnings, then positives
    insights.sort((a, b) {
      final severityOrder = {
        InsightSeverity.critical: 0,
        InsightSeverity.warning: 1,
        InsightSeverity.neutral: 2,
        InsightSeverity.positive: 3,
      };
      return severityOrder[a.severity]!.compareTo(severityOrder[b.severity]!);
    });

    return insights;
  }

  // ────────────── 1. Spending Anomaly Detection ──────────────

  static SmartInsight? _detectSpendingAnomaly(
    List<Transaction> expenses,
    DateTime now,
  ) {
    final last30 = expenses
        .where((t) => t.date.isAfter(now.subtract(const Duration(days: 30))))
        .toList();
    if (last30.length < 7) return null;

    // Group by day
    final dailyTotals = <String, double>{};
    for (final t in last30) {
      final key = '${t.date.year}-${t.date.month}-${t.date.day}';
      dailyTotals[key] = (dailyTotals[key] ?? 0) + t.amount;
    }

    if (dailyTotals.length < 5) return null;

    final values = dailyTotals.values.toList();
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance =
        values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
        values.length;
    final stdDev = _sqrt(variance);

    if (stdDev == 0) return null;

    // Check today's spending
    final todayKey = '${now.year}-${now.month}-${now.day}';
    final todaySpent = dailyTotals[todayKey] ?? 0;
    final zScore = (todaySpent - mean) / stdDev;

    if (zScore > 2.0) {
      return SmartInsight(
        id: 'anomaly_today',
        icon: Icons.warning_amber_rounded,
        title: 'Unusual spending today',
        body:
            'You\'ve spent ${CurrencyHelper.format(todaySpent)} today — that\'s ${zScore.toStringAsFixed(1)}x above your daily average of ${CurrencyHelper.format(mean)}. Check if everything looks right.',
        severity: InsightSeverity.warning,
        category: InsightCategory.alert,
        impactAmount: todaySpent - mean,
        generatedAt: now,
      );
    }

    if (zScore < -1.5 && todaySpent > 0) {
      return SmartInsight(
        id: 'anomaly_low',
        icon: Icons.celebration_rounded,
        title: 'Low spending day!',
        body:
            'You\'ve only spent ${CurrencyHelper.format(todaySpent)} today — well below your ${CurrencyHelper.format(mean)} average. Nice discipline!',
        severity: InsightSeverity.positive,
        category: InsightCategory.saving,
        impactAmount: mean - todaySpent,
        generatedAt: now,
      );
    }

    return null;
  }

  // ────────────── 2. Category Trend Analysis ──────────────

  static List<SmartInsight> _analyzeCategoryTrends(
    List<Transaction> expenses,
    DateTime now,
  ) {
    final insights = <SmartInsight>[];

    final thisMonthStart = DateTime(now.year, now.month, 1);
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);
    final lastMonthEnd = DateTime(now.year, now.month, 0, 23, 59, 59);

    final thisMonth = expenses
        .where((t) => !t.date.isBefore(thisMonthStart))
        .toList();
    final lastMonth = expenses
        .where(
          (t) =>
              !t.date.isBefore(lastMonthStart) && t.date.isBefore(lastMonthEnd),
        )
        .toList();

    if (thisMonth.isEmpty || lastMonth.isEmpty) return insights;

    // Prorate this month's spending to full month
    final daysSoFar = now.day;
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final prorateFactor = daysInMonth / daysSoFar;

    final thisMonthByCat = _groupByCategory(thisMonth);
    final lastMonthByCat = _groupByCategory(lastMonth);

    for (final cat in thisMonthByCat.keys) {
      final thisAmount = thisMonthByCat[cat]! * prorateFactor;
      final lastAmount = lastMonthByCat[cat] ?? 0;

      if (lastAmount <= 0) continue;

      final changePct = ((thisAmount - lastAmount) / lastAmount * 100);

      if (changePct > 50 && thisAmount > 500) {
        insights.add(
          SmartInsight(
            id: 'trend_up_$cat',
            icon: Icons.trending_up_rounded,
            title: '$cat spending surging',
            body:
                'On pace to spend ${changePct.round()}% more on $cat this month vs last. Projected: ${CurrencyHelper.format(thisAmount)} vs ${CurrencyHelper.format(lastAmount)} last month.',
            severity: InsightSeverity.warning,
            category: InsightCategory.spending,
            impactAmount: thisAmount - lastAmount,
            generatedAt: now,
          ),
        );
      } else if (changePct < -30 && lastAmount > 500) {
        insights.add(
          SmartInsight(
            id: 'trend_down_$cat',
            icon: Icons.trending_down_rounded,
            title: '$cat spending dropping',
            body:
                'Great job! $cat spending is down ${changePct.abs().round()}% this month. You\'re saving ${CurrencyHelper.format(lastAmount - thisAmount)} vs last month.',
            severity: InsightSeverity.positive,
            category: InsightCategory.saving,
            impactAmount: lastAmount - thisAmount,
            generatedAt: now,
          ),
        );
      }
    }

    // Limit to top 2 trend insights
    if (insights.length > 2) {
      insights.sort(
        (a, b) => (b.impactAmount ?? 0).compareTo(a.impactAmount ?? 0),
      );
      return insights.take(2).toList();
    }

    return insights;
  }

  // ────────────── 3. Merchant Loyalty ──────────────

  static SmartInsight? _detectMerchantLoyalty(
    List<Transaction> expenses,
    DateTime now,
  ) {
    final last90 = expenses
        .where((t) => t.date.isAfter(now.subtract(const Duration(days: 90))))
        .toList();
    if (last90.length < 10) return null;

    final merchantCount = <String, int>{};
    final merchantTotal = <String, double>{};

    for (final t in last90) {
      final name = t.merchantName.toLowerCase().trim();
      if (name.isEmpty || name == 'unknown' || name == 'unknown merchant')
        continue;
      merchantCount[name] = (merchantCount[name] ?? 0) + 1;
      merchantTotal[name] = (merchantTotal[name] ?? 0) + t.amount;
    }

    if (merchantCount.isEmpty) return null;

    final topMerchant = merchantCount.entries.reduce(
      (a, b) => a.value > b.value ? a : b,
    );

    if (topMerchant.value >= 8) {
      final total = merchantTotal[topMerchant.key]!;
      final displayName = _capitalize(topMerchant.key);
      return SmartInsight(
        id: 'loyalty_${topMerchant.key}',
        icon: Icons.emoji_events_rounded,
        title: '$displayName loyalist!',
        body:
            'You\'ve visited $displayName ${topMerchant.value} times in 3 months, spending ${CurrencyHelper.format(total)} total. That\'s ${CurrencyHelper.format(total / topMerchant.value)} per visit on average.',
        severity: InsightSeverity.neutral,
        category: InsightCategory.pattern,
        impactAmount: total,
        generatedAt: now,
      );
    }

    return null;
  }

  // ────────────── 4. Savings Opportunity ──────────────

  static SmartInsight? _findSavingsOpportunity(
    List<Transaction> expenses,
    List<Transaction> incomes,
    DateTime now,
  ) {
    final last30Expenses = expenses
        .where((t) => t.date.isAfter(now.subtract(const Duration(days: 30))))
        .toList();
    final last30Income = incomes
        .where((t) => t.date.isAfter(now.subtract(const Duration(days: 30))))
        .toList();

    if (last30Expenses.isEmpty || last30Income.isEmpty) return null;

    final totalExpense = last30Expenses.fold(0.0, (s, t) => s + t.amount);
    final totalIncome = last30Income.fold(0.0, (s, t) => s + t.amount);
    final savingsRate = (totalIncome - totalExpense) / totalIncome;

    // Find the smallest discretionary category to cut
    final catSpending = _groupByCategory(last30Expenses);
    final discretionary = [
      'Food & Dining',
      'Shopping',
      'Entertainment',
      'Subscription',
    ];

    MapEntry<String, double>? bestCut;
    for (final cat in discretionary) {
      if (catSpending.containsKey(cat)) {
        final amount = catSpending[cat]!;
        if (bestCut == null || amount > bestCut.value) {
          bestCut = MapEntry(cat, amount);
        }
      }
    }

    if (savingsRate < 0.1 && bestCut != null) {
      final potentialSaving = bestCut.value * 0.2; // Cut 20%
      return SmartInsight(
        id: 'savings_opp',
        icon: Icons.lightbulb_outline_rounded,
        title: 'Savings opportunity found',
        body:
            'Your savings rate is only ${(savingsRate * 100).round()}%. Cutting ${bestCut.key} by 20% could save you ${CurrencyHelper.format(potentialSaving)}/month — that\'s ${CurrencyHelper.format(potentialSaving * 12)}/year!',
        severity: InsightSeverity.warning,
        category: InsightCategory.saving,
        impactAmount: potentialSaving * 12,
        generatedAt: now,
      );
    } else if (savingsRate >= 0.3) {
      return SmartInsight(
        id: 'savings_great',
        icon: Icons.military_tech_rounded,
        title: 'Elite saver status',
        body:
            'You\'re saving ${(savingsRate * 100).round()}% of your income — top 10% of users. At this rate, you\'ll save ${CurrencyHelper.format((totalIncome - totalExpense) * 12)} this year!',
        severity: InsightSeverity.positive,
        category: InsightCategory.saving,
        impactAmount: (totalIncome - totalExpense) * 12,
        generatedAt: now,
      );
    }

    return null;
  }

  // ────────────── 5. Income Irregularity ──────────────

  static SmartInsight? _analyzeIncomePattern(
    List<Transaction> incomes,
    DateTime now,
  ) {
    if (incomes.length < 3) return null;

    final last90 = incomes
        .where((t) => t.date.isAfter(now.subtract(const Duration(days: 90))))
        .toList();

    if (last90.length < 2) return null;

    // Group by month
    final monthlyIncome = <String, double>{};
    for (final t in last90) {
      final key = '${t.date.year}-${t.date.month}';
      monthlyIncome[key] = (monthlyIncome[key] ?? 0) + t.amount;
    }

    if (monthlyIncome.length < 2) return null;

    final values = monthlyIncome.values.toList();
    final mean = values.reduce((a, b) => a + b) / values.length;
    final maxVariance = values
        .map((v) => ((v - mean) / mean).abs())
        .reduce((a, b) => a > b ? a : b);

    if (maxVariance > 0.4) {
      return SmartInsight(
        id: 'income_irregular',
        icon: Icons.bolt_rounded,
        title: 'Irregular income detected',
        body:
            'Your income varies by up to ${(maxVariance * 100).round()}% month-to-month. Consider building a 3-month emergency buffer of ${CurrencyHelper.format(mean * 3)}.',
        severity: InsightSeverity.warning,
        category: InsightCategory.income,
        impactAmount: mean,
        generatedAt: now,
      );
    }

    return null;
  }

  // ────────────── 6. Weekend vs Weekday Pattern ──────────────

  static SmartInsight? _analyzeWeekendPattern(
    List<Transaction> expenses,
    DateTime now,
  ) {
    final last30 = expenses
        .where((t) => t.date.isAfter(now.subtract(const Duration(days: 30))))
        .toList();
    if (last30.length < 10) return null;

    double weekdayTotal = 0, weekendTotal = 0;
    int weekdayCount = 0, weekendCount = 0;

    for (final t in last30) {
      if (t.date.weekday >= 6) {
        weekendTotal += t.amount;
        weekendCount++;
      } else {
        weekdayTotal += t.amount;
        weekdayCount++;
      }
    }

    if (weekdayCount == 0 || weekendCount == 0) return null;

    final weekdayAvg = weekdayTotal / weekdayCount;
    final weekendAvg = weekendTotal / weekendCount;

    if (weekendAvg > weekdayAvg * 1.5) {
      final extraPerWeekend = (weekendAvg - weekdayAvg) * 2; // 2 weekend days
      return SmartInsight(
        id: 'weekend_spender',
        icon: Icons.theater_comedy_rounded,
        title: 'Weekend splurger alert',
        body:
            'You spend ${(weekendAvg / weekdayAvg).toStringAsFixed(1)}x more on weekends (${CurrencyHelper.format(weekendAvg)}/day vs ${CurrencyHelper.format(weekdayAvg)}/day). That\'s ${CurrencyHelper.format(extraPerWeekend * 4)} extra per month.',
        severity: InsightSeverity.warning,
        category: InsightCategory.pattern,
        impactAmount: extraPerWeekend * 4,
        generatedAt: now,
      );
    }

    return null;
  }

  // ────────────── 7. Time-of-Day Pattern ──────────────

  static SmartInsight? _analyzeTimeOfDayPattern(
    List<Transaction> expenses,
    DateTime now,
  ) {
    final last30 = expenses
        .where((t) => t.date.isAfter(now.subtract(const Duration(days: 30))))
        .toList();
    if (last30.length < 15) return null;

    // Bucket: Morning (6-12), Afternoon (12-17), Evening (17-22), Night (22-6)
    final buckets = <String, double>{
      'Morning': 0,
      'Afternoon': 0,
      'Evening': 0,
      'Night': 0,
    };
    final bucketCounts = <String, int>{
      'Morning': 0,
      'Afternoon': 0,
      'Evening': 0,
      'Night': 0,
    };

    for (final t in last30) {
      final h = t.date.hour;
      String bucket;
      if (h >= 6 && h < 12)
        bucket = 'Morning';
      else if (h >= 12 && h < 17)
        bucket = 'Afternoon';
      else if (h >= 17 && h < 22)
        bucket = 'Evening';
      else
        bucket = 'Night';

      buckets[bucket] = (buckets[bucket] ?? 0) + t.amount;
      bucketCounts[bucket] = (bucketCounts[bucket] ?? 0) + 1;
    }

    // Find highest spending time
    final topBucket = buckets.entries
        .where((e) => e.value > 0)
        .reduce((a, b) => a.value > b.value ? a : b);
    final totalSpend = buckets.values.reduce((a, b) => a + b);
    final pct = (topBucket.value / totalSpend * 100).round();

    if (pct > 45) {
      final iconMap = {
        'Morning': Icons.wb_sunny_rounded,
        'Afternoon': Icons.wb_sunny_outlined,
        'Evening': Icons.nights_stay_outlined,
        'Night': Icons.dark_mode_rounded,
      };
      return SmartInsight(
        id: 'time_pattern',
        icon: iconMap[topBucket.key] ?? Icons.schedule_rounded,
        title: '${topBucket.key} is your spending peak',
        body:
            '$pct% of your spending (${CurrencyHelper.format(topBucket.value)}) happens in the ${topBucket.key.toLowerCase()}. Being aware of this pattern helps you control impulse buys.',
        severity: InsightSeverity.neutral,
        category: InsightCategory.pattern,
        impactAmount: topBucket.value,
        generatedAt: now,
      );
    }

    return null;
  }

  // ────────────── 8. Recurring Payment Detection ──────────────

  static List<SmartInsight> _detectRecurringPayments(
    List<Transaction> expenses,
    DateTime now,
  ) {
    final insights = <SmartInsight>[];
    final last90 = expenses
        .where((t) => t.date.isAfter(now.subtract(const Duration(days: 90))))
        .toList();

    // Group by merchant
    final byMerchant = <String, List<Transaction>>{};
    for (final t in last90) {
      final key = t.merchantName.toLowerCase().trim();
      if (key.isEmpty || key == 'unknown' || key == 'unknown merchant')
        continue;
      byMerchant.putIfAbsent(key, () => []).add(t);
    }

    double totalRecurring = 0;
    int recurringCount = 0;

    for (final entry in byMerchant.entries) {
      final txns = entry.value;
      if (txns.length < 3) continue;

      txns.sort((a, b) => a.date.compareTo(b.date));

      // Check amount consistency
      final amounts = txns.map((t) => t.amount).toList();
      final avgAmount = amounts.reduce((a, b) => a + b) / amounts.length;
      final amountConsistent = amounts.every(
        (a) => (a - avgAmount).abs() / avgAmount < 0.15,
      );

      if (!amountConsistent) continue;

      // Check interval consistency
      final intervals = <int>[];
      for (int i = 1; i < txns.length; i++) {
        intervals.add(txns[i].date.difference(txns[i - 1].date).inDays);
      }
      final avgInterval = intervals.reduce((a, b) => a + b) / intervals.length;

      if (avgInterval >= 25 && avgInterval <= 35) {
        totalRecurring += avgAmount;
        recurringCount++;
      }
    }

    if (recurringCount > 0 && totalRecurring > 0) {
      insights.add(
        SmartInsight(
          id: 'recurring_total',
          icon: Icons.replay_rounded,
          title: '$recurringCount recurring payments found',
          body:
              'You have ~${CurrencyHelper.format(totalRecurring)}/month in recurring payments. Review them periodically — the average person wastes ${CurrencyHelper.format(totalRecurring * 0.15)}/month on unused subscriptions.',
          severity: InsightSeverity.neutral,
          category: InsightCategory.spending,
          impactAmount: totalRecurring,
          generatedAt: now,
        ),
      );
    }

    return insights;
  }

  // ────────────── 9. Cash Flow Velocity ──────────────

  static SmartInsight? _analyzeCashFlowVelocity(
    List<Transaction> expenses,
    List<Transaction> incomes,
    DateTime now,
  ) {
    final last30Expenses = expenses
        .where((t) => t.date.isAfter(now.subtract(const Duration(days: 30))))
        .toList();
    final last30Income = incomes
        .where((t) => t.date.isAfter(now.subtract(const Duration(days: 30))))
        .toList();

    if (last30Expenses.isEmpty || last30Income.isEmpty) return null;

    final totalExpense = last30Expenses.fold(0.0, (s, t) => s + t.amount);
    final totalIncome = last30Income.fold(0.0, (s, t) => s + t.amount);

    if (totalIncome <= 0) return null;

    final burnRate =
        totalExpense / totalIncome; // >1 means spending more than earning

    if (burnRate > 1.2) {
      final deficit = totalExpense - totalIncome;
      return SmartInsight(
        id: 'burn_rate_high',
        icon: Icons.local_fire_department_rounded,
        title: 'Burn rate critical',
        body:
            'You\'re spending ${(burnRate * 100).round()}% of your income — that\'s a ${CurrencyHelper.format(deficit)} deficit this month. At this rate, you\'ll need to cut ${CurrencyHelper.format(deficit)} to break even.',
        severity: InsightSeverity.critical,
        category: InsightCategory.alert,
        impactAmount: deficit,
        generatedAt: now,
      );
    } else if (burnRate > 0.9) {
      return SmartInsight(
        id: 'burn_rate_warn',
        icon: Icons.warning_rounded,
        title: 'Thin margin',
        body:
            'You\'re spending ${(burnRate * 100).round()}% of your income. Only ${CurrencyHelper.format(totalIncome - totalExpense)} left as buffer. Aim for at least 20% savings.',
        severity: InsightSeverity.warning,
        category: InsightCategory.spending,
        impactAmount: totalIncome - totalExpense,
        generatedAt: now,
      );
    }

    return null;
  }

  // ────────────── 10. Category Concentration ──────────────

  static SmartInsight? _analyzeCategoryConcentration(
    List<Transaction> expenses,
    DateTime now,
  ) {
    final last30 = expenses
        .where((t) => t.date.isAfter(now.subtract(const Duration(days: 30))))
        .toList();
    if (last30.length < 5) return null;

    final catSpending = _groupByCategory(last30);
    final totalSpend = catSpending.values.fold(0.0, (s, v) => s + v);
    if (totalSpend <= 0) return null;

    final topCat = catSpending.entries.reduce(
      (a, b) => a.value > b.value ? a : b,
    );
    final concentration = topCat.value / totalSpend;

    if (concentration > 0.6) {
      return SmartInsight(
        id: 'concentration_risk',
        icon: Icons.track_changes_rounded,
        title: '${topCat.key} dominates your budget',
        body:
            '${(concentration * 100).round()}% of spending goes to ${topCat.key} (${CurrencyHelper.format(topCat.value)}). High concentration in one category increases financial risk. Try diversifying.',
        severity: InsightSeverity.warning,
        category: InsightCategory.spending,
        impactAmount: topCat.value,
        generatedAt: now,
      );
    }

    return null;
  }

  // ────────────── Helpers ──────────────

  static Map<String, double> _groupByCategory(List<Transaction> txns) {
    final map = <String, double>{};
    for (final t in txns) {
      map[t.category] = (map[t.category] ?? 0) + t.amount;
    }
    return map;
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s
        .split(' ')
        .map((w) {
          if (w.isEmpty) return w;
          return w[0].toUpperCase() + w.substring(1);
        })
        .join(' ');
  }

  static double _sqrt(double value) {
    if (value <= 0) return 0;
    double guess = value / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + value / guess) / 2;
    }
    return guess;
  }
}
