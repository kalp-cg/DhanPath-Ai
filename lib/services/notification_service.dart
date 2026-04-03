import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'notification_content.dart';
import 'actionable_notification_handler.dart';

/// -------------------------------------------------------------------
/// NotificationService — Singleton that handles ALL local + scheduled
/// notifications.  Every notification pops as a heads-up banner at the
/// top of the screen with sound on Android (HIGH importance channel).
/// -------------------------------------------------------------------

class NotificationService {
  // ── singleton ──
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  // ── Notification ID ranges ──
  static const int _idTransaction = 1000;
  static const int _idBudgetAlert = 2000;
  static const int _idDailyReminder = 3000;
  static const int _idWeeklySummary = 3001;
  static const int _idStreak = 4000;
  static const int _idSmartTip = 5000;
  static const int _idLargeExpense = 6000;

  // ── Channel ids ──
  static const String channelTransaction = 'transaction_alerts_v2';
  static const String channelBudget = 'budget_alerts_v2';
  static const String channelReminder = 'daily_reminders_v2';
  static const String channelInsights = 'smart_insights_v2';

  // ────────────────────────────────────────────
  //  INIT
  // ────────────────────────────────────────────

  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      onDidReceiveNotificationResponse: notificationTapBackground,
    );

    // Create notification channels (Android 8.0+)
    await _createChannels();

    _isInitialized = true;
    debugPrint('FlutterLocalNotifications initialized');
  }

  Future<void> _createChannels() async {
    const channels = [
      AndroidNotificationChannel(
        channelTransaction,
        'Transaction Alerts',
        description: 'New transaction detected from SMS',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
      AndroidNotificationChannel(
        channelBudget,
        'Budget Alerts',
        description: 'Budget spending alerts',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
      AndroidNotificationChannel(
        channelReminder,
        'Daily Reminders',
        description: 'Daily expense logging reminders',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
      AndroidNotificationChannel(
        channelInsights,
        'Smart Insights',
        description: 'Spending tips & weekly summaries',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    ];

    for (final channel in channels) {
      await _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
    }
  }

  // ────────────────────────────────────────────
  //  1. TRANSACTION NOTIFICATION
  //  Shown immediately when a new SMS transaction is parsed.
  // ────────────────────────────────────────────
  Future<void> showTransactionNotification({
    required double amount,
    required String merchant,
    required String type, // "expense" | "income" | "transfer"
    required String category,
    String? bankName,
  }) async {
    if (!await _isEnabled('notify_transactions')) return;
    await _ensureInit();

    final label = type == 'income'
        ? 'Received'
        : type == 'transfer'
        ? 'Transfer'
        : 'Spent';
    final verb = type == 'income'
        ? 'received'
        : type == 'transfer'
        ? 'transferred'
        : 'spent';
    final bank = bankName != null ? ' via $bankName' : '';

    await _notifications.show(
      _idTransaction + DateTime.now().millisecondsSinceEpoch % 999,
      '$label: \u20B9${amount.toStringAsFixed(0)} $verb',
      '$merchant ($category)$bank',
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelTransaction,
          'Transaction Alerts',
          channelDescription: 'New transaction detected from SMS',
          importance: Importance.max,
          priority: Priority.max,
          ticker: 'ticker',
          playSound: true,
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  // ────────────────────────────────────────────
  //  2. BUDGET ALERT
  //  Fires when spending crosses 80% / 100% of budget.
  // ────────────────────────────────────────────
  Future<void> showBudgetAlert({
    required String category,
    required double spent,
    required double budget,
    required double thresholdPercent,
  }) async {
    if (!await _isEnabled('notify_budget')) return;
    await _ensureInit();

    final pct = ((spent / budget) * 100).toStringAsFixed(0);
    final isOver = spent >= budget;
    final title = isOver
        ? 'Budget Exceeded: $category'
        : 'Budget Alert: $category';
    final body = isOver
        ? 'You\'ve spent ₹${spent.toStringAsFixed(0)} — ₹${(spent - budget).toStringAsFixed(0)} OVER your ₹${budget.toStringAsFixed(0)} budget!'
        : 'You\'ve used $pct% (₹${spent.toStringAsFixed(0)}) of your ₹${budget.toStringAsFixed(0)} budget.';

    await _notifications.show(
      _idBudgetAlert + category.hashCode % 999,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelBudget,
          'Budget Alerts',
          channelDescription: 'Budget spending alerts',
          importance: Importance.max,
          priority: Priority.max,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  // ────────────────────────────────────────────
  //  3. DAILY REMINDER  (scheduled)
  //  "Don't forget to log your expenses today!"
  //  Fires every day at the chosen hour.
  // ────────────────────────────────────────────
  Future<void> scheduleDailyReminder({int hour = 20, int minute = 0}) async {
    if (!await _isEnabled('notify_daily_reminder')) return;
    await _ensureInit();

    final scheduledDate = _nextInstanceOfTime(hour, minute);
    final content = NotificationContent.getDailyReminder();

    await _notifications.zonedSchedule(
      _idDailyReminder,
      content['title'],
      content['body'],
      scheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelReminder,
          'Daily Reminders',
          channelDescription: 'Daily expense logging reminders',
          importance: Importance.max,
          priority: Priority.max,
          styleInformation: BigTextStyleInformation(content['body'] ?? ''),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    debugPrint(
      'Daily reminder scheduled at $hour:${minute.toString().padLeft(2, '0')}',
    );
  }

  Future<void> cancelDailyReminder() async {
    await _notifications.cancel(_idDailyReminder);
  }

  // ────────────────────────────────────────────
  //  4. WEEKLY SUMMARY (scheduled)
  //  "This week you spent ₹X across Y transactions."
  //  Fires every Sunday at 10 AM.
  // ────────────────────────────────────────────
  Future<void> scheduleWeeklySummary() async {
    if (!await _isEnabled('notify_weekly_summary')) return;
    await _ensureInit();

    final scheduledDate = _nextInstanceOfWeekday(DateTime.sunday, 10, 0);
    final content = NotificationContent.getWeeklySummary();

    await _notifications.zonedSchedule(
      _idWeeklySummary,
      content['title'],
      content['body'],
      scheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelInsights,
          'Smart Insights',
          channelDescription: 'Spending tips & weekly summaries',
          importance: Importance.max,
          priority: Priority.max,
          styleInformation: BigTextStyleInformation(content['body'] ?? ''),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );

    debugPrint('Weekly summary scheduled for Sundays 10:00 AM');
  }

  Future<void> cancelWeeklySummary() async {
    await _notifications.cancel(_idWeeklySummary);
  }

  // ────────────────────────────────────────────
  //  5. LARGE EXPENSE ALERT
  //  Fires when a single transaction exceeds the
  //  user's configured threshold.
  // ────────────────────────────────────────────
  Future<void> showLargeExpenseAlert({
    required double amount,
    required String merchant,
    required double threshold,
  }) async {
    if (!await _isEnabled('notify_large_expense')) return;
    await _ensureInit();

    await _notifications.show(
      _idLargeExpense + DateTime.now().millisecondsSinceEpoch % 999,
      'Large Expense: \u20B9${amount.toStringAsFixed(0)}',
      '$merchant — this is above your ₹${threshold.toStringAsFixed(0)} alert threshold.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelBudget,
          'Budget Alerts',
          channelDescription: 'Budget spending alerts',
          importance: Importance.max,
          priority: Priority.max,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  // ────────────────────────────────────────────
  //  6. SMART SPENDING TIP
  //  Called by the smart triggers engine with
  //  intelligent, context-aware messages.
  // ────────────────────────────────────────────
  Future<void> showSmartTip({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!await _isEnabled('notify_smart_tips')) return;
    await _ensureInit();

    await _notifications.show(
      _idSmartTip + DateTime.now().millisecondsSinceEpoch % 999,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelInsights,
          'Smart Insights',
          channelDescription: 'Spending tips & weekly summaries',
          importance: Importance.max,
          priority: Priority.max,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  // ────────────────────────────────────────────
  //  7. STREAK NOTIFICATION
  //  Encourages the user to keep logging.
  // ────────────────────────────────────────────
  Future<void> showStreakNotification({required int days}) async {
    if (!await _isEnabled('notify_smart_tips')) return;
    await _ensureInit();

    await _notifications.show(
      _idStreak,
      '$days-Day Streak!',
      'You\'ve been tracking expenses for $days days straight. Keep it up!',
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelInsights,
          'Smart Insights',
          channelDescription: 'Spending tips & weekly summaries',
          importance: Importance.max,
          priority: Priority.max,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  // ────────────────────────────────────────────
  //  8. GENERAL NOTIFICATION  (catch-all)
  // ────────────────────────────────────────────
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _ensureInit();

    await _notifications.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelInsights,
          'Smart Insights',
          channelDescription: 'Spending tips & weekly summaries',
          importance: Importance.max,
          priority: Priority.max,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  // ────────────────────────────────────────────
  //  CANCEL helpers
  // ───────────────────────────────────────────-
  Future<void> cancelNotification(int id) async => _notifications.cancel(id);
  Future<void> cancelAllNotifications() async => _notifications.cancelAll();

  // ────────────────────────────────────────────
  //  SCHEDULE helpers  (used by daily / weekly)
  // ────────────────────────────────────────────
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  tz.TZDateTime _nextInstanceOfWeekday(int weekday, int hour, int minute) {
    var scheduled = _nextInstanceOfTime(hour, minute);
    while (scheduled.weekday != weekday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  // ────────────────────────────────────────────
  //  PREFERENCE helpers
  // ────────────────────────────────────────────
  Future<bool> _isEnabled(String key) async {
    final prefs = await SharedPreferences.getInstance();
    // Master kill-switch
    if (!(prefs.getBool('notifications_enabled') ?? true)) return false;
    return prefs.getBool(key) ?? true;
  }

  Future<void> _ensureInit() async {
    if (!_isInitialized) await initialize();
  }

  Future<void> showPushNotification(String title, String body) async {
    await _ensureInit();
    await _notifications.show(
      DateTime.now().millisecond,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'push_alerts_v2',
          'Push Notifications',
          channelDescription: 'Important updates',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          ticker: 'ticker',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  // ────────────────────────────────────────────
  //  APP INACTIVITY NUDGE
  // ────────────────────────────────────────────
  Future<void> scheduleInactivityNudge() async {
    if (!await _isEnabled('notify_daily_reminder')) return;
    await _ensureInit();

    // Schedule 3 days from now
    final scheduledDate = tz.TZDateTime.now(
      tz.local,
    ).add(const Duration(days: 3));
    final content = NotificationContent.getInactivityNudge();

    await _notifications.zonedSchedule(
      _idDailyReminder + 1, // Unique ID just for this
      content['title'],
      content['body'],
      scheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelReminder,
          'Engagement Nudges',
          channelDescription: 'Reminders if you forget to open the app',
          importance: Importance.max,
          priority: Priority.max,
          styleInformation: BigTextStyleInformation(content['body'] ?? ''),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ────────────────────────────────────────────
  //  ACTIONABLE REMINDERS (EMI / Bills)
  // ────────────────────────────────────────────
  Future<void> showActionableReminder({
    required String title,
    required String body,
    required String payload,
  }) async {
    if (!await _isEnabled('notify_smart_tips')) return;
    await _ensureInit();

    await _notifications.show(
      _idSmartTip + DateTime.now().millisecondsSinceEpoch % 999,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelInsights,
          'Smart Insights',
          channelDescription: 'Spending tips & weekly summaries',
          importance: Importance.max,
          priority: Priority.max,
          actions: <AndroidNotificationAction>[
            const AndroidNotificationAction(
              'action_mark_paid', 
              'Mark as Paid', 
              showsUserInterface: true,
              cancelNotification: true,
            ),
          ],
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }
}
