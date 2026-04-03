import { FamilySummary } from "@/types/family";

export const mockFamilySummary: FamilySummary = {
  familyId: "demo-family-001",
  familyName: "Patel Family",
  totalMonthlySpend: 31840,
  memberBreakdown: [
    { userId: "u-1", name: "Ravi", role: "admin", monthlySpend: 11240 },
    { userId: "u-2", name: "Meera", role: "member", monthlySpend: 10100 },
    { userId: "u-3", name: "Aarav", role: "member", monthlySpend: 10500 },
  ],
  topCategories: [
    { category: "Food", amount: 10400 },
    { category: "Shopping", amount: 8320 },
    { category: "Transport", amount: 6240 },
    { category: "Bills", amount: 4280 },
    { category: "Health", amount: 2600 },
  ],
  source: "mock",
};
