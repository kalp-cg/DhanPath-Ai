enum BillFrequency { monthly, quarterly, yearly, weekly, daily }

enum BillStatus { pending, paid, overdue }

class BillReminder {
  final int? id;
  final String billName;
  final String category; // electricity, rent, mobile, internet, etc
  final double amount;
  final BillFrequency frequency;
  final int dayOfMonth; // 1-31 for monthly bills
  final DateTime? nextDueDate;
  final DateTime? lastPaidDate;
  final BillStatus status;
  final String? notes;
  final bool isActive;
  final bool autoDetected; // detected from SMS
  final DateTime createdAt;
  final DateTime updatedAt;

  BillReminder({
    this.id,
    required this.billName,
    required this.category,
    required this.amount,
    required this.frequency,
    required this.dayOfMonth,
    this.nextDueDate,
    this.lastPaidDate,
    this.status = BillStatus.pending,
    this.notes,
    this.isActive = true,
    this.autoDetected = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bill_name': billName,
      'category': category,
      'amount': amount,
      'frequency': frequency.toString().split('.').last,
      'day_of_month': dayOfMonth,
      'next_due_date': nextDueDate?.toIso8601String(),
      'last_paid_date': lastPaidDate?.toIso8601String(),
      'status': status.toString().split('.').last,
      'notes': notes,
      'is_active': isActive ? 1 : 0,
      'auto_detected': autoDetected ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory BillReminder.fromMap(Map<String, dynamic> map) {
    return BillReminder(
      id: map['id'] as int?,
      billName: map['bill_name'] as String,
      category: map['category'] as String,
      amount: (map['amount'] as num).toDouble(),
      frequency: BillFrequency.values.firstWhere(
        (e) => e.toString().split('.').last == map['frequency'],
      ),
      dayOfMonth: map['day_of_month'] as int,
      nextDueDate: map['next_due_date'] != null
          ? DateTime.parse(map['next_due_date'] as String)
          : null,
      lastPaidDate: map['last_paid_date'] != null
          ? DateTime.parse(map['last_paid_date'] as String)
          : null,
      status: BillStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
      ),
      notes: map['notes'] as String?,
      isActive: map['is_active'] == 1,
      autoDetected: map['auto_detected'] == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  BillReminder copyWith({
    int? id,
    String? billName,
    String? category,
    double? amount,
    BillFrequency? frequency,
    int? dayOfMonth,
    DateTime? nextDueDate,
    DateTime? lastPaidDate,
    BillStatus? status,
    String? notes,
    bool? isActive,
    bool? autoDetected,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BillReminder(
      id: id ?? this.id,
      billName: billName ?? this.billName,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      frequency: frequency ?? this.frequency,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      lastPaidDate: lastPaidDate ?? this.lastPaidDate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      autoDetected: autoDetected ?? this.autoDetected,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
