import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../models/transaction_model.dart';
import '../../services/compiled_patterns.dart';

/// Parsed transaction data before converting to Transaction model
class ParsedTransaction {
  final double amount;
  final TransactionType type;
  final String? merchant;
  final String? reference;
  final String? accountLast4;
  final double? balance;
  final double? creditLimit;
  final String smsBody;
  final String sender;
  final int timestamp;
  final String bankName;
  final bool isFromCard;
  final String currency;

  ParsedTransaction({
    required this.amount,
    required this.type,
    this.merchant,
    this.reference,
    this.accountLast4,
    this.balance,
    this.creditLimit,
    required this.smsBody,
    required this.sender,
    required this.timestamp,
    required this.bankName,
    this.isFromCard = false,
    this.currency = 'INR',
  });

  /// Generate unique hash for duplicate detection
  String generateHash() {
    final hashInput =
        '${amount}_${type.name}_${merchant ?? 'unknown'}_'
        '${accountLast4 ?? 'none'}_${timestamp ~/ 60000}'; // Group by minute
    final bytes = utf8.encode(hashInput);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Convert to Transaction model
  Transaction toTransaction() {
    return Transaction(
      amount: amount,
      merchantName: merchant ?? 'Unknown',
      category: _categorizeByType(type),
      type: _mapTransactionType(type),
      date: DateTime.fromMillisecondsSinceEpoch(timestamp),
      smsBody: smsBody,
      bankName: bankName,
      accountNumber: accountLast4,
      reference: reference,
      balance: balance,
      creditLimit: creditLimit,
      isFromCard: isFromCard,
      currency: currency,
      transactionHash: generateHash(),
    );
  }

  String _categorizeByType(TransactionType type) {
    switch (type) {
      case TransactionType.income:
        return 'Income';
      case TransactionType.credit:
        return 'Credit Card';
      case TransactionType.expense:
        return 'Expense';
      default:
        return 'Expense';
    }
  }

  TransactionType _mapTransactionType(TransactionType type) {
    // Returns the same type - both enums match now
    return type;
  }
}

/// Base class for bank-specific SMS parsers
/// Each bank extends this and implements specific parsing logic
abstract class BankParser {
  /// Returns the name of the bank this parser handles
  String getBankName();

  /// Checks if this parser can handle messages from the given sender
  bool canHandle(String sender);

  /// Returns the currency used by this bank (defaults to INR for Indian banks)
  String getCurrency() => 'INR';

  /// Main parsing method - extracts transaction from SMS
  ParsedTransaction? parse(String smsBody, String sender, int timestamp) {
    // Skip non-transaction messages
    if (!isTransactionMessage(smsBody)) {
      return null;
    }

    final amount = extractAmount(smsBody);
    if (amount == null || amount <= 0) {
      return null;
    }

    final type = extractTransactionType(smsBody);
    if (type == null) {
      return null;
    }

    // Extract available limit for credit card transactions
    final availableLimit = type == TransactionType.credit
        ? extractAvailableLimit(smsBody)
        : null;

    return ParsedTransaction(
      amount: amount,
      type: type,
      merchant: extractMerchant(smsBody, sender),
      reference: extractReference(smsBody),
      accountLast4: extractAccountLast4(smsBody),
      balance: extractBalance(smsBody),
      creditLimit: availableLimit,
      smsBody: smsBody,
      sender: sender,
      timestamp: timestamp,
      bankName: getBankName(),
      isFromCard: detectIsCard(smsBody),
      currency: getCurrency(),
    );
  }

