export type ForecastResult = {
  burnRatePerDay: number;
  projectedMonthSpend: number;
  projectedBudgetExhaustionDay: number | null;
  willExhaustInMonth: boolean;
};

export function computeForecast({
  monthlyBudget,
  spentSoFar,
  daysElapsed,
  daysInMonth,
}: {
  monthlyBudget: number;
  spentSoFar: number;
  daysElapsed: number;
  daysInMonth: number;
}): ForecastResult {
  if (monthlyBudget <= 0 || daysElapsed <= 0 || daysInMonth <= 0) {
    return {
      burnRatePerDay: 0,
      projectedMonthSpend: 0,
      projectedBudgetExhaustionDay: null,
      willExhaustInMonth: false,
    };
  }

  const burnRatePerDay = spentSoFar <= 0 ? 0 : spentSoFar / daysElapsed;
  const projectedMonthSpend = burnRatePerDay * daysInMonth;

  if (burnRatePerDay <= 0) {
    return {
      burnRatePerDay,
      projectedMonthSpend,
      projectedBudgetExhaustionDay: null,
      willExhaustInMonth: false,
    };
  }

  const projectedDay = Math.ceil(monthlyBudget / burnRatePerDay);
  const willExhaustInMonth = projectedDay <= daysInMonth;

  return {
    burnRatePerDay,
    projectedMonthSpend,
    projectedBudgetExhaustionDay: willExhaustInMonth ? projectedDay : null,
    willExhaustInMonth,
  };
}
