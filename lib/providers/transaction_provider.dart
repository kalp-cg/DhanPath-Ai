import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../core/di/service_locator.dart';
import '../domain/usecases/get_all_transactions_usecase.dart';
import '../domain/usecases/add_transaction_usecase.dart';
import '../domain/usecases/delete_transaction_usecase.dart';
import '../domain/usecases/search_transactions_usecase.dart';
import '../services/database_helper.dart';
import '../core/parsers/bank_parser_factory.dart';
import '../core/utils/result.dart';
import '../services/sms_service.dart';

/// Monthly breakdown model matching Kotlin implementation
class MonthlyBreakdown {
  final double total;
  final double income;
  final double expenses;

  MonthlyBreakdown({
    required this.total,
    required this.income,
    required this.expenses,
  });
}

/// ViewModel for managing transaction state
/// Follows MVVM pattern similar to Kotlin's HomeViewModel
class TransactionProvider extends ChangeNotifier {
  // Use cases - injected via service locator
  final GetAllTransactionsUseCase _getAllTransactionsUseCase;
  final AddTransactionUseCase _addTransactionUseCase;
  final DeleteTransactionUseCase _deleteTransactionUseCase;
  final SearchTransactionsUseCase _searchTransactionsUseCase;

  List<Transaction> _transactions = [];
  List<Transaction> _filteredTransactions = [];
  bool _isLoading = false;
  bool _hasLoadedOnce = false;
  String _searchQuery = '';
  bool _isSearchActive = false;
  String? _errorMessage;

  // Cached breakdowns — invalidated on data change
  MonthlyBreakdown? _cachedCurrentMonthBreakdown;
  MonthlyBreakdown? _cachedLastMonthBreakdown;
  int _lastTransactionHash = 0;
  int _lastMonthTransactionHash = 0;

  TransactionProvider({
    GetAllTransactionsUseCase? getAllTransactionsUseCase,
    AddTransactionUseCase? addTransactionUseCase,
    DeleteTransactionUseCase? deleteTransactionUseCase,
    SearchTransactionsUseCase? searchTransactionsUseCase,
  }) : _getAllTransactionsUseCase =
           getAllTransactionsUseCase ??
           serviceLocator.getAllTransactionsUseCase,
       _addTransactionUseCase =
           addTransactionUseCase ?? serviceLocator.addTransactionUseCase,
       _deleteTransactionUseCase =
           deleteTransactionUseCase ?? serviceLocator.deleteTransactionUseCase,
       _searchTransactionsUseCase =
           searchTransactionsUseCase ??
           serviceLocator.searchTransactionsUseCase {
    SmsService.onTransactionUpdated.listen((_) {
      if (_hasLoadedOnce) {
        loadTransactions();
      }
    });
  }

  // Getters
  List<Transaction> get transactions =>
      _isSearchActive ? _filteredTransactions : _transactions;

  /// Returns ALL transactions regardless of search filter state.
  List<Transaction> get allTransactions => _transactions;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String? get errorMessage => _errorMessage;

  // Advanced getters matching Kotlin version
  double get totalIncome => _getEffectiveTransactions()
      .where((t) => t.type == TransactionType.income)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get totalExpense => _getEffectiveTransactions()
      .where((t) => t.type == TransactionType.expense)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get totalCredit => _getEffectiveTransactions()
      .where((t) => t.type == TransactionType.credit)
      .fold(0.0, (sum, t) => sum + t.amount);

  List<Transaction> get recurringTransactions =>
      _getEffectiveTransactions().where((t) {
        final body = (t.smsBody ?? '').toLowerCase();
        final merchant = t.merchantName.toLowerCase();
        return t.isRecurring ||
            merchant.contains('autopay') ||
            body.contains('mandate') ||
            body.contains('auto-debit') ||
            body.contains('subscription');
      }).toList();

  double get totalRecurring =>
      recurringTransactions.fold(0.0, (sum, t) => sum + t.amount);

  double get balance => totalIncome + totalCredit - totalExpense;

  /// Daily budget remaining: (monthly budget - month spending so far) / days left in month
  double get dailyBudgetLeft {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysLeft = daysInMonth - now.day + 1; // including today
    final monthBudget = currentMonthBreakdown.income; // income = budget proxy
    final monthSpent = currentMonthBreakdown.expenses;
    final remaining = monthBudget - monthSpent;
    if (remaining <= 0 || daysLeft <= 0) return 0;
    return remaining / daysLeft;
  }

