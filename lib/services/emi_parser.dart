import '../models/emi_model.dart';

class EmiParser {
  /// Detects if an SMS is an EMI payment notification
  /// Returns the EMI payment amount if detected, null otherwise
  static EmiPaymentDetected? detectEmiPayment(String sms, String sender) {
    final lower = sms.toLowerCase();

    // EMI/Loan keywords
    if (!_isEmiSms(lower)) return null;

    // Extract EMI amount
    final amount = _extractAmount(sms);
    if (amount == null) return null;

    // Extract lender/bank name
    final lenderName = _extractLenderName(sms, sender);

    // Extract EMI type
    final type = _detectEmiType(lower);

    return EmiPaymentDetected(
      amount: amount,
      lenderName: lenderName,
      type: type,
    );
  }

  static bool _isEmiSms(String lower) {
    const emiKeywords = [
      'emi',
      'loan',
      'payment',
      'installment',
      'due',
      'equated monthly',
      'home loan',
      'car loan',
      'personal loan',
      'education loan',
      'lender',
      'mortgage',
      'principal',
      'interest',
      'emis',
      'disbursed',
      'emi due',
      'pay emi',
      'emi payment',
      'loan payment',
    ];

    final count = emiKeywords.where((kw) => lower.contains(kw)).length;
    return count >= 1;
  }

  static double? _extractAmount(String sms) {
    final patterns = [
      RegExp(
        r'(?:rs\.?|inr|₹|amount|emi|payment|due|installment)[\s:]*(?:₹|rs\.?|inr)?\s*([0-9,]+(?:\.[0-9]{1,2})?)',
        caseSensitive: false,
      ),
      RegExp(
        r'([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:rs\.?|inr|₹)',
        caseSensitive: false,
      ),
    ];

    for (var pattern in patterns) {
      final match = pattern.firstMatch(sms);
      if (match != null) {
        try {
          final amountStr = match.group(1)!.replaceAll(',', '');
          final amount = double.parse(amountStr);
          if (amount > 0 && amount < 100000000) return amount;
        } catch (e) {
          continue;
        }
      }
    }
    return null;
  }

  static String _extractLenderName(String sms, String sender) {
    // Common lender patterns
    final lenderPatterns = {
      'hdfc': 'HDFC Bank',
      'icici': 'ICICI Bank',
      'sbi': 'SBI',
      'axis': 'Axis Bank',
      'kotak': 'Kotak Bank',
      'pnb': 'PNB',
      'bob': 'Bank of India',
      'canara': 'Canara Bank',
      'union': 'Union Bank',
      'yes': 'YES Bank',
      'borrow': 'Borrowing Platform',
      'lendingkart': 'Lendingkart',
      'moneyview': 'MoneyView',
      'indiabulls': 'IndiaBulls',
      'bajaj': 'Bajaj Finance',
      'hdfc capital': 'HDFC Capital',
      'icici lombard': 'ICICI Lombard',
    };

    final lowerSms = sms.toLowerCase();
    for (var entry in lenderPatterns.entries) {
      if (lowerSms.contains(entry.key) ||
          sender.toLowerCase().contains(entry.key)) {
        return entry.value;
      }
    }

    // Extract from text patterns
    final pattern = RegExp(
      r'(?:dear|dear customer|payment from|emi for)\s+([A-Za-z\s]+?)(?:\.|,|$)',
    );
    final match = pattern.firstMatch(sms);
    if (match != null) {
      return match.group(1)!.trim();
    }

    return 'Unknown Lender';
  }

  static EmiType _detectEmiType(String lower) {
    if (lower.contains('home') || lower.contains('property'))
      return EmiType.homeLoan;
    if (lower.contains('car') ||
        lower.contains('vehicle') ||
        lower.contains('auto'))
      return EmiType.carLoan;
    if (lower.contains('personal')) return EmiType.personalLoan;
    if (lower.contains('education') || lower.contains('student'))
      return EmiType.education;
    if (lower.contains('credit card')) return EmiType.creditCard;
    return EmiType.other;
  }

  /// Find matching EMI record for auto-update
  static Future<Map<String, dynamic>?> findMatchingEmi(
    double amount,
    String lenderName,
    EmiType type,
    dynamic db,
  ) async {
    // Try to find EMI with matching amount
    List<Map<String, dynamic>> results = await db.query(
      'emis',
      where: 'is_active = 1 AND emi_amount = ?',
      whereArgs: [amount],
    );

    if (results.isNotEmpty) {
      return results.first;
    }

    // Try to find by lender name (fuzzy match)
    results = await db.query(
      'emis',
      where: 'is_active = 1 AND lender_name LIKE ?',
      whereArgs: ['%${lenderName.split(' ').first}%'],
    );

    if (results.isNotEmpty) {
      return results.first;
    }

    return null;
  }
}

class EmiPaymentDetected {
  final double amount;
  final String lenderName;
  final EmiType type;

  EmiPaymentDetected({
    required this.amount,
    required this.lenderName,
    required this.type,
  });
}
