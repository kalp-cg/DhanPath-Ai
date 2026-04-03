import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import 'user_preferences_service.dart';

/// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
/// Smart Budget Auto-Suggest Service
///
/// Analyzes 3 months of spending history and suggests
/// realistic, personalized budgets per category using
/// statistical analysis (no ML library needed).
///
/// ALGORITHM:
///  1. Calculate weighted moving average (recent months weighted more)
///  2. Apply category-specific elasticity (essentials vs discretionary)
///  3. Suggest a "comfortable" and "stretch" budget goal
///  4. Project annual savings if budget is followed
/// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

enum BudgetDifficulty { easy, moderate, stretch, aggressive }

class BudgetSuggestion {
  final String category;
  final IconData icon;
  final double currentAverage; // 3-month weighted avg
  final double suggestedBudget; // the recommendation
  final double stretchBudget; // aggressive target
  final double potentialMonthlySaving;
  final double potentialAnnualSaving;
  final BudgetDifficulty difficulty;
  final String rationale;
  final bool isEssential; // rent, groceries, bills = essential

  const BudgetSuggestion({
    required this.category,
    required this.icon,
    required this.currentAverage,
    required this.suggestedBudget,
    required this.stretchBudget,
    required this.potentialMonthlySaving,
    required this.potentialAnnualSaving,
    required this.difficulty,
    required this.rationale,
    required this.isEssential,
  });
}

class BudgetPlan {
  final List<BudgetSuggestion> suggestions;
  final double totalCurrentSpend;
  final double totalSuggestedBudget;
  final double totalStretchBudget;
  final double monthlyIncome;
  final double suggestedSavingsRate;
  final double currentSavingsRate;
  final String overallAdvice;
  final DateTime generatedAt;

  const BudgetPlan({
    required this.suggestions,
    required this.totalCurrentSpend,
    required this.totalSuggestedBudget,
    required this.totalStretchBudget,
    required this.monthlyIncome,
    required this.suggestedSavingsRate,
    required this.currentSavingsRate,
    required this.overallAdvice,
    required this.generatedAt,
  });
}

class BudgetSuggestService {
  // Category classifications
  static const _essentialCategories = {
    'Rent',
    'EMI',
    'Loan',
    'Insurance',
    'Utilities',
    'Bills',
    'Groceries',
    'Medical',
    'Health',
    'Education',
    'Fuel',
    'Transport',
  };

  static const _categoryIcons = {
    'Food & Dining': Icons.restaurant_rounded,
    'Shopping': Icons.shopping_bag_rounded,
    'Entertainment': Icons.movie_rounded,
    'Transport': Icons.directions_car_rounded,
    'Groceries': Icons.shopping_cart_rounded,
    'Bills': Icons.smartphone_rounded,
    'Utilities': Icons.lightbulb_outline_rounded,
    'Rent': Icons.home_rounded,
    'EMI': Icons.account_balance_rounded,
    'Loan': Icons.credit_card_rounded,
    'Insurance': Icons.shield_rounded,
    'Medical': Icons.local_hospital_rounded,
    'Health': Icons.medication_rounded,
    'Education': Icons.school_rounded,
    'Fuel': Icons.local_gas_station_rounded,
    'Subscription': Icons.subscriptions_rounded,
    'Travel': Icons.flight_rounded,
    'Personal Care': Icons.spa_rounded,
    'Clothing': Icons.checkroom_rounded,
    'Gift': Icons.card_giftcard_rounded,
    'Investment': Icons.trending_up_rounded,
    'Recharge': Icons.cell_tower_rounded,
    'Transfer': Icons.swap_horiz_rounded,
    'Other': Icons.inventory_2_rounded,
  };

