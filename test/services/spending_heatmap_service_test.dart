import 'package:flutter_test/flutter_test.dart';
import 'package:dhanpath/services/spending_heatmap_service.dart';
import 'package:dhanpath/models/transaction_model.dart';

void main() {
  Transaction _tx({
    required double amount,
    String category = 'Food & Dining',
    TransactionType type = TransactionType.expense,
    required DateTime date,
  }) {
    return Transaction(
      amount: amount,
      merchantName: 'Test',
      category: category,
      type: type,
      date: date,
    );
  }

  group('SpendingHeatmapService', () {
    test('returns valid data for empty transactions', () {
      final data = SpendingHeatmapService.generate([], DateTime.now());
      expect(data, isNotNull);
      expect(data.days, isEmpty);
    });

    test('generates heatmap for single month', () {
      final month = DateTime(2024, 6);
      final txns = <Transaction>[];
      for (int d = 1; d <= 30; d++) {
        txns.add(_tx(amount: 500, date: DateTime(2024, 6, d)));
      }

      final data = SpendingHeatmapService.generate(txns, month);
      expect(data.days, isNotEmpty);
      expect(data.days.length, lessThanOrEqualTo(31));
    });

    test('intensity values are 0-4', () {
      final month = DateTime(2024, 6);
      final txns = <Transaction>[];
      for (int d = 1; d <= 30; d++) {
        txns.add(_tx(amount: d * 100.0, date: DateTime(2024, 6, d)));
      }

      final data = SpendingHeatmapService.generate(txns, month);
      for (final day in data.days) {
        expect(day.intensity, greaterThanOrEqualTo(0));
        expect(day.intensity, lessThanOrEqualTo(4));
      }
    });

    test('higher spending days have higher intensity', () {
      final month = DateTime(2024, 6);
      final txns = [
        _tx(amount: 100, date: DateTime(2024, 6, 1)),
        _tx(amount: 100000, date: DateTime(2024, 6, 15)),
      ];

      final data = SpendingHeatmapService.generate(txns, month);
      if (data.days.length >= 2) {
        final low = data.days.firstWhere((d) => d.date.day == 1);
        final high = data.days.firstWhere((d) => d.date.day == 15);
        expect(high.intensity, greaterThanOrEqualTo(low.intensity));
      }
    });

    test('weekStats contains weekday analysis', () {
      final month = DateTime(2024, 6);
      final txns = <Transaction>[];
      for (int d = 1; d <= 30; d++) {
        txns.add(_tx(amount: 500, date: DateTime(2024, 6, d)));
      }

      final data = SpendingHeatmapService.generate(txns, month);
      expect(data.weekStats, isNotNull);
    });

    test('only counts expense transactions', () {
      final month = DateTime(2024, 6);
      final txns = [
        _tx(amount: 50000, type: TransactionType.income, date: DateTime(2024, 6, 10)),
        _tx(amount: 500, type: TransactionType.expense, date: DateTime(2024, 6, 10)),
      ];

      final data = SpendingHeatmapService.generate(txns, month);
      if (data.days.isNotEmpty) {
        final day10 = data.days.firstWhere((d) => d.date.day == 10);
        // Should only reflect the 500 expense, not 50000 income
        expect(day10.amount, closeTo(500, 1));
      }
    });

    test('totalSpending sums correctly', () {
      final month = DateTime(2024, 6);
      final txns = [
        _tx(amount: 1000, date: DateTime(2024, 6, 1)),
        _tx(amount: 2000, date: DateTime(2024, 6, 2)),
        _tx(amount: 3000, date: DateTime(2024, 6, 3)),
      ];

      final data = SpendingHeatmapService.generate(txns, month);
      expect(data.totalSpending, closeTo(6000, 1));
    });
  });
}
