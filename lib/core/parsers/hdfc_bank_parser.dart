import 'bank_parser_base.dart';
import '../../models/transaction_model.dart';
import '../../services/compiled_patterns.dart';

/// HDFC Bank specific parser
/// Handles HDFC's unique message formats including:
/// - Standard debit/credit messages
/// - UPI transactions with VPA details
/// - Salary credits with company names
/// - Card transactions
class HDFCBankParser extends BankParser {
  @override
  String getBankName() => 'HDFC Bank';

  @override
  bool canHandle(String sender) {
    final upperSender = sender.toUpperCase();
    const hdfcSenders = ['HDFCBK', 'HDFCBANK', 'HDFC', 'HDFCB'];
    return hdfcSenders.any((s) => upperSender.contains(s));
  }

  @override
  String? extractMerchant(String message, String sender) {
    // Pattern 1: "Spent Rs.xxx From HDFC Bank Card xxxx At [MERCHANT] On xxx"
    if (message.contains('From HDFC Bank Card') && message.contains(' At ')) {
      final atMatch = RegExp(
        r' At (.+?) On ',
        caseSensitive: false,
      ).firstMatch(message);
      if (atMatch != null) {
        return cleanMerchantName(atMatch.group(1)!);
      }
    }

    // Pattern 2: ATM withdrawals - "withdrawn...At +18 Random Location On"
    if (message.toLowerCase().contains('withdrawn')) {
      final atmMatch = RegExp(
        r'At\s+\+?([^O]+?)\s+On',
        caseSensitive: false,
      ).firstMatch(message);
      if (atmMatch != null) {
        final location = atmMatch.group(1)!.trim();
        return location.isNotEmpty
            ? 'ATM at ${cleanMerchantName(location)}'
            : 'ATM';
      }
      return 'ATM';
    }

    // Pattern 3: Generic ATM mentions
    if (message.toLowerCase().contains('atm')) {
      return 'ATM';
    }

    // Pattern 4: Credit card - "at [merchant] by UPI" or "at [merchant]"
    if (message.toLowerCase().contains('card') &&
        message.toLowerCase().contains(' at ') &&
        (message.toLowerCase().contains('block cc') ||
            message.toLowerCase().contains('block pcc'))) {
      final atMatch = RegExp(
        r'at\s+([^@\s]+(?:@[^\s]+)?(?:\s+[^\s]+)?)(?:\s+by\s+|\s+on\s+|$)',
        caseSensitive: false,
      ).firstMatch(message);
      if (atMatch != null) {
        var merchant = atMatch.group(1)!.trim();
        // Use base class UPI extraction
        merchant = extractMerchantFromUpiVpa(merchant);
        if (merchant.isNotEmpty) {
          return cleanMerchantName(merchant);
        }
      }
    }

    // Pattern 5: Salary credit - "for XXXXX-ABC-XYZ MONTH SALARY-COMPANY NAME"
    if (message.toLowerCase().contains('salary') &&
        message.toLowerCase().contains('deposited')) {
      final salaryMatch = RegExp(
        r'for\s+[A-Z0-9\-]+\s+[A-Z]{3}\s+SALARY\s*-\s*(.+?)(?:\.|$)',
        caseSensitive: false,
      ).firstMatch(message);
      if (salaryMatch != null) {
        return cleanMerchantName(salaryMatch.group(1)!);
      }
    }

    // Pattern 6: "Info: UPI/merchant/category" format
    if (message.toLowerCase().contains('info:')) {
      final infoMatch = RegExp(
        r'Info:\s*UPI/([^/]+)/',
        caseSensitive: false,
      ).firstMatch(message);
      if (infoMatch != null) {
        final merchant = infoMatch.group(1)!.trim();
        if (merchant.isNotEmpty && merchant.toUpperCase() != 'UPI') {
          return cleanMerchantName(merchant);
        }
      }
    }

    // Pattern 7: VPA patterns - "from VPA username@provider" for credits
    if (message.toLowerCase().contains('vpa')) {
      if (message.toLowerCase().contains('from vpa') &&
          message.toLowerCase().contains('credited')) {
        final vpaMatch = RegExp(
          r'from\s+VPA\s*([^@\s]+)@[^\s]+\s*\(UPI\s+\d+\)',
          caseSensitive: false,
        ).firstMatch(message);
        if (vpaMatch != null) {
          final merchant = extractMerchantFromUpiVpa(vpaMatch.group(1)!);
          return cleanMerchantName(merchant);
        }
      }

      // VPA with name in parentheses
      final vpaNameMatch = RegExp(
        r'VPA\s+[^(]+\(([^)]+)\)',
        caseSensitive: false,
      ).firstMatch(message);
      if (vpaNameMatch != null) {
        return cleanMerchantName(vpaNameMatch.group(1)!);
      }

      // Just VPA username - extract full VPA including @
      final vpaUsernameMatch = RegExp(
        r'VPA\s+([^@\s]+@[^\s]+)',
        caseSensitive: false,
      ).firstMatch(message);
      if (vpaUsernameMatch != null) {
        final vpaFull = vpaUsernameMatch.group(1)!.trim();
        final merchant = extractMerchantFromUpiVpa(vpaFull);
        if (merchant.length > 3 && !RegExp(r'^\\d+$').hasMatch(merchant)) {
          return cleanMerchantName(merchant);
        }
      }
    }

    // Pattern 8: "spent on Card XX1234 at merchant on date"
    if (message.toLowerCase().contains('spent on card')) {
      final spentMatch = RegExp(
        r'at\s+(.+?)\s+on',
        caseSensitive: false,
      ).firstMatch(message);
      if (spentMatch != null) {
        return cleanMerchantName(spentMatch.group(1)!);
      }
    }

    // Pattern 9: "debited for merchant on date"
    if (message.toLowerCase().contains('debited for')) {
      final debitMatch = RegExp(
        r'debited for\s+(.+?)\s+on',
        caseSensitive: false,
      ).firstMatch(message);
      if (debitMatch != null) {
        return cleanMerchantName(debitMatch.group(1)!);
      }
    }

    // Pattern 10: "towards [Merchant Name]" for payments
    if (message.toLowerCase().contains('towards')) {
      final towardsMatch = RegExp(
        r'towards\s+([^\n]+?)(?:\s+UMRN|\s+ID:|\s+Alert:|$)',
        caseSensitive: false,
      ).firstMatch(message);
      if (towardsMatch != null) {
        return cleanMerchantName(towardsMatch.group(1)!);
      }
    }

    // Pattern 11: HDFC Multi-line "To [Name] On [Date]"
    final toOnMatch = CompiledPatterns.hdfcToOn.firstMatch(message);
    if (toOnMatch != null) {
      return cleanMerchantName(toOnMatch.group(1)!);
    }

    // Fallback to base class
    return super.extractMerchant(message, sender);
  }

