class BudgetForecast {
  final double currentBurnRatePerDay;
  final double projectedMonthSpend;
  final int? projectedBudgetExhaustionDay;
  final bool willExhaustWithinMonth;

  const BudgetForecast({
    required this.currentBurnRatePerDay,
    required this.projectedMonthSpend,
    required this.projectedBudgetExhaustionDay,
    required this.willExhaustWithinMonth,
  });
}

class BudgetForecastService {
  const BudgetForecastService();

  BudgetForecast generate({
    required double monthlyBudget,
    required double spentSoFar,
    required int daysElapsed,
    required int daysInMonth,
  }) {
    if (daysElapsed <= 0 || daysInMonth <= 0 || monthlyBudget <= 0) {
      return const BudgetForecast(
        currentBurnRatePerDay: 0,
        projectedMonthSpend: 0,
        projectedBudgetExhaustionDay: null,
        willExhaustWithinMonth: false,
      );
    }

    final burnRate = spentSoFar <= 0 ? 0.0 : spentSoFar / daysElapsed;
    final projectedSpend = burnRate * daysInMonth;

    int? exhaustionDay;
    var willExhaust = false;

    if (burnRate > 0) {
      final projectedDay = (monthlyBudget / burnRate).ceil();
      if (projectedDay <= daysInMonth) {
        exhaustionDay = projectedDay;
        willExhaust = true;
      }
    }

    return BudgetForecast(
      currentBurnRatePerDay: burnRate,
      projectedMonthSpend: projectedSpend,
      projectedBudgetExhaustionDay: exhaustionDay,
      willExhaustWithinMonth: willExhaust,
    );
  }
}
