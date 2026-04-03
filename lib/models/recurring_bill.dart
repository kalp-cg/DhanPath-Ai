class RecurringBill {
  final int? id;
  final String name;
  final double amount;
  final String category;
  final int dayOfMonth; // 1-31
  final bool isActive;
  final DateTime? lastPaid;
  final DateTime createdAt;

  RecurringBill({
    this.id,
    required this.name,
    required this.amount,
    required this.category,
    required this.dayOfMonth,
    this.isActive = true,
    this.lastPaid,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'amount': amount,
      'category': category,
      'day_of_month': dayOfMonth,
      'is_active': isActive ? 1 : 0,
      'last_paid': lastPaid?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory RecurringBill.fromMap(Map<String, dynamic> map) {
    return RecurringBill(
      id: map['id'] as int?,
      name: map['name'] as String,
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String,
      dayOfMonth: map['day_of_month'] as int,
      isActive: (map['is_active'] as int) == 1,
      lastPaid: map['last_paid'] != null
          ? DateTime.parse(map['last_paid'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  RecurringBill copyWith({
    int? id,
    String? name,
    double? amount,
    String? category,
    int? dayOfMonth,
    bool? isActive,
    DateTime? lastPaid,
    DateTime? createdAt,
  }) {
    return RecurringBill(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      isActive: isActive ?? this.isActive,
      lastPaid: lastPaid ?? this.lastPaid,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
