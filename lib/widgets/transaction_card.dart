import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../utils/category_icons.dart';
import '../theme/app_theme.dart';
import '../services/user_preferences_service.dart';

class TransactionCard extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback? onTap;

  const TransactionCard({super.key, required this.transaction, this.onTap});

  Color _getTypeColor(ColorScheme cs) {
    switch (transaction.type) {
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

  IconData _getTypeIcon() {
    switch (transaction.type) {
      case TransactionType.income:
        return Icons.arrow_downward_rounded;
      case TransactionType.expense:
        return Icons.arrow_upward_rounded;
      case TransactionType.credit:
        return Icons.credit_card_rounded;
      case TransactionType.transfer:
        return Icons.swap_horiz_rounded;
      case TransactionType.investment:
        return Icons.show_chart_rounded;
      default:
        return Icons.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final isIncome = transaction.type == TransactionType.income;
    final color = _getTypeColor(cs);
    final amountPrefix = isIncome ? '+' : '-';
    final catIcon = CategoryIcons.getIcon(transaction.category);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      color: theme.cardTheme.color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        side: BorderSide(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : const Color(0xFFF0F0F0),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Category icon with colored background
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: Icon(catIcon, size: 22, color: color)),
              ),
              const SizedBox(width: 14),

              // Title + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.merchantName.isNotEmpty
                          ? transaction.merchantName
                          : (transaction.bankName ?? 'Unknown'),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(_getTypeIcon(), size: 12, color: color),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${DateFormat('MMM d').format(transaction.date)} • ${transaction.category}',
                            style: theme.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Amount
              Text(
                '$amountPrefix${CurrencyHelper.symbol}${_formatAmount(transaction.amount)}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000)
      return NumberFormat('#,##,###').format(amount.round()).toString();
    return amount.toStringAsFixed(amount == amount.roundToDouble() ? 0 : 2);
  }
}
