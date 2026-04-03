import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/transaction_provider.dart';
import '../models/transaction_model.dart';
import '../widgets/dhanpath_components.dart';
import '../theme/app_theme.dart';
import '../utils/category_icons.dart';
import 'transaction_detail_screen.dart';

import '../services/export_service.dart';
import '../services/user_preferences_service.dart';

class TransactionsScreen extends StatefulWidget {
  final int initialFilterIndex;
  const TransactionsScreen({super.key, this.initialFilterIndex = 0});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  late int _selectedPeriod;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  TransactionType? _typeFilter;

  @override
  void initState() {
    super.initState();
    _selectedPeriod = widget.initialFilterIndex;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Transaction> _filterTransactions(List<Transaction> transactions) {
    final now = DateTime.now();
    List<Transaction> filtered = transactions;

    switch (_selectedPeriod) {
      case 0: // This Month
        filtered = filtered
            .where((t) => t.date.year == now.year && t.date.month == now.month)
            .toList();
        break;
      case 1: // This Week
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
        filtered = filtered.where((t) => !t.date.isBefore(start)).toList();
        break;
      case 2: // Last Month
        final lastMonth = now.month == 1 ? 12 : now.month - 1;
        final lastMonthYear = now.month == 1 ? now.year - 1 : now.year;
        filtered = filtered
            .where((t) => t.date.year == lastMonthYear && t.date.month == lastMonth)
            .toList();
        break;
      case 3: // All
        break;
    }

    if (_typeFilter != null) {
      filtered = filtered.where((t) => t.type == _typeFilter).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered
          .where(
            (t) =>
                t.merchantName.toLowerCase().contains(q) ||
                t.category.toLowerCase().contains(q) ||
                (t.bankName ?? '').toLowerCase().contains(q),
          )
          .toList();
    }

    return filtered;
  }

  /// Groups transactions by date label, with daily totals
  Map<String, List<Transaction>> _groupByDate(List<Transaction> transactions) {
    final Map<String, List<Transaction>> grouped = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (var t in transactions) {
      final txDate = DateTime(t.date.year, t.date.month, t.date.day);
      String label;

      if (txDate.isAtSameMomentAs(today)) {
        label = 'Today';
      } else if (txDate.isAtSameMomentAs(yesterday)) {
        label = 'Yesterday';
      } else if (now.difference(t.date).inDays < 7) {
        label = DateFormat('EEEE').format(t.date);
      } else {
        label = DateFormat('d MMMM yyyy').format(t.date);
      }

      grouped.putIfAbsent(label, () => []).add(t);
    }
    return grouped;
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

  double _dailyTotal(List<Transaction> txns) {
    return txns
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  void _showTransactionDetail(Transaction t) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final color = _getTransactionColor(t.type, cs);
    final isIncome = t.type == TransactionType.income;
    final catIcon = CategoryIcons.getIcon(t.category);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          MediaQuery.of(ctx).padding.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            // Icon + Amount
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withOpacity(isDark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(catIcon, size: 28, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              '${isIncome ? '+' : '-'}${_formatAmount(t.amount)}',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w300,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              t.merchantName.isNotEmpty
                  ? t.merchantName
                  : (t.bankName ?? 'Unknown'),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            // Details
            _detailRow('Category', t.category, Icons.category_rounded, cs),
            _detailRow(
              'Date',
              DateFormat('EEE, d MMM yyyy • h:mm a').format(t.date),
              Icons.calendar_today_rounded,
              cs,
            ),
            if (t.bankName != null && t.bankName!.isNotEmpty)
              _detailRow(
                'Bank',
                t.bankName!,
                Icons.account_balance_rounded,
                cs,
              ),
            if (t.description != null && t.description!.isNotEmpty)
              _detailRow('Note', t.description!, Icons.notes_rounded, cs),
            const SizedBox(height: 20),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              TransactionDetailScreen(transaction: t),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      _confirmDelete(t);
                    },
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: cs.error,
                    ),
                    label: Text('Delete', style: TextStyle(color: cs.error)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      side: BorderSide(color: cs.error.withOpacity(0.3)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, IconData icon, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(Transaction t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: Text(
          'Remove "${t.merchantName.isNotEmpty ? t.merchantName : t.category}" '
          'for ${_formatAmount(t.amount)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = Provider.of<TransactionProvider>(context, listen: false);
      final success = await provider.deleteTransaction(t.id!, permanent: false);
      if (mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction deleted'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: Text('Transactions', style: theme.appBarTheme.titleTextStyle),
        actions: [
          Consumer<TransactionProvider>(
            builder: (context, provider, _) => IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: 'Export',
              onPressed: () async {
                final transactions = _filterTransactions(provider.transactions);
                if (transactions.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No transactions to export')),
                  );
                  return;
                }
                try {
                  await ExportService.shareCSV(transactions);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Export failed: $e')),
                    );
                  }
                }
              },
            ),
          ),
        ],
      ),
      body: Consumer<TransactionProvider>(
        builder: (context, provider, _) {
          // Always start from full dataset; this screen has its own local filters.
          final filtered = _filterTransactions(provider.allTransactions);
          final grouped = _groupByDate(filtered);

          double income = 0, expense = 0;
          for (var t in filtered) {
            if (t.type == TransactionType.income) {
              income += t.amount;
            } else if (t.type == TransactionType.expense) {
              expense += t.amount;
            }
          }

          return Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search transactions...',
                    prefixIcon: Icon(Icons.search, color: cs.outline),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: cs.outline),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),

              // Period + Type filter chips (single row)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _buildPeriodChip('This Month', 0),
                    const SizedBox(width: 8),
                    _buildPeriodChip('This Week', 1),
                    const SizedBox(width: 8),
                    _buildPeriodChip('Last Month', 2),
                    const SizedBox(width: 8),
                    _buildPeriodChip('All', 3),
                    const SizedBox(width: 16),
                    // Vertical divider
                    Container(width: 1, height: 20, color: cs.outlineVariant),
                    const SizedBox(width: 16),
                    _buildTypeChip('All Types', null),
                    const SizedBox(width: 8),
                    _buildTypeChip('Income', TransactionType.income),
                    const SizedBox(width: 8),
                    _buildTypeChip('Expense', TransactionType.expense),
                    const SizedBox(width: 8),
                    _buildTypeChip('Credit', TransactionType.credit),
                    const SizedBox(width: 8),
                    _buildTypeChip('Transfer', TransactionType.transfer),
                    const SizedBox(width: 16),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Summary Card (Redesigned for non-tech clarity: Expense is huge)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? cs.surface : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.06)
                        : const Color(0xFFF0F0F0),
                    width: 1.5,
                  ),
                  boxShadow: isDark
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Column(
                  children: [
                    // Hero metric: Spent
                    Text(
                      'Total Spent',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatAmount(expense),
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: cs.expense,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Secondary metrics: Income and Net
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMinorSummary('Income', income, cs.income),
                          Container(
                            width: 1,
                            height: 24,
                            color: cs.outlineVariant,
                          ),
                          _buildMinorSummary(
                            'Net',
                            income - expense,
                            income >= expense ? cs.income : cs.onSurface,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Transaction list with Dismissible
              Expanded(
                child: filtered.isEmpty
                    ? EmptyStateWidget(
                        icon: Icons.search_off_rounded,
                        title: 'No transactions found',
                        subtitle: _searchQuery.isNotEmpty
                            ? 'Try a different search term'
                            : 'Transactions will appear here once scanned',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: grouped.entries.length,
                        itemBuilder: (context, index) {
                          final entry = grouped.entries.elementAt(index);
                          final dailyTotal = _dailyTotal(entry.value);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Date header with daily total
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  4,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        entry.key,
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: cs.onSurfaceVariant,
                                            ),
                                      ),
                                    ),
                                    if (dailyTotal > 0)
                                      Text(
                                        '-${_formatAmount(dailyTotal)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: cs.expense,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              // Transaction tiles with swipe-to-delete
                              ...entry.value.map(
                                (t) => _buildDismissibleTile(t),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDismissibleTile(Transaction t) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isIncome = t.type == TransactionType.income;
    final color = _getTransactionColor(t.type, cs);
    final catIcon = CategoryIcons.getIcon(t.category);
    final timeStr = DateFormat('h:mm a').format(t.date);

    return Dismissible(
      key: ValueKey(t.id ?? t.hashCode),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        _confirmDelete(t);
        return false; // We handle deletion ourselves
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: cs.error.withOpacity(0.1),
        child: Icon(Icons.delete_outline_rounded, color: cs.error),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
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
              '${isIncome ? '+' : '-'}${_formatAmount(t.amount)}',
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
        onTap: () => _showTransactionDetail(t),
      ),
    );
  }

  Widget _buildMinorSummary(String label, double amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _formatAmount(amount.abs()),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodChip(String label, int index) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = _selectedPeriod == index;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedPeriod = index),
      selectedColor: cs.primaryContainer,
      labelStyle: TextStyle(
        color: isSelected ? cs.onPrimaryContainer : cs.onSurface,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        fontSize: 13,
      ),
      side: BorderSide(
        color: isSelected
            ? cs.primary.withOpacity(0.3)
            : cs.outline.withOpacity(0.3),
      ),
      showCheckmark: false,
    );
  }

  Widget _buildTypeChip(String label, TransactionType? type) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = _typeFilter == type;

    Color chipColor;
    if (type == null) {
      chipColor = cs.primary;
    } else {
      switch (type) {
        case TransactionType.income:
          chipColor = cs.income;
        case TransactionType.expense:
          chipColor = cs.expense;
        case TransactionType.credit:
          chipColor = cs.credit;
        case TransactionType.transfer:
          chipColor = cs.transfer;
        default:
          chipColor = cs.outline;
      }
    }

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _typeFilter = type),
      selectedColor: chipColor.withOpacity(0.15),
      labelStyle: TextStyle(
        color: isSelected ? chipColor : cs.onSurface,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        fontSize: 12,
      ),
      side: BorderSide(
        color: isSelected
            ? chipColor.withOpacity(0.4)
            : cs.outline.withOpacity(0.2),
      ),
      showCheckmark: false,
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
