import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/recurring_bill.dart';
import '../providers/recurring_bills_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/dhanpath_components.dart';
import '../utils/category_icons.dart';
import '../services/user_preferences_service.dart';

class RecurringBillsScreen extends StatelessWidget {
  const RecurringBillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Recurring Bills'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showAddBillSheet(context),
          ),
        ],
      ),
      body: Consumer<RecurringBillsProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.bills.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.autorenew_rounded,
              title: 'No recurring bills',
              subtitle: 'Keep track of subscriptions, rent, and utility bills.',
              actionText: 'Add Bill',
              onAction: () => _showAddBillSheet(context),
            );
          }

          final now = DateTime.now();
          final today = now.day;

          // Compute summaries
          final totalThisMonth = provider.bills.fold(
            0.0,
            (sum, b) => sum + b.amount,
          );

          // Split into Due Soon and Later This Month
          final targetDueSoon = provider.bills.where((b) {
            int diff = b.dayOfMonth - today;
            if (diff < 0) diff += 30; // rough approximation for next month
            return diff <= 7;
          }).toList();

          final targetLater = provider.bills
              .where((b) => !targetDueSoon.contains(b))
              .toList();

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SummaryCard(
                  title: 'Total Monthly Bills',
                  amount:
                      '${CurrencyHelper.symbol}${NumberFormat('#,##,###').format(totalThisMonth)}',
                  subtitle: '${provider.bills.length} active bills',
                  icon: Icons.autorenew_rounded,
                ),
              ),
              if (targetDueSoon.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: SectionHeader(title: 'Due Soon'),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _BillCard(bill: targetDueSoon[index], isDark: isDark),
                    childCount: targetDueSoon.length,
                  ),
                ),
              ],
              if (targetLater.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: SectionHeader(title: 'Later This Month'),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _BillCard(bill: targetLater[index], isDark: isDark),
                    childCount: targetLater.length,
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ), // FAB padding
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddBillSheet(context),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _showAddBillSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddEditBillSheet(),
    );
  }
}

class _BillCard extends StatelessWidget {
  final RecurringBill bill;
  final bool isDark;

  const _BillCard({required this.bill, required this.isDark});

