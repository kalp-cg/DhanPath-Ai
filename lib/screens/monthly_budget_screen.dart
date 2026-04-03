import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/budget_service.dart';
import '../services/user_preferences_service.dart';
import '../theme/app_theme.dart';

class MonthlyBudgetScreen extends StatefulWidget {
  const MonthlyBudgetScreen({super.key});

  @override
  State<MonthlyBudgetScreen> createState() => _MonthlyBudgetScreenState();
}

class _MonthlyBudgetScreenState extends State<MonthlyBudgetScreen> {
  final BudgetService _budgetService = BudgetService();
  String _currentMonth = DateFormat('yyyy-MM').format(DateTime.now());
  List<Map<String, dynamic>> _budgets = [];
  bool _isLoading = true;
  Map<String, double> _summary = {'budget': 0.0, 'spent': 0.0};

  @override
  void initState() {
    super.initState();
    _loadBudgets();
  }

  Future<void> _loadBudgets() async {
    setState(() => _isLoading = true);
    final budgets = await _budgetService.getBudgetsForMonth(_currentMonth);
    final summary = await _budgetService.getTotalBudgetVsSpending(
      _currentMonth,
    );

    // Check for budget alerts
    await _budgetService.checkBudgetAlerts(_currentMonth);

    setState(() {
      _budgets = budgets;
      _summary = summary;
      _isLoading = false;
    });
  }

  void _changeMonth(int months) {
    final date = DateTime.parse('$_currentMonth-01');
    final newDate = DateTime(date.year, date.month + months);
    setState(() {
      _currentMonth = DateFormat('yyyy-MM').format(newDate);
    });
    _loadBudgets();
  }

  Future<void> _showSetBudgetDialog({
    Map<String, dynamic>? existingBudget,
  }) async {
    final categoryController = TextEditingController(
      text: existingBudget?['category'],
    );
    final amountController = TextEditingController(
      text: existingBudget != null ? existingBudget['amount'].toString() : '',
    );

    // Simple list of categories for now - ideally fetch from DB or distinct transaction categories
    final List<String> categories = [
      'Food',
      'Transport',
      'Utilities',
      'Entertainment',
      'Shopping',
      'Health',
      'Education',
      'Others',
    ];

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existingBudget == null ? 'Set Budget' : 'Edit Budget'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (existingBudget == null)
              DropdownButtonFormField<String>(
                value: categories.contains(categoryController.text)
                    ? categoryController.text
                    : null,
                hint: const Text('Select Category'),
                items: categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) => categoryController.text = val ?? '',
              ),
            if (existingBudget != null)
              TextFormField(
                controller: categoryController,
                decoration: const InputDecoration(labelText: 'Category'),
                readOnly: true,
                enabled: false,
              ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              decoration: InputDecoration(
                labelText: 'Amount (${CurrencyHelper.symbol})',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (categoryController.text.isNotEmpty &&
                  amountController.text.isNotEmpty) {
                final amount = double.tryParse(amountController.text) ?? 0.0;
                await _budgetService.setBudget(
                  categoryController.text,
                  amount,
                  _currentMonth,
                );
                if (mounted) Navigator.pop(context);
                _loadBudgets();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse('$_currentMonth-01');
    final monthDisplay = DateFormat('MMMM yyyy').format(date);
    double totalBudget = _summary['budget'] ?? 0;
    double totalSpent = _summary['spent'] ?? 0;
    double progress = totalBudget > 0
        ? (totalSpent / totalBudget).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Budget'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showSetBudgetDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Month Selector
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeMonth(-1),
                ),
                Text(
                  monthDisplay,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
          ),

          // Total Summary
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const Text(
                        'Total Spending',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${CurrencyHelper.symbol}${totalSpent.toStringAsFixed(0)} / ${CurrencyHelper.symbol}${totalBudget.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey[200],
                        color: progress > 0.9
                            ? Colors.red
                            : (progress > 0.75
                                  ? Colors.orange
                                  : AppTheme.primaryColor),
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(progress * 100).toStringAsFixed(1)}% Used',
                        style: TextStyle(
                          color: progress > 0.9 ? Colors.red : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Budgets List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _budgets.isEmpty
                ? Center(
                    child: Text(
                      'No budgets set for $monthDisplay',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _budgets.length,
                    itemBuilder: (context, index) {
                      final item = _budgets[index];
                      final amount = item['amount'] as double;
                      final spent = item['spent'] as double;
                      final category = item['category'] as String;
                      final itemProgress = amount > 0
                          ? (spent / amount).clamp(0.0, 1.0)
                          : 0.0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () =>
                              _showSetBudgetDialog(existingBudget: item),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      category,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '${CurrencyHelper.symbol}${spent.toStringAsFixed(0)} / ${CurrencyHelper.symbol}${amount.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: spent > amount
                                            ? Colors.red
                                            : Colors.grey[800],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                LinearProgressIndicator(
                                  value: itemProgress,
                                  backgroundColor: Colors.grey[100],
                                  color: itemProgress > 1.0
                                      ? Colors.red
                                      : (itemProgress > 0.8
                                            ? Colors.orange
                                            : Colors.green),
                                  minHeight: 6,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
