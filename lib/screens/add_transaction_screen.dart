import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/transaction_model.dart';
import '../providers/transaction_provider.dart';
import '../services/database_helper.dart';
import '../services/user_preferences_service.dart';
import '../theme/app_theme.dart';
import '../utils/category_icons.dart';

class AddTransactionScreen extends StatefulWidget {
  final String? prefilledDescription;

  const AddTransactionScreen({super.key, this.prefilledDescription});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _amountController = TextEditingController();
  final _merchantController = TextEditingController();
  final _noteController = TextEditingController();
  final _amountFocus = FocusNode();

  TransactionType _selectedType = TransactionType.expense;
  String _selectedCategory = 'Food & Dining';
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isSaving = false;

  // Top-level categories shown as chips (most common)
  static const _quickCategories = [
    'Food & Dining',
    'Transportation',
    'Shopping',
    'Utilities',
    'Entertainment',
    'Healthcare',
    'Education',
    'Groceries',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.prefilledDescription != null &&
        widget.prefilledDescription!.isNotEmpty) {
      _noteController.text = widget.prefilledDescription!;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _amountFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _noteController.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  bool get _canSave {
    final text = _amountController.text;
    if (text.isEmpty) return false;
    final val = double.tryParse(text);
    return val != null && val > 0;
  }

  Future<void> _saveTransaction() async {
    if (!_canSave || _isSaving) return;
    setState(() => _isSaving = true);

    final dateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final uniqueSmsBody =
        'Manually added transaction at ${DateTime.now().toIso8601String()}';

    final transaction = Transaction(
      amount: double.parse(_amountController.text),
      merchantName: _merchantController.text.isNotEmpty
          ? _merchantController.text
          : _selectedCategory,
      category: _selectedCategory,
      type: _selectedType,
      date: dateTime,
      description: _noteController.text.isEmpty ? null : _noteController.text,
      smsBody: uniqueSmsBody,
    );

    final id = await DatabaseHelper.instance.create(transaction);

    if (mounted) {
      final provider = Provider.of<TransactionProvider>(context, listen: false);
      provider.loadTransactions();
      Navigator.pop(context);

      final typeLabel = _selectedType == TransactionType.income
          ? 'Income'
          : 'Expense';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$typeLabel saved'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await provider.deleteTransaction(id, permanent: true);
            },
          ),
        ),
      );
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (time != null) {
      setState(() => _selectedTime = time);
    }
  }

  void _showAllCategories() {
    final cs = Theme.of(context).colorScheme;
    final allCats = CategoryIcons.getAllCategories();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'All Categories',
                style: Theme.of(
                  ctx,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  controller: scrollController,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.1,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: allCats.length,
                  itemBuilder: (_, idx) {
                    final cat = allCats.keys.elementAt(idx);
                    final icon = allCats.values.elementAt(idx);
                    final isSelected = _selectedCategory == cat;

                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedCategory = cat);
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? cs.primaryContainer
                              : cs.surfaceContainerHighest.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(color: cs.primary, width: 1.5)
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              icon,
                              size: 24,
                              color: isSelected
                                  ? cs.primary
                                  : cs.onSurface.withOpacity(0.7),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              cat,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isSelected
                                    ? cs.primary
                                    : cs.onSurface.withOpacity(0.7),
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final isExpense = _selectedType == TransactionType.expense;
    final typeColor = isExpense ? cs.expense : cs.income;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(isExpense ? 'Add Expense' : 'Add Income'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),

            // ── Expense / Income Toggle ──
            Center(
              child: SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(
                    value: TransactionType.expense,
                    label: Text('Expense'),
                    icon: Icon(Icons.arrow_upward_rounded),
                  ),
                  ButtonSegment(
                    value: TransactionType.income,
                    label: Text('Income'),
                    icon: Icon(Icons.arrow_downward_rounded),
                  ),
                ],
                selected: {_selectedType},
                onSelectionChanged: (set) {
                  setState(() => _selectedType = set.first);
                },
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: typeColor.withOpacity(
                    isDark ? 0.2 : 0.12,
                  ),
                  selectedForegroundColor: typeColor,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // ── Hero Amount Input ──
            Center(
              child: IntrinsicWidth(
                child: TextField(
                  controller: _amountController,
                  focusNode: _amountFocus,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'),
                    ),
                  ],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w300,
                    color: cs.onSurface,
                    letterSpacing: -1,
                  ),
                  decoration: InputDecoration(
                    prefixText: '${CurrencyHelper.symbol} ',
                    prefixStyle: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w300,
                      color: cs.onSurface,
                    ),
                    hintText: '0',
                    hintStyle: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w300,
                      color: cs.outlineVariant,
                    ),
                    border: InputBorder.none,
                    constraints: const BoxConstraints(minWidth: 120),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Category Chips (horizontal scroll) ──
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _quickCategories.length + 1, // +1 for "More"
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  if (index == _quickCategories.length) {
                    // "More" chip
                    return FilterChip(
                      label: const Text('More'),
                      avatar: const Icon(Icons.expand_more_rounded, size: 18),
                      onSelected: (_) => _showAllCategories(),
                      side: BorderSide(color: cs.outlineVariant),
                    );
                  }

                  final cat = _quickCategories[index];
                  final isSelected = _selectedCategory == cat;
                  final catIcon = CategoryIcons.getIcon(cat);

                  return FilterChip(
                    selected: isSelected,
                    label: Text(cat),
                    avatar: Icon(catIcon, size: 16),
                    selectedColor: cs.primaryContainer,
                    checkmarkColor: cs.primary,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: isSelected ? cs.primary : cs.onSurfaceVariant,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                    side: isSelected
                        ? BorderSide(color: cs.primary.withOpacity(0.5))
                        : BorderSide(color: cs.outlineVariant),
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // ── Merchant / Note Field ──
            TextField(
              controller: _merchantController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.store_rounded),
                hintText: 'Merchant name (optional)',
                filled: true,
                fillColor: cs.surfaceContainerHighest.withOpacity(0.4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.notes_rounded),
                hintText: 'Note (optional)',
                filled: true,
                fillColor: cs.surfaceContainerHighest.withOpacity(0.4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Date + Time Chips ──
            Row(
              children: [
                Expanded(
                  child: _buildDateTimeChip(
                    icon: Icons.calendar_today_rounded,
                    label: _isToday(_selectedDate)
                        ? 'Today'
                        : DateFormat('d MMM').format(_selectedDate),
                    onTap: _pickDate,
                    cs: cs,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDateTimeChip(
                    icon: Icons.access_time_rounded,
                    label: _selectedTime.format(context),
                    onTap: _pickTime,
                    cs: cs,
                    isDark: isDark,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // ── Save Button ──
            FilledButton(
              onPressed: _canSave ? _saveTransaction : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      isExpense ? 'Save Expense' : 'Save Income',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimeChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ColorScheme cs,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.04)
                : cs.surfaceContainerHighest.withOpacity(0.4),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}
