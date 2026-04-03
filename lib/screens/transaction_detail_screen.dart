import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../services/user_preferences_service.dart';
import '../theme/app_theme.dart';

class TransactionDetailScreen extends StatelessWidget {
  final Transaction transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final isIncome =
        transaction.type == TransactionType.income ||
        transaction.type == TransactionType.credit;
    final color = _getTypeColor(transaction.type, cs);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Transaction Details',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: cs.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero Amount Card ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withOpacity(isDark ? 0.15 : 0.08),
                    color.withOpacity(isDark ? 0.05 : 0.02),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: color.withOpacity(isDark ? 0.2 : 0.12),
                ),
              ),
              child: Column(
                children: [
                  // Icon
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: color.withOpacity(isDark ? 0.2 : 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isIncome
                          ? Icons.south_west_rounded
                          : Icons.north_east_rounded,
                      color: color,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Merchant name
                  Text(
                    transaction.merchantName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // Amount
                  Text(
                    '${isIncome ? '+' : '-'} ${CurrencyHelper.symbol}${NumberFormat('#,##,###.##').format(transaction.amount)}',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: color,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Date
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withOpacity(
                        isDark ? 0.3 : 0.5,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      DateFormat(
                        'EEEE, MMMM d, yyyy \u2022 h:mm a',
                      ).format(transaction.date),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Details Section ──
            Text(
              'Details',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: isDark ? cs.surfaceContainer : cs.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: cs.outlineVariant.withOpacity(isDark ? 0.15 : 0.3),
                ),
              ),
              child: Column(
                children: [
                  _buildDetailRow(
                    context,
                    icon: Icons.category_rounded,
                    label: 'Category',
                    value: transaction.category,
                    iconColor: cs.primary,
                  ),
                  _divider(cs, isDark),
                  _buildDetailRow(
                    context,
                    icon: Icons.swap_vert_rounded,
                    label: 'Type',
                    value: _getTypeLabel(transaction.type),
                    iconColor: color,
                    valueBadge: true,
                    badgeColor: color,
                  ),
                  if (transaction.bankName != null) ...[
                    _divider(cs, isDark),
                    _buildDetailRow(
                      context,
                      icon: Icons.account_balance_rounded,
                      label: 'Bank',
                      value: transaction.bankName!,
                      iconColor: cs.secondary,
                    ),
                  ],
                  if (transaction.accountNumber != null) ...[
                    _divider(cs, isDark),
                    _buildDetailRow(
                      context,
                      icon: Icons.credit_card_rounded,
                      label: 'Account',
                      value: transaction.accountNumber!,
                      iconColor: cs.tertiary,
                    ),
                  ],
                  if (transaction.description != null &&
                      transaction.description!.isNotEmpty) ...[
                    _divider(cs, isDark),
                    _buildDetailRow(
                      context,
                      icon: Icons.notes_rounded,
                      label: 'Note',
                      value: transaction.description!,
                      iconColor: cs.outline,
                    ),
                  ],
                ],
              ),
            ),

            // ── Original SMS Section ──
            if (transaction.smsBody != null &&
                transaction.smsBody!.isNotEmpty) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    'Original SMS',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const Spacer(),
                  // Copy button
                  IconButton(
                    icon: Icon(
                      Icons.copy_rounded,
                      size: 18,
                      color: cs.onSurfaceVariant,
                    ),
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: transaction.smsBody!),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('SMS copied to clipboard'),
                          duration: const Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    },
                    tooltip: 'Copy SMS',
                    style: IconButton.styleFrom(
                      minimumSize: const Size(36, 36),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? cs.surfaceContainerHighest.withOpacity(0.3)
                      : cs.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: cs.outlineVariant.withOpacity(isDark ? 0.12 : 0.2),
                  ),
                ),
                child: SelectableText(
                  transaction.smsBody!,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    height: 1.6,
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _divider(ColorScheme cs, bool isDark) {
    return Divider(
      height: 1,
      indent: 52,
      color: cs.outlineVariant.withOpacity(isDark ? 0.1 : 0.2),
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
    bool valueBadge = false,
    Color? badgeColor,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          if (valueBadge)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (badgeColor ?? cs.primary).withOpacity(
                  isDark ? 0.15 : 0.1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: badgeColor ?? cs.primary,
                ),
              ),
            )
          else
            Flexible(
              child: Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
                textAlign: TextAlign.end,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  String _getTypeLabel(TransactionType type) {
    switch (type) {
      case TransactionType.income:
        return 'Income';
      case TransactionType.expense:
        return 'Expense';
      case TransactionType.credit:
        return 'Credit';
      case TransactionType.transfer:
        return 'Transfer';
      case TransactionType.investment:
        return 'Investment';
      default:
        return 'Unknown';
    }
  }

  Color _getTypeColor(TransactionType type, ColorScheme cs) {
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
