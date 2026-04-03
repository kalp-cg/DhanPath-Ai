import 'package:flutter_test/flutter_test.dart';
import 'package:dhanpath/providers/transaction_provider.dart';

void main() {
  group('MonthlyBreakdown', () {
    test('creates with correct values', () {
      final breakdown = MonthlyBreakdown(
        total: 5000,
        income: 10000,
        expenses: 5000,
      );

      expect(breakdown.total, 5000);
      expect(breakdown.income, 10000);
      expect(breakdown.expenses, 5000);
    });

    test('zero values are valid', () {
      final breakdown = MonthlyBreakdown(total: 0, income: 0, expenses: 0);

      expect(breakdown.total, 0);
      expect(breakdown.income, 0);
      expect(breakdown.expenses, 0);
    });

    test('negative total valid when expenses exceed income', () {
      final breakdown = MonthlyBreakdown(
        total: -3000,
        income: 2000,
        expenses: 5000,
      );

      expect(breakdown.total, -3000);
    });
  });

  group('TransactionProvider initial state', () {
    late TransactionProvider provider;

    setUp(() {
      // Create provider without service locator (tests just the logic)
      provider = TransactionProvider();
    });

    test('transactions list is initially empty', () {
      expect(provider.transactions, isEmpty);
    });

    test('isLoading is false initially', () {
      expect(provider.isLoading, false);
    });

    test('searchQuery is empty initially', () {
      expect(provider.searchQuery, isEmpty);
    });

    test('errorMessage is null initially', () {
      expect(provider.errorMessage, isNull);
    });

    test('totalIncome is 0 with no transactions', () {
      expect(provider.totalIncome, 0);
    });

    test('totalExpense is 0 with no transactions', () {
      expect(provider.totalExpense, 0);
    });

    test('balance is 0 with no transactions', () {
      expect(provider.balance, 0);
    });

    test('categories is empty with no transactions', () {
      expect(provider.categories, isEmpty);
    });

    test('banks is empty with no transactions', () {
      expect(provider.banks, isEmpty);
    });

    test('todayTransactions is empty', () {
      expect(provider.todayTransactions, isEmpty);
    });

    test('thisMonthTransactions is empty', () {
      expect(provider.thisMonthTransactions, isEmpty);
    });

    test('recurringTransactions is empty', () {
      expect(provider.recurringTransactions, isEmpty);
    });

    test('totalRecurring is 0', () {
      expect(provider.totalRecurring, 0);
    });

    test('currentMonthBreakdown has zero values', () {
      final b = provider.currentMonthBreakdown;
      expect(b.income, 0);
      expect(b.expenses, 0);
      expect(b.total, 0);
    });

    test('lastMonthBreakdown has zero values', () {
      final b = provider.lastMonthBreakdown;
      expect(b.income, 0);
      expect(b.expenses, 0);
      expect(b.total, 0);
    });

    test('clearError sets errorMessage to null', () {
      provider.clearError();
      expect(provider.errorMessage, isNull);
    });

    test('clearFilters resets search', () {
      provider.clearFilters();
      expect(provider.searchQuery, isEmpty);
    });

    test('setSearchQuery updates query', () {
      provider.setSearchQuery('food');
      expect(provider.searchQuery, 'food');
    });

    test('setSearchQuery with empty string resets', () {
      provider.setSearchQuery('test');
      provider.setSearchQuery('');
      expect(provider.searchQuery, isEmpty);
    });
  });
}
