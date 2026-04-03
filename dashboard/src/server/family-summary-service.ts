import { FamilyMember, FamilySummary } from "@/types/family";
import { createSupabaseStorageClient } from "@/lib/supabase-server";

function getMonthStartIso(): string {
  const now = new Date();
  const first = new Date(now.getFullYear(), now.getMonth(), 1);
  return first.toISOString();
}

export async function fetchFamilySummaryFromStorage(
  familyId: string,
): Promise<FamilySummary> {
  const supabase = createSupabaseStorageClient();

  const [familyRes, memberRes, txRes] = await Promise.all([
    supabase.from("families").select("id,name").eq("id", familyId).single(),
    supabase.from("family_members").select("user_id,role").eq("family_id", familyId),
    supabase
      .from("transactions")
      .select("user_id,amount,category,txn_time")
      .eq("family_id", familyId)
      .gte("txn_time", getMonthStartIso()),
  ]);

  if (familyRes.error) {
    throw new Error(`Family query failed: ${familyRes.error.message}`);
  }
  if (memberRes.error) {
    throw new Error(`Member query failed: ${memberRes.error.message}`);
  }
  if (txRes.error) {
    throw new Error(`Transaction query failed: ${txRes.error.message}`);
  }

  const userIds = (memberRes.data ?? []).map((row) => String(row.user_id));
  const userRes = userIds.length
    ? await supabase.from("users").select("id,name").in("id", userIds)
    : { data: [] as Array<{ id: string; name: string | null }>, error: null };

  if (userRes.error) {
    throw new Error(`User query failed: ${userRes.error.message}`);
  }

  const userNameMap = new Map<string, string>();
  for (const row of userRes.data ?? []) {
    userNameMap.set(String(row.id), row.name?.trim() || String(row.id).slice(0, 8));
  }

  const memberSpendMap = new Map<string, number>();
  const categorySpendMap = new Map<string, number>();

  for (const tx of txRes.data ?? []) {
    const userId = String(tx.user_id ?? "");
    const category = String(tx.category ?? "Uncategorized");
    const amount = Number(tx.amount ?? 0);
    if (!userId || Number.isNaN(amount)) {
      continue;
    }
    memberSpendMap.set(userId, (memberSpendMap.get(userId) ?? 0) + amount);
    categorySpendMap.set(category, (categorySpendMap.get(category) ?? 0) + amount);
  }

  const memberBreakdown: FamilyMember[] = (memberRes.data ?? []).map((member) => {
    const role: FamilyMember["role"] = member.role === "admin" ? "admin" : "member";
    const userId = String(member.user_id);
    return {
      userId,
      name: userNameMap.get(userId) || userId.slice(0, 8),
      role,
      monthlySpend: Number(memberSpendMap.get(userId) ?? 0),
    };
  });

  const topCategories = Array.from(categorySpendMap.entries())
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([category, amount]) => ({ category, amount }));

  const totalMonthlySpend = memberBreakdown.reduce((sum, member) => sum + member.monthlySpend, 0);

  return {
    familyId,
    familyName: familyRes.data?.name ?? "Family Workspace",
    totalMonthlySpend,
    memberBreakdown,
    topCategories,
    source: "supabase",
  };
}
