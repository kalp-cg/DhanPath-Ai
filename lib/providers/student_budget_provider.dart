import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../models/transaction_model.dart';

/// Tracks student monthly budget with per-category spending
class StudentBudgetProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  double _monthlyBudget = 0;
  double _totalSpent = 0;
  Map<String, double> _categorySpending = {};
  Map<String, double> _categoryBudgets = {};
  List<Transaction> _recentTransactions = [];
  bool _isLoading = false;
  String? _errorMessage;

  // ── Getters ──
  double get monthlyBudget => _monthlyBudget;
  double get totalSpent => _totalSpent;
  double get remaining => _monthlyBudget - _totalSpent;
  double get spentPercent =>
      _monthlyBudget > 0 ? (_totalSpent / _monthlyBudget).clamp(0, 1) : 0;
  Map<String, double> get categorySpending =>
      Map.unmodifiable(_categorySpending);
  Map<String, double> get categoryBudgets => Map.unmodifiable(_categoryBudgets);
  List<Transaction> get recentTransactions =>
      List.unmodifiable(_recentTransactions);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isOverBudget => _totalSpent > _monthlyBudget && _monthlyBudget > 0;

  /// Daily average spending this month
  double get dailyAverage {
    final now = DateTime.now();
    final dayOfMonth = now.day;
    return dayOfMonth > 0 ? _totalSpent / dayOfMonth : 0;
  }

  /// Suggested daily spend to stay on budget for the rest of the month
  double get suggestedDailySpend {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysLeft = daysInMonth - now.day;
    if (daysLeft <= 0) return 0;
    final left = remaining;
    return left > 0 ? left / daysLeft : 0;
  }

  /// Highest spending category
  String get topCategory {
    if (_categorySpending.isEmpty) return 'None';
    final sorted = _categorySpending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  /// Load data for the current month
  Future<void> loadCurrentMonth() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, 1);
      final endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      final db = await _db.database;

      // Load monthly budget from shared prefs or budgets table
      final budgetResult = await db.rawQuery(
        "SELECT SUM(amount) as total FROM budgets WHERE month = ?",
        ['${now.year}-${now.month.toString().padLeft(2, '0')}'],
      );
      _monthlyBudget = (budgetResult.first['total'] as num?)?.toDouble() ?? 0.0;

      // Load transactions for this month
      final txResults = await db.query(
        'transactions',
        where: "type = 'expense' AND is_deleted = 0 AND date BETWEEN ? AND ?",
        whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
        orderBy: 'date DESC',
      );

      _totalSpent = 0;
      _categorySpending = {};
      _recentTransactions = [];

      for (var row in txResults) {
        final tx = Transaction.fromMap(row);
        _totalSpent += tx.amount;
        _categorySpending[tx.category] =
            (_categorySpending[tx.category] ?? 0) + tx.amount;
        if (_recentTransactions.length < 10) {
          _recentTransactions.add(tx);
        }
      }

      // Load per-category budgets
      final catBudgets = await db.query(
        'budgets',
        where: "month = ?",
        whereArgs: ['${now.year}-${now.month.toString().padLeft(2, '0')}'],
      );
      _categoryBudgets = {};
      for (var b in catBudgets) {
        _categoryBudgets[b['category'] as String] = (b['amount'] as num)
            .toDouble();
      }
    } catch (e) {
      _errorMessage = 'Failed to load budget data: $e';
      debugPrint(_errorMessage);
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Set or update overall monthly budget
  Future<void> setMonthlyBudget(double amount) async {
    _monthlyBudget = amount;
    notifyListeners();
  }

  /// Set budget for a specific category
  Future<void> setCategoryBudget(String category, double amount) async {
    try {
      final db = await _db.database;
      final now = DateTime.now();
      final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final timestamp = now.toIso8601String();

      final existing = await db.query(
        'budgets',
        where: 'category = ? AND month = ?',
        whereArgs: [category, month],
      );

      if (existing.isNotEmpty) {
        await db.update(
          'budgets',
          {'amount': amount, 'updated_at': timestamp},
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
      } else {
        await db.insert('budgets', {
          'category': category,
          'amount': amount,
          'month': month,
          'spent': 0.0,
          'created_at': timestamp,
          'updated_at': timestamp,
        });
      }

      _categoryBudgets[category] = amount;
      _monthlyBudget = _categoryBudgets.values.fold(0, (sum, v) => sum + v);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to set budget: $e';
      notifyListeners();
    }
  }

  /// Get categories where spending exceeds budget
  List<MapEntry<String, double>> get overBudgetCategories {
    return _categorySpending.entries.where((entry) {
      final budget = _categoryBudgets[entry.key];
      return budget != null && entry.value > budget;
    }).toList();
  }

  /// Get weekly spending for the current month (for chart)
  Future<List<double>> getWeeklySpending() async {
    try {
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, 1);
      final db = await _db.database;

      List<double> weekly = [0, 0, 0, 0, 0]; // Up to 5 weeks

      final results = await db.query(
        'transactions',
        where: "type = 'expense' AND is_deleted = 0 AND date >= ?",
        whereArgs: [startDate.toIso8601String()],
      );

      for (var row in results) {
        final date = DateTime.parse(row['date'] as String);
        final weekIndex = ((date.day - 1) / 7).floor().clamp(0, 4);
        weekly[weekIndex] += (row['amount'] as num).toDouble();
      }

      return weekly;
    } catch (e) {
      return [0, 0, 0, 0, 0];
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
