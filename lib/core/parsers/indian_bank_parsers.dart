import 'bank_parser_base.dart';
import '../../models/transaction_model.dart';
import '../../services/compiled_patterns.dart';

/// SBI (State Bank of India) specific parser
class SBIBankParser extends BankParser {
  @override
  String getBankName() => 'SBI';

  @override
  bool canHandle(String sender) {
    final upperSender = sender.toUpperCase();
    const sbiSenders = ['SBIINB', 'SBIPSG', 'SBIUPI', 'SBI', 'SBICARD'];
    return sbiSenders.any((s) => upperSender.contains(s));
  }

  @override
  String? extractMerchant(String message, String sender) {
    // Pattern 1: "at [MERCHANT]" for card transactions
    final atMatch = RegExp(
      r'\bat\s+([A-Z][A-Za-z0-9\s&\.\-]{2,30})',
      caseSensitive: true,
    ).firstMatch(message);
    if (atMatch != null) {
      return cleanMerchantName(atMatch.group(1)!);
    }

    // Pattern 2: "to VPA [merchant@provider]"
    if (message.toLowerCase().contains('vpa')) {
      final vpaMatch = RegExp(
        r'VPA\s+([a-z0-9\-\.]+)@',
        caseSensitive: false,
      ).firstMatch(message);
      if (vpaMatch != null) {
        return cleanMerchantName(vpaMatch.group(1)!);
      }
    }

    // Pattern 3: "UPI/merchant/..." format
    if (message.toLowerCase().contains('upi/')) {
      final upiMatch = RegExp(
        r'UPI/([A-Za-z0-9\s\.]+)/',
        caseSensitive: false,
      ).firstMatch(message);
      if (upiMatch != null) {
        return cleanMerchantName(upiMatch.group(1)!);
      }
    }

    // Pattern 4: ATM withdrawals
    if (message.toLowerCase().contains('atm')) {
      return 'ATM';
    }

    return super.extractMerchant(message, sender);
  }

  @override
  TransactionType? extractTransactionType(String message) {
    final lowerMessage = message.toLowerCase();

    // Credit card transactions
    if (lowerMessage.contains('sbi card') && lowerMessage.contains('spent')) {
      return TransactionType.credit;
    }

    return super.extractTransactionType(message);
  }

  @override
  String? extractReference(String message) {
    // SBI specific patterns
    final patterns = [
      RegExp(r'UPI\s+Ref\s+No\s+([a-z0-9]+)', caseSensitive: false),
      RegExp(r'Txn\s+ID\s+([a-z0-9]+)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(message);
      if (match != null) {
        return match.group(1);
      }
    }

    return super.extractReference(message);
  }

  @override
  double? extractBalance(String message) {
    // SBI specific: "Avbl bal Rs.NNNN.NN"
    final avblMatch = RegExp(
      r'Avbl\s+bal\s+Rs\.?\s*([0-9,]+(?:\.[0-9]{2})?)',
      caseSensitive: false,
    ).firstMatch(message);
    if (avblMatch != null) {
      final balanceStr = avblMatch.group(1)!.replaceAll(',', '');
      return double.tryParse(balanceStr);
    }

    return super.extractBalance(message);
  }
}

/// ICICI Bank specific parser
class ICICIBankParser extends BankParser {
  @override
  String getBankName() => 'ICICI Bank';

  @override
  bool canHandle(String sender) {
    final upperSender = sender.toUpperCase();
    const iciciSenders = ['ICICIB', 'ICICI', 'ICICIC'];
    return iciciSenders.any((s) => upperSender.contains(s));
  }

  @override
  String? extractMerchant(String message, String sender) {
    // Pattern 1: "at [MERCHANT]" for card transactions
    final atMatch = RegExp(
      r'\bat\s+([A-Z][A-Za-z0-9\s&\.\-]{2,30})',
      caseSensitive: true,
    ).firstMatch(message);
    if (atMatch != null) {
      return cleanMerchantName(atMatch.group(1)!);
    }

    // Pattern 2: "to VPA [merchant@provider]"
    if (message.toLowerCase().contains('vpa')) {
      final vpaMatch = RegExp(
        r'VPA\s+([a-z0-9\-\.]+)@',
        caseSensitive: false,
      ).firstMatch(message);
      if (vpaMatch != null) {
        return cleanMerchantName(vpaMatch.group(1)!);
      }
    }

    // Pattern 3: "a/c [merchant]" for transfers
    final transferMatch = RegExp(
      r'a/c\s+([A-Za-z][A-Za-z0-9\s&\-]{2,30})',
      caseSensitive: false,
    ).firstMatch(message);
    if (transferMatch != null) {
      final merchant = transferMatch.group(1)!;
      // Skip if it's just account numbers
      if (!RegExp(r'^\d+$').hasMatch(merchant)) {
        return cleanMerchantName(merchant);
      }
    }

    // Pattern 4: ATM withdrawals
    if (message.toLowerCase().contains('atm')) {
      return 'ATM';
    }

    return super.extractMerchant(message, sender);
  }