  Color _getCategoryColor(String category) {
    final colors = [
      const Color(0xFF6C5CE7),
      const Color(0xFF00B894),
      const Color(0xFF0984E3),
      const Color(0xFFE17055),
      const Color(0xFFFFBE0B),
      const Color(0xFFD63031),
    ];
    return colors[category.hashCode % colors.length].withOpacity(0.85);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final daysUntil = _calculateDaysUntil(bill.dayOfMonth);
    final isDueSoon = daysUntil <= 3;
    final isPaid =
        bill.lastPaid != null &&
        bill.lastPaid!.month == DateTime.now().month &&
        bill.lastPaid!.year == DateTime.now().year;

    final categoryColor = _getCategoryColor(bill.category);

    return DhanPathCard(
      onTap: () => _showBillDetail(context),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          BrandIcon(
            icon: CategoryIcons.getIcon(bill.category),
            backgroundColor: categoryColor.withOpacity(0.15),
            iconColor: categoryColor,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bill.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${bill.category} • Every ${bill.dayOfMonth}${_getOrdinalIndicator(bill.dayOfMonth)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${CurrencyHelper.symbol}${NumberFormat('#,##,###').format(bill.amount)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isPaid
                      ? AppTheme.budgetSuccess.withOpacity(0.1)
                      : (isDueSoon
                            ? theme.colorScheme.error.withOpacity(0.1)
                            : cs.surfaceContainerHighest),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isPaid
                      ? 'Paid'
                      : (daysUntil == 0 ? 'Today' : 'In $daysUntil d'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isPaid
                        ? AppTheme.budgetSuccess
                        : (isDueSoon
                              ? theme.colorScheme.error
                              : cs.onSurfaceVariant),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _calculateDaysUntil(int dayOfMonth) {
    final now = DateTime.now();
    int diff = dayOfMonth - now.day;
    if (diff < 0)
      diff += DateTime(
        now.year,
        now.month + 1,
        0,
      ).day; // Wrap around to next month correctly based on days in month
    return diff;
  }

  String _getOrdinalIndicator(int maxDay) {
    if (maxDay >= 11 && maxDay <= 13) return 'th';
    switch (maxDay % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  void _showBillDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BillDetailSheet(bill: bill),
    );
  }
}

class _BillDetailSheet extends StatelessWidget {
  final RecurringBill bill;

  const _BillDetailSheet({required this.bill});

  Color _getCategoryColor(String category) {
    final colors = [
      const Color(0xFF6C5CE7),
      const Color(0xFF00B894),
      const Color(0xFF0984E3),
      const Color(0xFFE17055),
      const Color(0xFFFFBE0B),
      const Color(0xFFD63031),
    ];
    return colors[category.hashCode % colors.length].withOpacity(0.85);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final categoryColor = _getCategoryColor(bill.category);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? cs.surface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 24),
            BrandIcon(
              icon: CategoryIcons.getIcon(bill.category),
              backgroundColor: categoryColor.withOpacity(0.15),
              iconColor: categoryColor,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              bill.name,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${CurrencyHelper.symbol}${NumberFormat('#,##,###').format(bill.amount)}',
              style: theme.textTheme.titleMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Provider.of<RecurringBillsProvider>(
                        context,
                        listen: false,
                      ).markAsPaid(bill.id!);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text('Mark Paid'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppTheme.budgetSuccess,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => _AddEditBillSheet(bill: bill),
                      );
                    },
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Edit Bill'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Provider.of<RecurringBillsProvider>(
                  context,
                  listen: false,
                ).deleteBill(bill.id!);
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(foregroundColor: cs.error),
              child: const Text('Delete Bill'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddEditBillSheet extends StatefulWidget {
  final RecurringBill? bill;

  const _AddEditBillSheet({this.bill});

  @override
  State<_AddEditBillSheet> createState() => _AddEditBillSheetState();
}

class _AddEditBillSheetState extends State<_AddEditBillSheet> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  String _category = 'Subscriptions';
  int _dayOfMonth = 1;

  final List<String> _categories = [
    'Subscriptions',
    'Bills & Utilities',
    'Rent / EMIs',
    'Insurance',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.bill != null) {
      _nameController.text = widget.bill!.name;
      _amountController.text = widget.bill!.amount.toStringAsFixed(0);
      _category = widget.bill!.category;
      _dayOfMonth = widget.bill!.dayOfMonth;

      if (!_categories.contains(_category)) {
        _categories.add(_category);
      }
    } else {
      _dayOfMonth = DateTime.now().day;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? cs.surface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.bill == null ? 'Add Recurring Bill' : 'Edit Bill',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Bill Name',
                      hintText: 'Netflix, Rent, etc.',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      prefixText: CurrencyHelper.symbol,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              items: _categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _category = val);
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text('Repeats on', style: theme.textTheme.bodyLarge),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<int>(
                    value: _dayOfMonth,
                    underline: const SizedBox(),
                    items: List.generate(31, (i) => i + 1)
                        .map(
                          (day) => DropdownMenuItem(
                            value: day,
                            child: Text('$day${_getOrdinal(day)}'),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _dayOfMonth = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: _saveBill,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  widget.bill == null ? 'Create Bill' : 'Save Changes',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getOrdinal(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  void _saveBill() {
    final name = _nameController.text.trim();
    final amount = double.tryParse(_amountController.text) ?? 0;

    if (name.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter name and valid amount')),
      );
      return;
    }

    final provider = Provider.of<RecurringBillsProvider>(
      context,
      listen: false,
    );

    if (widget.bill == null) {
      provider.addBill(
        RecurringBill(
          name: name,
          amount: amount,
          category: _category,
          dayOfMonth: _dayOfMonth,
        ),
      );
    } else {
      provider.updateBill(
        widget.bill!.copyWith(
          name: name,
          amount: amount,
          category: _category,
          dayOfMonth: _dayOfMonth,
        ),
      );
    }

    Navigator.pop(context);
  }
}
