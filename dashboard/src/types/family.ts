export type FamilyMember = {
  userId: string;
  name: string;
  role: "admin" | "member";
  monthlySpend: number;
};

export type FamilySummary = {
  familyId: string;
  familyName: string;
  totalMonthlySpend: number;
  memberBreakdown: FamilyMember[];
  topCategories: Array<{ category: string; amount: number }>;
  source: "supabase" | "mock";
};
