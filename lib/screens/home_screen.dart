import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math' as math;
import '../providers/transaction_provider.dart';
import '../models/transaction_model.dart';
import '../services/sms_service.dart';
import '../services/notification_service.dart';
import '../widgets/dhanpath_components.dart';
import '../theme/app_theme.dart';
import '../utils/category_icons.dart';
import '../services/user_preferences_service.dart';
import 'transaction_detail_screen.dart';
import 'transactions_screen.dart';
import 'add_transaction_screen.dart';
import 'settings_screen.dart';
import 'smart_insights_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final SmsService _smsService = SmsService();
  bool _isSyncing = false;
  late String _userName;
  bool _isSimpleMode = false;

  // Animation controller for the budget ring
  late AnimationController _ringAnimController;
  late Animation<double> _ringAnimation;

  @override
  void initState() {
    super.initState();
    _initSmsService();
    _userName = CurrencyHelper.userName;
    _loadSimpleMode();

    _ringAnimController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _ringAnimation = CurvedAnimation(
      parent: _ringAnimController,
      curve: Curves.easeOutCubic,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TransactionProvider>(
        context,
        listen: false,
      ).loadTransactions();
      _ringAnimController.forward();
    });
  }

  Future<void> _loadSimpleMode() async {
    final simple = await UserPreferencesService().isSimpleMode();
    if (mounted) setState(() => _isSimpleMode = simple);
  }

  Future<void> _initSmsService() async {
    final hasPermission = await _smsService.requestPermissions();
    if (hasPermission) {
      await _smsService.init();
    }
  }

  @override
  void dispose() {
    _ringAnimController.dispose();
    super.dispose();
  }

  String _formatAmount(double amount) {
    if (amount >= 10000000) {
      return '${CurrencyHelper.symbol}${(amount / 10000000).toStringAsFixed(1)}Cr';
    }
    if (amount >= 100000) {
      return '${CurrencyHelper.symbol}${(amount / 100000).toStringAsFixed(1)}L';
    }
    if (amount >= 1000) {
      return '${CurrencyHelper.symbol}${NumberFormat('#,##,###').format(amount.round())}';
    }
    return '${CurrencyHelper.symbol}${amount.toStringAsFixed(amount == amount.roundToDouble() ? 0 : 2)}';
  }

  Future<void> _syncSms() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);

    try {
      bool hasPermission = await _smsService.requestPermissions();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('SMS permission required to scan messages'),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () => openAppSettings(),
              ),
            ),
          );
        }
        return;
      }

      final result = await _smsService.scanInbox();
      if (mounted) {
        Provider.of<TransactionProvider>(
          context,
          listen: false,
        ).loadTransactions();
        final msg = result.transactionsFound > 0
            ? 'Found ${result.transactionsFound} transactions'
            : 'Scanned ${result.totalSmsRead} SMS — no new transactions';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _fullResync() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Full Resync'),
        content: const Text(
          'This will reprocess all SMS messages from scratch. '
          'Use this to fix issues caused by updated bank parsers.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Resync All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isSyncing = true);
      try {
        bool hasPermission = await _smsService.requestPermissions();
        if (!hasPermission) return;
        final result = await _smsService.scanInbox(resetScan: true);
        if (mounted) {
          Provider.of<TransactionProvider>(
            context,
            listen: false,
          ).loadTransactions();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Resynced: ${result.transactionsFound} transactions '
                'from ${result.totalSmsRead} SMS',
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
        }
      } finally {
        if (mounted) setState(() => _isSyncing = false);
      }
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 17) return 'Good afternoon';
    if (hour >= 17 && hour < 21) return 'Good evening';
    return 'Good night';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Consumer<TransactionProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final breakdown = provider.currentMonthBreakdown;
          final recentTransactions = provider.transactions.take(5).toList();
          final todayExpenses = provider.todaySpent;
          final dailyBudget = provider.dailyBudgetLeft;
          final streak = provider.streakDays;

          return SafeArea(
            child: CustomScrollView(
              slivers: [
                // ─── Greeting Header ───
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_getGreeting()}${_userName.isNotEmpty ? ', $_userName' : ''}',
                                style: tt.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('EEEE, d MMMM').format(now),
                                style: tt.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Streak badge
                        if (streak > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF3E2723)
                                  : const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.local_fire_department_rounded,
                                  size: 14,
                                  color: isDark
                                      ? const Color(0xFFFFAB40)
                                      : const Color(0xFFE65100),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$streak',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? const Color(0xFFFFAB40)
                                        : const Color(0xFFE65100),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        // Sync button
                        _buildCircleButton(
                          icon: Icons.sync_rounded,
                          isLoading: _isSyncing,
                          onTap: _syncSms,
                          onLongPress: () {
                            HapticFeedback.heavyImpact();
                            _fullResync();
                          },
                          cs: cs,
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        // Settings button
                        _buildCircleButton(
                          icon: Icons.settings_rounded,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
                          ),
                          cs: cs,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                ),

                // ─── Hero Daily Budget Ring ───
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: _buildHeroBudgetRing(
                      todaySpent: todayExpenses,
                      dailyBudget: dailyBudget,
                      monthlyIncome: breakdown.income,
                      monthlyExpenses: breakdown.expenses,
                      cs: cs,
                      tt: tt,
                      isDark: isDark,
                    ),
                  ),
                ),

                // ─── Quick Actions Row ───
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Row(
                      children: [
                        _buildQuickAction(
                          icon: Icons.add_rounded,
                          label: 'Add',
                          color: cs.primary,
                          isDark: isDark,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AddTransactionScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _buildQuickAction(
                          icon: Icons.sync_rounded,
                          label: 'Scan SMS',
                          color: cs.secondary,
                          isDark: isDark,
                          onTap: _syncSms,
                        ),
                        const SizedBox(width: 12),
                        _buildQuickAction(
                          icon: Icons.lightbulb_rounded,
                          label: 'Tips',
                          color: const Color(0xFFE17055),
                          isDark: isDark,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SmartInsightsScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ─── Recent Transactions Header ───
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Recent Transactions',
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TransactionsScreen(),
                            ),
                          ),
                          child: Text(
                            'View all',
                            style: tt.bodyMedium?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ─── Recent Transaction List (or Empty State) ───
                if (recentTransactions.isEmpty)
                  SliverToBoxAdapter(
                    child: EmptyStateWidget(
                      icon: Icons.receipt_long_outlined,
                      title: 'No transactions yet',
                      subtitle:
                          'Tap the sync button to scan your SMS\nor add a transaction manually',
                      actionText: 'Scan Inbox',
                      onAction: _syncSms,
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _buildTransactionTile(recentTransactions[index]),
                      childCount: recentTransactions.length,
                    ),
                  ),

                // ─── Monthly Summary Card (hidden in Simple Mode) ───
                if (!_isSimpleMode && recentTransactions.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                      child: _buildMonthlySummaryCard(
                        breakdown: breakdown,
                        cs: cs,
                        tt: tt,
                        isDark: isDark,
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          );
        },
      ),
      // FAB for adding transactions
      floatingActionButton: GestureDetector(
        onLongPress: () {
          // Hidden test for notifications
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Testing transaction notification...'),
            ),
          );
          NotificationService().showTransactionNotification(
            amount: 500,
            merchant: 'Test Merchant',
            type: 'expense',
            category: 'Testing',
          );
        },
        child: FloatingActionButton(
          heroTag: 'add',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
          ),
          elevation: 2,
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
    );
  }

  // ─── Circle Button (Sync / Settings) ───
  Widget _buildCircleButton({
    required IconData icon,
    required ColorScheme cs,
    required bool isDark,
    bool isLoading = false,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      onLongPress: onLongPress,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : cs.surfaceContainerHighest.withOpacity(0.5),
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon, size: 20, color: cs.onSurface.withOpacity(0.6)),
        ),
      ),
    );
  }

  // ─── Hero Budget Ring (THE core widget) ───
  Widget _buildHeroBudgetRing({
    required double todaySpent,
    required double dailyBudget,
    required double monthlyIncome,
    required double monthlyExpenses,
    required ColorScheme cs,
    required TextTheme tt,
    required bool isDark,
  }) {
    final remaining = (dailyBudget - todaySpent).clamp(0.0, double.infinity);
    final progress = dailyBudget > 0
        ? (todaySpent / dailyBudget).clamp(0.0, 1.5)
        : 0.0;
    final isOverBudget = todaySpent > dailyBudget && dailyBudget > 0;

    // Ring color: green → amber → red based on usage percentage
    Color ringColor;
    String statusText;
    if (dailyBudget <= 0) {
      ringColor = cs.outline;
      statusText = 'Set a budget to track spending';
    } else if (progress <= 0.7) {
      ringColor = AppTheme.budgetSafe;
      statusText = 'You\'re on track today';
    } else if (progress <= 0.9) {
      ringColor = AppTheme.budgetWarning;
      statusText = 'Spending is picking up';
    } else if (progress <= 1.0) {
      ringColor = AppTheme.budgetDanger;
      statusText = 'Almost at today\'s limit';
    } else {
      ringColor = AppTheme.budgetDanger;
      statusText = 'Over budget today!';
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isDark
              ? cs.primary.withOpacity(0.15)
              : cs.outlineVariant.withOpacity(0.5),
          width: 0.5,
        ),
      ),
      color: isDark ? const Color(0xFF0F1A0F) : cs.primary.withOpacity(0.03),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          children: [
            // Budget Ring — HERO
            AnimatedBuilder(
              animation: _ringAnimation,
              builder: (context, child) {
                return SizedBox(
                  width: 200,
                  height: 200,
                  child: CustomPaint(
                    painter: _HeroBudgetRingPainter(
                      progress: (progress * _ringAnimation.value).clamp(
                        0.0,
                        1.0,
                      ),
                      color: ringColor,
                      trackColor: isDark
                          ? Colors.white.withOpacity(0.08)
                          : cs.onSurface.withOpacity(0.06),
                      strokeWidth: 16,
                      isOverBudget: isOverBudget,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            dailyBudget > 0 ? _formatAmount(remaining) : '--',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w300,
                              color: cs.onSurface,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'left today',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          if (dailyBudget > 0) ...[
                            const SizedBox(height: 2),
                            Text(
                              'of ${_formatAmount(dailyBudget)} daily',
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurfaceVariant.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            // Status text
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: ringColor.withOpacity(isDark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ringColor,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Income vs Expense row
            Row(
              children: [
                Expanded(
                  child: _buildIncomeExpensePill(
                    label: 'Income',
                    amount: _formatAmount(monthlyIncome),
                    icon: Icons.arrow_downward_rounded,
                    color: cs.primary,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildIncomeExpensePill(
                    label: 'Spent',
                    amount: _formatAmount(monthlyExpenses),
                    icon: Icons.arrow_upward_rounded,
                    color: cs.error,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomeExpensePill({
    required String label,
    required String amount,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.04)
            : color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface.withOpacity(0.5),
                ),
              ),
              Text(
                amount,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Quick Action Button ───
  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? color.withOpacity(0.1) : color.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? color.withOpacity(0.15)
                    : color.withOpacity(0.1),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(isDark ? 0.2 : 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Transaction Tile ───
  Widget _buildTransactionTile(Transaction t) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final isIncome = t.type == TransactionType.income;
    final color = _getTransactionColor(t.type, cs);
    final prefix = isIncome ? '+' : '-';
    final catIcon = CategoryIcons.getIcon(t.category);
    final timeStr = DateFormat('h:mm a').format(t.date);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 2,
            ),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(isDark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(catIcon, size: 22, color: color),
            ),
            title: Text(
              t.merchantName.isNotEmpty
                  ? t.merchantName
                  : (t.bankName ?? 'Unknown'),
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              t.category,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$prefix${_formatAmount(t.amount)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  timeStr,
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
              ],
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TransactionDetailScreen(transaction: t),
              ),
            ),
          ),
          Divider(
            height: 1,
            indent: 52,
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : const Color(0xFFF0F0F0),
          ),
        ],
      ),
    );
  }

  // ─── Monthly Summary Card (advanced — hidden in Simple Mode) ───
  Widget _buildMonthlySummaryCard({
    required MonthlyBreakdown breakdown,
    required ColorScheme cs,
    required TextTheme tt,
    required bool isDark,
  }) {
    final savings = breakdown.income - breakdown.expenses;
    final savingsRate = breakdown.income > 0
        ? (savings / breakdown.income * 100)
        : 0.0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant, width: 0.5),
      ),
      color: cs.surface,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_month_rounded, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  'This Month',
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: savings >= 0
                        ? cs.primary.withOpacity(0.1)
                        : cs.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    savings >= 0
                        ? 'Saved ${_formatAmount(savings)}'
                        : 'Over by ${_formatAmount(savings.abs())}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: savings >= 0 ? cs.primary : cs.error,
                    ),
                  ),
                ),
              ],
            ),
            if (breakdown.income > 0) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: savingsRate.clamp(0, 100) / 100,
                  minHeight: 6,
                  backgroundColor: isDark
                      ? Colors.white.withOpacity(0.06)
                      : cs.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    savingsRate >= 20
                        ? cs.primary
                        : savingsRate >= 10
                        ? AppTheme.budgetWarning
                        : cs.error,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${savingsRate.toStringAsFixed(0)}% savings rate',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getTransactionColor(TransactionType type, ColorScheme cs) {
    switch (type) {
      case TransactionType.income:
        return cs.income;
      case TransactionType.expense:
        return cs.expense;
      case TransactionType.credit:
        return cs.credit;
      case TransactionType.transfer:
        return cs.transfer;
      case TransactionType.investment:
        return cs.investment;
      default:
        return cs.outline;
    }
  }
}

/// Custom painter for the hero budget ring (280px, stroke 16)
class _HeroBudgetRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;
  final bool isOverBudget;

  _HeroBudgetRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
    required this.isOverBudget,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _HeroBudgetRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor;
  }
}
