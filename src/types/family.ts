export type FamilyMember = {
  userId: string;
  name: string;
  role: "admin" | "member";
  monthlySpend: number;
  avatarColor: string;
};

export type Transaction = {
  id: string;
  userId: string;
  userName: string;
  amount: number;
  type: "debit" | "credit";
  category: string;
  merchant: string | null;
  source: "sms" | "manual" | "vision" | "voice";
  txnTime: string;
};

export type DailySpend = {
  date: string;      // ISO date  e.g. "2026-04-03"
  dayOfMonth: number;
  cumulativeSpend: number;
};

export type FamilySummary = {
  familyId: string;
  familyName: string;
  inviteCode?: string | null;
  totalMonthlySpend: number;
  monthlyBudget: number;
  memberBreakdown: FamilyMember[];
  topCategories: Array<{ category: string; amount: number }>;
  dailySpend: DailySpend[];
  recentTransactions: Transaction[];
  source: "supabase" | "mock";
};
