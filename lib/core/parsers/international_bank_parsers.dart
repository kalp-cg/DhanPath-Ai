import 'bank_parser_base.dart';

// =====================================
// USA BANKS
// =====================================

class ChaseBankParser extends BankParser {
  @override
  String getBankName() => 'Chase Bank';

  @override
  String getCurrency() => 'USD';

  @override
  bool canHandle(String sender) {
    final s = sender.toUpperCase();
    return s.contains('CHASE') || s == '28107' || s == '36640' || s == '72166';
  }

  @override
  double? extractAmount(String message) {
    // Chase: sent you $20.00
    // Chase: You paid $50.00
    // Try $ pattern first
    var match = RegExp(r'\$\s*([0-9,]+(\.[0-9]+)?)').firstMatch(message);
    if (match != null) {
      return double.tryParse(match.group(1)!.replaceAll(',', ''));
    }
    return super.extractAmount(message);
  }
}

class WellsFargoParser extends BankParser {
  @override
  String getBankName() => 'Wells Fargo';

  @override
  String getCurrency() => 'USD';

  @override
  bool canHandle(String sender) {
    final s = sender.toUpperCase();
    return s.contains('WELLS') || s == '93557';
  }

  @override
  double? extractAmount(String message) {
    var match = RegExp(r'\$\s*([0-9,]+(\.[0-9]+)?)').firstMatch(message);
    if (match != null) {
      return double.tryParse(match.group(1)!.replaceAll(',', ''));
    }
    return super.extractAmount(message);
  }
}

class BankOfAmericaParser extends BankParser {
  @override
  String getBankName() => 'Bank of America';

  @override
  String getCurrency() => 'USD';

  @override
  bool canHandle(String sender) {
    final s = sender.toUpperCase();
    return s.contains('BOA') || s.contains('BANKOFAMERICA');
  }

  @override
  double? extractAmount(String message) {
    var match = RegExp(r'\$\s*([0-9,]+(\.[0-9]+)?)').firstMatch(message);
    if (match != null) {
      return double.tryParse(match.group(1)!.replaceAll(',', ''));
    }
    return super.extractAmount(message);
  }
}

// =====================================
// UK BANKS
// =====================================

class HSBCBankParser extends BankParser {
  @override
  String getBankName() => 'HSBC UK';

  @override
  String getCurrency() => 'GBP';

  @override
  bool canHandle(String sender) {
    final s = sender.toUpperCase();
    // UK HSBC sender IDs often just HSBC or HSBCUK
    return s == 'HSBC' || s == 'HSBCUK';
  }

  @override
  double? extractAmount(String message) {
    // HSBC: ... for £24.91
    var match = RegExp(r'\u00A3\s*([0-9,]+(\.[0-9]+)?)').firstMatch(message);
    if (match != null) {
      return double.tryParse(match.group(1)!.replaceAll(',', ''));
    }
    return super.extractAmount(message);
  }
}

class BarclaysBankParser extends BankParser {
  @override
  String getBankName() => 'Barclays';

  @override
  String getCurrency() => 'GBP';

  @override
  bool canHandle(String sender) {
    final s = sender.toUpperCase();
    return s.contains('BARCLAYS');
  }

  @override
  double? extractAmount(String message) {
    var match = RegExp(r'\u00A3\s*([0-9,]+(\.[0-9]+)?)').firstMatch(message);
    if (match != null) {
      return double.tryParse(match.group(1)!.replaceAll(',', ''));
    }
    return super.extractAmount(message);
  }
}

// =====================================
// UAE BANKS
// =====================================

class EmiratesNBDParser extends BankParser {
  @override
  String getBankName() => 'Emirates NBD';

  @override
  String getCurrency() => 'AED';

  @override
  bool canHandle(String sender) {
    final s = sender.toUpperCase();
    return s.contains('EMIRATESNBD') || s.contains('ENBD');
  }

  @override
  double? extractAmount(String message) {
    // AED 1,800.00 has been deducted...
    var match = RegExp(
      r'AED\s*([0-9,]+(\.[0-9]+)?)',
      caseSensitive: false,
    ).firstMatch(message);
    if (match != null) {
      return double.tryParse(match.group(1)!.replaceAll(',', ''));
    }
    return super.extractAmount(message);
  }
}

class ADCBParser extends BankParser {
  @override
  String getBankName() => 'ADCB';

  @override
  String getCurrency() => 'AED';

  @override
  bool canHandle(String sender) {
    final s = sender.toUpperCase();
    return s.contains('ADCB') || s == '2626';
  }

  @override
  double? extractAmount(String message) {
    var match = RegExp(
      r'AED\s*([0-9,]+(\.[0-9]+)?)',
      caseSensitive: false,
    ).firstMatch(message);
    if (match != null) {
      return double.tryParse(match.group(1)!.replaceAll(',', ''));
    }
    return super.extractAmount(message);
  }
}
