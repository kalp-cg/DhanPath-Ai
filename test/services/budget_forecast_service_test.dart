import 'package:dhanpath/services/budget_forecast_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BudgetForecastService', () {
    const service = BudgetForecastService();

    test('returns zeroed forecast when monthly budget is invalid', () {
      final result = service.generate(
        monthlyBudget: 0,
        spentSoFar: 1000,
        daysElapsed: 5,
        daysInMonth: 30,
      );

      expect(result.currentBurnRatePerDay, 0);
      expect(result.projectedMonthSpend, 0);
      expect(result.projectedBudgetExhaustionDay, isNull);
      expect(result.willExhaustWithinMonth, isFalse);
    });

    test('projects exhaustion day inside month when burn rate is high', () {
      final result = service.generate(
        monthlyBudget: 40000,
        spentSoFar: 20000,
        daysElapsed: 10,
        daysInMonth: 30,
      );

      expect(result.currentBurnRatePerDay, 2000);
      expect(result.projectedMonthSpend, 60000);
      expect(result.projectedBudgetExhaustionDay, 20);
      expect(result.willExhaustWithinMonth, isTrue);
    });

    test('does not mark exhaustion if projected day exceeds month length', () {
      final result = service.generate(
        monthlyBudget: 40000,
        spentSoFar: 8000,
        daysElapsed: 10,
        daysInMonth: 30,
      );

      expect(result.currentBurnRatePerDay, 800);
      expect(result.projectedMonthSpend, 24000);
      expect(result.projectedBudgetExhaustionDay, isNull);
      expect(result.willExhaustWithinMonth, isFalse);
    });
  });
}
