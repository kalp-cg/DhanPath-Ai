class CategorySpending {
  final String category;
  final double amount;
  final double percentage;
  final int transactionCount;

  CategorySpending({
    required this.category,
    required this.amount,
    required this.percentage,
    this.transactionCount = 0,
  });

  factory CategorySpending.fromMap(Map<String, dynamic> map) {
    return CategorySpending(
      category: map['category'] ?? 'Uncategorized',
      amount: (map['amount'] ?? 0.0).toDouble(),
      percentage: (map['percentage'] ?? 0.0).toDouble(),
      transactionCount: map['transactionCount'] ?? 0,
    );
  }
}
