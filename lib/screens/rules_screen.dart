import 'package:flutter/material.dart';
import '../services/rule_service.dart';
import '../theme/app_theme.dart';
import 'add_rule_screen.dart';

class RulesScreen extends StatefulWidget {
  const RulesScreen({super.key});

  @override
  State<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends State<RulesScreen> {
  final RuleService _ruleService = RuleService();
  List<Rule> _rules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    final rules = await _ruleService.getRules();
    if (mounted) {
      setState(() {
        _rules = rules;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Automation Rules'),
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rules.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.rule, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No rules defined',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _navigateToAddRule,
                    child: const Text('Create your first rule'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _rules.length,
              itemBuilder: (context, index) {
                final rule = _rules[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ExpansionTile(
                    title: Text(
                      rule.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${rule.conditions.length} conditions • ${rule.actions.length} actions',
                    ),
                    leading: Switch(
                      value: rule.enabled,
                      activeColor: AppTheme.primaryColor,
                      onChanged: (val) => _toggleRule(rule, val),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(),
                            const Text(
                              'Conditions:',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            ...rule.conditions.map(
                              (c) => Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '• ${c.field} ${c.operator} "${c.value}"',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Actions:',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            ...rule.actions.map(
                              (a) => Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '• ${a.type.replaceAll('_', ' ')}: "${a.value}"',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                  onPressed: () => _deleteRule(rule),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddRule,
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Future<void> _toggleRule(Rule rule, bool enabled) async {
    final updated = Rule(
      id: rule.id,
      name: rule.name,
      priority: rule.priority,
      enabled: enabled,
      conditions: rule.conditions,
      actions: rule.actions,
    );
    await _ruleService.updateRule(updated);
    _loadRules();
  }

  Future<void> _deleteRule(Rule rule) async {
    if (rule.id == null) return;
    await _ruleService.deleteRule(rule.id!);
    _loadRules();
  }

  void _navigateToAddRule() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddRuleScreen()),
    );
    if (result == true) {
      _loadRules();
    }
  }
}
