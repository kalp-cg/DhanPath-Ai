/// Detects and parses Split Bill related SMS
class SplitBillParser {
  static SplitBillDetected? detectSplitBill(String sms, String sender) {
    final lower = sms.toLowerCase();

    // Keywords for split/shared expenses
    if (!_isSplitBillSms(lower)) return null;

    final amount = _extractAmount(sms);
    if (amount == null) return null;

    final person = _extractPersonName(sms, lower);
    final billName = _extractBillName(sms, lower);

    return SplitBillDetected(
      amount: amount,
      personName: person,
      billName: billName,
      isPaidByMe: _isPaidByMe(lower),
    );
  }

  static bool _isSplitBillSms(String lower) {
    const keywords = [
      'split',
      'owe',
      'owes',
      'pay back',
      'payback',
      'settled',
      'settlement',
      'paid for you',
      'your share',
      'share',
      'shared expense',
      'bill split',
    ];
    return keywords.any((kw) => lower.contains(kw));
  }

  static double? _extractAmount(String sms) {
    final patterns = [
      RegExp(
        r'(?:₹|rs\.?|inr)\s*([0-9,]+(?:\.[0-9]{1,2})?)',
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
          return double.parse(match.group(1)!.replaceAll(',', ''));
        } catch (e) {
          continue;
        }
      }
    }
    return null;
  }

  static String _extractPersonName(String sms, String lower) {
    final pattern = RegExp(
      r'(?:from|to|by|with)\s+([A-Za-z\s]+?)(?:\s+owes|\s+owe|\s+paid|\s+for|$)',
    );
    final match = pattern.firstMatch(sms);
    return match != null ? match.group(1)!.trim() : 'Friend';
  }

  static String _extractBillName(String sms, String lower) {
    if (lower.contains('food') ||
        lower.contains('dinner') ||
        lower.contains('lunch'))
      return 'Food/Dinner';
    if (lower.contains('movie') || lower.contains('cinema')) return 'Movie';
    if (lower.contains('uber') ||
        lower.contains('ola') ||
        lower.contains('ride'))
      return 'Ride';
    if (lower.contains('hotel') || lower.contains('restaurant'))
      return 'Restaurant';
    if (lower.contains('trip') || lower.contains('travel')) return 'Trip';
    if (lower.contains('party')) return 'Party';
    return 'Shared Expense';
  }

  static bool _isPaidByMe(String lower) {
    return lower.contains('you owe') ||
        lower.contains('you pay') ||
        lower.contains('owes me');
  }
}

class SplitBillDetected {
  final double amount;
  final String personName;
  final String billName;
  final bool isPaidByMe;

  SplitBillDetected({
    required this.amount,
    required this.personName,
    required this.billName,
    required this.isPaidByMe,
  });
}
