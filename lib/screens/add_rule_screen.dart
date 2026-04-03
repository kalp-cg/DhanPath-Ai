import 'package:flutter/material.dart';
import '../services/rule_service.dart';
import '../theme/app_theme.dart';

class AddRuleScreen extends StatefulWidget {
  const AddRuleScreen({super.key});

  @override
  State<AddRuleScreen> createState() => _AddRuleScreenState();
}

class _AddRuleScreenState extends State<AddRuleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final List<RuleCondition> _conditions = [];
  final List<RuleAction> _actions = [];

  // Temporary state for adding new condition/action
  String _condField = 'merchant';
  String _condOp = 'contains';
  final _condValueController = TextEditingController();

  String _actionType = 'set_category';
  final _actionValueController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Create Rule'),
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _saveRule,
            child: const Text(
              'SAVE',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Rule Name',
                  border: OutlineInputBorder(),
                  hintText: 'e.g. Starbucks to Coffee',
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 24),

              _buildSectionHeader('If transaction matches...'),
              ..._conditions.map((c) => _buildConditionItem(c)),
              const SizedBox(height: 8),
              _buildAddConditionForm(),

              const SizedBox(height: 24),

              _buildSectionHeader('Then perform actions...'),
              ..._actions.map((a) => _buildActionItem(a)),
              const SizedBox(height: 8),
              _buildAddActionForm(),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }

  Widget _buildConditionItem(RuleCondition c) {
    return Card(
      child: ListTile(
        title: Text('${c.field} ${c.operator} "${c.value}"'),
        trailing: IconButton(
          icon: const Icon(Icons.close, color: Colors.grey),
          onPressed: () => setState(() => _conditions.remove(c)),
        ),
        dense: true,
      ),
    );
  }

  Widget _buildActionItem(RuleAction a) {
    return Card(
      child: ListTile(
        title: Text('${a.type.replaceAll('_', ' ')} "${a.value}"'),
        trailing: IconButton(
          icon: const Icon(Icons.close, color: Colors.grey),
          onPressed: () => setState(() => _actions.remove(a)),
        ),
        dense: true,
      ),
    );
  }

  Widget _buildAddConditionForm() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _condField,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 0,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'merchant',
                      child: Text('Merchant'),
                    ),
                    DropdownMenuItem(value: 'amount', child: Text('Amount')),
                    DropdownMenuItem(value: 'body', child: Text('Body')),
                    DropdownMenuItem(value: 'bank', child: Text('Bank')),
                  ],
                  onChanged: (v) => setState(() => _condField = v!),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _condOp,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 0,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'contains',
                      child: Text('Contains'),
                    ),
                    DropdownMenuItem(value: 'equals', child: Text('Equals')),
                    DropdownMenuItem(
                      value: 'startsWith',
                      child: Text('Starts With'),
                    ),
                    DropdownMenuItem(value: 'gt', child: Text('>')),
                    DropdownMenuItem(value: 'lt', child: Text('<')),
                  ],
                  onChanged: (v) => setState(() => _condOp = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _condValueController,
                  decoration: const InputDecoration(
                    hintText: 'Value',
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.add_circle,
                  color: AppTheme.primaryColor,
                ),
                onPressed: () {
                  if (_condValueController.text.isNotEmpty) {
                    setState(() {
                      _conditions.add(
                        RuleCondition(
                          field: _condField,
                          operator: _condOp,
                          value: _condValueController.text,
                        ),
                      );
                      _condValueController.clear();
                    });
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddActionForm() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              value: _actionType,
              isExpanded: true,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 0,
                ),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'set_category',
                  child: Text('Set Category'),
                ),
                DropdownMenuItem(
                  value: 'set_description',
                  child: Text('Set Desc'),
                ),
              ],
              onChanged: (v) => setState(() => _actionType = v!),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: _actionValueController,
              decoration: const InputDecoration(
                hintText: 'Value',
                isDense: true,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle, color: AppTheme.primaryColor),
            onPressed: () {
              if (_actionValueController.text.isNotEmpty) {
                setState(() {
                  _actions.add(
                    RuleAction(
                      type: _actionType,
                      value: _actionValueController.text,
                    ),
                  );
                  _actionValueController.clear();
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _saveRule() async {
    if (_formKey.currentState!.validate()) {
      if (_conditions.isEmpty || _actions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Add at least one condition and action'),
          ),
        );
        return;
      }

      final rule = Rule(
        name: _nameController.text,
        conditions: _conditions,
        actions: _actions,
        enabled: true,
        priority: 1, // Default priority
      );

      await RuleService().addRule(rule);
      if (mounted) Navigator.pop(context, true);
    }
  }
}
