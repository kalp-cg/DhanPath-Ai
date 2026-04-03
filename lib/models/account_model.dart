class Account {
  final int? id;
  final String bankName;
  final String accountNumber; // Last 4 digits for privacy
  final String accountType; // Savings, Current, Credit Card
  final double? currentBalance;
  final String? iconName;
  final int isActive;

  Account({
    this.id,
    required this.bankName,
    required this.accountNumber,
    required this.accountType,
    this.currentBalance,
    this.iconName,
    this.isActive = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bank_name': bankName,
      'account_number': accountNumber,
      'account_type': accountType,
      'current_balance': currentBalance,
      'icon_name': iconName,
      'is_active': isActive,
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'],
      bankName: map['bank_name'],
      accountNumber: map['account_number'],
      accountType: map['account_type'],
      currentBalance: map['current_balance'],
      iconName: map['icon_name'],
      isActive: map['is_active'] ?? 1,
    );
  }

  String get displayName => '$bankName (XX$accountNumber)';
}
