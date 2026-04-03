import 'package:flutter_test/flutter_test.dart';
import 'package:dhanpath/services/weekly_digest_service.dart';
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

  group('WeeklyDigestService', () {
    test('returns valid digest for empty transactions', () {
      final digest = WeeklyDigestService.generate([]);
      expect(digest, isNotNull);
      expect(digest.weekLabel, isNotEmpty);
    });

    test('generates digest from two weeks of data', () {
      final now = DateTime.now();
      final txns = <Transaction>[];

      // Two weeks of spending
      for (int i = 0; i < 14; i++) {
        txns.add(_tx(
          amount: 500 + (i * 50),
          date: now.subtract(Duration(days: i)),
        ));
        // Also income
        if (i % 7 == 0) {
          txns.add(_tx(
            amount: 25000,
            type: TransactionType.income,
            category: 'Salary',
            merchant: 'Employer',
            date: now.subtract(Duration(days: i)),
          ));
        }
      }

      final digest = WeeklyDigestService.generate(txns);
      expect(digest.weekLabel, isNotEmpty);
      expect(digest.totalSpent, greaterThan(0));
    });

    test('headline is non-empty', () {
      final now = DateTime.now();
      final txns = List.generate(
        14,
        (i) => _tx(amount: 1000, date: now.subtract(Duration(days: i))),
      );

      final digest = WeeklyDigestService.generate(txns);
      expect(digest.headline, isNotEmpty);
    });

    test('daily breakdown covers 7 days', () {
      final now = DateTime.now();
      final txns = <Transaction>[];
      for (int i = 0; i < 7; i++) {
        txns.add(_tx(
          amount: 1000,
          date: now.subtract(Duration(days: i)),
        ));
      }

      final digest = WeeklyDigestService.generate(txns);
      expect(digest.dailyBreakdown.length, 7,
          reason: 'Should have 7 days in breakdown');
    });

    test('week-over-week change is calculated', () {
      final now = DateTime.now();
      final txns = <Transaction>[];

      // This week: higher spending
      for (int i = 0; i < 7; i++) {
        txns.add(_tx(
          amount: 2000,
          date: now.subtract(Duration(days: i)),
        ));
      }
      // Last week: lower spending
      for (int i = 7; i < 14; i++) {
        txns.add(_tx(
          amount: 1000,
          date: now.subtract(Duration(days: i)),
        ));
      }

      final digest = WeeklyDigestService.generate(txns);
      // Change should be positive since this week > last week
      expect(digest.weekOverWeekChange, isNotNull);
    });

    test('tip is non-empty', () {
      final now = DateTime.now();
      final txns = List.generate(
        7,
        (i) => _tx(amount: 500, date: now.subtract(Duration(days: i))),
      );

      final digest = WeeklyDigestService.generate(txns);
      expect(digest.tip, isNotEmpty);
    });
  });
}