  @override
  TransactionType? extractTransactionType(String message) {
    final lowerMessage = message.toLowerCase();

    // Credit card transactions - ONLY with CC/PCC indicators
    if (lowerMessage.contains('block cc') ||
        lowerMessage.contains('block pcc')) {
      return TransactionType.credit;
    }

    // Legacy pattern - "spent on card" (not debit card)
    if (lowerMessage.contains('spent on card') &&
        !lowerMessage.contains('block dc')) {
      return TransactionType.credit;
    }

    // Credit card bill payments (expense from bank account)
    if ((lowerMessage.contains('payment') ||
            lowerMessage.contains('towards')) &&
        lowerMessage.contains('credit card')) {
      return TransactionType.expense;
    }

    // HDFC specific: "Sent Rs.X From HDFC Bank"
    if (lowerMessage.contains('sent') && lowerMessage.contains('from hdfc')) {
      return TransactionType.expense;
    }

    // HDFC specific: "Spent Rs.X From HDFC Bank Card" (debit card)
    if (lowerMessage.contains('spent') &&
        lowerMessage.contains('from hdfc bank card')) {
      return TransactionType.expense;
    }

    // Fallback to base class logic
    return super.extractTransactionType(message);
  }

  @override
  String? extractReference(String message) {
    // HDFC specific reference patterns
    final patterns = [
      RegExp(r'Ref\s+no\s+([a-z0-9]+)', caseSensitive: false),
      RegExp(r'UPI\s+Ref\s*[:\s]+([a-z0-9]+)', caseSensitive: false),
      RegExp(r'Ref:\s*([a-z0-9]+)', caseSensitive: false),
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
  String? extractAccountLast4(String message) {
    // Pattern for "Card x####"
    final cardMatch = RegExp(
      r'Card\s+x(\d{4})',
      caseSensitive: false,
    ).firstMatch(message);
    if (cardMatch != null) {
      return cardMatch.group(1);
    }

    // Pattern for "BLOCK DC ####"
    final blockDCMatch = RegExp(
      r'BLOCK\s+DC\s+(\d{4})',
      caseSensitive: false,
    ).firstMatch(message);
    if (blockDCMatch != null) {
      return blockDCMatch.group(1);
    }

    // Pattern for "HDFC Bank XXNNNN"
    final hdfcBankMatch = RegExp(
      r'HDFC\s+Bank\s+([X\*]*\d+)',
      caseSensitive: false,
    ).firstMatch(message);
    if (hdfcBankMatch != null) {
      final accountStr = hdfcBankMatch.group(1)!;
      final digitsOnly = accountStr.replaceAll(RegExp(r'[^\d]'), '');
      return digitsOnly.length >= 4
          ? digitsOnly.substring(digitsOnly.length - 4)
          : digitsOnly;
    }

    return super.extractAccountLast4(message);
  }

  @override
  double? extractBalance(String message) {
    // HDFC specific: "Avl bal:INR NNNN.NN"
    final avlBalMatch = RegExp(
      r'Avl\s+bal:?\s*INR\s*([0-9,]+(?:\.[0-9]{2})?)',
      caseSensitive: false,
    ).firstMatch(message);
    if (avlBalMatch != null) {
      final balanceStr = avlBalMatch.group(1)!.replaceAll(',', '');
      return double.tryParse(balanceStr);
    }

    // "Available Balance: INR NNNN.NN"
    final availBalMatch = RegExp(
      r'Available\s+Balance:?\s*INR\s*([0-9,]+(?:\.[0-9]{2})?)',
      caseSensitive: false,
    ).firstMatch(message);
    if (availBalMatch != null) {
      final balanceStr = availBalMatch.group(1)!.replaceAll(',', '');
      return double.tryParse(balanceStr);
    }

    // "Bal Rs.NNNN.NN" or "Bal Rs NNNN.NN"
    final balRsMatch = RegExp(
      r'Bal\s+Rs\.?\s*([0-9,]+(?:\.[0-9]{2})?)',
      caseSensitive: false,
    ).firstMatch(message);
    if (balRsMatch != null) {
      final balanceStr = balRsMatch.group(1)!.replaceAll(',', '');
      return double.tryParse(balanceStr);
    }

    return super.extractBalance(message);
  }

  @override
  bool isTransactionMessage(String message) {
    final lowerMessage = message.toLowerCase();

    // Skip bill alert notifications
    if (lowerMessage.contains('bill alert') ||
        (lowerMessage.contains('bill') && lowerMessage.contains('is due on'))) {
      return false;
    }

    // Check for payment alerts (current transactions)
    if (lowerMessage.contains('payment alert')) {
      // Make sure it's not a future debit
      if (!lowerMessage.contains('will be')) {
        return true;
      }
    }

    // Skip payment request messages
    if (lowerMessage.contains('has requested') ||
        lowerMessage.contains('to pay, download') ||
        lowerMessage.contains('collect request')) {
      return false;
    }

    // Skip credit card payment confirmations
    if (lowerMessage.contains('received towards your credit card')) {
      return false;
    }

    // Skip credit card payment credited notifications
    if (lowerMessage.contains('payment') &&
        lowerMessage.contains('credited to your card')) {
      return false;
    }

    return super.isTransactionMessage(message);
  }
}