  /// Generate a budget plan from transaction history
  static BudgetPlan generate(List<Transaction> allTransactions) {
    final now = DateTime.now();
    final active = allTransactions.where((t) => !t.isDeleted).toList();

    // Last 3 months of data
    final month1Start = DateTime(now.year, now.month - 1, 1);
    final month2Start = DateTime(now.year, now.month - 2, 1);
    final month3Start = DateTime(now.year, now.month - 3, 1);
    final currentStart = DateTime(now.year, now.month, 1);

    final m1Expenses = _monthExpenses(active, month1Start, currentStart);
    final m2Expenses = _monthExpenses(active, month2Start, month1Start);
    final m3Expenses = _monthExpenses(active, month3Start, month2Start);

    // Calculate monthly income (average of last 3 months)
    final incomes = active
        .where((t) => t.type == TransactionType.income)
        .toList();
    final m1Income = _monthSum(incomes, month1Start, currentStart);
    final m2Income = _monthSum(incomes, month2Start, month1Start);
    final m3Income = _monthSum(incomes, month3Start, month2Start);
    final avgIncome = (m1Income * 0.5 + m2Income * 0.3 + m3Income * 0.2);

    // Group expenses by category with weighted averages
    final allCategories = <String>{};
    for (final cats in [m1Expenses, m2Expenses, m3Expenses]) {
      allCategories.addAll(cats.keys);
    }

    final suggestions = <BudgetSuggestion>[];
    double totalCurrent = 0;
    double totalSuggested = 0;
    double totalStretch = 0;

    for (final cat in allCategories) {
      final v1 = m1Expenses[cat] ?? 0.0;
      final v2 = m2Expenses[cat] ?? 0.0;
      final v3 = m3Expenses[cat] ?? 0.0;

      // Skip trivially small categories
      if (v1 + v2 + v3 < 100) continue;

      // Weighted moving average (most recent month = 50%, then 30%, 20%)
      final weightedAvg = v1 * 0.5 + v2 * 0.3 + v3 * 0.2;
      final isEssential = _essentialCategories.any(
        (e) => cat.toLowerCase().contains(e.toLowerCase()),
      );

      // Elasticity: essentials get smaller cuts, discretionary gets larger
      final cutFactor = isEssential ? 0.05 : 0.15; // 5% vs 15%
      final stretchCutFactor = isEssential ? 0.10 : 0.25; // 10% vs 25%

      final suggested = weightedAvg * (1 - cutFactor);
      final stretch = weightedAvg * (1 - stretchCutFactor);

      final difficulty = _assessDifficulty(
        cutFactor,
        stretchCutFactor,
        v1,
        v2,
        v3,
      );
      final rationale = _generateRationale(
        cat,
        weightedAvg,
        suggested,
        isEssential,
        v1,
        v2,
      );

      totalCurrent += weightedAvg;
      totalSuggested += suggested;
      totalStretch += stretch;

      suggestions.add(
        BudgetSuggestion(
          category: cat,
          icon: _categoryIcons[cat] ?? Icons.inventory_2_rounded,
          currentAverage: weightedAvg,
          suggestedBudget: suggested,
          stretchBudget: stretch,
          potentialMonthlySaving: weightedAvg - suggested,
          potentialAnnualSaving: (weightedAvg - suggested) * 12,
          difficulty: difficulty,
          rationale: rationale,
          isEssential: isEssential,
        ),
      );
    }

    // Sort: discretionary first (more actionable), then by saving potential
    suggestions.sort((a, b) {
      if (a.isEssential != b.isEssential) return a.isEssential ? 1 : -1;
      return b.potentialMonthlySaving.compareTo(a.potentialMonthlySaving);
    });

    final currentSavingsRate = avgIncome > 0
        ? (avgIncome - totalCurrent) / avgIncome
        : 0.0;
    final suggestedSavingsRate = avgIncome > 0
        ? (avgIncome - totalSuggested) / avgIncome
        : 0.0;

    final advice = _generateOverallAdvice(
      currentSavingsRate,
      suggestedSavingsRate,
      totalCurrent,
      totalSuggested,
      avgIncome,
    );

    return BudgetPlan(
      suggestions: suggestions,
      totalCurrentSpend: totalCurrent,
      totalSuggestedBudget: totalSuggested,
      totalStretchBudget: totalStretch,
      monthlyIncome: avgIncome,
      suggestedSavingsRate: suggestedSavingsRate,
      currentSavingsRate: currentSavingsRate,
      overallAdvice: advice,
      generatedAt: now,
    );
  }

  static Map<String, double> _monthExpenses(
    List<Transaction> txns,
    DateTime start,
    DateTime end,
  ) {
    final map = <String, double>{};
    for (final t in txns) {
      if (t.type == TransactionType.expense &&
          !t.date.isBefore(start) &&
          t.date.isBefore(end)) {
        map[t.category] = (map[t.category] ?? 0) + t.amount;
      }
    }
    return map;
  }

  static double _monthSum(
    List<Transaction> txns,
    DateTime start,
    DateTime end,
  ) {
    return txns
        .where((t) => !t.date.isBefore(start) && t.date.isBefore(end))
        .fold(0.0, (s, t) => s + t.amount);
  }

  static BudgetDifficulty _assessDifficulty(
    double cut,
    double stretchCut,
    double v1,
    double v2,
    double v3,
  ) {
    // Check trend: if already decreasing, easier
    final isDecreasing = v1 < v2 && v2 < v3;
    final isStable = (v1 - v2).abs() / (v2.clamp(1, double.infinity)) < 0.1;

    if (isDecreasing) return BudgetDifficulty.easy;
    if (isStable && cut <= 0.10) return BudgetDifficulty.moderate;
    if (cut > 0.15) return BudgetDifficulty.aggressive;
    return BudgetDifficulty.stretch;
  }

  static String _generateRationale(
    String cat,
    double avg,
    double suggested,
    bool essential,
    double v1,
    double v2,
  ) {
    if (essential) {
      return 'As an essential expense, we suggest a modest 5% buffer. Your 3-month average is ${CurrencyHelper.format(avg)}.';
    }
    if (v1 > v2 * 1.2) {
      return 'Your $cat spending increased last month. Aim for ${CurrencyHelper.format(suggested)} — back to your normal range.';
    }
    if (v1 < v2 * 0.8) {
      return 'Already trending down! Lock in ${CurrencyHelper.format(suggested)} as your new normal.';
    }
    return 'Based on your 3-month pattern, ${CurrencyHelper.format(suggested)}/month is achievable with minor adjustments.';
  }

  static String _generateOverallAdvice(
    double currentRate,
    double suggestedRate,
    double spend,
    double suggested,
    double income,
  ) {
    final monthlySaving = spend - suggested;
    final annualSaving = monthlySaving * 12;

    if (income <= 0) {
      return 'Add your income sources to get a complete budget picture with savings projections.';
    }

    if (currentRate < 0) {
      return 'You\'re spending more than you earn. Following this budget saves ${CurrencyHelper.format(monthlySaving)}/month, helping close the gap. Focus on the biggest discretionary categories first.';
    }

    if (suggestedRate >= 0.2) {
      return 'Following this plan puts your savings rate at ${(suggestedRate * 100).round()}% — that\'s ${CurrencyHelper.format(annualSaving)} more per year. You\'re in great shape!';
    }

    return 'This budget saves ${CurrencyHelper.format(monthlySaving)}/month (${CurrencyHelper.format(annualSaving)}/year). Start with the top 2 discretionary categories for quick wins.';
  }
}
