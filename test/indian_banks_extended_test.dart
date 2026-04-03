import 'package:flutter_test/flutter_test.dart';
import 'package:dhanpath/core/parsers/bank_parser_factory.dart';
import 'package:dhanpath/models/transaction_model.dart';

void main() {
  group('Extended Indian Banks Parser Tests', () {
    test('Maharashtra Bank (Public Sector)', () {
      final sms =
          "Ac X1234 debited with Rs. 5000.00 on 01-01-2025. Bal Rs. 10000.00 CR - MAHABK";
      final transaction = BankParserFactory.parseTransaction(
        sms,
        "BZ-MAHABK",
        DateTime.now().millisecondsSinceEpoch,
      );

      expect(transaction, isNotNull);
      expect(transaction?.bankName, 'Bank of Maharashtra');
      expect(transaction?.amount, 5000.00);
      expect(transaction?.type, TransactionType.expense);
    });

    test('IDFC First Bank (Private Sector)', () {
      final sms =
          "Rs 2000.00 credited to your A/c XX8888 on 02/02/2025 by UPI. Avl Bal INR 45000.00";
      final transaction = BankParserFactory.parseTransaction(
        sms,
        "AD-IDFCFB",
        DateTime.now().millisecondsSinceEpoch,
      );

      expect(transaction, isNotNull);
      expect(transaction?.bankName, 'IDFC First Bank');
      expect(transaction?.amount, 2000.00);
      expect(transaction?.type, TransactionType.income);
    });

    test('AU Small Finance Bank', () {
      final sms =
          "Transaction of Rs 350.50 at ZOMATO made on your AU Bank Debit Card XX1234.";
      final transaction = BankParserFactory.parseTransaction(
        sms,
        "VM-AUBANK",
        DateTime.now().millisecondsSinceEpoch,
      );

      expect(transaction, isNotNull);
      expect(transaction?.bankName, 'AU Small Finance Bank');
      expect(transaction?.amount, 350.50);
      expect(transaction?.merchant, 'ZOMATO');
    });

    test('Paytm Payments Bank', () {
      final sms =
          "Rs. 100 paid to PAYTMQR123@PAYTM from your Paytm Bank Wallet. Updated Balance Rs. 500.";
      final transaction = BankParserFactory.parseTransaction(
        sms,
        "JD-PAYTMB",
        DateTime.now().millisecondsSinceEpoch,
      );

      expect(transaction, isNotNull);
      expect(transaction?.bankName, 'Paytm Payments Bank');
      expect(transaction?.amount, 100.0);
      // Merchant might be extracted as 'PAYTMQR123' or similar
    });

    test('Saraswat Bank (Co-operative)', () {
      final sms =
          "Your A/c 9999 is debited for Rs 1500.00 on 10/10/25. Info: ATM WDL. Avl Bal Rs 500.00";
      final transaction = BankParserFactory.parseTransaction(
        sms,
        "VK-SRC",
        DateTime.now().millisecondsSinceEpoch,
      );

      expect(transaction, isNotNull);
      expect(transaction?.bankName, 'Saraswat Bank');
      expect(transaction?.amount, 1500.00);
    });
  });
}
