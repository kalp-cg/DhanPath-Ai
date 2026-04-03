import 'package:flutter_test/flutter_test.dart';
import 'package:dhanpath/services/spending_story_service.dart';
import 'package:dhanpath/models/transaction_model.dart';

void main() {
  group('SpendingStoryService', () {
    List<Transaction> _makeTxns({
      int incomeCount = 1,
      double incomeAmount = 50000,
      int expenseCount = 10,
      double expenseAmount = 2000,
      DateTime? month,
    }) {
      final m = month ?? DateTime.now();
      final txns = <Transaction>[];
      for (int i = 0; i < incomeCount; i++) {
        txns.add(
          Transaction(
            amount: incomeAmount,
            merchantName: 'Salary',
            category: 'Income',
            type: TransactionType.income,
            date: DateTime(m.year, m.month, 1 + i),
          ),
        );
      }
      for (int i = 0; i < expenseCount; i++) {
        txns.add(
          Transaction(
            amount: expenseAmount,
            merchantName: i % 2 == 0 ? 'Swiggy' : 'Amazon',
            category: i % 2 == 0 ? 'Food & Dining' : 'Shopping',
            type: TransactionType.expense,
            date: DateTime(m.year, m.month, 2 + i),
          ),
        );
      }
      return txns;
    }

    test('generates story with insights from basic data', () {
      final now = DateTime.now();
      final txns = _makeTxns(month: now);
      final story = SpendingStoryService.generate(
        allTransactions: txns,
        month: now,
      );

      expect(story.monthLabel, isNotEmpty);
      expect(story.totalIncome, 50000);
      expect(story.totalExpenses, 20000);
      expect(story.savings, 30000);
      expect(story.transactionCount, 11);
      expect(story.insights, isNotEmpty);
      expect(story.insights.first.type, StoryInsightType.headline);
    });

    test('headline shows positive savings message', () {
      final now = DateTime.now();
      final txns = _makeTxns(month: now);
      final story = SpendingStoryService.generate(
        allTransactions: txns,
        month: now,
      );

      final headline = story.insights.first;
      expect(headline.body, contains('saved'));
      expect(headline.body, contains('60%'));
    });

    test('headline shows overspending warning', () {
      final now = DateTime.now();
      final txns = _makeTxns(
        incomeAmount: 10000,
        expenseAmount: 5000,
        expenseCount: 5,
        month: now,
      );
      final story = SpendingStoryService.generate(
        allTransactions: txns,
        month: now,
      );

      final headline = story.insights.first;
      expect(headline.body, contains('more than you earned'));
      expect(headline.emoji, '⚠️');
    });

    test('top category insight identifies highest spend', () {
      final now = DateTime.now();
      final txns = _makeTxns(month: now);
      final story = SpendingStoryService.generate(
        allTransactions: txns,
        month: now,
      );

      final catInsight = story.insights.firstWhere(
        (i) => i.type == StoryInsightType.topCategory,
      );
      // 5 Swiggy @ 2000 = 10000, 5 Amazon @ 2000 = 10000
      // Both equal, so first alphabetically or first seen wins
      expect(catInsight.body, contains('50%'));
    });

    test('comparison insight works when last month data exists', () {
      final now = DateTime.now();
      final lastMonth = DateTime(now.year, now.month - 1, 1);

      final thisMonthTxns = _makeTxns(month: now, expenseAmount: 3000);
      final lastMonthTxns = _makeTxns(month: lastMonth, expenseAmount: 2000);

      final story = SpendingStoryService.generate(
        allTransactions: thisMonthTxns,
        month: now,
        lastMonthTransactions: lastMonthTxns,
      );

      final compInsight = story.insights.where(
        (i) => i.type == StoryInsightType.comparison,
      );
      expect(compInsight, isNotEmpty);
      expect(compInsight.first.body, contains('more'));
    });

    test('savings insight shows correct tier', () {
      final now = DateTime.now();
      final txns = _makeTxns(
        incomeAmount: 100000,
        expenseAmount: 2000,
        month: now,
      );
      final story = SpendingStoryService.generate(
        allTransactions: txns,
        month: now,
      );

      final savingsInsight = story.insights.firstWhere(
        (i) => i.type == StoryInsightType.savingsRate,
      );
      expect(savingsInsight.emoji, '🏆'); // 80% savings
      expect(savingsInsight.body, contains('Outstanding'));
    });

    test('no-spend days calculated correctly', () {
      final now = DateTime.now();
      final txns = _makeTxns(expenseCount: 3, month: now);
      final story = SpendingStoryService.generate(
        allTransactions: txns,
        month: now,
      );

      // 4 transactions over ~4 unique days, so noSpendDays = daysSoFar - 4
      expect(story.noSpendDays, greaterThan(0));
    });

    test('empty transactions returns empty insights with headline', () {
      final story = SpendingStoryService.generate(
        allTransactions: [],
        month: DateTime.now(),
      );

      expect(story.transactionCount, 0);
      expect(story.totalIncome, 0);
      expect(story.totalExpenses, 0);
      // Should at least have the headline
      expect(story.insights.length, greaterThanOrEqualTo(1));
    });

    test('indian number formatting works', () {
      // Test through the story body text
      final now = DateTime.now();
      final txns = [
        Transaction(
          amount: 150000,
          merchantName: 'Salary',
          category: 'Income',
          type: TransactionType.income,
          date: DateTime(now.year, now.month, 1),
        ),
        Transaction(
          amount: 123456,
          merchantName: 'Rent',
          category: 'Hostel & Rent',
          type: TransactionType.expense,
          date: DateTime(now.year, now.month, 5),
        ),
      ];

      final story = SpendingStoryService.generate(
        allTransactions: txns,
        month: now,
      );

      // The headline should contain formatted amount for 123456 → 1.2L
      expect(story.insights.first.body, contains('1.2L'));
    });
  });
}
