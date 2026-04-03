import 'bank_parser_base.dart';

// ============================================================
// Extended Indian Bank Parsers
// Each parser handles the specific SMS formats that the bank
// actually sends. The GenericIndianBankParser (fallback) still
// catches anything these miss, but having dedicated parsers
// gives much better merchant / reference / balance extraction.
// ============================================================

// ────────────────────────────────────────────────────────────
// BANK OF INDIA (BOI)
// ────────────────────────────────────────────────────────────
// Debit:  Rs.100.00 debited A/cXX0155 and credited to YADAV KALPESHBHAI
//         via UPI Ref No 641547925176 on 18Feb26. Call 18001031906,
//         if not done by you. -BOI
// Credit: BOI -  Rs.2000.00 Credited to your Ac XX0155 on 16-02-26
//         by UPI ref No.055621196526.Avl Bal 2558.72
// ATM:    Rs.500.00 withdrawn from your A/cXX0155 at ATM on 15Feb26.
//         Avl Bal 2058.72 -BOI
// NEFT:   Rs.10000.00 credited to your A/cXX0155 on 10-02-26 by NEFT
//         from RAHUL SHARMA ref No.N055621196526.Avl Bal 12558.72
// ────────────────────────────────────────────────────────────
class BOIBankParser extends BankParser {
  @override
  String getBankName() => 'Bank of India';

  @override
  bool canHandle(String sender) {
    final s = sender.toUpperCase();
    return s.contains('BOIIND') ||
        s.contains('BOISMS') ||
        (s.contains('BOI') && !s.contains('OBOI'));
  }

  @override
  String? extractMerchant(String message, String sender) {
    final lower = message.toLowerCase();

    // "credited to YADAV KALPESHBHAI via UPI"
    final toMatch = RegExp(
      r'credited\s+to\s+([A-Za-z][A-Za-z\s]+?)(?:\s+via|\s+on|\s+Ref)',
      caseSensitive: false,
    ).firstMatch(message);
    if (toMatch != null) {
      final name = toMatch.group(1)!.trim();
      if (!RegExp(r'^(?:your|A/c|Ac)\b', caseSensitive: false).hasMatch(name)) {
        return cleanMerchantName(name);
      }
    }

    // "by UPI ref" / "by NEFT from NAME ref"
    final fromMatch = RegExp(
      r'by\s+(?:NEFT|RTGS|IMPS)\s+from\s+([A-Za-z][A-Za-z\s]+?)(?:\s+ref|\s+on|\.)',
      caseSensitive: false,
    ).firstMatch(message);
    if (fromMatch != null) {
      return cleanMerchantName(fromMatch.group(1)!.trim());
    }

    if (lower.contains('atm')) return 'ATM';

    return super.extractMerchant(message, sender);
  }

