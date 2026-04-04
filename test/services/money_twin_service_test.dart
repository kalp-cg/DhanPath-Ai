import 'package:flutter_test/flutter_test.dart';
import 'package:dhanpath/models/transaction_model.dart';
import 'package:dhanpath/services/money_twin_service.dart';

void main() {
  group('MoneyTwinService', () {
    const service = MoneyTwinService();

    List<Transaction> sampleTransactions() {
      return [
        Transaction(
          amount: 50000,
          merchantName: 'Salary',
          category: 'Income',
          type: TransactionType.income,
          date: DateTime(2026, 1, 1),
        ),
        Transaction(
          amount: 52000,
          merchantName: 'Salary',
          category: 'Income',
          type: TransactionType.income,
          date: DateTime(2026, 2, 1),
        ),
        Transaction(
          amount: 18000,
          merchantName: 'Rent',
          category: 'Housing',
          type: TransactionType.expense,
          date: DateTime(2026, 1, 2),
        ),
        Transaction(
          amount: 12000,
          merchantName: 'Food + Misc',
          category: 'Lifestyle',
          type: TransactionType.expense,
          date: DateTime(2026, 1, 14),
        ),
        Transaction(
          amount: 21000,
          merchantName: 'Rent',
          category: 'Housing',
          type: TransactionType.expense,
          date: DateTime(2026, 2, 2),
        ),
        Transaction(
          amount: 14000,
          merchantName: 'Shopping',
          category: 'Lifestyle',
          type: TransactionType.expense,
          date: DateTime(2026, 2, 18),
        ),
      ];
    }

    test('creates projection for full horizon', () {
      final result = service.simulate(
        transactions: sampleTransactions(),
        scenario: const MoneyTwinScenario(
          monthlyIncome: 55000,
          fixedCosts: 25000,
          startingBuffer: 30000,
          horizonMonths: 6,
        ),
      );

      expect(result.projections.length, 6);
      expect(result.riskScore, inInclusiveRange(0, 100));
    });

    test('detects runway when scenario is negative cashflow', () {
      final result = service.simulate(
        transactions: sampleTransactions(),
        scenario: const MoneyTwinScenario(
          monthlyIncome: 25000,
          fixedCosts: 30000,
          startingBuffer: 10000,
          horizonMonths: 6,
          emergencyExpense: 15000,
          emergencyMonth: 2,
        ),
      );

      expect(result.runwayMonth, isNotNull);
      expect(result.riskScore, greaterThan(40));
    });

    test('handles empty transaction history', () {
      final result = service.simulate(
        transactions: const [],
        scenario: const MoneyTwinScenario(
          monthlyIncome: 40000,
          fixedCosts: 20000,
          startingBuffer: 5000,
          horizonMonths: 3,
        ),
      );

      expect(result.projections.length, 3);
      expect(result.avgHistoricalExpense, 0);
    });
  });
}