  /// Today's total expenses
  double get todaySpent {
    return todayTransactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  /// How many consecutive days the user has had transactions
  int get streakDays {
    if (_transactions.isEmpty) return 0;
    final now = DateTime.now();
    final effective = _getEffectiveTransactions();
    // Build a Set of date-only strings for O(1) lookup
    final activeDays = <String>{};
    for (final t in effective) {
      activeDays.add('${t.date.year}-${t.date.month}-${t.date.day}');
    }
    int streak = 0;
    for (int i = 0; i < 365; i++) {
      final day = DateTime(now.year, now.month, now.day - i);
      final key = '${day.year}-${day.month}-${day.day}';
      if (activeDays.contains(key)) {
        streak++;
      } else if (i > 0) {
        break;
      }
    }
    return streak;
  }

  List<Transaction> get todayTransactions {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    return _getEffectiveTransactions().where((t) {
      return !t.date.isBefore(today) && t.date.isBefore(tomorrow);
    }).toList();
  }

  List<Transaction> get thisMonthTransactions {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    return _getEffectiveTransactions().where((t) {
      return !t.date.isBefore(monthStart) && t.date.isBefore(monthEnd);
    }).toList();
  }

  // Cached effective transactions — invalidated when data changes
  List<Transaction>? _cachedEffective;
  int _effectiveCacheKey = -1;

  // Get effective transactions (excluding deleted ones)
  List<Transaction> _getEffectiveTransactions() {
    final source = _isSearchActive ? _filteredTransactions : _transactions;
    final key =
        source.length.hashCode ^
        _isSearchActive.hashCode ^
        _lastTransactionHash;
    if (_cachedEffective != null && key == _effectiveCacheKey) {
      return _cachedEffective!;
    }
    _effectiveCacheKey = key;
    _cachedEffective = source.where((t) => !t.isDeleted).toList();
    return _cachedEffective!;
  }

  /// Calculate current month breakdown (cached, invalidated on data change)
  MonthlyBreakdown get currentMonthBreakdown {
    // Build a non-commutative hash that includes amount, type, date, and id
    final hash = _transactions.fold(
      17,
      (h, t) =>
          h * 31 + t.amount.hashCode ^
          t.type.hashCode ^
          t.date.hashCode ^
          (t.id ?? 0),
    );
    if (_cachedCurrentMonthBreakdown != null && hash == _lastTransactionHash) {
      return _cachedCurrentMonthBreakdown!;
    }
    _lastTransactionHash = hash;

    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, 1);
    final endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final monthTransactions = _getEffectiveTransactions().where((t) {
      return !t.date.isBefore(startDate) && t.date.isBefore(endDate);
    });

    final income = monthTransactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);

