class SavingsGoal {
  final int? id;
  final String goalName;
  final double targetAmount;
  final double currentAmount;
  final double monthlyContribution;
  final DateTime targetDate;
  final DateTime startDate;
  final String? description;
  final String? icon;
  final String color;
  final String status; // active, completed, paused

  SavingsGoal({
    this.id,
    required this.goalName,
    required this.targetAmount,
    this.currentAmount = 0.0,
    this.monthlyContribution = 0.0,
    required this.targetDate,
    required this.startDate,
    this.description,
    this.icon,
    this.color = 'FF4CAF50',
    this.status = 'active',
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'goal_name': goalName,
      'target_amount': targetAmount,
      'current_amount': currentAmount,
      'monthly_contribution': monthlyContribution,
      'target_date': targetDate.toIso8601String(),
      'start_date': startDate.toIso8601String(),
      'description': description,
      'icon': icon,
      'color': color,
      'status': status,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  factory SavingsGoal.fromMap(Map<String, dynamic> map) {
    return SavingsGoal(
      id: map['id'] as int?,
      goalName: map['goal_name'] as String,
      targetAmount: (map['target_amount'] as num).toDouble(),
      currentAmount: (map['current_amount'] as num).toDouble(),
      monthlyContribution: (map['monthly_contribution'] as num).toDouble(),
      targetDate: DateTime.parse(map['target_date'] as String),
      startDate: DateTime.parse(map['start_date'] as String),
      description: map['description'] as String?,
      icon: map['icon'] as String?,
      color: map['color'] as String? ?? 'FF4CAF50',
      status: map['status'] as String? ?? 'active',
    );
  }

  SavingsGoal copyWith({
    int? id,
    String? goalName,
    double? targetAmount,
    double? currentAmount,
    double? monthlyContribution,
    DateTime? targetDate,
    DateTime? startDate,
    String? description,
    String? icon,
    String? color,
    String? status,
  }) {
    return SavingsGoal(
      id: id ?? this.id,
      goalName: goalName ?? this.goalName,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      monthlyContribution: monthlyContribution ?? this.monthlyContribution,
      targetDate: targetDate ?? this.targetDate,
      startDate: startDate ?? this.startDate,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      status: status ?? this.status,
    );
  }

  double get progressPercentage {
    if (targetAmount == 0) return 0;
    return (currentAmount / targetAmount) * 100;
  }
}
