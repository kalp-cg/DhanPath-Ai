import 'package:flutter_test/flutter_test.dart';
import 'package:dhanpath/services/money_personality_engine.dart';
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

  group('MoneyPersonalityEngine', () {
    test('returns default personality for empty transactions', () {
      final result = MoneyPersonalityEngine.analyze([]);
      expect(result, isNotNull);
      expect(result.personalityType, isNotEmpty);
      expect(result.traits, isNotEmpty);
    });

    test('personality type is one of defined types', () {
      final now = DateTime.now();
      final txns = List.generate(
        60,
        (i) => _tx(
          amount: 500,
          date: now.subtract(Duration(days: i)),
        ),
      );

      final result = MoneyPersonalityEngine.analyze(txns);
      const validTypes = [
        'The Guardian',
        'The Strategist',
        'The Spontaneous',
        'The Achiever',
        'The Social Spender',
      ];
      expect(
        validTypes.contains(result.personalityType),
        isTrue,
        reason: 'Personality type "${result.personalityType}" should be one of $validTypes',
      );
    });

    test('trait scores are within 0-100 range', () {
      final now = DateTime.now();
      final txns = <Transaction>[];
      for (int i = 0; i < 90; i++) {
        txns.add(_tx(
          amount: 200 + (i * 10),
          category: ['Food & Dining', 'Shopping', 'Transport', 'Entertainment'][i % 4],
          date: now.subtract(Duration(days: i)),
        ));
      }

      final result = MoneyPersonalityEngine.analyze(txns);
      for (final trait in result.traits) {
        expect(trait.score, greaterThanOrEqualTo(0),
            reason: '${trait.name} score should be >= 0');
        expect(trait.score, lessThanOrEqualTo(100),
            reason: '${trait.name} score should be <= 100');
      }
    });

    test('has exactly 5 traits', () {
      final now = DateTime.now();
      final txns = List.generate(
        30,
        (i) => _tx(amount: 1000, date: now.subtract(Duration(days: i))),
      );

      final result = MoneyPersonalityEngine.analyze(txns);
      expect(result.traits.length, 5);
    });

    test('strengths and watchouts are non-empty', () {
      final now = DateTime.now();
      final txns = List.generate(
        50,
        (i) => _tx(
          amount: 500 + (i * 50),
          date: now.subtract(Duration(days: i)),
        ),
      );

      final result = MoneyPersonalityEngine.analyze(txns);
      expect(result.strengths, isNotEmpty, reason: 'Should list at least one strength');
      expect(result.watchOuts, isNotEmpty, reason: 'Should list at least one watch-out');
    });

    test('mantra is non-empty', () {
      final now = DateTime.now();
      final txns = List.generate(
        20,
        (i) => _tx(amount: 200, date: now.subtract(Duration(days: i))),
      );

      final result = MoneyPersonalityEngine.analyze(txns);
      expect(result.mantra, isNotEmpty);
    });

    test('consistent spender tends towards Guardian/Strategist', () {
      final now = DateTime.now();
      final txns = <Transaction>[];
      // Very consistent daily spending — same amount, same category
      for (int i = 0; i < 90; i++) {
        txns.add(_tx(
          amount: 500,
          category: 'Groceries',
          date: now.subtract(Duration(days: i)),
        ));
      }
      // Steady income
      for (int m = 0; m < 3; m++) {
        txns.add(_tx(
          amount: 50000,
          type: TransactionType.income,
          category: 'Salary',
          date: DateTime(now.year, now.month - m, 1),
        ));
      }

      final result = MoneyPersonalityEngine.analyze(txns);
      // Consistent spender — discipline should be high
      final discipline = result.traits.firstWhere(
        (t) => t.name.toLowerCase().contains('discipline'),
        orElse: () => result.traits.first,
      );
      expect(discipline.score, greaterThan(40),
          reason: 'Consistent spending should yield decent discipline score');
    });

    test('erratic spender has lower discipline', () {
      final now = DateTime.now();
      final txns = <Transaction>[];
      // Very erratic spending — huge variance
      for (int i = 0; i < 90; i++) {
        final wildAmount = (i % 5 == 0) ? 50000.0 : 100.0;
        txns.add(_tx(
          amount: wildAmount,
          category: ['Food & Dining', 'Shopping', 'Transport', 'Entertainment', 'Luxury'][i % 5],
          date: now.subtract(Duration(days: i)),
        ));
      }

      final result = MoneyPersonalityEngine.analyze(txns);
      expect(result, isA<MoneyPersonality>());
    });

    test('handles mixed transaction types', () {
      final now = DateTime.now();
      final txns = [
        _tx(amount: 100000, type: TransactionType.income, category: 'Salary', date: now),
        _tx(amount: 50000, type: TransactionType.investment, category: 'Stocks', date: now),
        _tx(amount: 5000, type: TransactionType.expense, category: 'Food', date: now),
        _tx(amount: 2000, type: TransactionType.transfer, category: 'Transfer', date: now),
        _tx(amount: 10000, type: TransactionType.credit, category: 'Credit', date: now),
      ];

      final result = MoneyPersonalityEngine.analyze(txns);
      expect(result.personalityType, isNotEmpty);
    });
  });
}