  /// Checks if the message is a transaction (not OTP, promotional, etc.)
  bool isTransactionMessage(String message) {
    final lowerMessage = message.toLowerCase();

    // Skip OTP messages (but not "Never Share OTP" disclaimers in transaction SMS)
    if ((lowerMessage.contains('otp') &&
            !lowerMessage.contains('share otp') &&
            !lowerMessage.contains('share your otp')) ||
        lowerMessage.contains('one time password') ||
        lowerMessage.contains('verification code')) {
      return false;
    }

    // Skip promotional messages
    if (lowerMessage.contains('offer') ||
        lowerMessage.contains('discount') ||
        lowerMessage.contains('cashback offer') ||
        lowerMessage.contains('win ')) {
      return false;
    }

    // Skip payment request messages
    if (lowerMessage.contains('has requested') ||
        lowerMessage.contains('payment request') ||
        lowerMessage.contains('collect request') ||
        lowerMessage.contains('requesting payment') ||
        lowerMessage.contains('requests rs') ||
        lowerMessage.contains('ignore if already paid')) {
      return false;
    }

    // Skip merchant payment acknowledgments
    if (lowerMessage.contains('have received payment')) {
      return false;
    }

    // Skip payment reminder/due messages
    if (lowerMessage.contains('is due') ||
        lowerMessage.contains('min amount due') ||
        lowerMessage.contains('minimum amount due') ||
        lowerMessage.contains('in arrears') ||
        lowerMessage.contains('is overdue') ||
        lowerMessage.contains('ignore if paid') ||
        (lowerMessage.contains('pls pay') && lowerMessage.contains('min of'))) {
      return false;
    }

    // Skip spam / scam / fake SMS (gambling, loan scams, phishing, etc.)
    for (final pattern in CompiledPatterns.allSpamBodyPatterns) {
      if (pattern.hasMatch(message)) {
        return false;
      }
    }

    // Must contain transaction keywords
    const transactionKeywords = [
      'debited',
      'credited',
      'withdrawn',
      'deposited',
      'spent',
      'received',
      'transferred',
      'paid',
      'used',
      'purchase',
      'transaction',
      'payment',
      'sent',
    ];

    if (transactionKeywords.any((keyword) => lowerMessage.contains(keyword))) {
      return true;
    }

    // Dr./Cr. abbreviations used by BOB and other banks
    // e.g. "Rs.34.00 Dr. from A/C" or "Cr. to gsrtc111@icici"
    if (RegExp(r'\b(?:dr|cr)\.\s', caseSensitive: false).hasMatch(message)) {
      return true;
    }

    return false;
  }

  /// Extract transaction amount from SMS
  double? extractAmount(String message) {
    // Common patterns for amount extraction
    // rs[.:] handles both "Rs.207" and "Rs:207" (Union Bank uses colon)
    final patterns = [
      RegExp(
        r'(?:rs[.:]?|inr|₹)\s*([0-9,]+(?:\.[0-9]{1,2})?)',
        caseSensitive: false,
      ),
      RegExp(
        r'([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:rs[.:]?|inr|₹)',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:amount|amt)\s*(?:of)?\s*(?:rs[.:]?|inr|₹)?\s*([0-9,]+(?:\.[0-9]{1,2})?)',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(message);
      if (match != null) {
        final amountStr = match.group(1)!.replaceAll(',', '');
        final amount = double.tryParse(amountStr);
        if (amount != null && amount > 0) {
          return amount;
        }
      }
    }

    return null;
  }

  /// Extract transaction type (debit/credit/income)
  TransactionType? extractTransactionType(String message) {
    final lowerMessage = message.toLowerCase();

    // Credit card transactions
    if (lowerMessage.contains('block cc') ||
        lowerMessage.contains('block pcc')) {
      return TransactionType.credit;
    }

    // Normalize Dr./Cr. abbreviations to debited/credited for unified handling
    // e.g. "Rs.34.00 Dr. from A/C" → "Rs.34.00 debited from A/C"
    //       "Cr. to gsrtc111@icici" → "credited to gsrtc111@icici"
    String normalizedMessage = lowerMessage;
    normalizedMessage = normalizedMessage.replaceAll(
      RegExp(r'\bdr\.\s'),
      'debited ',
    );
    normalizedMessage = normalizedMessage.replaceAll(
      RegExp(r'\bcr\.\s'),
      'credited ',
    );

    // When BOTH "debited" and "credited" appear, use position & context:
    //   "Rs.450 debited A/c...credited to Faisal" → expense (your money left)
    //   "Rs.450 credited...debited from sender"   → income  (rare, but possible)
    final hasDebited = normalizedMessage.contains('debited');
    final hasCredited = normalizedMessage.contains('credited');
    if (hasDebited && hasCredited) {
      final debitIdx = normalizedMessage.indexOf('debited');
      final creditIdx = normalizedMessage.indexOf('credited');
      // "credited to <name>" means money went TO someone else → expense
      // "credited to your" means money came TO you → income
      final creditedToYour = RegExp(
        r'credited\s+to\s+(?:your|ur|a/?c|ac\b)',
        caseSensitive: false,
      ).hasMatch(normalizedMessage);
      if (creditedToYour) {
        return TransactionType.income;
      }
      // Whichever keyword appears first describes YOUR account
      return debitIdx < creditIdx
          ? TransactionType.expense
          : TransactionType.income;
    }

    // Income keywords
    if (hasCredited ||
        normalizedMessage.contains('deposited') ||
        normalizedMessage.contains('received') ||
        normalizedMessage.contains('refund')) {
      return TransactionType.income;
    }

    // Expense keywords
    if (hasDebited ||
        normalizedMessage.contains('withdrawn') ||
        normalizedMessage.contains('spent') ||
        normalizedMessage.contains('used') ||
        normalizedMessage.contains('paid') ||
        normalizedMessage.contains('purchase') ||
        normalizedMessage.contains('payment') ||
        normalizedMessage.contains('transaction')) {
      return TransactionType.expense;
    }

    return null;
  }

