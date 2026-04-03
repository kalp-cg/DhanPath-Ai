import 'dart:convert';
import '../models/transaction_model.dart';
import 'database_helper.dart';

class RuleCondition {
  final String field; // 'merchant', 'body', 'amount', 'sender'
  final String
  operator; // 'contains', 'equals', 'startsWith', 'endsWith', 'gt', 'lt'
  final String value;

  RuleCondition({
    required this.field,
    required this.operator,
    required this.value,
  });

  Map<String, dynamic> toJson() => {
    'field': field,
    'operator': operator,
    'value': value,
  };
  factory RuleCondition.fromJson(Map<String, dynamic> json) => RuleCondition(
    field: json['field'],
    operator: json['operator'],
    value: json['value'],
  );
}

class RuleAction {
  final String
  type; // 'set_category', 'mark_as_investment', 'set_description', 'mark_as_transfer'
  final String value;

  RuleAction({required this.type, required this.value});

  Map<String, dynamic> toJson() => {'type': type, 'value': value};
  factory RuleAction.fromJson(Map<String, dynamic> json) =>
      RuleAction(type: json['type'], value: json['value']);
}

class Rule {
  final int? id;
  final String name;
  final int priority;
  final bool enabled;
  final List<RuleCondition> conditions;
  final List<RuleAction> actions;

  Rule({
    this.id,
    required this.name,
    this.priority = 0,
    this.enabled = true,
    required this.conditions,
    required this.actions,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'priority': priority,
      'enabled': enabled ? 1 : 0,
      'conditions': jsonEncode(conditions.map((e) => e.toJson()).toList()),
      'actions': jsonEncode(actions.map((e) => e.toJson()).toList()),
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  factory Rule.fromMap(Map<String, dynamic> map) {
    return Rule(
      id: map['id'],
      name: map['name'],
      priority: map['priority'],
      enabled: map['enabled'] == 1,
      conditions: (jsonDecode(map['conditions']) as List)
          .map((e) => RuleCondition.fromJson(e))
          .toList(),
      actions: (jsonDecode(map['actions']) as List)
          .map((e) => RuleAction.fromJson(e))
          .toList(),
    );
  }
}

class RuleService {
  final DatabaseHelper _dbContext = DatabaseHelper.instance;

  Future<List<Rule>> getRules() async {
    final db = await _dbContext.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'rules',
      orderBy: 'priority DESC, id ASC',
    );
    return List.generate(maps.length, (i) => Rule.fromMap(maps[i]));
  }

  Future<int> addRule(Rule rule) async {
    final db = await _dbContext.database;
    return await db.insert('rules', rule.toMap());
  }

  Future<int> updateRule(Rule rule) async {
    final db = await _dbContext.database;
    return await db.update(
      'rules',
      rule.toMap(),
      where: 'id = ?',
      whereArgs: [rule.id],
    );
  }

  Future<int> deleteRule(int id) async {
    final db = await _dbContext.database;
    return await db.delete('rules', where: 'id = ?', whereArgs: [id]);
  }

  // Apply rules to a transaction and return the modified transaction
  Future<Transaction> applyRules(Transaction transaction) async {
    final rules = await getRules();
    var modifiedTx = transaction;

    // Create a mutable copy-like structure since Transaction might be immutable
    // Assuming Transaction has copyWith or we create a new one.
    // Let's assume we modify fields. Since Transaction fields are final, we need to create a new one.

    String category = transaction.category;
    String description = transaction.description ?? '';
    TransactionType type = transaction.type;
    // We can't easily change field names without a copyWith.
    // I'll assume Transaction has a copyWith method or I'll implement one/manual copy.

    for (var rule in rules) {
      if (!rule.enabled) continue;

      bool matches = true;
      // AND logic for conditions
      for (var condition in rule.conditions) {
        if (!_checkCondition(condition, modifiedTx)) {
          matches = false;
          break;
        }
      }

      if (matches) {
        print('Rule matched: ${rule.name}');

        for (var action in rule.actions) {
          switch (action.type) {
            case 'set_category':
              category = action.value;
              break;
            case 'mark_as_investment':
              // Set category to Investment
              category = 'Investment';
              break;
            case 'set_description':
              description = action.value;
              break;
            case 'mark_as_transfer':
              type = TransactionType.transfer;
              break;
          }
        }
      }
    }

    // Return new transaction with updates
    // Assuming Transaction constructor
    return Transaction(
      id: transaction.id,
      amount: transaction.amount,
      merchantName: transaction.merchantName,
      category: category,
      type: type,
      date: transaction.date,
      description: description.isNotEmpty
          ? description
          : transaction.description,
      smsBody: transaction.smsBody,
      bankName: transaction.bankName,
      accountNumber: transaction.accountNumber,
      isRecurring: transaction.isRecurring,
    );
  }

  bool _checkCondition(RuleCondition condition, Transaction tx) {
    String fieldValue = '';
    switch (condition.field) {
      case 'merchant':
        fieldValue = tx.merchantName;
        break;
      case 'body':
        fieldValue = tx.smsBody ?? '';
        break;
      case 'amount':
        fieldValue = tx.amount.toString();
        break;
      case 'bank':
        fieldValue = tx.bankName ?? '';
        break;
      default:
        return false;
    }

    final val = condition.value.toLowerCase();
    final field = fieldValue.toLowerCase();

    switch (condition.operator) {
      case 'contains':
        return field.contains(val);
      case 'equals':
        return field == val;
      case 'startsWith':
        return field.startsWith(val);
      case 'endsWith':
        return field.endsWith(val);
      case 'gt':
        final numF = double.tryParse(fieldValue) ?? 0;
        final numV = double.tryParse(condition.value) ?? 0;
        return numF > numV;
      case 'lt':
        final numF = double.tryParse(fieldValue) ?? 0;
        final numV = double.tryParse(condition.value) ?? 0;
        return numF < numV;
      default:
        return false;
    }
  }
}
