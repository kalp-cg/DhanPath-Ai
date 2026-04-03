import { FamilyMember, FamilySummary, Transaction, DailySpend } from "@/types/family";
import { createSupabaseStorageClient } from "@/lib/supabase-server";

const AVATAR_COLORS = [
  "#0f766e", "#b45309", "#7c3aed", "#db2777",
  "#059669", "#d97706",
];

function getMonthStartIso(): string {
  const now = new Date();
  const first = new Date(now.getFullYear(), now.getMonth(), 1);
  return first.toISOString();
}

export async function fetchFamilySummaryFromStorage(
  familyId: string,
): Promise<FamilySummary> {
  const supabase = createSupabaseStorageClient();

  const [familyRes, memberRes, txRes, budgetRes] = await Promise.all([
    supabase.from("families").select("id,name").eq("id", familyId).single(),
    supabase.from("family_members").select("user_id,role").eq("family_id", familyId),
    supabase
      .from("transactions")
      .select("id,user_id,amount,type,category,merchant,source,txn_time")
      .eq("family_id", familyId)
      .gte("txn_time", getMonthStartIso())
      .order("txn_time", { ascending: true }),
    supabase
      .from("budgets")
      .select("monthly_budget")
      .eq("family_id", familyId)
      .order("year", { ascending: false })
      .order("month", { ascending: false })
      .limit(1),
  ]);

  if (familyRes.error) throw new Error(`Family query failed: ${familyRes.error.message}`);
  if (memberRes.error) throw new Error(`Member query failed: ${memberRes.error.message}`);
  if (txRes.error) throw new Error(`Transaction query failed: ${txRes.error.message}`);

  const userIds = (memberRes.data ?? []).map((row) => String(row.user_id));
  const userRes = userIds.length
    ? await supabase.from("users").select("id,name").in("id", userIds)
    : { data: [] as Array<{ id: string; name: string | null }>, error: null };

  if (userRes.error) throw new Error(`User query failed: ${userRes.error.message}`);

  const userNameMap = new Map<string, string>();
  for (const row of userRes.data ?? []) {
    userNameMap.set(String(row.id), row.name?.trim() || String(row.id).slice(0, 8));
  }

  const memberSpendMap = new Map<string, number>();
  const categorySpendMap = new Map<string, number>();
  const dailyMap = new Map<string, number>();

  for (const tx of txRes.data ?? []) {
    const userId = String(tx.user_id ?? "");
    const category = String(tx.category ?? "Uncategorized");
    const amount = Number(tx.amount ?? 0);
    if (!userId || Number.isNaN(amount)) continue;

    memberSpendMap.set(userId, (memberSpendMap.get(userId) ?? 0) + amount);
    categorySpendMap.set(category, (categorySpendMap.get(category) ?? 0) + amount);

    const dateKey = new Date(tx.txn_time).toISOString().slice(0, 10);
    dailyMap.set(dateKey, (dailyMap.get(dateKey) ?? 0) + amount);
  }

  // Build cumulative daily spend
  const sortedDays = Array.from(dailyMap.keys()).sort();
  let cumulative = 0;
  const dailySpend: DailySpend[] = sortedDays.map((date) => {
    cumulative += dailyMap.get(date) ?? 0;
    return {
      date,
      dayOfMonth: new Date(date).getDate(),
      cumulativeSpend: cumulative,
    };
  });

  const memberBreakdown: FamilyMember[] = (memberRes.data ?? []).map((member, idx) => {
    const role: FamilyMember["role"] = member.role === "admin" ? "admin" : "member";
    const userId = String(member.user_id);
    return {
      userId,
      name: userNameMap.get(userId) || userId.slice(0, 8),
      role,
      monthlySpend: Number(memberSpendMap.get(userId) ?? 0),
      avatarColor: AVATAR_COLORS[idx % AVATAR_COLORS.length],
    };
  });

  const topCategories = Array.from(categorySpendMap.entries())
    .sort((a, b) => b[1] - a[1])
    .slice(0, 6)
    .map(([category, amount]) => ({ category, amount }));

  const totalMonthlySpend = memberBreakdown.reduce((sum, m) => sum + m.monthlySpend, 0);

  // Recent transactions (last 10)
  const allTx = txRes.data ?? [];
  const recentRaw = allTx.slice(-10).reverse();
  const recentTransactions: Transaction[] = recentRaw.map((tx) => ({
    id: String(tx.id),
    userId: String(tx.user_id),
    userName: userNameMap.get(String(tx.user_id)) || String(tx.user_id).slice(0, 8),
    amount: Number(tx.amount),
    type: (tx.type as "debit" | "credit") ?? "debit",
    category: String(tx.category ?? "Uncategorized"),
    merchant: tx.merchant ? String(tx.merchant) : null,
    source: (tx.source as Transaction["source"]) ?? "manual",
    txnTime: String(tx.txn_time),
  }));

  const monthlyBudget = budgetRes.data?.[0]?.monthly_budget
    ? Number(budgetRes.data[0].monthly_budget)
    : 40000;

  return {
    familyId,
    familyName: familyRes.data?.name ?? "Family Workspace",
    totalMonthlySpend,
    monthlyBudget,
    memberBreakdown,
    topCategories,
    dailySpend,
    recentTransactions,
    source: "supabase",
  };
}
