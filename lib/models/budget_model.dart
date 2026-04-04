class Budget {
  final int? id;
  final String category;
  final double monthlyLimit;
  final int month;
  final int year;
  final bool isActive;

  const Budget({
    this.id,
    required this.category,
    required this.monthlyLimit,
    required this.month,
    required this.year,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'category': category,
      'monthly_limit': monthlyLimit,
      'month': month,
      'year': year,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'] as int?,
      category: map['category'] as String,
      monthlyLimit: (map['monthly_limit'] as num).toDouble(),
      month: map['month'] as int,
      year: map['year'] as int,
      isActive: (map['is_active'] ?? 1) == 1,
    );
  }
}
