import '../models/bill_reminder_model.dart';

class BillReminderParser {
  static BillDetected? detectBill(String sms, String sender) {
    final lower = sms.toLowerCase();

    if (!_isBillSms(lower)) return null;

    final amount = _extractAmount(sms);
    if (amount == null) return null;

    final category = _detectBillCategory(sms, lower);
    final billName = _extractBillName(sms, lower, category);

    return BillDetected(
      billName: billName,
      category: category,
      amount: amount,
      frequency: BillFrequency.monthly, // Default to monthly
    );
  }

  static bool _isBillSms(String lower) {
    const billKeywords = [
      'bill',
      'electricity',
      'water',
      'gas',
      'internet',
      'broadband',
      'mobile',
      'recharge',
      'due',
      'payment due',
      'pay',
      'utility',
      'invoice',
      'statement',
      'monthly',
      'quarterly',
      'subscription',
      'renewal',
    ];

    return billKeywords.any((kw) => lower.contains(kw));
  }

  static double? _extractAmount(String sms) {
    final patterns = [
      RegExp(
        r'(?:₹|rs\.?|inr|amount)\s*([0-9,]+(?:\.[0-9]{1,2})?)',
        caseSensitive: false,
      ),
      RegExp(
        r'([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:₹|rs\.?|inr)',
        caseSensitive: false,
      ),
    ];

    for (var pattern in patterns) {
      final match = pattern.firstMatch(sms);
      if (match != null) {
        try {
          final amountStr = match.group(1)!.replaceAll(',', '');
          final amount = double.parse(amountStr);
          if (amount > 0 && amount < 100000) return amount;
        } catch (e) {
          continue;
        }
      }
    }
    return null;
  }

  static String _detectBillCategory(String sms, String lower) {
    if (lower.contains('electricity') || lower.contains('electric'))
      return 'electricity';
    if (lower.contains('water')) return 'water';
    if (lower.contains('gas')) return 'gas';
    if (lower.contains('internet') ||
        lower.contains('broadband') ||
        lower.contains('wifi'))
      return 'internet';
    if (lower.contains('mobile') ||
        lower.contains('recharge') ||
        lower.contains('phone'))
      return 'mobile';
    if (lower.contains('netflix') ||
        lower.contains('prime') ||
        lower.contains('spotify'))
      return 'subscription';
    if (lower.contains('insurance')) return 'insurance';
    if (lower.contains('rent')) return 'rent';
    return 'other';
  }

  static String _extractBillName(String sms, String lower, String category) {
    final providerNames = {
      'electricity': ['discoms', 'electricity board', 'power', 'electricity'],
      'internet': ['jio', 'airtel', 'voda', 'idea', 'broadband', 'isp'],
      'mobile': ['jio', 'airtel', 'voda', 'idea', 'mobile'],
      'water': ['water board', 'municipal'],
      'gas': ['lpg', 'gas agency', 'gas'],
    };

    final providers = providerNames[category] ?? [];
    for (var provider in providers) {
      if (lower.contains(provider)) {
        return provider.replaceFirst(provider[0], provider[0].toUpperCase());
      }
    }

    return category.replaceFirst(category[0], category[0].toUpperCase());
  }
}

class BillDetected {
  final String billName;
  final String category;
  final double amount;
  final BillFrequency frequency;

  BillDetected({
    required this.billName,
    required this.category,
    required this.amount,
    required this.frequency,
  });
}
