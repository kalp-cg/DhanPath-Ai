import '../models/transaction_model.dart';
import 'user_preferences_service.dart';

/// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
/// Spending Heatmap Service
///
/// Generates GitHub-style contribution grid data for spending,
/// showing spending intensity per day over a configurable period.
/// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

enum HeatmapIntensity { zero, low, medium, high, extreme }

class HeatmapDay {
  final DateTime date;
  final double amount;
  final int transactionCount;
  final HeatmapIntensity intensity;
  final String? topCategory;
  final String tooltip;

  const HeatmapDay({
    required this.date,
    required this.amount,
    required this.transactionCount,
    required this.intensity,
    this.topCategory,
    required this.tooltip,
  });
}

class HeatmapWeekStats {
  final String label; // "Mon", "Tue", etc.
  final double averageSpend;
  final int dayIndex; // 1=Mon, 7=Sun

  const HeatmapWeekStats({
    required this.label,
    required this.averageSpend,
    required this.dayIndex,
  });
}

class HeatmapData {
  final List<HeatmapDay> days;
  final double maxDailySpend;
  final double avgDailySpend;
  final double totalSpend;
  final int totalTransactions;
  final int zeroDays;
  final String busiestDay; // "Wednesday"
  final String quietestDay; // "Sunday"
  final List<HeatmapWeekStats> weekdayAverages;
  final int monthsSpanned;
  final String topCategory;
  final double topCategoryAmount;

  const HeatmapData({
    required this.days,
    required this.maxDailySpend,
    required this.avgDailySpend,
    required this.totalSpend,
    required this.totalTransactions,
    required this.zeroDays,
    required this.busiestDay,
    required this.quietestDay,
    required this.weekdayAverages,
    required this.monthsSpanned,
    required this.topCategory,
    required this.topCategoryAmount,
  });
}

class SpendingHeatmapService {
  static const _weekdayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _weekdayShort = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  /// Generate heatmap data for the last N months (default: 6)
  static HeatmapData generate(
    List<Transaction> allTransactions, {
    int months = 6,
  }) {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month - months + 1, 1);
    final endDate = DateTime(now.year, now.month, now.day);

    final expenses = allTransactions
        .where(
          (t) =>
              !t.isDeleted &&
              t.type == TransactionType.expense &&
              !t.date.isBefore(startDate) &&
              !t.date.isAfter(endDate),
        )
        .toList();

    // Group by date
    final dailyMap = <String, List<Transaction>>{};
    for (final t in expenses) {
      final key =
          '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}-${t.date.day.toString().padLeft(2, '0')}';
      dailyMap.putIfAbsent(key, () => []).add(t);
    }

    // Calculate percentiles for intensity thresholds
    final allDailyAmounts =
        dailyMap.values
            .map((txns) => txns.fold(0.0, (s, t) => s + t.amount))
            .where((a) => a > 0)
            .toList()
          ..sort();

    final p25 = allDailyAmounts.isEmpty
        ? 0.0
        : _percentile(allDailyAmounts, 25);
    final p50 = allDailyAmounts.isEmpty
        ? 0.0
        : _percentile(allDailyAmounts, 50);
    final p75 = allDailyAmounts.isEmpty
        ? 0.0
        : _percentile(allDailyAmounts, 75);

    // Generate all days in range
    final days = <HeatmapDay>[];
    var current = startDate;
    double maxDaily = 0;
    double totalSpend = 0;
    int totalTxns = 0;

    while (!current.isAfter(endDate)) {
      final key =
          '${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}';
      final dayTxns = dailyMap[key] ?? [];
      final dayAmount = dayTxns.fold(0.0, (s, t) => s + t.amount);

      if (dayAmount > maxDaily) maxDaily = dayAmount;
      totalSpend += dayAmount;
      totalTxns += dayTxns.length;

      // Find top category for day
      String? topCat;
      if (dayTxns.isNotEmpty) {
        final catMap = <String, double>{};
        for (final t in dayTxns) {
          catMap[t.category] = (catMap[t.category] ?? 0) + t.amount;
        }
        topCat = catMap.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      }

      final intensity = _intensity(dayAmount, p25, p50, p75);

      days.add(
        HeatmapDay(
          date: current,
          amount: dayAmount,
          transactionCount: dayTxns.length,
          intensity: intensity,
          topCategory: topCat,
          tooltip: dayAmount > 0
              ? '${_formatDate(current)}: ${CurrencyHelper.format(dayAmount)} (${dayTxns.length} txns)'
              : '${_formatDate(current)}: No spending',
        ),
      );

      current = current.add(const Duration(days: 1));
    }

    final totalDays = days.length;
    final zeroDays = days.where((d) => d.amount == 0).length;
    final avgDaily = totalDays > 0
        ? totalSpend / (totalDays - zeroDays).clamp(1, 9999)
        : 0.0;

    // Weekday averages
    final weekdayTotals = List.filled(7, 0.0);
    final weekdayCounts = List.filled(7, 0);
    for (final d in days) {
      final idx = d.date.weekday - 1; // 0=Mon
      weekdayTotals[idx] += d.amount;
      weekdayCounts[idx]++;
    }

    final weekdayAverages = List.generate(7, (i) {
      return HeatmapWeekStats(
        label: _weekdayShort[i],
        averageSpend: weekdayCounts[i] > 0
            ? weekdayTotals[i] / weekdayCounts[i]
            : 0,
        dayIndex: i + 1,
      );
    });

    // Find busiest & quietest day
    final busiestIdx =
        weekdayAverages
            .reduce((a, b) => a.averageSpend > b.averageSpend ? a : b)
            .dayIndex -
        1;
    final quietestIdx =
        weekdayAverages
            .reduce((a, b) => a.averageSpend < b.averageSpend ? a : b)
            .dayIndex -
        1;

    // Overall top category
    final overallCatMap = <String, double>{};
    for (final t in expenses) {
      overallCatMap[t.category] = (overallCatMap[t.category] ?? 0) + t.amount;
    }
    final topCatEntry = overallCatMap.isEmpty
        ? const MapEntry('None', 0.0)
        : overallCatMap.entries.reduce((a, b) => a.value > b.value ? a : b);

    return HeatmapData(
      days: days,
      maxDailySpend: maxDaily,
      avgDailySpend: avgDaily,
      totalSpend: totalSpend,
      totalTransactions: totalTxns,
      zeroDays: zeroDays,
      busiestDay: _weekdayNames[busiestIdx],
      quietestDay: _weekdayNames[quietestIdx],
      weekdayAverages: weekdayAverages,
      monthsSpanned: months,
      topCategory: topCatEntry.key,
      topCategoryAmount: topCatEntry.value,
    );
  }

  static HeatmapIntensity _intensity(
    double amount,
    double p25,
    double p50,
    double p75,
  ) {
    if (amount <= 0) return HeatmapIntensity.zero;
    if (amount <= p25) return HeatmapIntensity.low;
    if (amount <= p50) return HeatmapIntensity.medium;
    if (amount <= p75) return HeatmapIntensity.high;
    return HeatmapIntensity.extreme;
  }

  static double _percentile(List<double> sorted, int percentile) {
    if (sorted.isEmpty) return 0;
    final idx = (percentile / 100 * (sorted.length - 1)).round();
    return sorted[idx.clamp(0, sorted.length - 1)];
  }

  static String _formatDate(DateTime d) {
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
    return '${months[d.month - 1]} ${d.day}';
  }
}
