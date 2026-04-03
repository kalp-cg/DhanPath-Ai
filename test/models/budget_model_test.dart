import 'package:flutter_test/flutter_test.dart';
import 'package:dhanpath/models/budget_model.dart';

void main() {
  group('Budget model', () {
    test('creates with required fields', () {
      final budget = Budget(
        category: 'Food & Dining',
        monthlyLimit: 3000,
        month: 2,
        year: 2026,
      );

      expect(budget.category, 'Food & Dining');
      expect(budget.monthlyLimit, 3000);
      expect(budget.month, 2);
      expect(budget.year, 2026);
      expect(budget.isActive, true);
      expect(budget.id, isNull);
    });

    test('toMap serializes correctly', () {
      final budget = Budget(
        id: 1,
        category: 'Mess & Canteen',
        monthlyLimit: 2000,
        month: 2,
        year: 2026,
        isActive: true,
      );

      final map = budget.toMap();
      expect(map['id'], 1);
      expect(map['category'], 'Mess & Canteen');
      expect(map['monthly_limit'], 2000);
      expect(map['month'], 2);
      expect(map['year'], 2026);
      expect(map['is_active'], 1);
    });

    test('fromMap deserializes correctly', () {
      final map = {
        'id': 5,
        'category': 'Books & Stationery',
        'monthly_limit': 1500.0,
        'month': 3,
        'year': 2026,
        'is_active': 1,
      };

      final budget = Budget.fromMap(map);
      expect(budget.id, 5);
      expect(budget.category, 'Books & Stationery');
      expect(budget.monthlyLimit, 1500.0);
      expect(budget.month, 3);
      expect(budget.year, 2026);
      expect(budget.isActive, true);
    });

    test('roundtrip toMap -> fromMap preserves data', () {
      final original = Budget(
        id: 10,
        category: 'Tuition',
        monthlyLimit: 50000,
        month: 7,
        year: 2026,
        isActive: false,
      );

      final restored = Budget.fromMap(original.toMap());
      expect(restored.id, original.id);
      expect(restored.category, original.category);
      expect(restored.monthlyLimit, original.monthlyLimit);
      expect(restored.month, original.month);
      expect(restored.year, original.year);
      expect(restored.isActive, original.isActive);
    });

    test('isActive defaults to true', () {
      final b = Budget(
        category: 'Food',
        monthlyLimit: 1000,
        month: 1,
        year: 2026,
      );
      expect(b.isActive, true);
    });

    test('inactive budget serializes correctly', () {
      final b = Budget(
        category: 'Entertainment',
        monthlyLimit: 500,
        month: 2,
        year: 2026,
        isActive: false,
      );
      expect(b.toMap()['is_active'], 0);
    });
  });
}
