import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/transaction_provider.dart';
import '../services/money_twin_service.dart';
import '../services/user_preferences_service.dart';

class MoneyTwinScreen extends StatefulWidget {
  const MoneyTwinScreen({super.key});

  @override
  State<MoneyTwinScreen> createState() => _MoneyTwinScreenState();
}

class _MoneyTwinScreenState extends State<MoneyTwinScreen> {
  final _incomeController = TextEditingController();
  final _fixedController = TextEditingController();
  final _bufferController = TextEditingController(text: '25000');
  final _emergencyController = TextEditingController(text: '0');

  int _horizonMonths = 6;
  int _emergencyMonth = 0;
  double _incomeDropPct = 0;
  double _cutPct = 0;
  double _inflationPct = 5;

  final _service = const MoneyTwinService();

  @override
  void dispose() {
    _incomeController.dispose();
    _fixedController.dispose();
    _bufferController.dispose();
    _emergencyController.dispose();
    super.dispose();
  }

  double _parse(TextEditingController c) {
    final raw = c.text.replaceAll(',', '').trim();
    return double.tryParse(raw) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final txProvider = context.watch<TransactionProvider>();
    final txns = txProvider.allTransactions;

    final scenario = MoneyTwinScenario(
      monthlyIncome: _parse(_incomeController),
      fixedCosts: _parse(_fixedController),
      startingBuffer: _parse(_bufferController),
      horizonMonths: _horizonMonths,
      incomeDropPct: _incomeDropPct,
      discretionaryCutPct: _cutPct,
      inflationPct: _inflationPct,
      emergencyExpense: _parse(_emergencyController),
      emergencyMonth: _emergencyMonth,
    );

    final result = _service.simulate(transactions: txns, scenario: scenario);
    final worstBalance = result.projections.isEmpty
        ? 0.0
        : result.projections.map((p) => p.balance).reduce((a, b) => a < b ? a : b);

    return Scaffold(
      appBar: AppBar(title: const Text('Money Twin Simulator')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _heroCard(result, worstBalance),
          const SizedBox(height: 14),
          _inputsCard(),
          const SizedBox(height: 14),
          _projectionCard(result),
          const SizedBox(height: 14),
          _recommendationCard(result),
        ],
      ),
    );
  }

  Widget _heroCard(MoneyTwinResult result, double worstBalance) {
    final riskColor = result.riskScore >= 70
        ? Colors.red
        : result.riskScore >= 40
            ? Colors.orange
            : Colors.green;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_graph_rounded),
                const SizedBox(width: 8),
                Text(
                  'Shock Meter',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              minHeight: 10,
              value: (result.riskScore / 100).clamp(0, 1),
              color: riskColor,
              backgroundColor: riskColor.withOpacity(0.15),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _chip('Risk ${result.riskScore.toStringAsFixed(0)}/100'),
                _chip(result.runwayMonth == null ? 'Runway: stable' : 'Runway: month ${result.runwayMonth}'),
                _chip('Worst balance ${CurrencyHelper.format(worstBalance)}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _inputsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Scenario Controls', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _field(_incomeController, 'Monthly Income (INR, optional)'),
            const SizedBox(height: 10),
            _field(_fixedController, 'Fixed Costs (Rent/EMI/Bills, optional)'),
            const SizedBox(height: 10),
            _field(_bufferController, 'Starting Emergency Buffer (INR)'),
            const SizedBox(height: 10),
            _field(_emergencyController, 'One-time Emergency Expense (INR)'),
            const SizedBox(height: 14),
            _slider('Income Drop %', _incomeDropPct, 0, 60, (v) => setState(() => _incomeDropPct = v)),
            _slider('Discretionary Cut %', _cutPct, 0, 60, (v) => setState(() => _cutPct = v)),
            _slider('Inflation %', _inflationPct, 0, 15, (v) => setState(() => _inflationPct = v)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _horizonMonths,
                    decoration: const InputDecoration(labelText: 'Projection Horizon'),
                    items: const [3, 6, 9, 12]
                        .map((m) => DropdownMenuItem(value: m, child: Text('$m months')))
                        .toList(),
                    onChanged: (v) => setState(() => _horizonMonths = v ?? 6),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _emergencyMonth,
                    decoration: const InputDecoration(labelText: 'Emergency Month'),
                    items: List.generate(_horizonMonths + 1, (i) => i)
                        .map((m) => DropdownMenuItem(value: m, child: Text(m == 0 ? 'None' : 'Month $m')))
                        .toList(),
                    onChanged: (v) => setState(() => _emergencyMonth = v ?? 0),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _slider(String title, double value, double min, double max, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$title: ${value.toStringAsFixed(0)}%'),
        Slider(value: value, min: min, max: max, onChanged: onChanged),
      ],
    );
  }

  Widget _projectionCard(MoneyTwinResult result) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Projection Timeline', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            ...result.projections.map((p) {
              final isDanger = p.balance < 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(width: 62, child: Text('M${p.month}', style: const TextStyle(fontWeight: FontWeight.w700))),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('In ${CurrencyHelper.format(p.income)}  •  Out ${CurrencyHelper.format(p.expense)}', style: const TextStyle(fontSize: 12)),
                          const SizedBox(height: 3),
                          LinearProgressIndicator(
                            minHeight: 8,
                            value: (p.balance.abs() / 100000).clamp(0, 1),
                            backgroundColor: Colors.grey.withOpacity(0.2),
                            color: isDanger ? Colors.red : Colors.green,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      CurrencyHelper.format(p.balance),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isDanger ? Colors.red : Colors.green,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _recommendationCard(MoneyTwinResult result) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Twin Recommendations', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            ...result.recommendations.map(
              (note) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.bolt_rounded, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(note)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