    final expenses = monthTransactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);

    _cachedCurrentMonthBreakdown = MonthlyBreakdown(
      total: income - expenses,
      income: income,
      expenses: expenses,
    );
    return _cachedCurrentMonthBreakdown!;
  }

  /// Calculate last month breakdown (cached, invalidated on data change)
  MonthlyBreakdown get lastMonthBreakdown {
    final hash = _transactions.fold(
      17,
      (h, t) =>
          h * 31 + t.amount.hashCode ^
          t.type.hashCode ^
          t.date.hashCode ^
          (t.id ?? 0),
    );
    if (_cachedLastMonthBreakdown != null &&
        hash == _lastMonthTransactionHash) {
      return _cachedLastMonthBreakdown!;
    }
    _lastMonthTransactionHash = hash;

    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    final dayOfMonth = now.day;
    final lastMonthMaxDay = dayOfMonth < lastMonth.day
        ? dayOfMonth
        : DateTime(lastMonth.year, lastMonth.month + 1, 0).day;

    final startDate = DateTime(lastMonth.year, lastMonth.month, 1);
    final endDate = DateTime(
      lastMonth.year,
      lastMonth.month,
      lastMonthMaxDay,
      23,
      59,
      59,
    );

    final monthTransactions = _getEffectiveTransactions().where((t) {
      return !t.date.isBefore(startDate) && t.date.isBefore(endDate);
    });

    final income = monthTransactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);

    final expenses = monthTransactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);

    _cachedLastMonthBreakdown = MonthlyBreakdown(
      total: income - expenses,
      income: income,
      expenses: expenses,
    );
    return _cachedLastMonthBreakdown!;
  }

  /// Load all transactions using use case.
  /// Shows loading spinner only on first load. Subsequent loads are silent.
  Future<void> loadTransactions() async {
    // Only show loading spinner on first load — no flicker on revisits
    if (!_hasLoadedOnce) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    final result = await _getAllTransactionsUseCase.call();

    result.fold(
      (failure) {
        _errorMessage = failure.message;
        debugPrint('Error: Error loading transactions: ${failure.message}');
      },
      (transactions) {
        _transactions = transactions;
        // Invalidate cached breakdowns
        _cachedCurrentMonthBreakdown = null;
        _cachedLastMonthBreakdown = null;
      },
    );

    _isLoading = false;
    _hasLoadedOnce = true;
    notifyListeners();
  }

  /// Add a new transaction using use case
  Future<bool> addTransaction(Transaction transaction) async {
    debugPrint(
      'Adding transaction: ${transaction.merchantName}, amount: ₹${transaction.amount}, type: ${transaction.type}',
    );

    final result = await _addTransactionUseCase.call(transaction);

    return result.fold(
      (failure) {
        _errorMessage = failure.message;
        debugPrint('Error: Error adding transaction: ${failure.message}');
        notifyListeners();
        return false;
      },
      (id) async {
        debugPrint('Transaction added with ID: $id');
        // Clear filters when adding to show all transactions including new one
        _filteredTransactions = [];
        _searchQuery = '';
        _isSearchActive = false;
        await loadTransactions();
        debugPrint('Total transactions after add: ${_transactions.length}');
        return true;
      },
    );
  }

  /// Delete a transaction using use case
  Future<bool> deleteTransaction(int id, {bool permanent = false}) async {
    // Clear filters when deleting to show updated list
    _filteredTransactions = [];
    _searchQuery = '';
    _isSearchActive = false;

    final result = await _deleteTransactionUseCase.call(
      DeleteTransactionParams(transactionId: id, permanent: permanent),
    );

    return result.fold(
      (failure) {
        _errorMessage = failure.message;
        debugPrint('Error deleting transaction: ${failure.message}');
        notifyListeners();
        return false;
      },
      (_) async {
        await loadTransactions();
        return true;
      },
    );
  }

  /// Update an existing transaction
  Future<void> updateTransaction(Transaction transaction) async {
    try {
      await DatabaseHelper.instance.update(transaction);
      await loadTransactions();
    } catch (e) {
      _errorMessage = 'Error updating transaction: $e';
      debugPrint(_errorMessage);
      notifyListeners();
    }
  }

  /// Soft delete a transaction
  Future<void> softDeleteTransaction(int id) async {
    await deleteTransaction(id, permanent: false);
  }

  /// Clear all transactions
  Future<void> clearAllTransactions() async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete('transactions');
      _transactions = [];
      _filteredTransactions = [];
      notifyListeners();
      debugPrint('All transactions cleared');
    } catch (e) {
      _errorMessage = 'Error clearing all transactions: $e';
      debugPrint(_errorMessage);
      notifyListeners();
      rethrow;
    }
  }

  /// Parse and import SMS messages using the canonical BankParserFactory
  Future<void> parseAndImportSMS(List<Map<String, dynamic>> smsMessages) async {
    _isLoading = true;
    notifyListeners();

    try {
      int importedCount = 0;

      for (var sms in smsMessages) {
        final sender = sms['sender'] ?? '';
        final body = sms['body'] ?? '';
        final timestamp =
            sms['timestamp'] ?? DateTime.now().millisecondsSinceEpoch;

        final parsed = BankParserFactory.parseTransaction(
          body,
          sender,
          timestamp,
        );
        if (parsed != null) {
          await addTransaction(parsed.toTransaction());
          importedCount++;
        } else {
          await DatabaseHelper.instance.insertUnrecognizedSms({
            'sender': sender,
            'body': body,
            'reason': 'Unrecognized by BankParserFactory',
            'received_at': DateTime.fromMillisecondsSinceEpoch(
              timestamp,
            ).toIso8601String(),
            'is_processed': 0,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }

      debugPrint('Imported $importedCount transactions');
    } catch (e) {
      _errorMessage = 'Error importing SMS: $e';
      debugPrint(_errorMessage);
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Search transactions using use case
  Future<void> search(String query) async {
    _searchQuery = query;
    _isLoading = true;
    notifyListeners();

    final result = await _searchTransactionsUseCase.call(
      SearchTransactionsParams(query),
    );

    result.fold(
      (failure) {
        _errorMessage = failure.message;
        _filteredTransactions = [];
        debugPrint('Error searching transactions: ${failure.message}');
      },
      (transactions) {
        if (query.isEmpty) {
          _filteredTransactions = [];
          _isSearchActive = false;
        } else {
          _filteredTransactions = transactions;
          _isSearchActive = true;
        }
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFilters();
  }

  void clearFilters() {
    _searchQuery = '';
    _isSearchActive = false;
    _filteredTransactions = [];
    notifyListeners();
  }

  void _applyFilters() {
    if (_searchQuery.isEmpty) {
      _filteredTransactions = [];
      _isSearchActive = false;
    } else {
      _isSearchActive = true;
      _filteredTransactions = _transactions.where((transaction) {
        final query = _searchQuery.toLowerCase();
        return transaction.merchantName.toLowerCase().contains(query) ||
            transaction.category.toLowerCase().contains(query) ||
            (transaction.bankName ?? '').toLowerCase().contains(query) ||
            (transaction.description ?? '').toLowerCase().contains(query);
      }).toList();
    }
    notifyListeners();
  }

  List<String> get categories {
    final categorySet = <String>{};
    for (var transaction in _transactions) {
      categorySet.add(transaction.category);
    }
    final categoryList = categorySet.toList();
    categoryList.sort();
    return categoryList;
  }

  List<String> get banks {
    final bankSet = <String>{};
    for (var transaction in _transactions) {
      if (transaction.bankName != null) {
        bankSet.add(transaction.bankName!);
      }
    }
    final bankList = bankSet.toList();
    bankList.sort();
    return bankList;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