  @override
  String? extractReference(String message) {
    // "Ref No 641547925176" or "ref No.055621196526"
    final m = RegExp(
      r'ref\s+No\.?\s*([A-Za-z]?\d{6,16})',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return m.group(1);
    return super.extractReference(message);
  }

  @override
  String? extractAccountLast4(String message) {
    // A/cXX0155 or Ac XX0155
    final m = RegExp(
      r'A/?c\s*[Xx*]+(\d{4})',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return m.group(1);
    return super.extractAccountLast4(message);
  }

  @override
  double? extractBalance(String message) {
    final m = RegExp(
      r'Avl\s*Bal\s*(?:Rs\.?\s*)?([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return double.tryParse(m.group(1)!.replaceAll(',', ''));
    return super.extractBalance(message);
  }
}

// ────────────────────────────────────────────────────────────
// PUNJAB NATIONAL BANK (PNB)
// ────────────────────────────────────────────────────────────
// Debit:  Dear Customer, Rs.500.00 has been Debited from your A/c
//         XXXXXX1234 on 15-02-26, UPI Ref No:640512345678, to
//         RAHUL SHARMA . Bal: Rs.2500.00 -PNB
// Credit: Dear Customer, Rs.1000.00 has been Credited to your A/c
//         XXXXXX1234 on 16-02-26, UPI Ref No.640612345678.
//         Bal: Rs.3500.00 -PNB
// NEFT:   Dear Customer Rs.25000 credited to your A/c XXXXXX1234 on
//         12-02-26 by NEFT RAMESH KUMAR Ref No N055621. Bal Rs.28500
// ATM:    Dear Customer Rs.2000.00 withdrawn from your A/c XXXXXX1234
//         at ATM on 14-02-26. Bal Rs.26500.00 -PNB
// Card:   Rs.1299.00 has been spent on your PNB Debit Card ending
//         1234 at AMAZON on 13-02-26. Bal Rs.25201.00
// ────────────────────────────────────────────────────────────
class PNBBankParser extends BankParser {
  @override
  String getBankName() => 'Punjab National Bank';

  @override
  bool canHandle(String sender) {
    final s = sender.toUpperCase();
    return s.contains('PNBSMS') ||
        s.contains('PUNBAN') ||
        (s.contains('PNB') && !s.contains('APNB'));
  }

  @override
  String? extractMerchant(String message, String sender) {
    final lower = message.toLowerCase();

    // "to RAHUL SHARMA ."
    final toMatch = RegExp(
      r'to\s+([A-Za-z][A-Za-z\s]+?)\s*(?:\.|,|Bal|$)',
      caseSensitive: false,
    ).firstMatch(message);
    if (toMatch != null) {
      final name = toMatch.group(1)!.trim();
      if (!RegExp(r'^(?:your|A/c|Ac)\b', caseSensitive: false).hasMatch(name)) {
        final cleaned = cleanMerchantName(name);
        if (isValidMerchant(cleaned)) return cleaned;
      }
    }

    // "by NEFT RAMESH KUMAR Ref"
    final neftMatch = RegExp(
      r'by\s+(?:NEFT|RTGS|IMPS)\s+([A-Za-z][A-Za-z\s]+?)(?:\s+Ref|\s+on|\.)',
      caseSensitive: false,
    ).firstMatch(message);
    if (neftMatch != null) return cleanMerchantName(neftMatch.group(1)!.trim());

    // "at AMAZON on"
    final atMatch = RegExp(
      r'at\s+([A-Za-z][A-Za-z0-9\s&\.\-]+?)(?:\s+on|\s+Ref|\.)',
      caseSensitive: false,
    ).firstMatch(message);
    if (atMatch != null) {
      final cleaned = cleanMerchantName(atMatch.group(1)!.trim());
      if (isValidMerchant(cleaned)) return cleaned;
    }

    if (lower.contains('atm')) return 'ATM';
    return super.extractMerchant(message, sender);
  }

  @override
  String? extractReference(String message) {
    final m = RegExp(
      r'Ref\s+No[.:]?\s*([A-Za-z]?\d{6,16})',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return m.group(1);
    return super.extractReference(message);
  }

  @override
  double? extractBalance(String message) {
    final m = RegExp(
      r'Bal[:\s]+(?:Rs\.?\s*)?([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return double.tryParse(m.group(1)!.replaceAll(',', ''));
    return super.extractBalance(message);
  }
}

// ────────────────────────────────────────────────────────────
// CANARA BANK
// ────────────────────────────────────────────────────────────
// Debit:  Rs.1500.00 debited from A/c XX3456 on 15Feb26.
//         UPI-MERCHANT NAME-UPI Ref 406512345678.
//         Avl Bal Rs.8500.00 -CANARA BANK
// Credit: Rs.2000.00 credited to A/c XX3456 on 16-02-2026.
//         NEFT from KUMAR RAHUL. Ref AXIR25004061234.
//         Avl Bal Rs.10500.00 -CANARA BANK
// UPI:    Rs.200.00 Debited from A/c XX3456 to VPA merchant@ybl
//         on 14-02-2026. UPI Ref: 405612345678.
//         Avl Bal Rs.10300.00 -Canara Bank
// Card:   Rs.999.00 spent on Canara Bank Card XX5678 at FLIPKART
//         on 13-02-2026. Avl Bal Rs.9301.00
// ────────────────────────────────────────────────────────────
class CanaraBankParser extends BankParser {
  @override
  String getBankName() => 'Canara Bank';

  @override
  bool canHandle(String sender) {
    final s = sender.toUpperCase();
    return s.contains('CANBNK') || s.contains('CANARA') || s.contains('CANBKS');
  }

  @override
  String? extractMerchant(String message, String sender) {
    final lower = message.toLowerCase();

    // "UPI-MERCHANT NAME-UPI Ref"
    final upiDash = RegExp(
      r'UPI[- ]([A-Za-z][A-Za-z0-9\s]+?)[- ]UPI\s+Ref',
      caseSensitive: false,
    ).firstMatch(message);
    if (upiDash != null) return cleanMerchantName(upiDash.group(1)!.trim());

    // "to VPA merchant@ybl"
    final vpa = RegExp(
      r'VPA\s+([^\s@]+)@',
      caseSensitive: false,
    ).firstMatch(message);
    if (vpa != null)
      return cleanMerchantName(extractMerchantFromUpiVpa('${vpa.group(1)!}@x'));

    // "NEFT from KUMAR RAHUL"
    final from = RegExp(
      r'(?:NEFT|RTGS|IMPS)\s+from\s+([A-Za-z][A-Za-z\s]+?)(?:\.\s|Ref|$)',
      caseSensitive: false,
    ).firstMatch(message);
    if (from != null) return cleanMerchantName(from.group(1)!.trim());

    // "at FLIPKART on"
    final atMatch = RegExp(
      r'at\s+([A-Za-z][A-Za-z0-9\s&\.\-]+?)(?:\s+on|\s+Ref|\.)',
      caseSensitive: false,
    ).firstMatch(message);
    if (atMatch != null) {
      final cleaned = cleanMerchantName(atMatch.group(1)!.trim());
      if (isValidMerchant(cleaned)) return cleaned;
    }

    if (lower.contains('atm')) return 'ATM';
    return super.extractMerchant(message, sender);
  }

  @override
  String? extractReference(String message) {
    final m = RegExp(
      r'(?:UPI\s+)?Ref[:\s]+([A-Za-z0-9]{8,20})',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return m.group(1);
    return super.extractReference(message);
  }

  @override
  double? extractBalance(String message) {
    final m = RegExp(
      r'Avl\s*Bal\s*(?:Rs\.?\s*)?([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return double.tryParse(m.group(1)!.replaceAll(',', ''));
    return super.extractBalance(message);
  }
}

// ────────────────────────────────────────────────────────────
// UNION BANK OF INDIA
// ────────────────────────────────────────────────────────────
// Debit:  Dear Customer, INR 500.00 is Debited from A/c ..1234 on
//         15-Feb-26 (UPI Ref no 640512345678). To VPA rakesh@ybl.
//         If not done by you call 18002082244 -Union Bank
// Credit: Dear Customer, INR 2000.00 is Credited to A/c ..1234 on
//         16-Feb-26 (UPI Ref no 640612345678). Avl Bal: INR 4500.00
//         -Union Bank
// NEFT:   INR 15000.00 Credited to your A/c ..1234 on 12-Feb-26.
//         NEFT from SURESH PATEL Ref N0556212345. Avl Bal INR 19500.00
// Card:   INR 799.00 debited from Card XX5678 at SWIGGY on 13-Feb-26.
//         Avl Bal INR 18701.00 -Union Bank
// Alt:    A/c *0112 Credited for Rs:207.00 on 16-05-2025 08:26:02
//         by Mob Bk ref no 513600683228 Avl Bal Rs:429330.90.
//         Never Share OTP/PIN/CVV-Union Bank of India
// AltDr:  A/c *0112 Debited for Rs:500.00 on 16-05-2025 10:15:00
//         to VPA merchant@upi ref no 513600683999 Avl Bal Rs:428830.90.
//         -Union Bank of India
// ────────────────────────────────────────────────────────────
class UnionBankParser extends BankParser {
  @override
  String getBankName() => 'Union Bank';

  @override
  bool canHandle(String sender) {
    final s = sender.toUpperCase();
    return s.contains('UNIONB') || s.contains('UBOI') || s.contains('UBIINB');
  }

  @override
  String? extractMerchant(String message, String sender) {
    final lower = message.toLowerCase();

    // "To VPA rakesh@ybl" or "to VPA merchant@upi"
    final vpa = RegExp(
      r'VPA\s+([^\s@]+)@',
      caseSensitive: false,
    ).firstMatch(message);
    if (vpa != null)
      return cleanMerchantName(extractMerchantFromUpiVpa('${vpa.group(1)!}@x'));

    // "to merchant@upi" (without VPA prefix)
    final toVpa = RegExp(
      r'to\s+([^\s@]+@[^\s.]+)',
      caseSensitive: false,
    ).firstMatch(message);
    if (toVpa != null)
      return cleanMerchantName(extractMerchantFromUpiVpa(toVpa.group(1)!));

    // "NEFT from SURESH PATEL Ref"
    final from = RegExp(
      r'(?:NEFT|RTGS|IMPS)\s+from\s+([A-Za-z][A-Za-z\s]+?)(?:\s+Ref|\.|$)',
      caseSensitive: false,
    ).firstMatch(message);
    if (from != null) return cleanMerchantName(from.group(1)!.trim());

    // "by Mob Bk" → mobile banking transfer (no specific merchant)
    if (lower.contains('mob bk') || lower.contains('mobile banking')) {
      return 'Mobile Banking Transfer';
    }

    // "at SWIGGY on"
    final atMatch = RegExp(
      r'at\s+([A-Za-z][A-Za-z0-9\s&\.\-]+?)(?:\s+on|\.|$)',
      caseSensitive: false,
    ).firstMatch(message);
    if (atMatch != null) {
      final cleaned = cleanMerchantName(atMatch.group(1)!.trim());
      if (isValidMerchant(cleaned)) return cleaned;
    }

    if (lower.contains('atm')) return 'ATM';
    return super.extractMerchant(message, sender);
  }

  @override
  String? extractReference(String message) {
    final m = RegExp(
      r'[Rr]ef\s+(?:no\s+)?([A-Za-z]?\d{6,16})',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return m.group(1);
    return super.extractReference(message);
  }

  @override
  double? extractBalance(String message) {
    // "Avl Bal Rs:429330.90" or "Avl Bal: INR 15000.00"
    final m = RegExp(
      r'Avl\s*Bal[:\s]*(?:INR|Rs[.:]?)\s*([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return double.tryParse(m.group(1)!.replaceAll(',', ''));
    return super.extractBalance(message);
  }
}

// ────────────────────────────────────────────────────────────
// BANK OF BARODA (BOB)
// ────────────────────────────────────────────────────────────
// Debit:  INR 1000.00 debited from your a/c XX4567 on 15/02/26.
//         Info: UPI/RAHUL/upi ref/406512345678.
//         Avl Bal: INR 15000.00 -Bank of Baroda
// Credit: Your a/c XX4567 credited INR 5000.00 on 16/02/26.
//         Info: NEFT/SBIN0001234/RAVI KUMAR.
//         Avl Bal: INR 20000.00 -BOB
// UPI:    INR 250.00 debited from A/c XX4567 to VPA shop@upi
//         on 14/02/26. UPI Ref 405612345678.
//         Avl Bal: INR 19750.00 -Bank of Baroda
// ATM:    INR 2000.00 withdrawn from A/c XX4567 at ATM 15/02/26.
//         Avl Bal: INR 17750.00 -Bank of Baroda
// Dr/Cr:  Rs.34.00 Dr. from A/C XXXXXX2623 and Cr. to gsrtc111@icici.
//         Ref:643083561953. AvlBal:Rs4070.50(2026:03:05 05:40:04).
//         Not you? Call 18005700/5000-BOB
// ────────────────────────────────────────────────────────────
class BOBBankParser extends BankParser {
  @override
  String getBankName() => 'Bank of Baroda';

  @override
  bool canHandle(String sender) {
    final s = sender.toUpperCase();
    return s.contains('BOBTXN') || s.contains('BOBSMS') || s.contains('BARODA');
  }

  @override
  String? extractMerchant(String message, String sender) {
    final lower = message.toLowerCase();

    // "Info: UPI/RAHUL/upi ref/..."
    final infoUpi = RegExp(
      r'Info:\s*UPI/([A-Za-z][A-Za-z0-9\s]+?)/',
      caseSensitive: false,
    ).firstMatch(message);
    if (infoUpi != null) return cleanMerchantName(infoUpi.group(1)!.trim());

    // "Info: NEFT/SBIN.../RAVI KUMAR"
    final infoNeft = RegExp(
      r'Info:\s*(?:NEFT|RTGS|IMPS)/[A-Z0-9]+/([A-Za-z][A-Za-z\s]+?)(?:\.|$)',
      caseSensitive: false,
    ).firstMatch(message);
    if (infoNeft != null) return cleanMerchantName(infoNeft.group(1)!.trim());

    // "to VPA shop@upi"
    final vpa = RegExp(
      r'VPA\s+([^\s@]+)@',
      caseSensitive: false,
    ).firstMatch(message);
    if (vpa != null)
      return cleanMerchantName(extractMerchantFromUpiVpa('${vpa.group(1)!}@x'));

    // "Cr. to gsrtc111@icici" or "Cr. to RAVI KUMAR" (Dr./Cr. format)
    final crTo = RegExp(
      r'Cr\.\s+to\s+([^\s@.]+(?:@[^\s.]+)?)',
      caseSensitive: false,
    ).firstMatch(message);
    if (crTo != null) {
      final raw = crTo.group(1)!.trim();
      if (raw.contains('@')) {
        return cleanMerchantName(extractMerchantFromUpiVpa(raw));
      }
      return cleanMerchantName(raw);
    }

    if (lower.contains('atm')) return 'ATM';
    return super.extractMerchant(message, sender);
  }

  @override
  String? extractReference(String message) {
    // "UPI Ref 405612345678" or "upi ref/406512345678" or "Ref:643083561953"
    final m = RegExp(
      r'(?:UPI\s+)?[Rr]ef[/:\s]+(\d{8,16})',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return m.group(1);
    return super.extractReference(message);
  }

  @override
  String? extractAccountLast4(String message) {
    // "A/C XXXXXX2623" or "a/c XX4567"
    final m = RegExp(
      r'A/?C\s*[Xx]*([0-9]{4,6})',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) {
      final digits = m.group(1)!;
      return digits.length > 4 ? digits.substring(digits.length - 4) : digits;
    }
    return super.extractAccountLast4(message);
  }

  @override
  double? extractBalance(String message) {
    // "Avl Bal: INR 15000.00" or "AvlBal:Rs4070.50"
    final m = RegExp(
      r'Avl\s*Bal[:\s]*(?:INR|Rs\.?)\s*([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return double.tryParse(m.group(1)!.replaceAll(',', ''));
    return super.extractBalance(message);
  }
}

// ────────────────────────────────────────────────────────────
// YES BANK
// ────────────────────────────────────────────────────────────
// Debit:  Dear Customer, Rs.500.00 has been debited from A/c ending
//         1234 on 15-Feb-26 to VPA ravi@ybl (UPI Ref: 640512345678).
//         Avl Bal Rs.8500.00 -YES BANK
// Credit: Rs.3000.00 credited to your A/c ending 1234 on 16-Feb-26.
//         UPI Ref: 640612345678. Avl Bal Rs.11500.00 -YES BANK
// NEFT:   Dear Customer Rs.10000 credited to A/c ending 1234 on
//         12-Feb-26. NEFT from RAJESH SINGH ref YESB2605612.
//         Avl Bal Rs.21500.00 -YES BANK
// Card:   Rs.1499 spent on YES BANK Card ending 5678 at MYNTRA on
//         11-Feb-26. If not done by you call 18001200 -YES BANK
// ────────────────────────────────────────────────────────────
class YesBankParser extends BankParser {
  @override
  String getBankName() => 'Yes Bank';

  @override
  bool canHandle(String sender) {
    final s = sender.toUpperCase();
    return s.contains('YESBK') ||
        s.contains('YESBNK') ||
        s.contains('YESBANK') ||
        s.contains('YESB');
  }

  @override
  String? extractMerchant(String message, String sender) {
    final lower = message.toLowerCase();

    // "to VPA ravi@ybl"
    final vpa = RegExp(
      r'VPA\s+([^\s@]+)@',
      caseSensitive: false,
    ).firstMatch(message);
    if (vpa != null)
      return cleanMerchantName(extractMerchantFromUpiVpa('${vpa.group(1)!}@x'));

    // "to NAME (UPI Ref"
    final toUpi = RegExp(
      r'to\s+([A-Za-z][A-Za-z\s]+?)\s*\(UPI',
      caseSensitive: false,
    ).firstMatch(message);
    if (toUpi != null) {
      final name = toUpi.group(1)!.trim();
      if (!name.toLowerCase().startsWith('vpa')) {
        return cleanMerchantName(name);
      }
    }

    // "NEFT from RAJESH SINGH ref"
    final from = RegExp(
      r'(?:NEFT|RTGS|IMPS)\s+from\s+([A-Za-z][A-Za-z\s]+?)(?:\s+ref|\.|$)',
      caseSensitive: false,
    ).firstMatch(message);
    if (from != null) return cleanMerchantName(from.group(1)!.trim());

    // "at MYNTRA on"
    final atMatch = RegExp(
      r'at\s+([A-Za-z][A-Za-z0-9\s&\.\-]+?)(?:\s+on|\.|$)',
      caseSensitive: false,
    ).firstMatch(message);
    if (atMatch != null) {
      final cleaned = cleanMerchantName(atMatch.group(1)!.trim());
      if (isValidMerchant(cleaned)) return cleaned;
    }

    if (lower.contains('atm')) return 'ATM';
    return super.extractMerchant(message, sender);
  }

  @override
  String? extractReference(String message) {
    final m = RegExp(
      r'(?:UPI\s+)?Ref[:\s]+([A-Za-z0-9]{8,20})',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return m.group(1);
    return super.extractReference(message);
  }

  @override
  double? extractBalance(String message) {
    final m = RegExp(
      r'Avl\s*Bal\s*(?:Rs\.?\s*)?([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return double.tryParse(m.group(1)!.replaceAll(',', ''));
    return super.extractBalance(message);
  }
}

// ────────────────────────────────────────────────────────────
// IDFC FIRST BANK
// ────────────────────────────────────────────────────────────
// Debit:  Rs.750 debited from IDFC FIRST Bank A/c XX5678 on 15Feb26.
//         UPI/ravi.kumar@okaxis/Ref 640512345678.
//         Avl Bal Rs.9250 -IDFC FIRST Bank
// Credit: Rs.5000 credited to IDFC FIRST Bank A/c XX5678 on 16Feb26.
//         UPI Ref No 640612345678. Avl Bal Rs.14250 -IDFC FIRST Bank
// IMPS:   Rs.10000 credited to your A/c XX5678 by IMPS from PRIYA SHAH
//         Ref 5056212345 on 12Feb26. Avl Bal Rs.24250 -IDFC FIRST Bank
// Card:   Rs.2999 spent on IDFC FIRST Bank Card XX9012 at CROMA on
//         11Feb26. Avl Bal Rs.21251 -IDFC FIRST Bank
// ────────────────────────────────────────────────────────────
class IDFCFirstBankParser extends BankParser {
  @override
  String getBankName() => 'IDFC First Bank';

  @override
  bool canHandle(String sender) {
    final s = sender.toUpperCase();
    return s.contains('IDFCFB') ||
        s.contains('IDFCBK') ||
        (s.contains('IDFC') && !s.contains('CIDFC'));
  }

  @override
  String? extractMerchant(String message, String sender) {
    final lower = message.toLowerCase();

    // "UPI/ravi.kumar@okaxis/Ref"
    final upiSlash = RegExp(
      r'UPI/([^/]+@[^/]+)/',
      caseSensitive: false,
    ).firstMatch(message);
    if (upiSlash != null) {
      return cleanMerchantName(extractMerchantFromUpiVpa(upiSlash.group(1)!));
    }

    // "UPI/MERCHANT NAME/Ref"
    final upiMerch = RegExp(
      r'UPI/([A-Za-z][A-Za-z0-9\s\.]+?)/',
      caseSensitive: false,
    ).firstMatch(message);
    if (upiMerch != null) return cleanMerchantName(upiMerch.group(1)!.trim());

    // "IMPS from PRIYA SHAH Ref"
    final from = RegExp(
      r'(?:NEFT|RTGS|IMPS)\s+from\s+([A-Za-z][A-Za-z\s]+?)(?:\s+Ref|\s+on|\.|$)',
      caseSensitive: false,
    ).firstMatch(message);
    if (from != null) return cleanMerchantName(from.group(1)!.trim());

    // "at CROMA on"
    final atMatch = RegExp(
      r'at\s+([A-Za-z][A-Za-z0-9\s&\.\-]+?)(?:\s+on|\.|$)',
      caseSensitive: false,
    ).firstMatch(message);
    if (atMatch != null) {
      final cleaned = cleanMerchantName(atMatch.group(1)!.trim());
      if (isValidMerchant(cleaned)) return cleaned;
    }

    if (lower.contains('atm')) return 'ATM';
    return super.extractMerchant(message, sender);
  }

  @override
  String? extractReference(String message) {
    final m = RegExp(
      r'Ref\s+(?:No\s+)?(\d{8,16})',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return m.group(1);
    return super.extractReference(message);
  }

  @override
  double? extractBalance(String message) {
    final m = RegExp(
      r'Avl\s*Bal\s*(?:Rs\.?\s*)?([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return double.tryParse(m.group(1)!.replaceAll(',', ''));
    return super.extractBalance(message);
  }
}

// ────────────────────────────────────────────────────────────
// INDUSIND BANK
// ────────────────────────────────────────────────────────────
// Debit:  Rs 1500 debited from your IndusInd Bank A/c xx1234 on
//         15-02-26. Info: UPI/RAVI KUMAR/Ref 640512345678.
//         Bal: Rs 8500.00 -IndusInd Bank
// Credit: Rs 3000 credited to your IndusInd Bank A/c xx1234 on
//         16-02-26. Info: UPI/Ref 640612345678.
//         Bal: Rs 11500.00 -IndusInd Bank
// NEFT:   Rs 20000 credited to your A/c xx1234 on 12-02-26.
//         NEFT: ANITA DESAI/Ref NI056212345.
//         Bal Rs 31500 -IndusInd Bank
// Card:   Rs.899 spent on your IndusInd Bank Card ending 5678 at
//         ZOMATO on 11-02-26. Bal Rs 30601 -IndusInd Bank
// ────────────────────────────────────────────────────────────
class IndusIndBankParser extends BankParser {
  @override
  String getBankName() => 'IndusInd Bank';

  @override
  bool canHandle(String sender) {
    final s = sender.toUpperCase();
    return s.contains('INDUSB') ||
        s.contains('INDBNK') ||
        (s.contains('INDUS') && !s.contains('HINDUS'));
  }

  @override
  String? extractMerchant(String message, String sender) {
    final lower = message.toLowerCase();

    // "Info: UPI/RAVI KUMAR/Ref"
    final infoUpi = RegExp(
      r'Info:\s*UPI/([A-Za-z][A-Za-z0-9\s]+?)/',
      caseSensitive: false,
    ).firstMatch(message);
    if (infoUpi != null) return cleanMerchantName(infoUpi.group(1)!.trim());

    // "Info: UPI/vpa@bank/Ref" format
    final infoVpa = RegExp(
      r'Info:\s*UPI/([^/]+@[^/]+)/',
      caseSensitive: false,
    ).firstMatch(message);
    if (infoVpa != null) {
      return cleanMerchantName(extractMerchantFromUpiVpa(infoVpa.group(1)!));
    }

    // "NEFT: ANITA DESAI/Ref"
    final neftMatch = RegExp(
      r'(?:NEFT|RTGS|IMPS):\s*([A-Za-z][A-Za-z\s]+?)/(?:Ref|$)',
      caseSensitive: false,
    ).firstMatch(message);
    if (neftMatch != null) return cleanMerchantName(neftMatch.group(1)!.trim());

    // "at ZOMATO on"
    final atMatch = RegExp(
      r'at\s+([A-Za-z][A-Za-z0-9\s&\.\-]+?)(?:\s+on|\.|$)',
      caseSensitive: false,
    ).firstMatch(message);
    if (atMatch != null) {
      final cleaned = cleanMerchantName(atMatch.group(1)!.trim());
      if (isValidMerchant(cleaned)) return cleaned;
    }

    if (lower.contains('atm')) return 'ATM';
    return super.extractMerchant(message, sender);
  }

  @override
  String? extractReference(String message) {
    final m = RegExp(
      r'Ref\s+([A-Za-z]?\d{6,16})',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return m.group(1);
    return super.extractReference(message);
  }

  @override
  double? extractBalance(String message) {
    final m = RegExp(
      r'Bal[:\s]+(?:Rs\.?\s*)?([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return double.tryParse(m.group(1)!.replaceAll(',', ''));
    return super.extractBalance(message);
  }
}

// ────────────────────────────────────────────────────────────
// BANDHAN BANK
// ────────────────────────────────────────────────────────────
// Debit:  Rs.500 debited from your Bandhan Bank A/c ending 1234 on
//         15-Feb-2026 towards UPI to ravi@ybl.
//         Avl Bal Rs.7500. Ref 640512345678 -Bandhan Bank
// Credit: Rs.2000 credited to your Bandhan Bank A/c ending 1234 on
//         16-Feb-2026 through UPI. Ref 640612345678.
//         Avl Bal Rs.9500 -Bandhan Bank
// ────────────────────────────────────────────────────────────
class BandhanBankParser extends BankParser {
  @override
  String getBankName() => 'Bandhan Bank';

  @override
  bool canHandle(String sender) {
    final s = sender.toUpperCase();
    return s.contains('BANDHN') ||
        s.contains('BANDHAN') ||
        s.contains('BANDBN');
  }

  @override
  String? extractMerchant(String message, String sender) {
    final lower = message.toLowerCase();

    // "to ravi@ybl" (VPA after to)
    final vpa = RegExp(
      r'to\s+([^\s@]+@[^\s\.]+)',
      caseSensitive: false,
    ).firstMatch(message);
    if (vpa != null)
      return cleanMerchantName(extractMerchantFromUpiVpa(vpa.group(1)!));

    // "towards UPI to NAME"
    final towards = RegExp(
      r'towards\s+UPI\s+to\s+([A-Za-z][A-Za-z\s]+?)(?:\.|Ref|Avl|$)',
      caseSensitive: false,
    ).firstMatch(message);
    if (towards != null) return cleanMerchantName(towards.group(1)!.trim());

    if (lower.contains('atm')) return 'ATM';
    return super.extractMerchant(message, sender);
  }

  @override
  String? extractReference(String message) {
    final m = RegExp(
      r'Ref\s+(\d{8,16})',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return m.group(1);
    return super.extractReference(message);
  }

  @override
  double? extractBalance(String message) {
    final m = RegExp(
      r'Avl\s*Bal\s*(?:Rs\.?\s*)?([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return double.tryParse(m.group(1)!.replaceAll(',', ''));
    return super.extractBalance(message);
  }
}

// ────────────────────────────────────────────────────────────
// FEDERAL BANK
// ────────────────────────────────────────────────────────────
// Debit:  INR 800.00 has been debited from your Federal Bank A/c
//         XX6789 towards UPI txn to SURESH@ybl on 15/02/2026.
//         UPI Ref: 640512345678. Bal: INR 10200.00 -Federal Bank
// Credit: INR 5000.00 has been credited to your Federal Bank A/c
//         XX6789 on 16/02/2026. UPI Ref: 640612345678.
//         Bal: INR 15200.00 -Federal Bank
// NEFT:   INR 25000 credited to your A/c XX6789 via NEFT from
//         ANIL MOHAN on 12/02/2026. Ref FEDL2512345.
//         Bal: INR 40200 -Federal Bank
// ────────────────────────────────────────────────────────────
class FederalBankParser extends BankParser {
  @override
  String getBankName() => 'Federal Bank';

  @override
  bool canHandle(String sender) {
    final s = sender.toUpperCase();
    return s.contains('FEDBNK') ||
        s.contains('FEDSMS') ||
        (s.contains('FEDERAL') && !s.contains('CFEDER'));
  }

  @override
  String? extractMerchant(String message, String sender) {
    final lower = message.toLowerCase();

    // "to SURESH@ybl" (VPA)
    final vpa = RegExp(
      r'to\s+([^\s@]+@[^\s\.]+)',
      caseSensitive: false,
    ).firstMatch(message);
    if (vpa != null)
      return cleanMerchantName(extractMerchantFromUpiVpa(vpa.group(1)!));

    // "txn to NAME on" (name without @ sign)
    final toName = RegExp(
      r'txn\s+to\s+([A-Za-z][A-Za-z\s]+?)\s+on',
      caseSensitive: false,
    ).firstMatch(message);
    if (toName != null) return cleanMerchantName(toName.group(1)!.trim());

    // "NEFT from ANIL MOHAN on"
    final from = RegExp(
      r'(?:NEFT|RTGS|IMPS)\s+from\s+([A-Za-z][A-Za-z\s]+?)(?:\s+on|\s+Ref|\.|$)',
      caseSensitive: false,
    ).firstMatch(message);
    if (from != null) return cleanMerchantName(from.group(1)!.trim());

    if (lower.contains('atm')) return 'ATM';
    return super.extractMerchant(message, sender);
  }

  @override
  String? extractReference(String message) {
    final m = RegExp(
      r'(?:UPI\s+)?Ref[:\s]+([A-Za-z0-9]{8,20})',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return m.group(1);
    return super.extractReference(message);
  }

  @override
  double? extractBalance(String message) {
    final m = RegExp(
      r'Bal[:\s]+(?:INR|Rs\.?)\s*([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return double.tryParse(m.group(1)!.replaceAll(',', ''));
    return super.extractBalance(message);
  }
}

// ────────────────────────────────────────────────────────────
// IDBI BANK
// ────────────────────────────────────────────────────────────
// Debit:  Dear Customer, Rs.600 debited from your IDBI Bank A/c
//         ending 1234 on 15-02-2026. UPI to RAVI@ybl
//         Ref No 640512345678. Avl Bal Rs.9400 -IDBI Bank
// Credit: Dear Customer, Rs.3000 credited to IDBI Bank A/c
//         ending 1234 on 16-02-2026. UPI Ref No 640612345678.
//         Avl Bal Rs.12400 -IDBI Bank
// NEFT:   Rs.15000 credited to your IDBI A/c ending 1234 on 12-02-26.
//         From MEERA JOSHI via NEFT, Ref IDBI25056212.
//         Avl Bal Rs.27400 -IDBI Bank
// ────────────────────────────────────────────────────────────
class IDBIBankParser extends BankParser {
  @override
  String getBankName() => 'IDBI Bank';

  @override
  bool canHandle(String sender) {
    final s = sender.toUpperCase();
    return s.contains('IDBIBK') || (s.contains('IDBI') && !s.contains('AIDBI'));
  }

  @override
  String? extractMerchant(String message, String sender) {
    final lower = message.toLowerCase();

    // "UPI to RAVI@ybl" (VPA)
    final vpa = RegExp(
      r'to\s+([^\s@]+@[^\s\.]+)',
      caseSensitive: false,
    ).firstMatch(message);
    if (vpa != null)
      return cleanMerchantName(extractMerchantFromUpiVpa(vpa.group(1)!));

    // "UPI to NAME Ref"
    final toName = RegExp(
      r'UPI\s+to\s+([A-Za-z][A-Za-z\s]+?)\s+Ref',
      caseSensitive: false,
    ).firstMatch(message);
    if (toName != null) return cleanMerchantName(toName.group(1)!.trim());

    // "From MEERA JOSHI via NEFT"
    final fromVia = RegExp(
      r'[Ff]rom\s+([A-Za-z][A-Za-z\s]+?)\s+via',
    ).firstMatch(message);
    if (fromVia != null) return cleanMerchantName(fromVia.group(1)!.trim());

    if (lower.contains('atm')) return 'ATM';
    return super.extractMerchant(message, sender);
  }

  @override
  String? extractReference(String message) {
    final m = RegExp(
      r'Ref\s+(?:No\s+)?([A-Za-z0-9]{8,20})',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return m.group(1);
    return super.extractReference(message);
  }

  @override
  double? extractBalance(String message) {
    final m = RegExp(
      r'Avl\s*Bal\s*(?:Rs\.?\s*)?([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return double.tryParse(m.group(1)!.replaceAll(',', ''));
    return super.extractBalance(message);
  }
}

// ────────────────────────────────────────────────────────────
// INDIAN OVERSEAS BANK (IOB)
// ────────────────────────────────────────────────────────────
// Debit:  Your IOB A/c XX2345 debited for Rs.500 on 15-02-2026.
//         UPI to merchant@upi Ref 640512345678.
//         Avl Bal Rs.7500 -IOB
// Credit: Rs.2000 credited to your IOB A/c XX2345 on 16-02-2026.
//         UPI Ref 640612345678. Avl Bal Rs.9500 -IOB
// ────────────────────────────────────────────────────────────
class IOBBankParser extends BankParser {
  @override
  String getBankName() => 'Indian Overseas Bank';

  @override
  bool canHandle(String sender) {
    final s = sender.toUpperCase();
    return s.contains('IOBA') || (s.contains('IOB') && !s.contains('AIOB'));
  }

  @override
  String? extractMerchant(String message, String sender) {
    final lower = message.toLowerCase();

    // "to merchant@upi"
    final vpa = RegExp(
      r'to\s+([^\s@]+@[^\s\.]+)',
      caseSensitive: false,
    ).firstMatch(message);
    if (vpa != null)
      return cleanMerchantName(extractMerchantFromUpiVpa(vpa.group(1)!));

    // "to NAME Ref/on"
    final toName = RegExp(
      r'to\s+([A-Za-z][A-Za-z\s]+?)(?:\s+Ref|\s+on|\.|$)',
      caseSensitive: false,
    ).firstMatch(message);
    if (toName != null) {
      final cleaned = cleanMerchantName(toName.group(1)!.trim());
      if (isValidMerchant(cleaned)) return cleaned;
    }

    if (lower.contains('atm')) return 'ATM';
    return super.extractMerchant(message, sender);
  }

  @override
  String? extractReference(String message) {
    final m = RegExp(
      r'Ref\s+(\d{8,16})',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return m.group(1);
    return super.extractReference(message);
  }

  @override
  double? extractBalance(String message) {
    final m = RegExp(
      r'Avl\s*Bal\s*(?:Rs\.?\s*)?([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return double.tryParse(m.group(1)!.replaceAll(',', ''));
    return super.extractBalance(message);
  }
}

// ────────────────────────────────────────────────────────────
// UCO BANK
// ────────────────────────────────────────────────────────────
// Debit:  Dear Customer, Rs.1000.00 has been debited from your UCO
//         Bank A/c XXXX1234 on 15-02-2026 by UPI transfer to
//         RAHUL.SHAH@okaxis. Ref 640512345678. Bal Rs.9000.00
// Credit: Dear Customer, Rs.5000.00 has been credited to your UCO
//         Bank A/c XXXX1234 on 16-02-2026 by UPI. Ref 640612345678.
//         Bal Rs.14000.00
// ────────────────────────────────────────────────────────────
class UCOBankParser extends BankParser {
  @override
  String getBankName() => 'UCO Bank';

  @override
  bool canHandle(String sender) {
    final s = sender.toUpperCase();
    return s.contains('UCOBNK') || (s.contains('UCO') && !s.contains('AUCO'));
  }

  @override
  String? extractMerchant(String message, String sender) {
    final lower = message.toLowerCase();

    // "to RAHUL.SHAH@okaxis" (VPA)
    final vpa = RegExp(
      r'to\s+([^\s@]+@[^\s\.]+)',
      caseSensitive: false,
    ).firstMatch(message);
    if (vpa != null)
      return cleanMerchantName(extractMerchantFromUpiVpa(vpa.group(1)!));

    // "transfer to NAME . Ref"
    final toName = RegExp(
      r'transfer\s+to\s+([A-Za-z][A-Za-z\s]+?)(?:\.\s*Ref|\s+Ref|\.|$)',
      caseSensitive: false,
    ).firstMatch(message);
    if (toName != null) return cleanMerchantName(toName.group(1)!.trim());

    if (lower.contains('atm')) return 'ATM';
    return super.extractMerchant(message, sender);
  }

  @override
  String? extractReference(String message) {
    final m = RegExp(
      r'Ref\s+(\d{8,16})',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return m.group(1);
    return super.extractReference(message);
  }

  @override
  double? extractBalance(String message) {
    final m = RegExp(
      r'Bal\s*(?:Rs\.?\s*)?([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return double.tryParse(m.group(1)!.replaceAll(',', ''));
    return super.extractBalance(message);
  }
}

// ────────────────────────────────────────────────────────────
// CENTRAL BANK OF INDIA
// ────────────────────────────────────────────────────────────
// Debit:  Rs.500 debited from A/c XXXX1234 on 15/02/2026. UPI txn
//         to merchant@paytm Ref 640512345678. Avl Bal Rs.8500
//         -Central Bank of India
// Credit: Rs.3000 credited to A/c XXXX1234 on 16/02/2026.
//         Ref 640612345678. Avl Bal Rs.11500 -Central Bank of India
// ────────────────────────────────────────────────────────────
class CentralBankParser extends BankParser {
  @override
  String getBankName() => 'Central Bank of India';

  @override
  bool canHandle(String sender) {
    final s = sender.toUpperCase();
    return s.contains('CBIN') || s.contains('CENTRAL');
  }

  @override
  String? extractMerchant(String message, String sender) {
    final lower = message.toLowerCase();

    // "to merchant@paytm"
    final vpa = RegExp(
      r'to\s+([^\s@]+@[^\s\.]+)',
      caseSensitive: false,
    ).firstMatch(message);
    if (vpa != null)
      return cleanMerchantName(extractMerchantFromUpiVpa(vpa.group(1)!));

    // "to NAME Ref"
    final toName = RegExp(
      r'to\s+([A-Za-z][A-Za-z\s]+?)(?:\s+Ref|\.|$)',
      caseSensitive: false,
    ).firstMatch(message);
    if (toName != null) {
      final cleaned = cleanMerchantName(toName.group(1)!.trim());
      if (isValidMerchant(cleaned)) return cleaned;
    }

    if (lower.contains('atm')) return 'ATM';
    return super.extractMerchant(message, sender);
  }

  @override
  String? extractReference(String message) {
    final m = RegExp(
      r'Ref\s+(\d{8,16})',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return m.group(1);
    return super.extractReference(message);
  }

  @override
  double? extractBalance(String message) {
    final m = RegExp(
      r'Avl\s*Bal\s*(?:Rs\.?\s*)?([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return double.tryParse(m.group(1)!.replaceAll(',', ''));
    return super.extractBalance(message);
  }
}

// ────────────────────────────────────────────────────────────
// BANK OF MAHARASHTRA
// ────────────────────────────────────────────────────────────
// Debit:  Rs.350 debited from your Bank of Maharashtra A/c XX3456
//         on 15-02-2026 for UPI txn to ravi@ybl.
//         Ref 640512345678. Avl Bal Rs.6650 -BOM
// Credit: Rs.2000 credited to your A/c XX3456 on 16-02-2026.
//         Ref 640612345678. Avl Bal Rs.8650 -Bank of Maharashtra
// ────────────────────────────────────────────────────────────
class BankOfMaharashtraParser extends BankParser {
  @override
  String getBankName() => 'Bank of Maharashtra';

  @override
  bool canHandle(String sender) {
    final s = sender.toUpperCase();
    return s.contains('MAHB') ||
        s.contains('MAHABK') ||
        (s.contains('BOM') && !s.contains('BOMB'));
  }

  @override
  String? extractMerchant(String message, String sender) {
    final lower = message.toLowerCase();

    // "to ravi@ybl"
    final vpa = RegExp(
      r'to\s+([^\s@]+@[^\s\.]+)',
      caseSensitive: false,
    ).firstMatch(message);
    if (vpa != null)
      return cleanMerchantName(extractMerchantFromUpiVpa(vpa.group(1)!));

    // "to NAME . Ref"
    final toName = RegExp(
      r'to\s+([A-Za-z][A-Za-z\s]+?)(?:\.\s*Ref|\s+Ref|\.|$)',
      caseSensitive: false,
    ).firstMatch(message);
    if (toName != null) {
      final cleaned = cleanMerchantName(toName.group(1)!.trim());
      if (isValidMerchant(cleaned)) return cleaned;
    }

    if (lower.contains('atm')) return 'ATM';
    return super.extractMerchant(message, sender);
  }

  @override
  String? extractReference(String message) {
    final m = RegExp(
      r'Ref\s+(\d{8,16})',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return m.group(1);
    return super.extractReference(message);
  }

  @override
  double? extractBalance(String message) {
    final m = RegExp(
      r'Avl\s*Bal\s*(?:Rs\.?\s*)?([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return double.tryParse(m.group(1)!.replaceAll(',', ''));
    return super.extractBalance(message);
  }
}

// ────────────────────────────────────────────────────────────
// PUNJAB & SIND BANK (PSB)
// ────────────────────────────────────────────────────────────
// Debit:  Dear Customer, Rs.400 debited from your P&S Bank A/c
//         XXXX1234 to merchant@ybl on 15-02-2026.
//         UPI Ref 640512345678. Bal Rs.7600 -P&S Bank
// Credit: Rs.1500 credited to your A/c XXXX1234 on 16-02-2026.
//         Ref 640612345678. Bal Rs.9100 -Punjab & Sind Bank
// ────────────────────────────────────────────────────────────
class PunjabSindBankParser extends BankParser {
  @override
  String getBankName() => 'Punjab & Sind Bank';

  @override
  bool canHandle(String sender) {
    final s = sender.toUpperCase();
    return s.contains('PSBANK') || s.contains('PSB');
  }

  @override
  String? extractMerchant(String message, String sender) {
    final lower = message.toLowerCase();

    // "to merchant@ybl"
    final vpa = RegExp(
      r'to\s+([^\s@]+@[^\s\.]+)',
      caseSensitive: false,
    ).firstMatch(message);
    if (vpa != null)
      return cleanMerchantName(extractMerchantFromUpiVpa(vpa.group(1)!));

    if (lower.contains('atm')) return 'ATM';
    return super.extractMerchant(message, sender);
  }

  @override
  String? extractReference(String message) {
    final m = RegExp(
      r'(?:UPI\s+)?Ref\s+(\d{8,16})',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return m.group(1);
    return super.extractReference(message);
  }

  @override
  double? extractBalance(String message) {
    final m = RegExp(
      r'Bal\s*(?:Rs\.?\s*)?([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return double.tryParse(m.group(1)!.replaceAll(',', ''));
    return super.extractBalance(message);
  }
}

// ────────────────────────────────────────────────────────────
// RBL BANK (Ratnakar Bank)
// ────────────────────────────────────────────────────────────
// Debit:  INR 1200.00 debited from your RBL Bank A/c XX7890 on
//         15-02-2026 for UPI payment to SHOP@upi.
//         Ref: 640512345678. Bal: INR 18800.00 -RBL Bank
// Credit: INR 5000 credited to RBL Bank A/c XX7890 on 16-02-2026.
//         Ref: 640612345678. Bal: INR 23800.00 -RBL Bank
// Card:   INR 2499 spent on RBL Bank Card XX3456 at RELIANCE DIGITAL
//         on 13-02-2026. Bal: INR 21301 -RBL
// ────────────────────────────────────────────────────────────
class RBLBankParser extends BankParser {
  @override
  String getBankName() => 'RBL Bank';

  @override
  bool canHandle(String sender) {
    final s = sender.toUpperCase();
    return s.contains('RBLBNK') ||
        s.contains('RATNAKAR') ||
        (s.contains('RBL') && !s.contains('ARBL'));
  }

  @override
  String? extractMerchant(String message, String sender) {
    final lower = message.toLowerCase();

    // "to SHOP@upi"
    final vpa = RegExp(
      r'to\s+([^\s@]+@[^\s\.]+)',
      caseSensitive: false,
    ).firstMatch(message);
    if (vpa != null)
      return cleanMerchantName(extractMerchantFromUpiVpa(vpa.group(1)!));

    // "to NAME . Ref"
    final toName = RegExp(
      r'to\s+([A-Za-z][A-Za-z\s]+?)(?:\.\s*Ref|\s+Ref|\.|$)',
      caseSensitive: false,
    ).firstMatch(message);
    if (toName != null) {
      final cleaned = cleanMerchantName(toName.group(1)!.trim());
      if (isValidMerchant(cleaned)) return cleaned;
    }

    // "at RELIANCE DIGITAL on"
    final atMatch = RegExp(
      r'at\s+([A-Za-z][A-Za-z0-9\s&\.\-]+?)(?:\s+on|\.|$)',
      caseSensitive: false,
    ).firstMatch(message);
    if (atMatch != null) {
      final cleaned = cleanMerchantName(atMatch.group(1)!.trim());
      if (isValidMerchant(cleaned)) return cleaned;
    }

    if (lower.contains('atm')) return 'ATM';
    return super.extractMerchant(message, sender);
  }

  @override
  String? extractReference(String message) {
    final m = RegExp(
      r'Ref[:\s]+(\d{8,16})',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return m.group(1);
    return super.extractReference(message);
  }

  @override
  double? extractBalance(String message) {
    final m = RegExp(
      r'Bal[:\s]+(?:INR|Rs\.?)\s*([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return double.tryParse(m.group(1)!.replaceAll(',', ''));
    return super.extractBalance(message);
  }
}

// ────────────────────────────────────────────────────────────
// AU SMALL FINANCE BANK
// ────────────────────────────────────────────────────────────
// Debit:  Rs.600 debited from AU Small Finance Bank A/c XX4321 on
//         15-02-2026. UPI/ravi.kumar@okhdfcbank/Ref 640512345678.
//         Avl Bal Rs.9400 -AU Bank
// Credit: Rs.3000 credited to your AU Bank A/c XX4321 on 16-02-2026.
//         UPI Ref 640612345678. Avl Bal Rs.12400 -AU Bank
// Card:   Rs.1599 spent using AU Bank Card XX8765 at BIGBASKET on
//         11-02-2026. Avl Bal Rs.10801 -AU Small Finance Bank
// ────────────────────────────────────────────────────────────
class AUBankParser extends BankParser {
  @override
  String getBankName() => 'AU Small Finance Bank';

  @override
  bool canHandle(String sender) {
    final s = sender.toUpperCase();
    return s.contains('AUBANK') || s.contains('AUBK') || s.contains('AUFIN');
  }

  @override
  String? extractMerchant(String message, String sender) {
    final lower = message.toLowerCase();

    // "UPI/ravi.kumar@okhdfcbank/Ref"
    final upiSlash = RegExp(
      r'UPI/([^/]+@[^/]+)/',
      caseSensitive: false,
    ).firstMatch(message);
    if (upiSlash != null) {
      return cleanMerchantName(extractMerchantFromUpiVpa(upiSlash.group(1)!));
    }

    // "UPI/MERCHANT/Ref"
    final upiMerch = RegExp(
      r'UPI/([A-Za-z][A-Za-z0-9\s\.]+?)/',
      caseSensitive: false,
    ).firstMatch(message);
    if (upiMerch != null) return cleanMerchantName(upiMerch.group(1)!.trim());

    // "at BIGBASKET on"
    final atMatch = RegExp(
      r'at\s+([A-Za-z][A-Za-z0-9\s&\.\-]+?)(?:\s+on|\s+made|\.|$)',
      caseSensitive: false,
    ).firstMatch(message);
    if (atMatch != null) {
      final cleaned = cleanMerchantName(atMatch.group(1)!.trim());
      if (isValidMerchant(cleaned)) return cleaned;
    }

    if (lower.contains('atm')) return 'ATM';
    return super.extractMerchant(message, sender);
  }

  @override
  String? extractReference(String message) {
    final m = RegExp(
      r'Ref\s+(\d{8,16})',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return m.group(1);
    return super.extractReference(message);
  }

  @override
  double? extractBalance(String message) {
    final m = RegExp(
      r'Avl\s*Bal\s*(?:Rs\.?\s*)?([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return double.tryParse(m.group(1)!.replaceAll(',', ''));
    return super.extractBalance(message);
  }
}

// ────────────────────────────────────────────────────────────
// INDIAN BANK
// ────────────────────────────────────────────────────────────
// Debit:  Dear Customer, Rs.700 debited from your Indian Bank A/c
//         XXXX5678 on 15-02-2026. UPI to RAVI@ybl
//         Ref No 640512345678. Avl Bal Rs.9300 -Indian Bank
// Credit: Rs.4000 credited to Indian Bank A/c XXXX5678 on 16-02-2026.
//         Ref No 640612345678. Avl Bal Rs.13300 -Indian Bank
// ────────────────────────────────────────────────────────────
class IndianBankParser extends BankParser {
  @override
  String getBankName() => 'Indian Bank';

  @override
  bool canHandle(String sender) {
    final s = sender.toUpperCase();
    // Avoid matching 'INDIAN' in generic strings; be specific
    return s.contains('INDBNK') ||
        s.contains('INDIANB') ||
        (s.contains('INDIAN') && s.contains('BANK'));
  }

  @override
  String? extractMerchant(String message, String sender) {
    final lower = message.toLowerCase();

    // "to RAVI@ybl"
    final vpa = RegExp(
      r'to\s+([^\s@]+@[^\s\.]+)',
      caseSensitive: false,
    ).firstMatch(message);
    if (vpa != null)
      return cleanMerchantName(extractMerchantFromUpiVpa(vpa.group(1)!));

    // "to NAME Ref"
    final toName = RegExp(
      r'to\s+([A-Za-z][A-Za-z\s]+?)(?:\s+Ref|\.|$)',
      caseSensitive: false,
    ).firstMatch(message);
    if (toName != null) {
      final cleaned = cleanMerchantName(toName.group(1)!.trim());
      if (isValidMerchant(cleaned)) return cleaned;
    }

    if (lower.contains('atm')) return 'ATM';
    return super.extractMerchant(message, sender);
  }

  @override
  String? extractReference(String message) {
    final m = RegExp(
      r'Ref\s+(?:No\s+)?(\d{8,16})',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return m.group(1);
    return super.extractReference(message);
  }

  @override
  double? extractBalance(String message) {
    final m = RegExp(
      r'Avl\s*Bal\s*(?:Rs\.?\s*)?([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return double.tryParse(m.group(1)!.replaceAll(',', ''));
    return super.extractBalance(message);
  }
}

// ────────────────────────────────────────────────────────────
// PAYTM PAYMENTS BANK
// ────────────────────────────────────────────────────────────
// Debit:  Rs.150 sent to RAHUL KUMAR from Paytm Wallet/Savings A/c
//         on 15-02-2026. UPI Ref 640512345678. Bal Rs.850
// Credit: Rs.500 added to your Paytm Wallet on 16-02-2026.
//         UPI Ref 640612345678. Bal Rs.1350
// Payment: Rs.99 paid to NETFLIX using Paytm UPI on 14-02-2026.
//          Ref 640412345678. Bal Rs.1251
// ────────────────────────────────────────────────────────────
class PaytmBankParser extends BankParser {
  @override
  String getBankName() => 'Paytm Payments Bank';

  @override
  bool canHandle(String sender) {
    final s = sender.toUpperCase();
    return s.contains('PAYTMB') ||
        s.contains('PYTM') ||
        (s.contains('PAYTM') && !s.contains('PAYTMO'));
  }

  @override
  String? extractMerchant(String message, String sender) {
    // "sent to RAHUL KUMAR from"
    final sentTo = RegExp(
      r'sent\s+to\s+([A-Za-z][A-Za-z\s]+?)\s+from',
      caseSensitive: false,
    ).firstMatch(message);
    if (sentTo != null) return cleanMerchantName(sentTo.group(1)!.trim());

    // "paid to NETFLIX using"
    final paidTo = RegExp(
      r'paid\s+to\s+([A-Za-z][A-Za-z0-9\s&\.\-]+?)\s+using',
      caseSensitive: false,
    ).firstMatch(message);
    if (paidTo != null) return cleanMerchantName(paidTo.group(1)!.trim());

    // "received from NAME via" or "from NAME on"
    final from = RegExp(
      r'(?:received\s+)?from\s+([A-Za-z][A-Za-z\s]+?)(?:\s+via|\s+on|\.|$)',
      caseSensitive: false,
    ).firstMatch(message);
    if (from != null) {
      final cleaned = cleanMerchantName(from.group(1)!.trim());
      if (isValidMerchant(cleaned) &&
          !cleaned.toLowerCase().contains('paytm') &&
          !cleaned.toLowerCase().contains('wallet') &&
          !cleaned.toLowerCase().contains('savings')) {
        return cleaned;
      }
    }

    return super.extractMerchant(message, sender);
  }

  @override
  String? extractReference(String message) {
    final m = RegExp(
      r'(?:UPI\s+)?Ref\s+(\d{8,16})',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return m.group(1);
    return super.extractReference(message);
  }

  @override
  double? extractBalance(String message) {
    final m = RegExp(
      r'Bal\s*(?:Rs\.?\s*)?([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return double.tryParse(m.group(1)!.replaceAll(',', ''));
    return super.extractBalance(message);
  }
}

// ────────────────────────────────────────────────────────────
// AIRTEL PAYMENTS BANK
// ────────────────────────────────────────────────────────────
// Debit:  Rs.200 sent from your Airtel Payments Bank A/c XX1234
//         to ravi@airtel on 15-02-2026.
//         UPI Ref 640512345678. Avl Bal Rs.1800 -Airtel Bank
// Credit: Rs.1000 received in your Airtel Payments Bank A/c XX1234
//         on 16-02-2026. Ref 640612345678. Avl Bal Rs.2800
// ────────────────────────────────────────────────────────────
class AirtelBankParser extends BankParser {
  @override
  String getBankName() => 'Airtel Payments Bank';

  @override
  bool canHandle(String sender) {
    final s = sender.toUpperCase();
    return s.contains('AIRBNK') ||
        s.contains('AIRPRB') ||
        (s.contains('AIRTEL') && s.contains('BANK'));
  }

  @override
  String? extractMerchant(String message, String sender) {
    // "to ravi@airtel"
    final vpa = RegExp(
      r'to\s+([^\s@]+@[^\s\.]+)',
      caseSensitive: false,
    ).firstMatch(message);
    if (vpa != null)
      return cleanMerchantName(extractMerchantFromUpiVpa(vpa.group(1)!));

    // "to NAME on"
    final toName = RegExp(
      r'to\s+([A-Za-z][A-Za-z\s]+?)\s+on',
      caseSensitive: false,
    ).firstMatch(message);
    if (toName != null) {
      final cleaned = cleanMerchantName(toName.group(1)!.trim());
      if (isValidMerchant(cleaned)) return cleaned;
    }

    return super.extractMerchant(message, sender);
  }

  @override
  String? extractReference(String message) {
    final m = RegExp(
      r'(?:UPI\s+)?Ref\s+(\d{8,16})',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return m.group(1);
    return super.extractReference(message);
  }

  @override
  double? extractBalance(String message) {
    final m = RegExp(
      r'Avl\s*Bal\s*(?:Rs\.?\s*)?([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return double.tryParse(m.group(1)!.replaceAll(',', ''));
    return super.extractBalance(message);
  }
}

// ────────────────────────────────────────────────────────────
// INDIA POST PAYMENTS BANK (IPPB)
// ────────────────────────────────────────────────────────────
// Debit:  Rs.300 debited from your IPPB A/c XX2345 to ravi@ippb
//         on 15-02-2026. UPI Ref 640512345678. Avl Bal Rs.3700
// Credit: Rs.2000 credited to IPPB A/c XX2345 on 16-02-2026.
//         Ref 640612345678. Avl Bal Rs.5700
// ────────────────────────────────────────────────────────────
class IPPBParser extends BankParser {
  @override
  String getBankName() => 'India Post Payments Bank';

  @override
  bool canHandle(String sender) {
    final s = sender.toUpperCase();
    return s.contains('IPPB') || s.contains('IPPBNK');
  }

  @override
  String? extractMerchant(String message, String sender) {
    // "to ravi@ippb"
    final vpa = RegExp(
      r'to\s+([^\s@]+@[^\s\.]+)',
      caseSensitive: false,
    ).firstMatch(message);
    if (vpa != null)
      return cleanMerchantName(extractMerchantFromUpiVpa(vpa.group(1)!));

    if (message.toLowerCase().contains('atm')) return 'ATM';
    return super.extractMerchant(message, sender);
  }

  @override
  String? extractReference(String message) {
    final m = RegExp(
      r'(?:UPI\s+)?Ref\s+(\d{8,16})',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return m.group(1);
    return super.extractReference(message);
  }

  @override
  double? extractBalance(String message) {
    final m = RegExp(
      r'Avl\s*Bal\s*(?:Rs\.?\s*)?([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return double.tryParse(m.group(1)!.replaceAll(',', ''));
    return super.extractBalance(message);
  }
}

// ────────────────────────────────────────────────────────────
// KARUR VYSYA BANK (KVB)
// ────────────────────────────────────────────────────────────
// Debit:  Rs.450 debited from your KVB A/c XX1234 on 15-02-26
//         for UPI txn to NAME@ybl. Ref 640512345678.
//         Avl Bal Rs.5550 -KVB
// Credit: Rs.2500 credited to your KVB A/c XX1234 on 16-02-26.
//         Ref 640612345678. Avl Bal Rs.8050 -KVB
// ────────────────────────────────────────────────────────────
class KVBBankParser extends BankParser {
  @override
  String getBankName() => 'Karur Vysya Bank';

  @override
  bool canHandle(String sender) {
    final s = sender.toUpperCase();
    return s.contains('KVBANK') || s.contains('KVB');
  }

  @override
  String? extractMerchant(String message, String sender) {
    // "to NAME@ybl"
    final vpa = RegExp(
      r'to\s+([^\s@]+@[^\s\.]+)',
      caseSensitive: false,
    ).firstMatch(message);
    if (vpa != null)
      return cleanMerchantName(extractMerchantFromUpiVpa(vpa.group(1)!));

    // "to NAME . Ref"
    final toName = RegExp(
      r'to\s+([A-Za-z][A-Za-z\s]+?)(?:\.\s*Ref|\s+Ref|\.|$)',
      caseSensitive: false,
    ).firstMatch(message);
    if (toName != null) {
      final cleaned = cleanMerchantName(toName.group(1)!.trim());
      if (isValidMerchant(cleaned)) return cleaned;
    }

    if (message.toLowerCase().contains('atm')) return 'ATM';
    return super.extractMerchant(message, sender);
  }

  @override
  String? extractReference(String message) {
    final m = RegExp(
      r'Ref\s+(\d{8,16})',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return m.group(1);
    return super.extractReference(message);
  }

  @override
  double? extractBalance(String message) {
    final m = RegExp(
      r'Avl\s*Bal\s*(?:Rs\.?\s*)?([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return double.tryParse(m.group(1)!.replaceAll(',', ''));
    return super.extractBalance(message);
  }
}

// ────────────────────────────────────────────────────────────
// SOUTH INDIAN BANK (SIB)
// ────────────────────────────────────────────────────────────
// Debit:  Rs.550 debited from your SIB A/c XX8901 on 15-02-26
//         to merchant@upi. UPI Ref: 640512345678.
//         Avl Bal Rs.7450 -South Indian Bank
// Credit: Rs.3000 credited to SIB A/c XX8901 on 16-02-26.
//         UPI Ref: 640612345678. Avl Bal Rs.10450 -SIB
// ────────────────────────────────────────────────────────────
class SouthIndianBankParser extends BankParser {
  @override
  String getBankName() => 'South Indian Bank';

  @override
  bool canHandle(String sender) {
    final s = sender.toUpperCase();
    return s.contains('SIBL') || s.contains('SIB');
  }

  @override
  String? extractMerchant(String message, String sender) {
    // "to merchant@upi"
    final vpa = RegExp(
      r'to\s+([^\s@]+@[^\s\.]+)',
      caseSensitive: false,
    ).firstMatch(message);
    if (vpa != null)
      return cleanMerchantName(extractMerchantFromUpiVpa(vpa.group(1)!));

    if (message.toLowerCase().contains('atm')) return 'ATM';
    return super.extractMerchant(message, sender);
  }

  @override
  String? extractReference(String message) {
    final m = RegExp(
      r'(?:UPI\s+)?Ref[:\s]+(\d{8,16})',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return m.group(1);
    return super.extractReference(message);
  }

  @override
  double? extractBalance(String message) {
    final m = RegExp(
      r'Avl\s*Bal\s*(?:Rs\.?\s*)?([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return double.tryParse(m.group(1)!.replaceAll(',', ''));
    return super.extractBalance(message);
  }
}

// ────────────────────────────────────────────────────────────
// KARNATAKA BANK
// ────────────────────────────────────────────────────────────
// Debit:  Rs.800 debited from Karnataka Bank A/c XX3456 to
//         merchant@ybl on 15-02-26. UPI Ref 640512345678.
//         Avl Bal Rs.12200 -Karnataka Bank
// Credit: Rs.5000 credited to your A/c XX3456 on 16-02-26.
//         Ref 640612345678. Avl Bal Rs.17200 -Karnataka Bank
// ────────────────────────────────────────────────────────────
class KarnatakaBankParser extends BankParser {
  @override
  String getBankName() => 'Karnataka Bank';

  @override
  bool canHandle(String sender) {
    final s = sender.toUpperCase();
    return s.contains('KARBNK') ||
        s.contains('KTKBNK') ||
        (s.contains('KARB') && !s.contains('AKARB'));
  }

  @override
  String? extractMerchant(String message, String sender) {
    // "to merchant@ybl"
    final vpa = RegExp(
      r'to\s+([^\s@]+@[^\s\.]+)',
      caseSensitive: false,
    ).firstMatch(message);
    if (vpa != null)
      return cleanMerchantName(extractMerchantFromUpiVpa(vpa.group(1)!));

    if (message.toLowerCase().contains('atm')) return 'ATM';
    return super.extractMerchant(message, sender);
  }

  @override
  String? extractReference(String message) {
    final m = RegExp(
      r'(?:UPI\s+)?Ref\s+(\d{8,16})',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return m.group(1);
    return super.extractReference(message);
  }

  @override
  double? extractBalance(String message) {
    final m = RegExp(
      r'Avl\s*Bal\s*(?:Rs\.?\s*)?([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return double.tryParse(m.group(1)!.replaceAll(',', ''));
    return super.extractBalance(message);
  }
}

// ────────────────────────────────────────────────────────────
// CSB BANK (Catholic Syrian Bank)
// ────────────────────────────────────────────────────────────
// Debit:  Rs.650 debited from your CSB Bank A/c XX4567 on 15-02-26
//         for UPI payment to merchant@axl.
//         Ref 640512345678. Avl Bal Rs.6350 -CSB Bank
// ────────────────────────────────────────────────────────────
class CSBBankParser extends BankParser {
  @override
  String getBankName() => 'CSB Bank';

  @override
  bool canHandle(String sender) {
    final s = sender.toUpperCase();
    return s.contains('CSBBNK') || (s.contains('CSB') && !s.contains('ACSB'));
  }

  @override
  String? extractMerchant(String message, String sender) {
    final vpa = RegExp(
      r'to\s+([^\s@]+@[^\s\.]+)',
      caseSensitive: false,
    ).firstMatch(message);
    if (vpa != null)
      return cleanMerchantName(extractMerchantFromUpiVpa(vpa.group(1)!));

    if (message.toLowerCase().contains('atm')) return 'ATM';
    return super.extractMerchant(message, sender);
  }

  @override
  String? extractReference(String message) {
    final m = RegExp(
      r'Ref\s+(\d{8,16})',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return m.group(1);
    return super.extractReference(message);
  }

  @override
  double? extractBalance(String message) {
    final m = RegExp(
      r'Avl\s*Bal\s*(?:Rs\.?\s*)?([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return double.tryParse(m.group(1)!.replaceAll(',', ''));
    return super.extractBalance(message);
  }
}

// ────────────────────────────────────────────────────────────
// DCB BANK
// ────────────────────────────────────────────────────────────
// Debit:  INR 900 debited from your DCB Bank A/c XX5678 on 15-02-26.
//         UPI to shop@ybl. Ref 640512345678. Bal INR 11100 -DCB Bank
// ────────────────────────────────────────────────────────────
class DCBBankParser extends BankParser {
  @override
  String getBankName() => 'DCB Bank';

  @override
  bool canHandle(String sender) {
    final s = sender.toUpperCase();
    return s.contains('DCBBNK') || (s.contains('DCB') && !s.contains('ADCB'));
  }

  @override
  String? extractMerchant(String message, String sender) {
    final vpa = RegExp(
      r'to\s+([^\s@]+@[^\s\.]+)',
      caseSensitive: false,
    ).firstMatch(message);
    if (vpa != null)
      return cleanMerchantName(extractMerchantFromUpiVpa(vpa.group(1)!));

    if (message.toLowerCase().contains('atm')) return 'ATM';
    return super.extractMerchant(message, sender);
  }

  @override
  String? extractReference(String message) {
    final m = RegExp(
      r'Ref\s+(\d{8,16})',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return m.group(1);
    return super.extractReference(message);
  }

  @override
  double? extractBalance(String message) {
    final m = RegExp(
      r'Bal\s*(?:INR|Rs\.?)\s*([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return double.tryParse(m.group(1)!.replaceAll(',', ''));
    return super.extractBalance(message);
  }
}

// ────────────────────────────────────────────────────────────
// TAMILNAD MERCANTILE BANK (TMB)
// ────────────────────────────────────────────────────────────
// Debit:  Rs.400 debited from TMB A/c XX6789 on 15-02-26.
//         UPI to shop@tmb. Ref 640512345678. Avl Bal Rs.7600 -TMB
// ────────────────────────────────────────────────────────────
class TMBBankParser extends BankParser {
  @override
  String getBankName() => 'Tamilnad Mercantile Bank';

  @override
  bool canHandle(String sender) {
    final s = sender.toUpperCase();
    return s.contains('TMBBNK') || (s.contains('TMB') && !s.contains('PAYTM'));
  }

  @override
  String? extractMerchant(String message, String sender) {
    final vpa = RegExp(
      r'to\s+([^\s@]+@[^\s\.]+)',
      caseSensitive: false,
    ).firstMatch(message);
    if (vpa != null)
      return cleanMerchantName(extractMerchantFromUpiVpa(vpa.group(1)!));

    if (message.toLowerCase().contains('atm')) return 'ATM';
    return super.extractMerchant(message, sender);
  }

  @override
  String? extractReference(String message) {
    final m = RegExp(
      r'Ref\s+(\d{8,16})',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return m.group(1);
    return super.extractReference(message);
  }

  @override
  double? extractBalance(String message) {
    final m = RegExp(
      r'Avl\s*Bal\s*(?:Rs\.?\s*)?([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ).firstMatch(message);
    if (m != null) return double.tryParse(m.group(1)!.replaceAll(',', ''));
    return super.extractBalance(message);
  }
}
