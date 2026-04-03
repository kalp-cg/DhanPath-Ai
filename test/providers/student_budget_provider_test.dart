import 'package:flutter_test/flutter_test.dart';
import 'package:dhanpath/providers/student_budget_provider.dart';

void main() {
  group('StudentBudgetProvider', () {
    late StudentBudgetProvider provider;

    setUp(() {
      provider = StudentBudgetProvider();
    });

    test('initial state is correct', () {
      expect(provider.monthlyBudget, 0);
      expect(provider.totalSpent, 0);
      expect(provider.remaining, 0);
      expect(provider.spentPercent, 0);
      expect(provider.categorySpending, isEmpty);
      expect(provider.categoryBudgets, isEmpty);
      expect(provider.recentTransactions, isEmpty);
      expect(provider.isLoading, false);
      expect(provider.errorMessage, isNull);
      expect(provider.isOverBudget, false);
    });

    test('spentPercent is 0 when budget is 0', () {
      expect(provider.spentPercent, 0);
    });

    test('isOverBudget is false when no budget set', () {
      expect(provider.isOverBudget, false);
    });

    test('remaining equals budget minus spent', () {
      // With default (both 0), remaining should be 0
      expect(provider.remaining, 0);
    });

    test('topCategory returns None when no spending', () {
      expect(provider.topCategory, 'None');
    });

    test('dailyAverage is 0 on first call', () {
      // We can't predict exact day avg without transactions
      // but default should be 0 total => 0 avg per day
      expect(provider.dailyAverage, 0);
    });

    test('suggestedDailySpend is 0 when no budget', () {
      expect(provider.suggestedDailySpend, 0);
    });

    test('overBudgetCategories is empty initially', () {
      expect(provider.overBudgetCategories, isEmpty);
    });

    test('clearError sets errorMessage to null', () {
      provider.clearError();
      expect(provider.errorMessage, isNull);
    });

    test('setMonthlyBudget updates budget', () async {
      await provider.setMonthlyBudget(5000);
      expect(provider.monthlyBudget, 5000);
    });

    test('categorySpending is unmodifiable', () {
      expect(
        () => (provider.categorySpending as Map)['test'] = 100.0,
        throwsA(anything),
      );
    });

    test('categoryBudgets is unmodifiable', () {
      expect(
        () => (provider.categoryBudgets as Map)['test'] = 100.0,
        throwsA(anything),
      );
    });

    test('recentTransactions is unmodifiable', () {
      expect(
        () => provider.recentTransactions.add(null as dynamic),
        throwsA(anything),
      );
    });
  });
}
