import 'package:flutter_test/flutter_test.dart';
import 'package:dhanpath/models/transaction_model.dart';

void main() {
  group('TransactionType', () {
    test('contains all expected types', () {
      expect(TransactionType.values.length, 6);
      expect(TransactionType.values, contains(TransactionType.income));
      expect(TransactionType.values, contains(TransactionType.expense));
      expect(TransactionType.values, contains(TransactionType.credit));
      expect(TransactionType.values, contains(TransactionType.transfer));
      expect(TransactionType.values, contains(TransactionType.investment));
      expect(TransactionType.values, contains(TransactionType.balance_update));
    });
  });

  group('Transaction', () {
    late Transaction sampleTransaction;

    setUp(() {
      sampleTransaction = Transaction(
        id: 1,
        amount: 250.50,
        merchantName: 'College Canteen',
        category: 'Mess & Canteen',
        type: TransactionType.expense,
        date: DateTime(2026, 2, 9, 12, 30),
        description: 'Lunch',
        bankName: 'HDFC',
        accountNumber: 'XX1234',
        isRecurring: false,
        isDeleted: false,
        currency: 'INR',
      );
    });

    test('creates with required fields', () {
      final tx = Transaction(
        amount: 100,
        merchantName: 'Test',
        category: 'Food',
        type: TransactionType.expense,
        date: DateTime.now(),
      );
      expect(tx.amount, 100);
      expect(tx.merchantName, 'Test');
      expect(tx.category, 'Food');
      expect(tx.type, TransactionType.expense);
      expect(tx.isRecurring, false);
      expect(tx.isDeleted, false);
      expect(tx.currency, 'INR');
    });

    test('toMap serializes correctly', () {
      final map = sampleTransaction.toMap();

      expect(map['id'], 1);
      expect(map['amount'], 250.50);
      expect(map['merchant_name'], 'College Canteen');
      expect(map['category'], 'Mess & Canteen');
      expect(map['type'], 'expense');
      expect(map['bank_name'], 'HDFC');
      expect(map['account_number'], 'XX1234');
      expect(map['is_recurring'], 0);
      expect(map['is_deleted'], 0);
      expect(map['currency'], 'INR');
      expect(map['description'], 'Lunch');
    });

    test('fromMap deserializes correctly', () {
      final map = {
        'id': 2,
        'amount': 500.0,
        'merchant_name': 'Book Store',
        'category': 'Books & Stationery',
        'type': 'expense',
        'date': '2026-02-09T10:00:00.000',
        'description': 'Textbook',
        'sms_body': null,
        'bank_name': 'SBI',
        'account_number': 'XX5678',
        'is_recurring': 0,
        'is_deleted': 0,
        'reference': null,
        'balance': 10000.0,
        'credit_limit': null,
        'is_from_card': 0,
        'currency': 'INR',
        'from_account': null,
        'to_account': null,
        'transaction_hash': null,
      };

      final tx = Transaction.fromMap(map);

      expect(tx.id, 2);
      expect(tx.amount, 500.0);
      expect(tx.merchantName, 'Book Store');
      expect(tx.category, 'Books & Stationery');
      expect(tx.type, TransactionType.expense);
      expect(tx.bankName, 'SBI');
      expect(tx.balance, 10000.0);
      expect(tx.isFromCard, false);
    });

    test('roundtrip toMap -> fromMap preserves data', () {
      final map = sampleTransaction.toMap();
      final restored = Transaction.fromMap(map);

      expect(restored.id, sampleTransaction.id);
      expect(restored.amount, sampleTransaction.amount);
      expect(restored.merchantName, sampleTransaction.merchantName);
      expect(restored.category, sampleTransaction.category);
      expect(restored.type, sampleTransaction.type);
      expect(restored.bankName, sampleTransaction.bankName);
      expect(restored.currency, sampleTransaction.currency);
    });

    test('fromMap handles unknown type gracefully', () {
      final map = {
        'amount': 100.0,
        'merchant_name': 'Test',
        'category': 'Other',
        'type': 'unknown_type',
        'date': '2026-01-01T00:00:00.000',
        'is_recurring': 0,
        'is_deleted': 0,
        'is_from_card': 0,
      };

      final tx = Transaction.fromMap(map);
      expect(tx.type, TransactionType.expense); // fallback
    });

    test('fromMap handles null optional fields', () {
      final map = {
        'amount': 50.0,
        'merchant_name': 'ATM',
        'category': 'Banking',
        'type': 'expense',
        'date': '2026-02-01T00:00:00.000',
        'is_recurring': 0,
        'is_deleted': 0,
        'is_from_card': 0,
      };

      final tx = Transaction.fromMap(map);
      expect(tx.description, isNull);
      expect(tx.smsBody, isNull);
      expect(tx.bankName, isNull);
      expect(tx.balance, isNull);
      expect(tx.currency, 'INR');
    });

    test('copyWith creates modified copy', () {
      final modified = sampleTransaction.copyWith(
        amount: 999.0,
        category: 'Education',
        isRecurring: true,
      );

      expect(modified.amount, 999.0);
      expect(modified.category, 'Education');
      expect(modified.isRecurring, true);
      // Unchanged fields preserved
      expect(modified.id, sampleTransaction.id);
      expect(modified.merchantName, sampleTransaction.merchantName);
      expect(modified.bankName, sampleTransaction.bankName);
    });

    test('copyWith with no args returns equivalent transaction', () {
      final copy = sampleTransaction.copyWith();
      expect(copy.amount, sampleTransaction.amount);
      expect(copy.merchantName, sampleTransaction.merchantName);
      expect(copy.category, sampleTransaction.category);
      expect(copy.type, sampleTransaction.type);
    });

    test('generateTransactionId produces consistent hash', () {
      final hash1 = sampleTransaction.generateTransactionId();
      final hash2 = sampleTransaction.generateTransactionId();
      expect(hash1, hash2);
      expect(hash1, isNotEmpty);
    });

    test('different transactions produce different hashes', () {
      final tx2 = Transaction(
        amount: 100,
        merchantName: 'Other',
        category: 'Food',
        type: TransactionType.expense,
        date: DateTime.now(),
        bankName: 'ICICI',
        smsBody: 'Different sms body',
      );
      expect(
        sampleTransaction.generateTransactionId(),
        isNot(tx2.generateTransactionId()),
      );
    });

    test('toMap stores booleans as integers', () {
      final recurringTx = Transaction(
        amount: 500,
        merchantName: 'Netflix',
        category: 'Subscription',
        type: TransactionType.expense,
        date: DateTime.now(),
        isRecurring: true,
        isFromCard: true,
      );

      final map = recurringTx.toMap();
      expect(map['is_recurring'], 1);
      expect(map['is_from_card'], 1);
    });
  });
}
