import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import 'notification_service.dart';

class BudgetService {
  final dbHelper = DatabaseHelper.instance;

  Future<void> setBudget(String category, double amount, String month) async {
    final db = await dbHelper.database;
    final now = DateTime.now().toIso8601String();

    // Check if budget exists for this category and month
    final existing = await db.query(
      'budgets',
      where: 'category = ? AND month = ?',
      whereArgs: [category, month],
    );

    if (existing.isNotEmpty) {
      await db.update(
        'budgets',
        {'amount': amount, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    } else {
      await db.insert('budgets', {
        'category': category,
        'amount': amount,
        'month': month,
        'spent': 0.0, // Initial spent is 0, will be calculated
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  Future<List<Map<String, dynamic>>> getBudgetsForMonth(String month) async {
    final db = await dbHelper.database;
    final prefs = await SharedPreferences.getInstance();
    final rolloverEnabled = prefs.getBool('budget_rollover') ?? false;

    // Get all budgets for the month
    final budgets = await db.query(
      'budgets',
      where: 'month = ?',
      whereArgs: [month],
    );

    List<Map<String, dynamic>> result = [];

    for (var budget in budgets) {
      final category = budget['category'] as String;
      final spending = await _calculateSpending(category, month);
      double budgetAmount = (budget['amount'] as num).toDouble();

      // Apply rollover from previous month if enabled
      if (rolloverEnabled) {
        final rollover = await _calculateRollover(category, month);
        budgetAmount += rollover;
      }

      final Map<String, dynamic> budgetMap = Map.from(budget);
      budgetMap['spent'] = spending;
      budgetMap['effective_amount'] = budgetAmount; // Budget + rollover
      result.add(budgetMap);
    }

    return result;
  }

  /// Calculate rollover from the previous month
  Future<double> _calculateRollover(
    String category,
    String currentMonth,
  ) async {
    final db = await dbHelper.database;

    // Parse current month to get previous month
    final parts = currentMonth.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);

    final prevDate = DateTime(year, month - 1, 1);
    final prevMonth =
        '${prevDate.year}-${prevDate.month.toString().padLeft(2, '0')}';

    // Get previous month's budget
    final prevBudgets = await db.query(
      'budgets',
      where: 'category = ? AND month = ?',
      whereArgs: [category, prevMonth],
    );

    if (prevBudgets.isEmpty) return 0.0;

    final prevBudgetAmount = (prevBudgets.first['amount'] as num).toDouble();
    final prevSpent = await _calculateSpending(category, prevMonth);

    // Rollover is unspent amount (positive) or 0 if overspent
    final rollover = prevBudgetAmount - prevSpent;
    return rollover > 0 ? rollover : 0.0;
  }

  Future<double> _calculateSpending(String category, String month) async {
    final db = await dbHelper.database;

    final startOfMonth = DateTime.parse('$month-01');
    final endOfMonth = DateTime(
      startOfMonth.year,
      startOfMonth.month + 1,
      0,
      23,
      59,
      59,
    );

    final result = await db.rawQuery(
      '''
      SELECT SUM(amount) as total 
      FROM transactions 
      WHERE category = ? 
      AND type = 'expense' 
      AND date BETWEEN ? AND ?
      AND is_deleted = 0
    ''',
      [category, startOfMonth.toIso8601String(), endOfMonth.toIso8601String()],
    );

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<Map<String, double>> getTotalBudgetVsSpending(String month) async {
    final budgets = await getBudgetsForMonth(month);
    double totalBudget = 0;
    double totalSpent = 0;

    for (var b in budgets) {
      totalBudget += (b['effective_amount'] ?? b['amount'] as num).toDouble();
      totalSpent += (b['spent'] as num).toDouble();
    }
    return {'budget': totalBudget, 'spent': totalSpent};
  }

  Future<void> deleteBudget(int id) async {
    final db = await dbHelper.database;
    await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }

  /// Check all budgets and send alerts if spending exceeds threshold
  /// Includes deduplication to prevent multiple alerts per category per day
  Future<void> checkBudgetAlerts(String month) async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled = prefs.getBool('budget_notifications') ?? true;

    if (!notificationsEnabled) return;

    final alertThreshold = prefs.getDouble('budget_alert_threshold') ?? 0.8;
    final budgets = await getBudgetsForMonth(month);
    final today = DateTime.now().toIso8601String().substring(
      0,
      10,
    ); // YYYY-MM-DD

    for (var budget in budgets) {
      final category = budget['category'] as String;
      final spent = (budget['spent'] as num).toDouble();
      final amount = (budget['effective_amount'] ?? budget['amount'] as num)
          .toDouble();

      if (amount > 0) {
        final usagePercent = spent / amount;

        // Alert if spending exceeds threshold
        if (usagePercent >= alertThreshold) {
          // Check if we already sent an alert for this category today
          final lastAlertKey = 'budget_alert_${category}_date';
          final lastAlertDate = prefs.getString(lastAlertKey);

          if (lastAlertDate == today) {
            // Already sent alert today for this category, skip
            continue;
          }

          // Send alert and record the date
          await NotificationService().showBudgetAlert(
            category: category,
            spent: spent,
            budget: amount,
            thresholdPercent: alertThreshold * 100,
          );

          // Save today's date to prevent duplicate alerts
          await prefs.setString(lastAlertKey, today);
        }
      }
    }
  }
}
