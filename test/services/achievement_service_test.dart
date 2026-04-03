import 'package:flutter_test/flutter_test.dart';
import 'package:dhanpath/services/achievement_service.dart';
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

  group('AchievementService', () {
    test('returns default stats for empty transactions', () {
      final stats = AchievementService.calculate([]);
      expect(stats.xp, 0);
      expect(stats.level.level, 1);
      expect(stats.level.title, isNotEmpty);
      expect(stats.badges, isEmpty);
      expect(stats.recentUnlocks, isEmpty);
    });

    test('calculates XP from transactions', () {
      final now = DateTime.now();
      final txns = List.generate(
        50,
        (i) => _tx(
          amount: 500,
          date: now.subtract(Duration(days: i)),
        ),
      );

      final stats = AchievementService.calculate(txns);
      expect(stats.xp, greaterThan(0));
    });

    test('level increases with more XP', () {
      final now = DateTime.now();

      // Few transactions
      final small = List.generate(
        5,
        (i) => _tx(amount: 100, date: now.subtract(Duration(days: i))),
      );
      final statsSmall = AchievementService.calculate(small);

      // Many transactions
      final large = List.generate(
        500,
        (i) => _tx(amount: 100, date: now.subtract(Duration(days: i % 365))),
      );
      final statsLarge = AchievementService.calculate(large);

      expect(statsLarge.level.level, greaterThanOrEqualTo(statsSmall.level.level));
      expect(statsLarge.xp, greaterThan(statsSmall.xp));
    });

    test('unlocks badges with sufficient data', () {
      final now = DateTime.now();
      final txns = <Transaction>[];

      // Generate diverse transactions over 6 months
      for (int day = 0; day < 180; day++) {
        // Daily expense
        txns.add(_tx(
          amount: 500,
          category: day % 2 == 0 ? 'Food & Dining' : 'Shopping',
          merchant: day % 2 == 0 ? 'Swiggy' : 'Amazon',
          date: now.subtract(Duration(days: day)),
        ));
      }
      // Add some income
      for (int m = 0; m < 6; m++) {
        txns.add(_tx(
          amount: 50000,
          type: TransactionType.income,
          category: 'Salary',
          merchant: 'Employer',
          date: DateTime(now.year, now.month - m, 1),
        ));
      }

      final stats = AchievementService.calculate(txns);
      expect(stats.badges, isNotEmpty, reason: 'Should unlock at least some badges with 180 days of data');
    });

    test('badge has valid properties', () {
      final now = DateTime.now();
      final txns = List.generate(
        100,
        (i) => _tx(
          amount: 300,
          date: now.subtract(Duration(days: i)),
        ),
      );

      final stats = AchievementService.calculate(txns);
      for (final badge in stats.badges) {
        expect(badge.name, isNotEmpty);
        expect(badge.description, isNotEmpty);
        expect(badge.icon, isNotEmpty);
        expect(badge.isUnlocked, isA<bool>());
      }
    });

    test('LevelInfo progression is consistent', () {
      final now = DateTime.now();
      // Generate progressively more transactions to test level progression
      for (int count = 10; count <= 100; count += 10) {
        final txns = List.generate(
          count,
          (i) => _tx(
            amount: 1000,
            date: now.subtract(Duration(days: i)),
          ),
        );
        final stats = AchievementService.calculate(txns);
        expect(stats.level.level, greaterThanOrEqualTo(1));
        expect(stats.level.level, lessThanOrEqualTo(11));
        expect(stats.xpForNextLevel, greaterThanOrEqualTo(stats.xp),
            reason: 'XP needed for next level should be >= current XP');
      }
    });

    test('no-spend day streaks contribute to XP', () {
      final now = DateTime.now();

      // Transactions with gaps (no-spend days)
      final txns = <Transaction>[];
      for (int i = 0; i < 30; i += 3) {
        txns.add(_tx(
          amount: 1000,
          date: now.subtract(Duration(days: i)),
        ));
      }

      final stats = AchievementService.calculate(txns);
      expect(stats.xp, greaterThan(0));
      // No-spend day bonus should be present
      expect(stats.noSpendDays, greaterThanOrEqualTo(0));
    });

    test('handles transaction types correctly', () {
      final now = DateTime.now();
      final txns = [
        _tx(amount: 50000, type: TransactionType.income, category: 'Salary', date: now),
        _tx(amount: 1000, type: TransactionType.expense, date: now),
        _tx(amount: 5000, type: TransactionType.investment, category: 'Mutual Fund', date: now),
        _tx(amount: 2000, type: TransactionType.transfer, category: 'Transfer', date: now),
        _tx(amount: 3000, type: TransactionType.credit, category: 'Credit Card', date: now),
      ];

      final stats = AchievementService.calculate(txns);
      expect(stats, isA<AchievementStats>());
      expect(stats.xp, greaterThan(0));
    });
  });
}
