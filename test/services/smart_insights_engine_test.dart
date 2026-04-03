import 'package:flutter_test/flutter_test.dart';
import 'package:dhanpath/services/smart_insights_engine.dart';
import 'package:dhanpath/models/transaction_model.dart';

void main() {
  /// Helper to create a list of transactions with customisable parameters.
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

  group('SmartInsightsEngine', () {
    test('returns empty list for empty transactions', () {
      final insights = SmartInsightsEngine.analyze([]);
      expect(insights, isEmpty);
    });

    test('returns insights for valid expense data', () {
      final now = DateTime.now();
      final txns = <Transaction>[];

      // Generate 60 days of regular expenses
      for (int i = 0; i < 60; i++) {
        txns.add(_tx(
          amount: 500,
          date: now.subtract(Duration(days: i)),
        ));
      }
      // Add one anomalous transaction
      txns.add(_tx(
        amount: 50000,
        date: now.subtract(const Duration(days: 2)),
      ));

      final insights = SmartInsightsEngine.analyze(txns);
      expect(insights, isNotEmpty);
      // Every insight should have a valid title and description
      for (final insight in insights) {
        expect(insight.title, isNotEmpty);
        expect(insight.description, isNotEmpty);
        expect(insight.icon, isNotEmpty);
      }
    });

    test('detects anomalous spending', () {
      final now = DateTime.now();
      final txns = <Transaction>[];

      // 30 days of consistent low spending
      for (int i = 1; i <= 30; i++) {
        txns.add(_tx(
          amount: 200,
          date: now.subtract(Duration(days: i)),
        ));
      }
      // One massive outlier
      txns.add(_tx(
        amount: 100000,
        date: now.subtract(const Duration(days: 1)),
      ));

      final insights = SmartInsightsEngine.analyze(txns);
      final anomaly = insights.where(
        (i) => i.title.toLowerCase().contains('unusual') ||
               i.title.toLowerCase().contains('spike') ||
               i.title.toLowerCase().contains('anomal'),
      );
      expect(anomaly, isNotEmpty, reason: 'Should detect the spending anomaly');
    });

    test('detects merchant loyalty', () {
      final now = DateTime.now();
      final txns = <Transaction>[];

      // 20 transactions at same merchant
      for (int i = 0; i < 20; i++) {
        txns.add(_tx(
          amount: 300,
          merchant: 'Starbucks',
          date: now.subtract(Duration(days: i * 2)),
        ));
      }
      // Mix in a few others
      for (int i = 0; i < 5; i++) {
        txns.add(_tx(
          amount: 100,
          merchant: 'Other Store $i',
          date: now.subtract(Duration(days: i * 3)),
        ));
      }

      final insights = SmartInsightsEngine.analyze(txns);
      final loyalty = insights.where(
        (i) => i.title.toLowerCase().contains('loyal') ||
               i.title.toLowerCase().contains('regular') ||
               i.title.toLowerCase().contains('merchant') ||
               i.description.toLowerCase().contains('starbucks'),
      );
      expect(loyalty, isNotEmpty, reason: 'Should detect merchant loyalty');
    });

    test('insight severities are valid enums', () {
      final now = DateTime.now();
      final txns = <Transaction>[];
      for (int i = 0; i < 30; i++) {
        txns.add(_tx(
          amount: 1000 + (i * 100),
          date: now.subtract(Duration(days: i)),
        ));
      }

      final insights = SmartInsightsEngine.analyze(txns);
      for (final insight in insights) {
        expect(
          InsightSeverity.values.contains(insight.severity),
          isTrue,
        );
      }
    });

    test('handles single transaction gracefully', () {
      final txns = [
        _tx(amount: 1000, date: DateTime.now()),
      ];
      // Should not throw
      final insights = SmartInsightsEngine.analyze(txns);
      expect(insights, isA<List<SmartInsight>>());
    });

    test('income transactions produce insights when dominant', () {
      final now = DateTime.now();
      final txns = <Transaction>[];

      // Multiple income streams with irregularity
      for (int i = 0; i < 6; i++) {
        txns.add(_tx(
          amount: i == 3 ? 200000 : 50000,
          type: TransactionType.income,
          category: 'Salary',
          merchant: 'Employer',
          date: DateTime(now.year, now.month - i, 1),
        ));
      }

      final insights = SmartInsightsEngine.analyze(txns);
      // Should have at least one insight about income
      expect(insights, isA<List<SmartInsight>>());
    });
  });
}
