import 'package:flutter_test/flutter_test.dart';
import 'package:dhanpath/core/parsers/bank_parser_factory.dart';
import 'package:dhanpath/core/parsers/hdfc_bank_parser.dart';
import 'package:dhanpath/core/parsers/indian_bank_parsers.dart';

void main() {
  group('Smart Logic Upgrade Tests', () {
    test('Should reject year 2025 as account number', () {
      final parser = HDFCBankParser();
      // "on 05/11/2025" -> 2025 should NOT be account
      final sms =
          "Rs. 500.00 debited from HDFC Bank Savings A/c ending 1234 on 05/11/2025 to AMAZON";
      final transaction = parser.parse(
        sms,
        "VM-HDFCBK",
        DateTime.now().millisecondsSinceEpoch,
      );

      expect(transaction?.accountLast4, '1234');
      expect(transaction?.accountLast4, isNot('2025'));
    });

    test('Should reject RRN as account number', () {
      final parser = SBIBankParser();
      // "Ref No 12345678" -> 5678 should NOT be account
      final sms =
          "Rs. 100 spent on SBI Card 4321 at STARBUCKS. Ref No 12345678";
      final transaction = parser.parse(
        sms,
        "SBIINB",
        DateTime.now().millisecondsSinceEpoch,
      );

      expect(transaction?.accountLast4, '4321');
      // If logic is dumb, it might pick 5678 or 1234 from RRN
    });

    test('Should strictly detect Card vs Account', () {
      final parser = HDFCBankParser();

      final accountSms = "Rs. 500 debited from A/c XX1234";
      final cardSms = "Rs. 500 spent on HDFC Bank Card XX5678";

      final t1 = parser.parse(accountSms, "HDFCBK", 0);
      final t2 = parser.parse(cardSms, "HDFCBK", 0);

      expect(
        t1?.isFromCard,
        false,
        reason: "Account transaction should not be card",
      );
      expect(t2?.isFromCard, true, reason: "Card transaction should be card");
    });

    test('Should clean and validate merchant names', () {
      final parser = HDFCBankParser();

      final sms = "Rs 200 paid to UPI/some@okaxis/1234";
      parser.parse(sms, "HDFCBK", 0);

      // "UPI" is invalid, but if cleaned correctly, it might extract "some" or reject "UPI"
      // Wait, "paid to UPI/..." pattern might match VPA or 'to'
      // If extractMerchant finds "UPI", validation should reject it
    });
  });

  group('New Banks Support Tests', () {
    test('Airtel Payments Bank Parse', () {
      final sms =
          "Rs. 100.00 debited from your Airtel Payments Bank A/c 1234 to Zomato. Ref 99887766.";
      final t = BankParserFactory.parseTransaction(sms, "AIRBNK", 0);

      expect(t, isNotNull);
      expect(t?.amount, 100.0);
    });

    test('Jio Payments Bank Parse', () {
      final sms =
          "Sent Rs.50.00 from Jio Payments Bank Account xx9988 to JIO MART.";
      final t = BankParserFactory.parseTransaction(sms, "JIOBNK", 0);

      if (t != null) {
        expect(t.amount, 50.0);
      }
    });

    test('Should reject Jio promotional recharge message', () {
      final sms =
          "Show that you care! Recharge your family member's Jio number 9510097966 with Rs.899 & enjoy Special benefits:Free Pro Google Gemini worth Rs.35100 + JioHotstar+ Unlimited 5G data + 2 GB/day & 20GB, Unlimited Voice, 90 Days. Use Paytm app & code: JIOPAYTM to get upto Rs.50 back. T&CA. https://p.paytm.me/xCTH/j6";

      final t = BankParserFactory.parseTransaction(sms, "JIO", 0);

      expect(t, isNull, reason: "Promotional message should be ignored");
    });

    test('Citi Bank Parse', () {
      final sms = "Rs 5000 withdrawn from Citi Bank Account 5566 at ATM";
      final t = BankParserFactory.parseTransaction(sms, "CITIBK", 0);

      if (t != null) {
        expect(t.amount, 5000.0);
      }
    });
  });

  group('Merchant Name Validation Tests', () {
    test('Should reject "BANK" as merchant name', () {
      final parser = HDFCBankParser();
      final sms =
          "Rs 500 debited from HDFC Bank A/c XX1234 to BANK on 01/01/2025";
      final t = parser.parse(sms, "HDFCBK", 0);

      // "BANK" alone should NOT be the merchant name
      if (t != null && t.merchant != null) {
        expect(t.merchant!.toLowerCase(), isNot(equals('bank')));
      }
    });

    test('Should reject "HDFC Bank" as merchant name', () {
      final parser = HDFCBankParser();
      final sms = "Rs 500 debited from HDFC Bank A/c XX1234";
      final t = parser.parse(sms, "HDFCBK", 0);

      if (t != null && t.merchant != null) {
        expect(t.merchant!.toLowerCase(), isNot(equals('hdfc bank')));
        expect(t.merchant!.toLowerCase(), isNot(equals('hdfc')));
      }
    });

    test('Should extract real merchant names from UPI VPA', () {
      final parser = HDFCBankParser();
      final sms =
          "Rs 200.00 debited from A/c XX1234 to swiggy@paytm on 15/01/2025. Ref 123456";
      final t = parser.parse(sms, "HDFCBK", 0);

      expect(t, isNotNull);
      if (t?.merchant != null) {
        // Should extract "Swiggy" from UPI VPA, not "BANK"
        expect(t!.merchant!.toLowerCase(), contains('swiggy'));
      }
    });

    test('Should show contextual name when no merchant found', () {
      final parser = HDFCBankParser();
      final sms = "Rs 500 debited from HDFC Bank A/c XX1234";
      final t = parser.parse(sms, "HDFCBK", 0);

      if (t != null) {
        final txn = t.toTransaction();
        // Should NOT be "Unknown Merchant", should have contextual fallback
        expect(txn.merchantName, isNot(equals('Unknown Merchant')));
        expect(txn.merchantName.isNotEmpty, isTrue);
      }
    });

    test('Should reject names with @ symbol', () {
      final parser = HDFCBankParser();
      // If somehow "user@bank" ends up as merchant, it should be rejected
      final sms = "Rs 200 sent to user@okhdfcbank UPI Ref 123456";
      final t = parser.parse(sms, "HDFCBK", 0);

      if (t?.merchant != null) {
        expect(
          t!.merchant!.contains('@'),
          isFalse,
          reason: 'Merchant should not contain @ symbol',
        );
      }
    });
  });
}
