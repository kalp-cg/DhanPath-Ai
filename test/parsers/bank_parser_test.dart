import 'package:flutter_test/flutter_test.dart';
import 'package:dhanpath/core/parsers/bank_parser_factory.dart';
import 'package:dhanpath/models/transaction_model.dart';

void main() {
  group('BankParserFactory Tests', () {
    test('should support multiple banks', () {
      final supportedBanks = BankParserFactory.getSupportedBanks();

      expect(supportedBanks.length, greaterThan(0));
      expect(supportedBanks, contains('HDFC Bank'));
      expect(supportedBanks, contains('SBI'));
      expect(supportedBanks, contains('ICICI Bank'));
    });

    test('should get parser by sender - HDFC', () {
      final parser = BankParserFactory.getParser('HDFCBK');

      expect(parser, isNotNull);
      expect(parser!.getBankName(), 'HDFC Bank');
    });

    test('should get parser by sender - SBI', () {
      final parser = BankParserFactory.getParser('SBIINB');

      expect(parser, isNotNull);
      expect(parser!.getBankName(), 'SBI');
    });

    test('should return null for unknown sender', () {
      final parser = BankParserFactory.getParser('UNKNOWN');

      expect(parser, isNull);
    });
  });

  group('HDFC Bank Parser Tests', () {
    test('should parse HDFC debit card transaction', () {
      const smsBody =
          'Spent Rs.1,250.00 From HDFC Bank Card x4567 At AMAZON On 12-Jan-24. '
          'Avl bal: INR 45,320.75. Block DC 4567 by SMS/App';
      const sender = 'HDFCBK';
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final parsed = BankParserFactory.parseTransaction(
        smsBody,
        sender,
        timestamp,
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, 1250.00);
      expect(parsed.merchant, 'AMAZON');
      expect(parsed.type, TransactionType.expense);
      expect(parsed.balance, 45320.75);
      expect(parsed.accountLast4, '4567');
      expect(parsed.bankName, 'HDFC Bank');
    });

    test('should parse HDFC UPI transaction', () {
      const smsBody =
          'Rs.500.00 debited from A/c XX1234 on 01-Feb-24 to VPA paytm@paytm '
          'Info: UPI/PAYTM/Shopping. Avl Bal: Rs.10,000.00';
      const sender = 'HDFCBK';
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final parsed = BankParserFactory.parseTransaction(
        smsBody,
        sender,
        timestamp,
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, 500.00);
      expect(parsed.merchant!.toLowerCase(), contains('paytm'));
      expect(parsed.type, TransactionType.expense);
      expect(parsed.balance, 10000.00);
    });

    test('should parse HDFC salary credit', () {
      const smsBody =
          'Rs.50,000.00 deposited to A/c XX1234 on 01-Feb-24 '
          'for ABC123-JAN SALARY-ACME CORPORATION LTD. Avl Bal: INR 75,000.00';
      const sender = 'HDFCBK';
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final parsed = BankParserFactory.parseTransaction(
        smsBody,
        sender,
        timestamp,
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, 50000.00);
      expect(parsed.type, TransactionType.income);
      expect(parsed.balance, 75000.00);
    });

    test('should skip OTP messages', () {
      const smsBody =
          'Your OTP for HDFC Bank transaction is 123456. Valid for 10 minutes.';
      const sender = 'HDFCBK';
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final parsed = BankParserFactory.parseTransaction(
        smsBody,
        sender,
        timestamp,
      );

      expect(parsed, isNull);
    });

    test('should skip promotional messages', () {
      const smsBody =
          'Get 10% cashback offer on your HDFC Credit Card! Click here to know more.';
      const sender = 'HDFCBK';
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final parsed = BankParserFactory.parseTransaction(
        smsBody,
        sender,
        timestamp,
      );

      expect(parsed, isNull);
    });

    test('should skip payment request messages', () {
      const smsBody = 'John has requested Rs.500 via UPI. Open app to pay.';
      const sender = 'HDFCBK';
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final parsed = BankParserFactory.parseTransaction(
        smsBody,
        sender,
        timestamp,
      );

      expect(parsed, isNull);
    });
  });

  group('SBI Bank Parser Tests', () {
    test('should parse SBI debit transaction', () {
      const smsBody =
          'Dear Customer, INR 1,500.00 debited from A/c XX5678 on 02-Feb-24 '
          'at FLIPKART. Avbl bal Rs.25,000.00';
      const sender = 'SBIINB';
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final parsed = BankParserFactory.parseTransaction(
        smsBody,
        sender,
        timestamp,
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, 1500.00);
      expect(parsed.merchant, 'FLIPKART');
      expect(parsed.type, TransactionType.expense);
      expect(parsed.balance, 25000.00);
      expect(parsed.bankName, 'SBI');
    });

    test('should parse SBI credit transaction', () {
      const smsBody =
          'Rs.10,000.00 credited to A/c XX5678 on 02-Feb-24. '
          'Avbl bal Rs.35,000.00';
      const sender = 'SBIINB';
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final parsed = BankParserFactory.parseTransaction(
        smsBody,
        sender,
        timestamp,
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, 10000.00);
      expect(parsed.type, TransactionType.income);
      expect(parsed.balance, 35000.00);
    });
  });

  group('ICICI Bank Parser Tests', () {
    test('should parse ICICI debit transaction', () {
      const smsBody =
          'INR 2,000.00 debited from A/c XX9999 on 02-Feb-24 at SWIGGY. '
          'Available balance Rs 15,000.00';
      const sender = 'ICICIB';
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final parsed = BankParserFactory.parseTransaction(
        smsBody,
        sender,
        timestamp,
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, 2000.00);
      expect(parsed.merchant, 'SWIGGY');
      expect(parsed.type, TransactionType.expense);
      expect(parsed.balance, 15000.00);
      expect(parsed.bankName, 'ICICI Bank');
    });
  });

  group('Duplicate Detection Tests', () {
    test('should generate same hash for same transaction', () {
      const smsBody = 'Rs.100.00 debited from A/c XX1234 on 01-Feb-24';
      const sender = 'HDFCBK';
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final parsed1 = BankParserFactory.parseTransaction(
        smsBody,
        sender,
        timestamp,
      );
      final parsed2 = BankParserFactory.parseTransaction(
        smsBody,
        sender,
        timestamp,
      );

      expect(parsed1, isNotNull);
      expect(parsed2, isNotNull);
      expect(parsed1!.generateHash(), equals(parsed2!.generateHash()));
    });

    test('should generate different hash for different amount', () {
      const smsBody1 = 'Rs.100.00 debited from A/c XX1234 on 01-Feb-24';
      const smsBody2 = 'Rs.200.00 debited from A/c XX1234 on 01-Feb-24';
      const sender = 'HDFCBK';
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final parsed1 = BankParserFactory.parseTransaction(
        smsBody1,
        sender,
        timestamp,
      );
      final parsed2 = BankParserFactory.parseTransaction(
        smsBody2,
        sender,
        timestamp,
      );

      expect(parsed1, isNotNull);
      expect(parsed2, isNotNull);
      expect(parsed1!.generateHash(), isNot(equals(parsed2!.generateHash())));
    });
  });

  group('Transaction Type Detection Tests', () {
    test('should detect expense for debited', () {
      const smsBody = 'Rs.100.00 debited from A/c XX1234';
      const sender = 'HDFCBK';
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final parsed = BankParserFactory.parseTransaction(
        smsBody,
        sender,
        timestamp,
      );

      expect(parsed, isNotNull);
      expect(parsed!.type, TransactionType.expense);
    });

    test('should detect income for credited', () {
      const smsBody = 'Rs.100.00 credited to A/c XX1234';
      const sender = 'HDFCBK';
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final parsed = BankParserFactory.parseTransaction(
        smsBody,
        sender,
        timestamp,
      );

      expect(parsed, isNotNull);
      expect(parsed!.type, TransactionType.income);
    });

    test('should detect credit card for block cc', () {
      const smsBody = 'Rs.100.00 spent at MERCHANT. Block CC 1234';
      const sender = 'HDFCBK';
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final parsed = BankParserFactory.parseTransaction(
        smsBody,
        sender,
        timestamp,
      );

      expect(parsed, isNotNull);
      expect(parsed!.type, TransactionType.credit);
    });
  });

  group('Amount Extraction Tests', () {
    test('should extract amount with Rs prefix', () {
      const smsBody = 'Rs.1,234.56 debited from A/c XX1234';
      const sender = 'HDFCBK';
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final parsed = BankParserFactory.parseTransaction(
        smsBody,
        sender,
        timestamp,
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, 1234.56);
    });

    test('should extract amount with INR prefix', () {
      const smsBody = 'INR 5,000.00 credited to A/c XX1234';
      const sender = 'SBIINB';
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final parsed = BankParserFactory.parseTransaction(
        smsBody,
        sender,
        timestamp,
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, 5000.00);
    });

    test('should extract amount with rupee symbol', () {
      const smsBody = '₹ 250.00 debited from A/c XX1234';
      const sender = 'ICICIB';
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final parsed = BankParserFactory.parseTransaction(
        smsBody,
        sender,
        timestamp,
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, 250.00);
    });
  });
}
