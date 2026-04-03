enum EmiType { homeLoan, carLoan, personalLoan, creditCard, education, other }

class Emi {
  final int? id;
  final String lenderName;
  final EmiType type;
  final double principalAmount;
  final double emiAmount;
  final double interestRate;
  final int tenureMonths;
  final int paidMonths;
  final DateTime startDate;
  final DateTime? endDate;
  final String? accountNumber;
  final double? currentOutstanding;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Emi({
    this.id,
    required this.lenderName,
    required this.type,
    required this.principalAmount,
    required this.emiAmount,
    required this.interestRate,
    required this.tenureMonths,
    this.paidMonths = 0,
    required this.startDate,
    this.endDate,
    this.accountNumber,
    this.currentOutstanding,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  double get totalInterest {
    final totalAmount = emiAmount * tenureMonths;
    return totalAmount - principalAmount;
  }

  double get interestPaidSoFar {
    final totalInterest = this.totalInterest;
    return (totalInterest / tenureMonths) * paidMonths;
  }

  double get remainingPrincipal {
    final remaining =
        currentOutstanding ??
        (principalAmount - (principalAmount / tenureMonths) * paidMonths);
    // Ensure never negative
    return remaining < 0 ? 0 : remaining;
  }

  int get remainingMonths {
    return tenureMonths - paidMonths;
  }

  double get progressPercentage {
    return (paidMonths / tenureMonths) * 100;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'lender_name': lenderName,
      'type': type.toString().split('.').last,
      'principal_amount': principalAmount,
      'emi_amount': emiAmount,
      'interest_rate': interestRate,
      'tenure_months': tenureMonths,
      'paid_months': paidMonths,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'account_number': accountNumber,
      'current_outstanding': currentOutstanding,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Emi.fromMap(Map<String, dynamic> map) {
    return Emi(
      id: map['id'] as int?,
      lenderName: map['lender_name'] as String,
      type: EmiType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
      ),
      principalAmount: (map['principal_amount'] as num).toDouble(),
      emiAmount: (map['emi_amount'] as num).toDouble(),
      interestRate: (map['interest_rate'] as num).toDouble(),
      tenureMonths: map['tenure_months'] as int,
      paidMonths: map['paid_months'] as int? ?? 0,
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: map['end_date'] != null
          ? DateTime.parse(map['end_date'] as String)
          : null,
      accountNumber: map['account_number'] as String?,
      currentOutstanding: map['current_outstanding'] != null
          ? (map['current_outstanding'] as num).toDouble()
          : null,
      isActive: map['is_active'] == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Emi copyWith({
    int? id,
    String? lenderName,
    EmiType? type,
    double? principalAmount,
    double? emiAmount,
    double? interestRate,
    int? tenureMonths,
    int? paidMonths,
    DateTime? startDate,
    DateTime? endDate,
    String? accountNumber,
    double? currentOutstanding,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Emi(
      id: id ?? this.id,
      lenderName: lenderName ?? this.lenderName,
      type: type ?? this.type,
      principalAmount: principalAmount ?? this.principalAmount,
      emiAmount: emiAmount ?? this.emiAmount,
      interestRate: interestRate ?? this.interestRate,
      tenureMonths: tenureMonths ?? this.tenureMonths,
      paidMonths: paidMonths ?? this.paidMonths,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      accountNumber: accountNumber ?? this.accountNumber,
      currentOutstanding: currentOutstanding ?? this.currentOutstanding,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
