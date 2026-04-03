import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'notification_service.dart';
import 'database_helper.dart';

/// -------------------------------------------------------------------
/// SmartNotificationEngine
///
/// Runs a set of heuristic checks against the user's transaction data
/// and fires contextual, useful notifications.  Should be called once
/// per app-open (and after each new transaction is added).
///
/// ── TRIGGER ALGORITHM ──
///
///  1. NEW TRANSACTION ALERT
///     → Immediately after an SMS is parsed into a transaction.
///     → Shows: amount, merchant, category, bank.
///
///  2. LARGE EXPENSE ALERT
///     → If a single expense > user-configured threshold (default ₹5000).
///
///  3. BUDGET THRESHOLD ALERT
///     → When spending in a category crosses 80 % or 100 % of budget.
///     → De-duplicated: max 1 alert per category per day.
///
///  4. DAILY REMINDER
///     → Scheduled at 8 PM (configurable): "Log your expenses today".
///     → Only fires if user hasn't opened the app that day.
///
///  5. WEEKLY SUMMARY
///     → Every Sunday 10 AM: "Tap to see your weekly insights".
///
///  6. SPENDING STREAK
///     → 3 / 7 / 14 / 30 consecutive days of logging → congratulations.
///
///  7. UNUSUAL SPENDING (spike detection)
///     → If today's total is > 2× daily average of last 30 days.
///
///  8. RECURRING PAYMENT REMINDER
///     → If a known recurring merchant is due in the next 2 days.
///
///  9. NO-SPEND DAY CELEBRATION
///     → If the user had zero expenses yesterday → positive reinforcement.
///
/// Each trigger has its own SharedPreferences guard to avoid spam.
/// -------------------------------------------------------------------
class SmartNotificationEngine {
  final _notif = NotificationService();
  final _db = DatabaseHelper.instance;

  /// Run all smart checks.  Call from main.dart on app start
  /// and after every new transaction.
  Future<void> runAllChecks() async {
    try {
      await Future.wait([
        _checkUnusualSpending(),
        _checkStreak(),
        _checkNoSpendDay(),
        _checkRecurringReminder(),
        _checkUpcomingBills(),
        _checkEMI(),
        _checkUnsettledSplitBills(),
      ]);
      // Reset the 3-day inactivity nudge every time they interact with the app
      await _notif.scheduleInactivityNudge();
    } catch (e) {
      debugPrint('SmartNotificationEngine error: $e');
    }
  }

  // ── 1. New transaction alert (called explicitly by SMS handler) ──
  Future<void> onNewTransaction({
    required double amount,
    required String merchant,
    required String type,
    required String category,
    String? bankName,
  }) async {
    // Show immediate notification
    await _notif.showTransactionNotification(
      amount: amount,
      merchant: merchant,
      type: type,
      category: category,
      bankName: bankName,
    );

    // Check if this is a large expense
    final prefs = await SharedPreferences.getInstance();
    final threshold = prefs.getDouble('large_expense_threshold') ?? 5000.0;
    if (type == 'expense' && amount >= threshold) {
      await _notif.showLargeExpenseAlert(
        amount: amount,
        merchant: merchant,
        threshold: threshold,
      );
    }

    // Re-run smart checks after each new transaction
    await runAllChecks();
  }

  // ── 7. UNUSUAL SPENDING (spike detection) ──
  Future<void> _checkUnusualSpending() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Only check once per day
    if (prefs.getString('_spike_check_date') == today) return;

    final db = await _db.database;

