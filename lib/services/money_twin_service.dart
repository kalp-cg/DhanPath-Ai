import '../models/transaction_model.dart';

class MoneyTwinScenario {
  final double monthlyIncome;
  final double fixedCosts;
  final double startingBuffer;
  final int horizonMonths;
  final double incomeDropPct;
  final double discretionaryCutPct;
  final double inflationPct;
  final double emergencyExpense;
  final int emergencyMonth;

  const MoneyTwinScenario({
    required this.monthlyIncome,
    required this.fixedCosts,
    required this.startingBuffer,
    required this.horizonMonths,
    this.incomeDropPct = 0,
    this.discretionaryCutPct = 0,
    this.inflationPct = 0,
    this.emergencyExpense = 0,
    this.emergencyMonth = 0,
  });
}

class MoneyTwinProjection {
  final int month;
  final double income;
  final double expense;
  final double net;
  final double balance;

  const MoneyTwinProjection({
    required this.month,
    required this.income,
    required this.expense,
    required this.net,
    required this.balance,
  });
}

class MoneyTwinResult {
  final double riskScore;
  final int? runwayMonth;
  final double avgHistoricalExpense;
  final double avgHistoricalIncome;
  final List<String> recommendations;
  final List<MoneyTwinProjection> projections;

  const MoneyTwinResult({
    required this.riskScore,
    required this.runwayMonth,
    required this.avgHistoricalExpense,
    required this.avgHistoricalIncome,
    required this.recommendations,
    required this.projections,
  });
}

class MoneyTwinService {
  const MoneyTwinService();

  MoneyTwinResult simulate({
    required List<Transaction> transactions,
    required MoneyTwinScenario scenario,
  }) {
    final avgExpense = _averageMonthlyAmount(transactions, TransactionType.expense);
    final avgIncome = _averageMonthlyAmount(transactions, TransactionType.income);

    final incomeBase = scenario.monthlyIncome > 0 ? scenario.monthlyIncome : avgIncome;
    final fixedBase = scenario.fixedCosts > 0
        ? scenario.fixedCosts
        : (avgExpense > 0 ? avgExpense * 0.45 : 0.0);
    final variableBase = (avgExpense - fixedBase).clamp(0.0, double.infinity);

    final projections = <MoneyTwinProjection>[];
    var balance = scenario.startingBuffer;
    int? runwayMonth;

    for (var month = 1; month <= scenario.horizonMonths; month++) {
      final inflationFactor = 1 + ((scenario.inflationPct.clamp(-50, 200)) / 100) * ((month - 1) / 12);
      final income = incomeBase * (1 - scenario.incomeDropPct.clamp(0, 100) / 100);
      final variableExpense = variableBase * (1 - scenario.discretionaryCutPct.clamp(0, 100) / 100) * inflationFactor;
      var expense = (fixedBase + variableExpense) * inflationFactor;

      if (scenario.emergencyExpense > 0 && scenario.emergencyMonth == month) {
        expense += scenario.emergencyExpense;
      }

      final net = income - expense;
      balance += net;

      if (balance < 0 && runwayMonth == null) {
        runwayMonth = month;
      }

      projections.add(
        MoneyTwinProjection(
          month: month,
          income: income,
          expense: expense,
          net: net,
          balance: balance,
        ),
      );
    }

    final riskScore = _computeRiskScore(
      projections: projections,
      runwayMonth: runwayMonth,
      startingBuffer: scenario.startingBuffer,
    );

    return MoneyTwinResult(
      riskScore: riskScore,
      runwayMonth: runwayMonth,
      avgHistoricalExpense: avgExpense,
      avgHistoricalIncome: avgIncome,
      recommendations: _buildRecommendations(
        riskScore: riskScore,
        runwayMonth: runwayMonth,
        projections: projections,
        scenario: scenario,
      ),
      projections: projections,
    );
  }

  double _averageMonthlyAmount(List<Transaction> txns, TransactionType type) {
    final filtered = txns.where((t) => t.type == type && !t.isDeleted).toList();
    if (filtered.isEmpty) return 0;

    final grouped = <String, double>{};
    for (final tx in filtered) {
      final key = '${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}';
      grouped[key] = (grouped[key] ?? 0) + tx.amount;
    }

    final totals = grouped.values.toList()..sort((a, b) => b.compareTo(a));
    final sample = totals.take(3).toList();
    final sum = sample.fold(0.0, (acc, value) => acc + value);
    return sum / sample.length;
  }

  double _computeRiskScore({
    required List<MoneyTwinProjection> projections,
    required int? runwayMonth,
    required double startingBuffer,
  }) {
    if (projections.isEmpty) return 0;

    var score = 15.0;
    final firstMonthNet = projections.first.net;
    if (firstMonthNet < 0) score += 30;
    if (runwayMonth != null) score += (50 - runwayMonth * 4).clamp(10, 50);

    final worstBalance = projections.map((p) => p.balance).reduce((a, b) => a < b ? a : b);
    if (worstBalance < 0) {
      score += 20;
    } else if (startingBuffer > 0 && worstBalance < startingBuffer * 0.3) {
      score += 10;
    }

    return score.clamp(0, 100);
  }

  List<String> _buildRecommendations({
    required double riskScore,
    required int? runwayMonth,
    required List<MoneyTwinProjection> projections,
    required MoneyTwinScenario scenario,
  }) {
    final notes = <String>[];

    if (runwayMonth != null) {
      notes.add('Cash buffer may go negative by month $runwayMonth.');
      notes.add('Increase emergency fund or cut discretionary spending by at least 15%.');
    }

    final avgNet = projections.fold(0.0, (s, p) => s + p.net) / projections.length;
    if (avgNet < 0) {
      notes.add('Average monthly net is negative (${avgNet.toStringAsFixed(0)} INR).');
    } else {
      notes.add('Average monthly net stays positive (${avgNet.toStringAsFixed(0)} INR).');
    }

    if (scenario.incomeDropPct > 0) {
      notes.add('Income drop scenario applied: ${scenario.incomeDropPct.toStringAsFixed(0)}%.');
    }
    if (scenario.emergencyExpense > 0 && scenario.emergencyMonth > 0) {
      notes.add('Emergency shock included in month ${scenario.emergencyMonth}.');
    }

    if (riskScore >= 70) {
      notes.add('Risk is high. Trigger strict plan: freeze optional categories for 30 days.');
    } else if (riskScore >= 40) {
      notes.add('Risk is moderate. Weekly review and limit drift in top 2 categories.');
    } else {
      notes.add('Risk is low. You can safely allocate more toward goals.');
    }

    return notes;
  }
}