  @override
  TransactionType? extractTransactionType(String message) {
    final lowerMessage = message.toLowerCase();

    // ICICI credit card
    if (lowerMessage.contains('icici bank credit card') ||
        lowerMessage.contains('icici cc')) {
      return TransactionType.credit;
    }

    return super.extractTransactionType(message);
  }

  @override
  String? extractReference(String message) {
    // ICICI specific patterns
    final patterns = [
      RegExp(r'Ref\s+no\s+([a-z0-9]+)', caseSensitive: false),
      RegExp(r'UPI\s+Ref\s+([a-z0-9]+)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(message);
      if (match != null) {
        return match.group(1);
      }
    }

    return super.extractReference(message);
  }

  @override
  double? extractBalance(String message) {
    // ICICI specific: "Available balance Rs NNNN.NN"
    final availMatch = RegExp(
      r'Available\s+balance\s+Rs\.?\s*([0-9,]+(?:\.[0-9]{2})?)',
      caseSensitive: false,
    ).firstMatch(message);
    if (availMatch != null) {
      final balanceStr = availMatch.group(1)!.replaceAll(',', '');
      return double.tryParse(balanceStr);
    }

    return super.extractBalance(message);
  }
}

/// Axis Bank specific parser
class AxisBankParser extends BankParser {
  @override
  String getBankName() => 'Axis Bank';

  @override
  bool canHandle(String sender) {
    final upperSender = sender.toUpperCase();
    const axisSenders = ['AXISBK', 'AXIS', 'AXISBNK'];
    return axisSenders.any((s) => upperSender.contains(s));
  }

  @override
  String? extractMerchant(String message, String sender) {
    // Pattern 1: "at [MERCHANT]"
    final atMatch = RegExp(
      r'\bat\s+([A-Z][A-Za-z0-9\s&\.\-]{2,30})',
      caseSensitive: true,
    ).firstMatch(message);
    if (atMatch != null) {
      return cleanMerchantName(atMatch.group(1)!);
    }

    // Pattern 2: ATM
    if (message.toLowerCase().contains('atm')) {
      return 'ATM';
    }

    return super.extractMerchant(message, sender);
  }
}

/// Kotak Bank specific parser
class KotakBankParser extends BankParser {
  @override
  String getBankName() => 'Kotak Bank';

  @override
  bool canHandle(String sender) {
    final upperSender = sender.toUpperCase();
    const kotakSenders = ['KOTAKB', 'KOTAK'];
    return kotakSenders.any((s) => upperSender.contains(s));
  }

  @override
  String? extractMerchant(String message, String sender) {
    // Pattern 1: "at [MERCHANT]"
    final atMatch = RegExp(
      r'\bat\s+([A-Z][A-Za-z0-9\s&\.\-]{2,30})',
      caseSensitive: true,
    ).firstMatch(message);
    if (atMatch != null) {
      return cleanMerchantName(atMatch.group(1)!);
    }

    // Pattern 2: ATM
    if (message.toLowerCase().contains('atm')) {
      return 'ATM';
    }

    return super.extractMerchant(message, sender);
  }
}

/// Generic parser for 100+ Indian banks using sender ID mapping
class GenericIndianBankParser extends BankParser {
  String _bankName = 'Bank';

  @override
  String getBankName() => _bankName;

  @override
  bool canHandle(String sender) {
    // Extract the strict 6-char sender ID (e.g. BZ-HDFCBK -> HDFCBK)
    // Or just check if the sender string contains any known key
    final cleanSender = _extractSenderId(sender);

    // Check strict map first
    if (CompiledPatterns.senderIdToBankName.containsKey(cleanSender)) {
      _bankName = CompiledPatterns.senderIdToBankName[cleanSender]!;
      return true;
    }

    // Check if sender contains key (fallback)
    for (final key in CompiledPatterns.senderIdToBankName.keys) {
      if (sender.toUpperCase().contains(key)) {
        _bankName = CompiledPatterns.senderIdToBankName[key]!;
        return true;
      }
    }

    return false;
  }

  String _extractSenderId(String fullSender) {
    // Standard format: XX-SSSSSS
    final parts = fullSender.split('-');
    if (parts.length > 1) {
      return parts.last.toUpperCase();
    }
    return fullSender.toUpperCase();
  }
}
