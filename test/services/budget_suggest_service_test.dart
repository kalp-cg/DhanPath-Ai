import 'package:flutter_test/flutter_test.dart';
import 'package:dhanpath/services/budget_suggest_service.dart';
import 'package:dhanpath/models/transaction_model.dart';

void main() {
  Transaction _tx({
    required double amount,
    String category = 'Food & Dining',
    String merchant = 'Swiggy',
    TransactionType type = TransactionType.expense,
    required DateTime date,
  }) {
    return Transaction(
      amount: amount,
      merchantName: merchant,
      category: category,
      type: type,
      date: date,
    );
  }

  group('BudgetSuggestService', () {
    test('returns empty plan for empty transactions', () {
      final plan = BudgetSuggestService.generate([]);
      expect(plan, isNotNull);
      expect(plan.suggestions, isEmpty);
    });

    test('generates suggestions from 3 months of data', () {
      final now = DateTime.now();
      final txns = <Transaction>[];

      // 3 months of varied spending
      for (int m = 0; m < 3; m++) {
        for (int d = 1; d <= 28; d++) {
          final cat = d % 3 == 0
              ? 'Food & Dining'
              : d % 3 == 1
                  ? 'Shopping'
                  : 'Transport';
          txns.add(_tx(
            amount: 300 + (d * 10),
            category: cat,
            date: DateTime(now.year, now.month - m, d),
          ));
        }
      }
      // Also add income
      for (int m = 0; m < 3; m++) {
        txns.add(_tx(
          amount: 60000,
          type: TransactionType.income,
          category: 'Salary',
          date: DateTime(now.year, now.month - m, 1),
        ));
      }

      final plan = BudgetSuggestService.generate(txns);
      expect(plan.suggestions, isNotEmpty,
          reason: 'Should suggest budgets for recurring categories');
    });

    test('suggestion amounts are positive', () {
      final now = DateTime.now();
      final txns = <Transaction>[];
      for (int m = 0; m < 3; m++) {
        for (int d = 1; d <= 10; d++) {
          txns.add(_tx(
            amount: 1000,
            category: 'Food & Dining',
            date: DateTime(now.year, now.month - m, d),
          ));
        }
      }

      final plan = BudgetSuggestService.generate(txns);
      for (final s in plan.suggestions) {
        expect(s.suggestedAmount, greaterThan(0),
            reason: '${s.category} suggested amount should be positive');
        expect(s.currentAverage, greaterThan(0));
      }
    });

    test('difficulty is valid string', () {
      final now = DateTime.now();
      final txns = <Transaction>[];
      for (int m = 0; m < 3; m++) {
        for (int d = 1; d <= 15; d++) {
          txns.add(_tx(
            amount: 500,
            category: 'Shopping',
            date: DateTime(now.year, now.month - m, d),
          ));
        }
      }

      final plan = BudgetSuggestService.generate(txns);
      for (final s in plan.suggestions) {
        expect(
          ['Easy', 'Moderate', 'Challenging', 'Hard'].contains(s.difficulty),
          isTrue,
          reason: 'Difficulty "${s.difficulty}" should be a valid level',
        );
      }
    });

    test('totalSuggested is sum of all suggestions', () {
      final now = DateTime.now();
      final txns = <Transaction>[];
      for (int m = 0; m < 3; m++) {
        txns.add(_tx(
          amount: 5000,
          category: 'Food & Dining',
          date: DateTime(now.year, now.month - m, 15),
        ));
        txns.add(_tx(
          amount: 3000,
          category: 'Transport',
          date: DateTime(now.year, now.month - m, 15),
        ));
      }

      final plan = BudgetSuggestService.generate(txns);
      if (plan.suggestions.isNotEmpty) {
        final sumSuggested = plan.suggestions.fold<double>(
          0,
          (sum, s) => sum + s.suggestedAmount,
        );
        expect(plan.totalSuggested, closeTo(sumSuggested, 1));
      }
    });

    test('handles single month gracefully', () {
      final now = DateTime.now();
      final txns = List.generate(
        10,
        (i) => _tx(
          amount: 800,
          date: DateTime(now.year, now.month, i + 1),
        ),
      );

      // Should not throw even with limited data
      final plan = BudgetSuggestService.generate(txns);
      expect(plan, isA<BudgetPlan>());
    });

    test('savings rate is between 0 and 100', () {
      final now = DateTime.now();
      final txns = <Transaction>[];
      for (int m = 0; m < 3; m++) {
        txns.add(_tx(
          amount: 50000,
          type: TransactionType.income,
          category: 'Salary',
          date: DateTime(now.year, now.month - m, 1),
        ));
        for (int d = 1; d <= 20; d++) {
          txns.add(_tx(
            amount: 1000,
            category: 'Food & Dining',
            date: DateTime(now.year, now.month - m, d),
          ));
        }
      }

      final plan = BudgetSuggestService.generate(txns);
      expect(plan.currentSavingsRate, greaterThanOrEqualTo(0));
      expect(plan.currentSavingsRate, lessThanOrEqualTo(100));
      expect(plan.suggestedSavingsRate, greaterThanOrEqualTo(0));
      expect(plan.suggestedSavingsRate, lessThanOrEqualTo(100));
    });
  });
}
