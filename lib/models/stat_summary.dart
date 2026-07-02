class Summary {
  const Summary({
    required this.income,
    required this.expense,
  });

  final double income;
  final double expense;

  double get balance => income - expense;
}

class MonthlyTrend {
  const MonthlyTrend({
    required this.month,
    required this.income,
    required this.expense,
  });

  final String month;
  final double income;
  final double expense;
}

class CategoryExpenseStat {
  const CategoryExpenseStat({
    required this.categoryName,
    required this.amount,
  });

  final String categoryName;
  final double amount;
}
