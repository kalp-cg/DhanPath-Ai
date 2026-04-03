import 'package:flutter_test/flutter_test.dart';
import 'package:dhanpath/core/parsers/bank_parser_factory.dart';

void main() {
  group('USA Banks Parser Tests', () {
    test('Chase Bank Parse', () {
      final sms = "Chase: You paid \$50.00 to AMAZON on 01/01/2026. Ref: 28392";
      final transaction = BankParserFactory.parseTransaction(
        sms,
        "72166", // Chase Shortcode
        DateTime.now().millisecondsSinceEpoch,
      );

      print('Chase parsed: ${transaction?.amount}, ${transaction?.bankName}');
      expect(transaction, isNotNull);
      expect(transaction?.bankName, 'Chase Bank');
      expect(transaction?.amount, 50.00);
      expect(transaction?.currency, 'USD');
      expect(transaction?.merchant, 'AMAZON');
    });

    test('Wells Fargo Parse', () {
      final sms =
          "Wells Fargo: Your card ending 1234 was used for \$100.25 at WALLMART on 02/02/2026.";
      final transaction = BankParserFactory.parseTransaction(
        sms,
        "93557",
        DateTime.now().millisecondsSinceEpoch,
      );

      print('Wells parsed: ${transaction?.amount}, ${transaction?.bankName}');
      expect(transaction, isNotNull);
      expect(transaction?.bankName, 'Wells Fargo');
      expect(transaction?.amount, 100.25);
      expect(transaction?.currency, 'USD');
      expect(transaction?.merchant, 'WALLMART'); // Or generic extraction
    });

    test('Bank of America Parse', () {
      final sms =
          "BoA: Your card sent you an alert. Transaction of \$20.00 at STARBUCKS approved.";
      final transaction = BankParserFactory.parseTransaction(
        sms,
        "BankOfAmerica",
        DateTime.now().millisecondsSinceEpoch,
      );

      print('BoA parsed: ${transaction?.amount}, ${transaction?.bankName}');
      expect(transaction, isNotNull);
      expect(transaction?.bankName, 'Bank of America');
      expect(transaction?.amount, 20.00);
      expect(transaction?.currency, 'USD');
    });
  });

  group('UK Banks Parser Tests', () {
    test('HSBC UK Parse', () {
      final sms =
          "HSBC: You spent \u00A324.99 at TESCO. Available balance \u00A3500.00.";
      final transaction = BankParserFactory.parseTransaction(
        sms,
        "HSBCUK",
        DateTime.now().millisecondsSinceEpoch,
      );

      print('HSBC parsed: ${transaction?.amount}, ${transaction?.bankName}');
      expect(transaction, isNotNull);
      expect(transaction?.bankName, 'HSBC UK');
      expect(transaction?.amount, 24.99);
      expect(transaction?.currency, 'GBP');
      expect(transaction?.merchant, 'TESCO');
    });

    test('Barclays UK Parse', () {
      final sms =
          "Barclays: Payment of \u00A310.00 to O2 was successful on 10/10/2025.";
      final transaction = BankParserFactory.parseTransaction(
        sms,
        "BARCLAYS",
        DateTime.now().millisecondsSinceEpoch,
      );

      print(
        'Barclays parsed: ${transaction?.amount}, ${transaction?.bankName}',
      );
      expect(transaction, isNotNull);
      expect(transaction?.bankName, 'Barclays');
      expect(transaction?.amount, 10.00);
      expect(transaction?.currency, 'GBP');
      expect(transaction?.merchant, 'O2');
    });
  });

  group('UAE Banks Parser Tests', () {
    test('Emirates NBD Parse', () {
      final sms =
          "Purchase of AED 150.00 with card ending 8888 at CARREFOUR. Available Limit AED 5000.";
      final transaction = BankParserFactory.parseTransaction(
        sms,
        "EmiratesNBD",
        DateTime.now().millisecondsSinceEpoch,
      );

      print(
        'Emirates parsed: ${transaction?.amount}, ${transaction?.bankName}',
      );
      expect(transaction, isNotNull);
      expect(transaction?.bankName, 'Emirates NBD');
      expect(transaction?.amount, 150.00);
      expect(transaction?.currency, 'AED');
      expect(transaction?.merchant, 'CARREFOUR');
    });

    test('ADCB Parse', () {
      final sms = "ADCB Alert: AED 50.00 withdrawn from ATM. Balance AED 1000.";
      final transaction = BankParserFactory.parseTransaction(
        sms,
        "ADCB",
        DateTime.now().millisecondsSinceEpoch,
      );

      print('ADCB parsed: ${transaction?.amount}, ${transaction?.bankName}');
      expect(transaction, isNotNull);
      expect(transaction?.bankName, 'ADCB');
      expect(transaction?.amount, 50.00);
      expect(transaction?.currency, 'AED');
    });
  });
}
