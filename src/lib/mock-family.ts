import { FamilySummary } from "@/types/family";

const now = new Date();
const day = now.getDate();

// Generate realistic daily spend data
function generateDailySpend() {
  const days = [];
  let cumulative = 0;
  for (let d = 1; d <= day; d++) {
    const dailyAmount = 800 + Math.floor(Math.random() * 600);
    cumulative += dailyAmount;
    const dateStr = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-${String(d).padStart(2, "0")}`;
    days.push({ date: dateStr, dayOfMonth: d, cumulativeSpend: cumulative });
  }
  return days;
}

const dailySpend = generateDailySpend();
const totalSpend = dailySpend.length > 0 ? dailySpend[dailySpend.length - 1].cumulativeSpend : 0;

export const mockFamilySummary: FamilySummary = {
  familyId: "demo-family-001",
  familyName: "Patel Family",
  totalMonthlySpend: totalSpend,
  monthlyBudget: 40000,
  memberBreakdown: [
    { userId: "u-1", name: "Ravi", role: "admin", monthlySpend: Math.round(totalSpend * 0.38), avatarColor: "#0f766e" },
    { userId: "u-2", name: "Meera", role: "member", monthlySpend: Math.round(totalSpend * 0.32), avatarColor: "#b45309" },
    { userId: "u-3", name: "Aarav", role: "member", monthlySpend: Math.round(totalSpend * 0.30), avatarColor: "#7c3aed" },
  ],
  topCategories: [
    { category: "Food", amount: Math.round(totalSpend * 0.28) },
    { category: "Shopping", amount: Math.round(totalSpend * 0.22) },
    { category: "Transport", amount: Math.round(totalSpend * 0.18) },
    { category: "Bills", amount: Math.round(totalSpend * 0.16) },
    { category: "Health", amount: Math.round(totalSpend * 0.09) },
    { category: "Entertainment", amount: Math.round(totalSpend * 0.07) },
  ],
  dailySpend,
  recentTransactions: [
    {
      id: "tx-1", userId: "u-3", userName: "Aarav", amount: 849	,
      type: "debit", category: "Shopping", merchant: "Amazon",
      source: "sms", txnTime: new Date(now.getTime() - 1800000).toISOString(),
    },
    {
      id: "tx-2", userId: "u-2", userName: "Meera", amount: 347,
      type: "debit", category: "Food", merchant: "BigBazaar",
      source: "vision", txnTime: new Date(now.getTime() - 5400000).toISOString(),
    },
    {
      id: "tx-3", userId: "u-1", userName: "Ravi", amount: 1200,
      type: "debit", category: "Bills", merchant: "Jio Fiber",
      source: "sms", txnTime: new Date(now.getTime() - 14400000).toISOString(),
    },
    {
      id: "tx-4", userId: "u-3", userName: "Aarav", amount: 150,
      type: "debit", category: "Transport", merchant: "Uber",
      source: "sms", txnTime: new Date(now.getTime() - 21600000).toISOString(),
    },
    {
      id: "tx-5", userId: "u-2", userName: "Meera", amount: 2100,
      type: "debit", category: "Health", merchant: "Apollo Pharmacy",
      source: "manual", txnTime: new Date(now.getTime() - 43200000).toISOString(),
    },
    {
      id: "tx-6", userId: "u-1", userName: "Ravi", amount: 500,
      type: "debit", category: "Food", merchant: "Swiggy",
      source: "sms", txnTime: new Date(now.getTime() - 57600000).toISOString(),
    },
    {
      id: "tx-7", userId: "u-2", userName: "Meera", amount: 3200,
      type: "debit", category: "Shopping", merchant: "Myntra",
      source: "sms", txnTime: new Date(now.getTime() - 72000000).toISOString(),
    },
    {
      id: "tx-8", userId: "u-1", userName: "Ravi", amount: 80,
      type: "debit", category: "Transport", merchant: "Metro Card",
      source: "sms", txnTime: new Date(now.getTime() - 86400000).toISOString(),
    },
  ],
  source: "mock",
};
