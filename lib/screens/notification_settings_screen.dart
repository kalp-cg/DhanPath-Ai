import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../services/smart_notification_engine.dart';
import '../theme/app_theme.dart';

/// Full-featured notification settings screen.
/// Each toggle maps to a SharedPreferences key that the
/// NotificationService checks before firing any notification.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _masterEnabled = true;
  bool _transactions = true;
  bool _budgetAlerts = true;
  bool _dailyReminder = true;
  bool _weeklySummary = true;
  bool _largeExpense = true;
  bool _smartTips = true;

  int _reminderHour = 20;
  int _reminderMinute = 0;
  double _largeExpenseThreshold = 5000;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _masterEnabled = prefs.getBool('notifications_enabled') ?? true;
      _transactions = prefs.getBool('notify_transactions') ?? true;
      _budgetAlerts = prefs.getBool('notify_budget') ?? true;
      _dailyReminder = prefs.getBool('notify_daily_reminder') ?? true;
      _weeklySummary = prefs.getBool('notify_weekly_summary') ?? true;
      _largeExpense = prefs.getBool('notify_large_expense') ?? true;
      _smartTips = prefs.getBool('notify_smart_tips') ?? true;
      _reminderHour = prefs.getInt('daily_reminder_hour') ?? 20;
      _reminderMinute = prefs.getInt('daily_reminder_minute') ?? 0;
      _largeExpenseThreshold =
          prefs.getDouble('large_expense_threshold') ?? 5000;
      _isLoading = false;
    });
  }

  Future<void> _save(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);

    // Re-schedule recurring notifications when toggles change
    if (key == 'notify_daily_reminder' || key == 'notify_weekly_summary') {
      if (!value) {
        if (key == 'notify_daily_reminder') {
          await NotificationService().cancelDailyReminder();
        } else {
          await NotificationService().cancelWeeklySummary();
        }
      } else {
        await SmartNotificationEngine().scheduleRecurringNotifications();
      }
    }
  }

  Future<void> _saveDouble(String key, double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(key, value);
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _reminderHour, minute: _reminderMinute),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Theme.of(context).colorScheme.surface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _reminderHour = picked.hour;
        _reminderMinute = picked.minute;
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('daily_reminder_hour', picked.hour);
      await prefs.setInt('daily_reminder_minute', picked.minute);

      // Re-schedule with new time
      await NotificationService().cancelDailyReminder();
      await NotificationService().scheduleDailyReminder(
        hour: picked.hour,
        minute: picked.minute,
      );
    }
  }

  String _formatTime(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        children: [
          // ── Master toggle ──
          _buildCard(
            children: [
              _buildToggle(
                icon: Icons.notifications_rounded,
                iconColor: cs.primary,
                title: 'All Notifications',
                subtitle: 'Master switch for all notifications',
                value: _masterEnabled,
                onChanged: (val) {
                  setState(() => _masterEnabled = val);
                  _save('notifications_enabled', val);
                  if (!val) {
                    NotificationService().cancelAllNotifications();
                  } else {
                    SmartNotificationEngine().scheduleRecurringNotifications();
                  }
                },
              ),
            ],
          ),

          if (_masterEnabled) ...[
            const SizedBox(height: AppTheme.spacingSm),

            // ── Transaction Alerts ──
            _buildSectionLabel('Transaction Alerts'),
            _buildCard(
              children: [
                _buildToggle(
                  icon: Icons.receipt_long_rounded,
                  iconColor: const Color(0xFF2ECC71),
                  title: 'New Transaction',
                  subtitle: 'Alert when SMS transaction is detected',
                  value: _transactions,
                  onChanged: (val) {
                    setState(() => _transactions = val);
                    _save('notify_transactions', val);
                  },
                ),
                const _Divider(),
                _buildToggle(
                  icon: Icons.warning_amber_rounded,
                  iconColor: const Color(0xFFF44336),
                  title: 'Large Expense Alert',
                  subtitle:
                      'Warn when expense exceeds ₹${_largeExpenseThreshold.toStringAsFixed(0)}',
                  value: _largeExpense,
                  onChanged: (val) {
                    setState(() => _largeExpense = val);
                    _save('notify_large_expense', val);
                  },
                ),
                if (_largeExpense) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(56, 0, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Threshold: ₹${_largeExpenseThreshold.toStringAsFixed(0)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Slider(
                          value: _largeExpenseThreshold,
                          min: 500,
                          max: 50000,
                          divisions: 99,
                          label:
                              '₹${_largeExpenseThreshold.toStringAsFixed(0)}',
                          onChanged: (val) {
                            setState(() => _largeExpenseThreshold = val);
                          },
                          onChangeEnd: (val) {
                            _saveDouble('large_expense_threshold', val);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: AppTheme.spacingSm),

            // ── Budget Alerts ──
            _buildSectionLabel('Budget Alerts'),
            _buildCard(
              children: [
                _buildToggle(
                  icon: Icons.account_balance_wallet_rounded,
                  iconColor: const Color(0xFFFF9800),
                  title: 'Budget Warnings',
                  subtitle: 'Alert at 80% and 100% of budget',
                  value: _budgetAlerts,
                  onChanged: (val) {
                    setState(() => _budgetAlerts = val);
                    _save('notify_budget', val);
                  },
                ),
              ],
            ),

            const SizedBox(height: AppTheme.spacingSm),

            // ── Reminders ──
            _buildSectionLabel('Reminders'),
            _buildCard(
              children: [
                _buildToggle(
                  icon: Icons.edit_calendar_rounded,
                  iconColor: const Color(0xFFBB86FC),
                  title: 'Daily Reminder',
                  subtitle: 'Remind to log expenses',
                  value: _dailyReminder,
                  onChanged: (val) {
                    setState(() => _dailyReminder = val);
                    _save('notify_daily_reminder', val);
                  },
                ),
                if (_dailyReminder) ...[
                  InkWell(
                    onTap: _pickReminderTime,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(56, 0, 16, 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 18,
                            color: cs.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Reminder at ${_formatTime(_reminderHour, _reminderMinute)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'CHANGE',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const _Divider(),
                _buildToggle(
                  icon: Icons.bar_chart_rounded,
                  iconColor: const Color(0xFF42A5F5),
                  title: 'Weekly Summary',
                  subtitle: 'Sunday 10 AM spending recap',
                  value: _weeklySummary,
                  onChanged: (val) {
                    setState(() => _weeklySummary = val);
                    _save('notify_weekly_summary', val);
                  },
                ),
              ],
            ),

            const SizedBox(height: AppTheme.spacingSm),

            // ── Smart Insights ──
            _buildSectionLabel('Smart Insights'),
            _buildCard(
              children: [
                _buildToggle(
                  icon: Icons.auto_awesome_rounded,
                  iconColor: const Color(0xFFFFD600),
                  title: 'Smart Tips & Insights',
                  subtitle: 'Spending spikes, no-spend days, streaks & more',
                  value: _smartTips,
                  onChanged: (val) {
                    setState(() => _smartTips = val);
                    _save('notify_smart_tips', val);
                  },
                ),
              ],
            ),

            const SizedBox(height: AppTheme.spacingLg),

            // ── Test button ──
            Center(
              child: TextButton.icon(
                onPressed: () async {
                  await NotificationService().showNotification(
                    id: 99999,
                    title: 'Test Notification',
                    body:
                        'If you see this with sound at the top of your screen, notifications work!',
                    payload: 'test',
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Test notification sent!')),
                    );
                  }
                },
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Send Test Notification'),
              ),
            ),

            const SizedBox(height: AppTheme.spacingXxl),
          ],
        ],
      ),
    );
  }

  // ── UI Helpers ──

  Widget _buildSectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 4,
        bottom: AppTheme.spacingSm,
        top: 4,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildToggle({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingSm,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingSm),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(icon, color: iconColor, size: AppTheme.iconSizeSm),
          ),
          const SizedBox(width: AppTheme.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    indent: 56,
    endIndent: 16,
    color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
  );
}