  /// Extract merchant name from SMS
  String? extractMerchant(String message, String sender) {
    // Match Kotlin's CompiledPatterns.Merchant.ALL_PATTERNS order
    // But handle UPI VPAs with dots better
    final patterns = [
      // UPI path format: UPI/DR/<ref>/<merchant>
      RegExp(r'UPI/(?:DR|CR)/[A-Za-z0-9]+/([^/\.\n]+)', caseSensitive: false),
      // VPA pattern: "credited to VPA GSRTC111@icici" - highest priority
      RegExp(r'VPA\s+([^@\s]+)@', caseSensitive: false),
      // TO_PATTERN: to [MERCHANT] followed by (UPI, on, was, or end/dot)
      RegExp(
        r'to\s+([^(\n]+?)(?:\s+\(UPI|\s+on\s+\d{2}|\s+was|[\.$])',
        caseSensitive: false,
      ),
      // FROM_PATTERN
      RegExp(
        r'from\s+([^(\n]+?)(?:\s+\(UPI|\s+on\s+\d{2}|\s+was|[\.$])',
        caseSensitive: false,
      ),
      // AT_PATTERN: at [MERCHANT] followed by (on, made, Ref, or end/dot)
      RegExp(
        r'at\s+([^\.\n]+?)(?:\s+on|\s+made|\s+Ref|[\.$])',
        caseSensitive: false,
      ),
      // FOR_PATTERN
      RegExp(
        r'for\s+([^\.\n]+?)(?:\s+on|\s+at|\s+Ref|[\.$])',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(message);
      if (match != null) {
        final rawMerchant = match.group(1)!.trim();
        // Skip if this looks like an account reference (e.g. "A/c ...3")
        if (RegExp(r'^A/c\b', caseSensitive: false).hasMatch(rawMerchant)) {
          continue;
        }
        // Extract merchant from UPI VPA if present (handles user@bank format)
        final extractedMerchant = extractMerchantFromUpiVpa(rawMerchant);
        final cleanedMerchant = cleanMerchantName(extractedMerchant);
        if (isValidMerchant(cleanedMerchant)) {
          return cleanedMerchant;
        }
      }
    }

    return null;
  }

  /// Extracts merchant name from UPI VPA (Virtual Payment Address).
  /// Examples:
  /// - "paytmqr123@paytm" -> "paytm123"
  /// - "merchant@ybl" -> "merchant"
  /// - "phonepe.12345@ybl" -> "phonepe 12345"
  /// - "Regular Merchant" -> "Regular Merchant"
  String extractMerchantFromUpiVpa(String merchant) {
    if (!merchant.contains('@')) {
      return merchant;
    }

    // Extract the part before @ (the UPI handle)
    final upiHandle = merchant.split('@')[0].trim();

    if (upiHandle.isEmpty) {
      return merchant;
    }

    // Clean up common UPI prefixes/suffixes
    String cleanedName = upiHandle;

    // Remove common UPI QR suffixes (case insensitive)
    final qrSuffixes = ['qr', 'merchant', 'pay'];
    for (var suffix in qrSuffixes) {
      if (cleanedName.toLowerCase().endsWith(suffix) &&
          cleanedName.length > suffix.length) {
        // Only remove if there's something before the suffix
        final withoutSuffix = cleanedName.substring(
          0,
          cleanedName.length - suffix.length,
        );
        if (withoutSuffix.isNotEmpty &&
            RegExp(r'[a-zA-Z]').hasMatch(withoutSuffix)) {
          cleanedName = withoutSuffix;
          break;
        }
      }
    }

    // Replace dots and underscores with spaces for better readability
    cleanedName = cleanedName.replaceAll('.', ' ').replaceAll('_', ' ').trim();
    // Collapse multiple spaces
    cleanedName = cleanedName.replaceAll(RegExp(r'\s+'), ' ');

    // If the cleaned name is too short or has no letters, return the original handle
    if (cleanedName.length < 3 || !RegExp(r'[a-zA-Z]').hasMatch(cleanedName)) {
      return upiHandle;
    }

    return cleanedName;
  }

  /// Validates if extracted merchant name is useful
  bool isValidMerchant(String name) {
    if (name.length < 3) {
      // Allow short brand-like tokens such as "O2".
      if (!RegExp(r'^[a-zA-Z]\d[a-zA-Z0-9]*$').hasMatch(name.trim())) {
        return false;
      }
    }
    if (RegExp(r'^\d+$').hasMatch(name)) return false;
    if (name.contains('@')) return false;
    if (!RegExp(r'[a-zA-Z]').hasMatch(name)) return false;

    final invalid = {
      'via',
      'through',
      'by',
      'with',
      'for',
      'to',
      'from',
      'at',
      'the',
      'info',
      'neft',
      'imps',
      'rtgs',
      'txn',
      'transfer',
      'payment',
      'sent',
      'using',
      'upi',
      'ref',
      'reference',
      'transaction',
      'card',
      'account',
      'bank',
      'hdfc',
      'hdfc bank',
      'sbi',
      'icici',
      'icici bank',
      'axis',
      'axis bank',
      'kotak',
      'yes bank',
      'pnb',
      'bob',
      'credit card',
      'debit card',
    };

    if (invalid.contains(name.toLowerCase().trim())) return false;

    // Reject "XXX Bank" patterns
    final lower = name.toLowerCase().trim();
    if (RegExp(
          r'^[\w\s]*\bbank\b[\w\s]*$',
          caseSensitive: false,
        ).hasMatch(lower) &&
        lower.split(' ').length <= 3) {
      return false;
    }

    return true;
  }

  /// Clean merchant name by removing common suffixes
  String cleanMerchantName(String merchant) {
    return merchant
        .replaceAll(
          RegExp(r'\s+(?:on|at|via|using)\s+.*', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(
            r'\s+(?:avbl|avl|available)\s+(?:bal|balance).*',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'[^\w\s&\-]'), '')
        .trim();
  }

  /// Extract reference/transaction ID
  String? extractReference(String message) {
    final patterns = [
      // "UPI Ref:DR/979247477" - extract numeric part after DR/
      RegExp(r'UPI\s+Ref[:\s]+DR/([0-9]+)', caseSensitive: false),
      // "UPI Ref no 979247477496" or "UPI Ref:979247477"
      RegExp(r'UPI\s+Ref\s+(?:no\.?\s+)?([a-z0-9]+)', caseSensitive: false),
      RegExp(
        r'(?:ref|reference|txn|transaction|upi\s*ref)[\s:]+([a-z0-9]+)',
        caseSensitive: false,
      ),
      RegExp(r'(?:id|ref):\s*([a-z0-9]+)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(message);
      if (match != null) {
        return match.group(1);
      }
    }

    return null;
  }

  /// Extract account last 4 digits
  String? extractAccountLast4(String message) {
    final patterns = [
      // Plain account ending format: "A/c ending 1234"
      RegExp(
        r'a/c\s*(?:no\.?\s*)?(?:ending|end|ending in)\s*(\d{4})',
        caseSensitive: false,
      ),
      // Standard masked: a/c XX1234 or a/c XXXX1234 or a/c no. XXXXXXXXXXX0693
      RegExp(r'a/c\s*(?:no\.?\s*)?(?:x+|\*+)(\d{3,4})', caseSensitive: false),
      // Ellipsis format: A/c ...3 or A/c ....0693
      RegExp(r'a/c\s*(?:no\.?\s*)?\.{2,}(\d{1,4})', caseSensitive: false),
      RegExp(r'card\s*(?:x+|\*+)?(\d{4})', caseSensitive: false),
      RegExp(r'xx(\d{4})', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(message);
      if (match != null) {
        return match.group(1);
      }
    }

    return null;
  }

  /// Extract account balance
  double? extractBalance(String message) {
    final patterns = [
      // "Clear Bal Rs.8168.15" format used by some banks (e.g. BGGB)
      RegExp(
        r'Clear\s+Bal\s+Rs[.:]?\s*([0-9,]+(?:\.[0-9]{2})?)',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:balance|bal|avl\s*bal|clear\s*bal)[:\s]*(?:rs[.:]?|inr|₹)?\s*([0-9,]+(?:\.[0-9]{2})?)',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(message);
      if (match != null) {
        final balanceStr = match.group(1)!.replaceAll(',', '');
        return double.tryParse(balanceStr);
      }
    }

    return null;
  }

  /// Extract available credit limit
  double? extractAvailableLimit(String message) {
    final patterns = [
      RegExp(
        r'(?:available|avl)\s*(?:limit|bal)[:\s]*(?:rs\.?|inr|₹)?\s*([0-9,]+(?:\.[0-9]{2})?)',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(message);
      if (match != null) {
        final limitStr = match.group(1)!.replaceAll(',', '');
        return double.tryParse(limitStr);
      }
    }

    return null;
  }

  /// Detect if transaction is from a card
  bool detectIsCard(String message) {
    final lowerMessage = message.toLowerCase();
    return lowerMessage.contains('card') ||
        lowerMessage.contains('block cc') ||
        lowerMessage.contains('block dc');
  }
}
