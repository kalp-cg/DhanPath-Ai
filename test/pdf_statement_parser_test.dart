import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:dhanpath/services/pdf_statement_parser.dart';
import 'package:dhanpath/services/database_helper.dart';

/// These tests exercise the parser's text-to-transaction logic directly,
/// bypassing PDF creation/extraction (which varies per PDF library layout).
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('SBI Parser', () {
    test('Extracts OCR-style single-line SBI rows with UPI/DR and UPI/CR', () {
      final parser = PdfStatementParser();
      final rawText = [
        'SBI Statement',
        '21 Mar 2026 BY TRANSFER-UPI/DR/123456789012/Amazon Pay/UTIB/gpay 366.00 14,077.25',
        '22 Mar 2026 BY TRANSFER-UPI/CR/998877665544/Salary/ICIC/salary 50,000.00 64,077.25',
      ].join('\n');

      final txns = parser.extractTransactionsFromText(rawText, 'SBI');

      expect(txns.length, 2, reason: 'Should extract 2 SBI transactions');

      final expense = txns.firstWhere((t) => t.type.name == 'expense');
      expect(expense.amount, 366.0);
      expect(expense.merchantName, contains('Amazon'));
      expect(expense.bankName, 'SBI');
      expect(expense.date, DateTime(2026, 3, 21));

      final income = txns.firstWhere((t) => t.type.name == 'income');
      expect(income.amount, 50000.0);
      expect(income.date, DateTime(2026, 3, 22));
    });

    test('Handles multi-line SBI format (date on one line, amounts on subsequent lines)', () {
      final parser = PdfStatementParser();
      final rawText = [
        '13 Mar 2026',
        'UPI/DR/111222333444/Zomato/UTIB/zomato',
        '299.00',
        '10,500.75',
        '15 Mar 2026',
        'UPI/CR/555666777888/Mom Transfer/SBIN/upi',
        '5,000.00',
        '15,500.75',
      ].join('\n');

      final txns = parser.extractTransactionsFromText(rawText, 'SBI');

      expect(txns.length, 2);

      final zomato = txns.firstWhere((t) => t.merchantName.toLowerCase().contains('zomato'));
      expect(zomato.amount, 299.0);
      expect(zomato.type.name, 'expense');
      expect(zomato.category, 'Food');
      expect(zomato.date, DateTime(2026, 3, 13));

      final transfer = txns.firstWhere((t) => t.type.name == 'income');
      expect(transfer.amount, 5000.0);
      expect(transfer.date, DateTime(2026, 3, 15));
    });

    test('Deduplication: same text produces same hash', () {
      final parser = PdfStatementParser();
      final rawText = '21 Mar 2026 UPI/DR/123/Test/UTIB/test 100.00 5000.00\n';

      final txns1 = parser.extractTransactionsFromText(rawText, 'SBI');
      final txns2 = parser.extractTransactionsFromText(rawText, 'SBI');

      expect(txns1.length, 1);
      expect(txns2.length, 1);
      expect(txns1.first.transactionHash, txns2.first.transactionHash,
          reason: 'Same input should produce the same dedup hash');
    });
  });

  group('HDFC Parser', () {
    test('Extracts single-line HDFC transaction rows', () {
      final parser = PdfStatementParser();
      final rawText = [
        'Account Statement from 1 Oct 2025 to 1 Apr 2026',
        'Txn Date Value Date Description Debit Credit Balance',
        '1 Oct 2025 1 Oct 2025 TO TRANSFER-UPI/DR/834535458945/Anand Gift/UTIB/gpay-11252/Pay 60.00 15,058.25',
        '3 Oct 2025 3 Oct 2025 TO TRANSFER-UPI/DR/042336527134/Amazon P/RATN/amazon-pod/Payme 366.00 14,077.25',
        '10 Oct 2025 10 Oct 2025 BY TRANSFER-UPI/CR/123456789012/Salary Account/ICIC/salary 50,000.00 64,077.25',
      ].join('\n');

      final txns = parser.extractTransactionsFromText(rawText, 'HDFC Bank');

      expect(txns.length, 3, reason: 'Should extract 3 HDFC transactions');

      final amazon = txns.firstWhere((t) => t.merchantName.contains('Amazon'));
      expect(amazon.amount, 366.0);
      expect(amazon.category, 'Shopping');
      expect(amazon.bankName, 'HDFC Bank');

      final salary = txns.firstWhere((t) => t.type.name == 'income');
      expect(salary.amount, 50000.0);
    });
  });

  // ── Calculation Correctness ────────────────────────────────────────────

  group('Amount Calculation Correctness', () {
    test('SBI: precise amount and balance extraction from single-line rows', () {
      final parser = PdfStatementParser();
      final rawText = [
        '1 Mar 2026 UPI/DR/111/Shop A/UTIB/upi 1,234.56 98,765.44',
        '5 Mar 2026 UPI/CR/222/Salary/SBIN/upi 45,000.00 1,43,765.44',
        '10 Mar 2026 UPI/DR/333/Rent/HDFC/upi 15,000.00 1,28,765.44',
        '15 Mar 2026 UPI/DR/444/Swiggy/UTIB/upi 350.50 1,28,414.94',
        '20 Mar 2026 UPI/CR/555/Refund/ICIC/upi 200.00 1,28,614.94',
        '25 Mar 2026 UPI/DR/666/Amazon/UTIB/upi 2,499.99 1,26,114.95',
        '31 Mar 2026 UPI/DR/777/Flipkart/RATN/upi 899.00 1,25,215.95',
      ].join('\n');

      final txns = parser.extractTransactionsFromText(rawText, 'SBI');

      expect(txns.length, 7, reason: 'Should extract all 7 rows');

      // Verify each amount precisely
      final amounts = txns.map((t) => t.amount).toList();
      expect(amounts, [1234.56, 45000.0, 15000.0, 350.50, 200.0, 2499.99, 899.0]);

      // Verify each balance precisely
      final balances = txns.map((t) => t.balance).toList();
      expect(balances, [98765.44, 143765.44, 128765.44, 128414.94, 128614.94, 126114.95, 125215.95]);

      // Verify types: DR=expense, CR=income
      final types = txns.map((t) => t.type.name).toList();
      expect(types, ['expense', 'income', 'expense', 'expense', 'income', 'expense', 'expense']);

      // Verify dates
      final dates = txns.map((t) => t.date).toList();
      expect(dates[0], DateTime(2026, 3, 1));
      expect(dates[3], DateTime(2026, 3, 15));
      expect(dates[6], DateTime(2026, 3, 31));

      // Verify categories
      expect(txns[3].category, 'Food', reason: 'Swiggy should be Food');
      expect(txns[5].category, 'Shopping', reason: 'Amazon should be Shopping');
      expect(txns[6].category, 'Shopping', reason: 'Flipkart should be Shopping');

      // Verify income/expense totals match expected
      double totalExpense = txns
          .where((t) => t.type.name == 'expense')
          .fold(0.0, (sum, t) => sum + t.amount);
      double totalIncome = txns
          .where((t) => t.type.name == 'income')
          .fold(0.0, (sum, t) => sum + t.amount);

      // Expected: expenses = 1234.56 + 15000 + 350.50 + 2499.99 + 899.00 = 19984.05
      expect(totalExpense, closeTo(19984.05, 0.01), reason: 'Total expenses should be 19984.05');

      // Expected: income = 45000.00 + 200.00 = 45200.00
      expect(totalIncome, closeTo(45200.0, 0.01), reason: 'Total income should be 45200.00');

      // Net = income - expense = 45200.00 - 19984.05 = 25215.95
      expect(totalIncome - totalExpense, closeTo(25215.95, 0.01));
    });

    test('SBI: multi-line format computes correct amounts and balances', () {
      final parser = PdfStatementParser();
      final rawText = [
        '1 Mar 2026',
        'UPI/DR/111/Zomato Order/UTIB/zomato',
        '456.78',
        '50,000.22',
        '2 Mar 2026',
        'UPI/CR/222/Freelance Payment/SBIN/upi',
        '10,000.00',
        '60,000.22',
        '3 Mar 2026',
        'UPI/DR/333/Electric Bill/HDFC/upi',
        '1,200.50',
        '58,799.72',
      ].join('\n');

      final txns = parser.extractTransactionsFromText(rawText, 'SBI');

      expect(txns.length, 3);

      // Amounts
      expect(txns[0].amount, 456.78);
      expect(txns[1].amount, 10000.0);
      expect(txns[2].amount, 1200.50);

      // Balances
      expect(txns[0].balance, 50000.22);
      expect(txns[1].balance, 60000.22);
      expect(txns[2].balance, 58799.72);

      // Types
      expect(txns[0].type.name, 'expense');
      expect(txns[1].type.name, 'income');
      expect(txns[2].type.name, 'expense');

      // Category auto-detection
      expect(txns[0].category, 'Food', reason: 'Zomato should be categorized as Food');
    });

    test('SBI: handles large amounts with comma formatting (lakhs/crores)', () {
      final parser = PdfStatementParser();
      final rawText = [
        '10 Mar 2026 UPI/CR/999/Big Salary/SBIN/upi 2,50,000.00 5,00,000.00',
        '11 Mar 2026 UPI/DR/888/Car EMI/HDFC/upi 25,000.00 4,75,000.00',
      ].join('\n');

      final txns = parser.extractTransactionsFromText(rawText, 'SBI');

      expect(txns.length, 2);
      expect(txns[0].amount, 250000.0);
      expect(txns[0].balance, 500000.0);
      expect(txns[1].amount, 25000.0);
      expect(txns[1].balance, 475000.0);
    });

    test('SBI: 2-digit year (e.g., "26") correctly maps to 2026', () {
      final parser = PdfStatementParser();
      final rawText = '5 Mar 26 UPI/DR/111/Test/UTIB/test 100.00 5000.00\n';
      final txns = parser.extractTransactionsFromText(rawText, 'SBI');
      expect(txns.length, 1);
      expect(txns.first.date, DateTime(2026, 3, 5));
    });

    test('HDFC: amount/balance/type correctly extracted', () {
      final parser = PdfStatementParser();
      final rawText = [
        '1 Mar 2026 1 Mar 2026 UPI/DR/111/Grocery Store/UTIB/gpay 2,345.67 47,654.33',
        '15 Mar 2026 15 Mar 2026 UPI/CR/222/Salary Deposit/ICIC/netbank 75,000.00 1,22,654.33',
      ].join('\n');
      
      final txns = parser.extractTransactionsFromText(rawText, 'HDFC Bank');

      expect(txns.length, 2);
      expect(txns[0].amount, 2345.67);
      expect(txns[0].balance, 47654.33);
      expect(txns[0].type.name, 'expense');
      expect(txns[1].amount, 75000.0);
      expect(txns[1].balance, 122654.33);
      expect(txns[1].type.name, 'income');
    });

    test('Merchant name extraction from UPI description', () {
      final parser = PdfStatementParser();
      final rawText = [
        '1 Mar 2026 UPI/DR/111/Starbucks India/UTIB/test 500.00 10,000.00',
        '2 Mar 2026 UPI/CR/222/John Smith Refund/ICIC/test 250.00 10,250.00',
        '3 Mar 2026 DEBIT CARD PURCHASE AT RELIANCE DIGITAL 3,999.00 6,251.00',
      ].join('\n');

      final txns = parser.extractTransactionsFromText(rawText, 'SBI');

      expect(txns.length, 3);
      expect(txns[0].merchantName, 'Starbucks India');
      expect(txns[1].merchantName, 'John Smith Refund');
      // Non-UPI description uses full desc as merchant
      expect(txns[2].type.name, 'expense'); // DEBIT => expense
    });
  });

  group('DB Integration', () {
    test('SBI transactions insert with correct bank_name and are queryable', () async {
      final db = await DatabaseHelper.instance.database;
      await db.delete('transactions');

      final parser = PdfStatementParser();
      final rawText = [
        '21 Mar 2026 UPI/DR/123/Flipkart/UTIB/test 500.00 9,500.00',
        '31 Mar 2026 UPI/CR/456/Refund/SBIN/upi 200.00 9,700.00',
      ].join('\n');

      final txns = parser.extractTransactionsFromText(rawText, 'SBI');
      expect(txns.length, 2);

      for (var t in txns) {
        await db.insert('transactions', t.toMap());
      }

      final rows = await db.query(
        'transactions',
        where: 'is_deleted = 0',
        orderBy: 'date DESC',
      );

      expect(rows.length, 2);
      expect(rows.every((r) => r['bank_name'] == 'SBI'), true);

      final marchRows = rows.where((r) {
        final date = DateTime.parse(r['date'] as String);
        return date.month == 3 && date.year == 2026;
      }).toList();
      expect(marchRows.length, 2, reason: 'Both transactions should be in March 2026');

      for (var t in txns) {
        final existing = await db.query(
          'transactions',
          where: 'transaction_hash = ?',
          whereArgs: [t.transactionHash],
          limit: 1,
        );
        expect(existing.length, 1, reason: 'Hash-based dedup lookup should find the row');
      }
    });

    test('Summary totals: income, expense, and net are computed correctly from DB rows', () async {
      final db = await DatabaseHelper.instance.database;
      await db.delete('transactions');

      final parser = PdfStatementParser();
      final rawText = [
        '1 Mar 2026 UPI/DR/001/Shop A/UTIB/upi 1,000.00 49,000.00',
        '5 Mar 2026 UPI/CR/002/Salary/SBIN/upi 30,000.00 79,000.00',
        '10 Mar 2026 UPI/DR/003/Electricity/HDFC/upi 2,500.00 76,500.00',
        '15 Mar 2026 UPI/DR/004/Swiggy/UTIB/upi 450.00 76,050.00',
        '20 Mar 2026 UPI/CR/005/Cashback/ICIC/upi 100.00 76,150.00',
        '25 Mar 2026 UPI/DR/006/Amazon/UTIB/upi 3,200.00 72,950.00',
      ].join('\n');

      final txns = parser.extractTransactionsFromText(rawText, 'SBI');
      for (var t in txns) {
        await db.insert('transactions', t.toMap());
      }

      // Query all non-deleted
      final rows = await db.query('transactions', where: 'is_deleted = 0');
      expect(rows.length, 6);

      // Compute totals the same way the TransactionsScreen does
      double income = 0, expense = 0;
      for (var r in rows) {
        final amount = r['amount'] as double;
        final type = r['type'] as String;
        if (type == 'income') {
          income += amount;
        } else if (type == 'expense') {
          expense += amount;
        }
      }

      // Expected: income = 30000 + 100 = 30100
      expect(income, closeTo(30100.0, 0.01), reason: 'Total income from DB should be 30100');

      // Expected: expense = 1000 + 2500 + 450 + 3200 = 7150
      expect(expense, closeTo(7150.0, 0.01), reason: 'Total expenses from DB should be 7150');

      // Net = 30100 - 7150 = 22950
      expect(income - expense, closeTo(22950.0, 0.01), reason: 'Net should be 22950');
    });

    test('Deduplication: second import inserts 0 new rows', () async {
      final db = await DatabaseHelper.instance.database;
      await db.delete('transactions');

      final parser = PdfStatementParser();
      final rawText = [
        '1 Mar 2026 UPI/DR/001/Shop/UTIB/upi 500.00 10,000.00',
        '2 Mar 2026 UPI/CR/002/Refund/SBIN/upi 200.00 10,200.00',
      ].join('\n');

      final txns = parser.extractTransactionsFromText(rawText, 'SBI');
      
      // First insert
      int inserted = 0;
      for (var t in txns) {
        final existing = await db.query('transactions', where: 'transaction_hash = ?', whereArgs: [t.transactionHash], limit: 1);
        if (existing.isEmpty) {
          await db.insert('transactions', t.toMap());
          inserted++;
        }
      }
      expect(inserted, 2);

      // Second insert (same data = same hashes)
      final txns2 = parser.extractTransactionsFromText(rawText, 'SBI');
      int inserted2 = 0;
      for (var t in txns2) {
        final existing = await db.query('transactions', where: 'transaction_hash = ?', whereArgs: [t.transactionHash], limit: 1);
        if (existing.isEmpty) {
          await db.insert('transactions', t.toMap());
          inserted2++;
        }
      }
      expect(inserted2, 0, reason: 'Second import should add 0 due to hash dedup');

      final total = await db.query('transactions');
      expect(total.length, 2, reason: 'DB should still have exactly 2 rows');
    });
  });
}
