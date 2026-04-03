import { NextRequest, NextResponse } from "next/server";

import { computeForecast } from "@/lib/forecast";

export async function GET(request: NextRequest) {
  const q = request.nextUrl.searchParams;
  const monthlyBudget = Number(q.get("monthlyBudget") ?? 40000);
  const spentSoFar = Number(q.get("spentSoFar") ?? 0);
  const daysElapsed = Number(q.get("daysElapsed") ?? new Date().getDate());
  const daysInMonth = Number(
    q.get("daysInMonth") ?? new Date(new Date().getFullYear(), new Date().getMonth() + 1, 0).getDate(),
  );

  const forecast = computeForecast({
    monthlyBudget,
    spentSoFar,
    daysElapsed,
    daysInMonth,
  });

  return NextResponse.json(forecast);
}
