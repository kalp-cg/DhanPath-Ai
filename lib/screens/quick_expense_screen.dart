import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/student_budget_provider.dart';
import '../models/transaction_model.dart';
import '../utils/category_icons.dart';
import '../services/user_preferences_service.dart';

/// Fast expense entry: pick category -> enter amount -> done.
class QuickExpenseScreen extends StatefulWidget {
  const QuickExpenseScreen({super.key});

  @override
  State<QuickExpenseScreen> createState() => _QuickExpenseScreenState();
}

class _QuickExpenseScreenState extends State<QuickExpenseScreen> {
  String? _selectedCategory;
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  bool _isSaving = false;

  // Quick-amount presets for students
  static const List<int> _presets = [10, 20, 50, 100, 200, 500];

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0 || _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount and category')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final tx = Transaction(
      amount: amount,
      merchantName: _noteController.text.isNotEmpty
          ? _noteController.text
          : _selectedCategory!,
      category: _selectedCategory!,
      type: TransactionType.expense,
      date: DateTime.now(),
      description: _noteController.text.isNotEmpty
          ? _noteController.text
          : null,
    );

    final provider = context.read<TransactionProvider>();
    final success = await provider.addTransaction(tx);

    if (mounted) {
      if (success) {
        // Also refresh student budget
        context.read<StudentBudgetProvider>().loadCurrentMonth();
        HapticFeedback.mediumImpact();
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${CurrencyHelper.symbol}${amount.toStringAsFixed(0)} added to $_selectedCategory',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to save expense')));
      }
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Expense'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Amount Input ──
              Center(
                child: Column(
                  children: [
                    Text(
                      'How much?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          CurrencyHelper.symbol,
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface.withOpacity(0.4),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IntrinsicWidth(
                          child: TextField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            autofocus: true,
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w800,
                              color: cs.onSurface,
                            ),
                            decoration: InputDecoration(
                              hintText: '0',
                              hintStyle: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w800,
                                color: cs.onSurface.withOpacity(0.15),
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Quick Amount Presets ──
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: _presets.map((p) {
                  return ActionChip(
                    label: Text('${CurrencyHelper.symbol}$p'),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      _amountController.text = p.toString();
                    },
                    backgroundColor: isDark
                        ? cs.surface
                        : cs.primary.withOpacity(0.06),
                    side: BorderSide(
                      color: isDark
                          ? Colors.white.withOpacity(0.08)
                          : cs.primary.withOpacity(0.15),
                    ),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                  );
                }).toList(),
              ),

              // ── Category Selection ──
              const SizedBox(height: 28),
              Text(
                'CATEGORY',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cs.outline,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: CategoryIcons.studentCategories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  final catIcon = CategoryIcons.getIcon(cat);
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedCategory = cat);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? cs.primary.withOpacity(0.15)
                            : isDark
                            ? cs.surface
                            : Colors.grey.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? cs.primary
                              : isDark
                              ? Colors.white.withOpacity(0.06)
                              : const Color(0xFFF0F0F0),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            catIcon,
                            size: 18,
                            color: isSelected
                                ? cs.primary
                                : cs.onSurface.withOpacity(0.6),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            cat,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? cs.primary
                                  : cs.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              // ── Optional Note ──
              const SizedBox(height: 24),
              TextField(
                controller: _noteController,
                decoration: InputDecoration(
                  hintText: 'Add a note (optional)',
                  hintStyle: TextStyle(color: cs.outline.withOpacity(0.4)),
                  prefixIcon: Icon(
                    Icons.note_outlined,
                    color: cs.outline,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? cs.surface
                      : Colors.grey.withOpacity(0.04),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),

              // ── Save Button ──
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _isSaving ? null : _save,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Text(
                          'Save Expense',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