    // Get today's total spending
    final todayResult = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total FROM transactions
      WHERE type = 'expense' AND is_deleted = 0
        AND date(date) = date('now')
    ''');
    final todayTotal = (todayResult.first['total'] as num?)?.toDouble() ?? 0;

    if (todayTotal == 0) return;

    // Get average daily spending for last 30 days
    final avgResult = await db.rawQuery('''
      SELECT COALESCE(AVG(daily_total), 0) as avg_daily FROM (
        SELECT SUM(amount) as daily_total FROM transactions
        WHERE type = 'expense' AND is_deleted = 0
          AND date >= date('now', '-30 days')
          AND date < date('now')
        GROUP BY date(date)
      )
    ''');
    final avgDaily = (avgResult.first['avg_daily'] as num?)?.toDouble() ?? 0;

    // If today > 2× average → spike alert
    if (avgDaily > 0 && todayTotal > avgDaily * 2) {
      await _notif.showSmartTip(
        title: 'Spending Spike Detected',
        body:
            'You\'ve spent ₹${todayTotal.toStringAsFixed(0)} today — that\'s ${(todayTotal / avgDaily).toStringAsFixed(1)}× your daily average of ₹${avgDaily.toStringAsFixed(0)}.',
        payload: 'screen:analytics',
      );
      await prefs.setString('_spike_check_date', today);
    }
  }

  // ── 6. STREAK ──
  Future<void> _checkStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (prefs.getString('_streak_check_date') == today) return;

    final db = await _db.database;

    // Single query: get all distinct days with transactions in last 365 days
    final result = await db.rawQuery('''
      SELECT DISTINCT date(date) as txn_date FROM transactions
      WHERE is_deleted = 0 AND date >= date('now', '-365 days')
      ORDER BY txn_date DESC
    ''');

    final activeDays = result
        .map((r) => r['txn_date'] as String?)
        .where((d) => d != null)
        .toSet();

    // Count consecutive days backwards from today
    int streak = 0;
    var checkDate = DateTime.now();
    for (int i = 0; i < 365; i++) {
      final dateStr = DateFormat('yyyy-MM-dd').format(checkDate);
      if (activeDays.contains(dateStr)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    // Notify on milestone streaks
    const milestones = [3, 7, 14, 30, 60, 100, 365];
    if (milestones.contains(streak)) {
      final lastNotifiedStreak = prefs.getInt('_last_streak_notified') ?? 0;
      if (streak > lastNotifiedStreak) {
        await _notif.showStreakNotification(days: streak);
        await prefs.setInt('_last_streak_notified', streak);
      }
    }

    await prefs.setString('_streak_check_date', today);
  }

  // ── 9. NO-SPEND DAY CELEBRATION ──
  Future<void> _checkNoSpendDay() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (prefs.getString('_nospend_check_date') == today) return;

    final db = await _db.database;

    // Check if yesterday had zero expenses
    final result = await db.rawQuery('''
      SELECT COUNT(*) as cnt FROM transactions
      WHERE type = 'expense' AND is_deleted = 0
        AND date(date) = date('now', '-1 day')
    ''');
    final count = (result.first['cnt'] as num?)?.toInt() ?? 0;

    if (count == 0) {
      // Make sure the user actually has some history (not a new user)
      final total = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM transactions WHERE is_deleted = 0',
      );
      final totalCount = (total.first['cnt'] as num?)?.toInt() ?? 0;

      if (totalCount > 5) {
        await _notif.showSmartTip(
          title: 'No-Spend Day!',
          body:
              'You didn\'t spend anything yesterday — nice discipline! Every saved rupee counts.',
          payload: 'tip:nospend',
        );
      }
    }

    await prefs.setString('_nospend_check_date', today);
  }

  // ── 8. RECURRING PAYMENT REMINDER ──
  Future<void> _checkRecurringReminder() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (prefs.getString('_recurring_check_date') == today) return;

    final db = await _db.database;

    // Find merchants that appear in the same day-of-month range (±2 days)
    // across at least 2 months
    final dayOfMonth = DateTime.now().day;
    final twoDaysLater = dayOfMonth + 2;

    final result = await db.rawQuery(
      '''
      SELECT merchant_name, AVG(amount) as avg_amount, COUNT(*) as cnt
      FROM transactions
      WHERE type = 'expense' AND is_deleted = 0 AND is_recurring = 1
        AND CAST(strftime('%d', date) AS INTEGER) BETWEEN ? AND ?
      GROUP BY merchant_name
      HAVING cnt >= 2
    ''',
      [dayOfMonth, twoDaysLater],
    );

    for (var row in result) {
      final merchant = row['merchant_name'] as String;
      final avgAmount = (row['avg_amount'] as num).toDouble();

      // Check if we already notified for this merchant this month
      final key =
          '_recurring_${merchant}_${DateFormat('yyyy-MM').format(DateTime.now())}';
      if (prefs.getBool(key) == true) continue;

      await _notif.showSmartTip(
        title: 'Upcoming: $merchant',
        body:
            'You usually pay ~₹${avgAmount.toStringAsFixed(0)} to $merchant around this time.',
        payload: 'recurring:$merchant',
      );

      await prefs.setBool(key, true);
    }

    await prefs.setString('_recurring_check_date', today);
  }

  // ── 10. UPCOMING BILLS ──
  Future<void> _checkUpcomingBills() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (prefs.getString('_upcoming_bills_check_date') == today) return;

    final db = await _db.database;
    final now = DateTime.now();
    // Check next 3 days
    final limitDate = now.add(const Duration(days: 3)).toIso8601String();

    final result = await db.rawQuery('''
      SELECT * FROM bill_reminders
      WHERE is_active = 1 AND status != 'paid' AND next_due_date <= ?
    ''', [limitDate]);

    for (var row in result) {
      final billName = row['bill_name'] as String;
      final amount = (row['amount'] as num).toDouble();
      
      final key = '_bill_notified_${row['id']}_$today';
      if (prefs.getBool(key) == true) continue;

      await _notif.showActionableReminder(
        title: 'Bill Reminder: $billName',
        body: '₹${amount.toStringAsFixed(0)} is due soon. Make sure to pay on time to avoid late fees!',
        payload: 'bill_${row['id']}',
      );
      await prefs.setBool(key, true);
    }
    await prefs.setString('_upcoming_bills_check_date', today);
  }

  // ── 11. EMI REMINDERS ──
  Future<void> _checkEMI() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (prefs.getString('_emi_check_date') == today) return;

    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT * FROM emis
      WHERE is_active = 1 AND paid_months < tenure_months
    ''');

    final currentDay = DateTime.now().day;
    for (var row in result) {
      final lenderName = row['lender_name'] as String;
      final emiAmount = (row['emi_amount'] as num).toDouble();
      final startDateStr = row['start_date'] as String;
      
      try {
        final startDate = DateTime.parse(startDateStr);
        final emiDay = startDate.day;

        // If EMI is due in next 3 days
        if ((emiDay - currentDay >= 0 && emiDay - currentDay <= 3) || 
            (currentDay > 25 && emiDay <= 3)) { // End of month check
          
          final key = '_emi_notified_${row['id']}_${DateTime.now().month}_${DateTime.now().year}';
          if (prefs.getBool(key) == true) continue;

          await _notif.showActionableReminder(
            title: 'EMI Alert: $lenderName',
            body: 'Your EMI of ₹${emiAmount.toStringAsFixed(0)} is coming up soon.',
            payload: 'emi_${row['id']}',
          );
          await prefs.setBool(key, true);
        }
      } catch (e) {
        continue;
      }
    }
    await prefs.setString('_emi_check_date', today);
  }

  // ── 12. UNSETTLED SPLIT BILLS ──
  Future<void> _checkUnsettledSplitBills() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    // Only remind once a week for split bills to avoid nagging
    if (prefs.getString('_split_bills_check_date') == today) return;
    if (DateTime.now().weekday != DateTime.friday) return; 

    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as cnt, SUM(total_amount) as total FROM split_bills
      WHERE status != 'settled'
    ''');

    final count = (result.first['cnt'] as num?)?.toInt() ?? 0;
    if (count > 0) {
      final total = (result.first['total'] as num?)?.toDouble() ?? 0.0;
      await _notif.showSmartTip(
        title: 'Unsettled Split Bills',
        body: 'You have $count unsettled split bills. Time to settle up!',
        payload: 'screen:split_bills',
      );
    }
    await prefs.setString('_split_bills_check_date', today);
  }

  // ── Schedule all recurring notifications ──
  Future<void> scheduleRecurringNotifications() async {
    final prefs = await SharedPreferences.getInstance();

    // Daily reminder
    if (prefs.getBool('notify_daily_reminder') ?? true) {
      final hour = prefs.getInt('daily_reminder_hour') ?? 20;
      final minute = prefs.getInt('daily_reminder_minute') ?? 0;
      await _notif.scheduleDailyReminder(hour: hour, minute: minute);
    }

    // Weekly summary
    if (prefs.getBool('notify_weekly_summary') ?? true) {
      await _notif.scheduleWeeklySummary();
    }
  }
}
