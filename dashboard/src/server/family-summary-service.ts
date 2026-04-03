import { FamilyMember, FamilySummary, Transaction, DailySpend } from "@/types/family";
import { createSupabaseStorageClient } from "@/lib/supabase-server";

const AVATAR_COLORS = [
  "#0f766e", "#b45309", "#7c3aed", "#db2777",
  "#059669", "#d97706",
];

function isMissingColumnError(message?: string): boolean {
  const m = (message ?? "").toLowerCase();
  return m.includes("could not find the") || m.includes("column");
}

function getMonthStartIso(): string {
  const now = new Date();
  const first = new Date(now.getFullYear(), now.getMonth(), 1);
  return first.toISOString();
}

export async function resolveFamilyIdForUser({
  userId,
  email,
}: {
  userId: string;
  email: string;
}): Promise<string | null> {
  const supabase = createSupabaseStorageClient();

  const withStatus = await supabase
    .from("family_members")
    .select("family_id,status,joined_at")
    .eq("user_id", userId)
    .in("status", ["accepted", "active"])
    .order("joined_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (withStatus.data?.family_id != null) {
    return String(withStatus.data.family_id);
  }

  if (withStatus.error && !isMissingColumnError(withStatus.error.message)) {
    throw new Error(`Family membership query failed: ${withStatus.error.message}`);
  }

  const legacy = await supabase
    .from("family_members")
    .select("family_id,joined_at")
    .eq("user_id", userId)
    .order("joined_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (legacy.error) {
    throw new Error(`Legacy membership query failed: ${legacy.error.message}`);
  }

  if (legacy.data?.family_id != null) {
    return String(legacy.data.family_id);
  }

  const invite = await supabase
    .from("family_invitations")
    .select("family_id,status")
    .eq("invited_email", email.trim().toLowerCase())
    .in("status", ["accepted", "active"])
    .limit(1)
    .maybeSingle();

  if (invite.error && !isMissingColumnError(invite.error.message)) {
    throw new Error(`Invitation query failed: ${invite.error.message}`);
  }

  if (invite.data?.family_id != null) {
    return String(invite.data.family_id);
  }

  return null;
}

export async function fetchFamilySummaryFromStorage(
  familyId: string,
  requesterUserId: string,
): Promise<FamilySummary> {
  const supabase = createSupabaseStorageClient();

  let membershipData: { role: string } | null = null;
  let membershipError: { message?: string } | null = null;

  const membershipWithStatus = await supabase
    .from("family_members")
    .select("role,status")
    .eq("family_id", familyId)
    .eq("user_id", requesterUserId)
    .in("status", ["accepted", "active"])
    .maybeSingle();
  membershipData = (membershipWithStatus.data as { role: string } | null) ?? null;
  membershipError = membershipWithStatus.error as { message?: string } | null;

  if (membershipError && isMissingColumnError(membershipError.message)) {
    const legacyMembership = await supabase
      .from("family_members")
      .select("role")
      .eq("family_id", familyId)
      .eq("user_id", requesterUserId)
      .maybeSingle();
    membershipData = (legacyMembership.data as { role: string } | null) ?? null;
    membershipError = legacyMembership.error as { message?: string } | null;
  }
  if (membershipError || !membershipData) {
    throw new Error("You do not have access to this workspace.");
  }

  const familyResPromise = supabase.from("families").select("id,name,invite_code").eq("id", familyId).single();
  const memberResPromise = supabase
    .from("family_members")
    .select("user_id,role,status")
    .eq("family_id", familyId)
    .in("status", ["accepted", "active"]);
  const [familyRes, memberResWithStatus, txRes, budgetRes] = await Promise.all([
    familyResPromise,
    memberResPromise,
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
  let memberRes: {
    data: Array<{ user_id: string; role: string; status?: string }> | null;
    error: { message?: string } | null;
  } = {
    data: (memberResWithStatus.data as Array<{ user_id: string; role: string; status?: string }> | null) ?? null,
    error: memberResWithStatus.error as { message?: string } | null,
  };
  if (memberRes.error && isMissingColumnError(memberRes.error.message)) {
    const legacyMemberRes = await supabase
      .from("family_members")
      .select("user_id,role")
      .eq("family_id", familyId);
    memberRes = {
      data: (legacyMemberRes.data as Array<{ user_id: string; role: string }> | null) ?? null,
      error: legacyMemberRes.error as { message?: string } | null,
    };
  }

  if (familyRes.error) throw new Error(`Family query failed: ${familyRes.error.message}`);
  if (memberRes.error) throw new Error(`Member query failed: ${memberRes.error.message}`);
  if (txRes.error) throw new Error(`Transaction query failed: ${txRes.error.message}`);

  const memberUserIds = (memberRes.data ?? []).map((row) => String(row.user_id));
  // Also collect user_ids from transactions for name lookup
  const txUserIds = Array.from(new Set((txRes.data ?? []).map((tx) => String(tx.user_id))));
  const allUserIds = Array.from(new Set([...memberUserIds, ...txUserIds]));
  
  const userNameMap = new Map<string, string>();
  if (allUserIds.length) {
    let userRes: {
      data: Array<{ id: string; name?: string | null; email?: string | null }> | null;
      error: { message?: string } | null;
    } = {
      data: null,
      error: null,
    };
    const profileRes = await supabase
      .from("profiles")
      .select("id,name,email")
      .in("id", allUserIds);
    userRes = {
      data: (profileRes.data as Array<{ id: string; name?: string | null; email?: string | null }> | null) ?? null,
      error: profileRes.error as { message?: string } | null,
    };
    if (userRes.error && userRes.error.message?.toLowerCase().includes("does not exist")) {
      const usersRes = await supabase.from("users").select("id,name").in("id", allUserIds);
      userRes = {
        data: (usersRes.data as Array<{ id: string; name?: string | null }> | null) ?? null,
        error: usersRes.error as { message?: string } | null,
      };
    }
    if (userRes.error && !isMissingColumnError(userRes.error.message)) {
      throw new Error(`User query failed: ${userRes.error.message}`);
    }
    for (const row of userRes.data ?? []) {
      const name = (row as { name?: string | null }).name;
      const email = (row as { email?: string | null }).email;
      const id = String((row as { id: string }).id);
      const display = name?.trim() || email?.trim() || id.slice(0, 8);
      userNameMap.set(id, display);
    }
  }

  for (const userId of allUserIds) {
    if (userNameMap.has(userId)) continue;
    const display = userId.slice(0, 8);
    userNameMap.set(userId, display);
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

  // Build member list: prefer family_members table, fall back to transaction user_ids
  const registeredMembers = memberRes.data ?? [];
  const memberBreakdown: FamilyMember[] = registeredMembers.length > 0
    ? registeredMembers.map((member, idx) => {
        const role: FamilyMember["role"] = member.role === "admin" ? "admin" : "member";
        const userId = String(member.user_id);
        return {
          userId,
          name: userNameMap.get(userId) || userId.slice(0, 8),
          role,
          monthlySpend: Number(memberSpendMap.get(userId) ?? 0),
          avatarColor: AVATAR_COLORS[idx % AVATAR_COLORS.length],
        };
      })
    : Array.from(memberSpendMap.entries()).map(([userId, spend], idx) => ({
        userId,
        name: userNameMap.get(userId) || userId.slice(0, 8),
        role: idx === 0 ? "admin" as const : "member" as const,
        monthlySpend: spend,
        avatarColor: AVATAR_COLORS[idx % AVATAR_COLORS.length],
      }));


  const topCategories = Array.from(categorySpendMap.entries())
    .sort((a, b) => b[1] - a[1])
    .slice(0, 6)
    .map(([category, amount]) => ({ category, amount }));

  const totalMonthlySpend = Array.from(memberSpendMap.values()).reduce((sum, v) => sum + v, 0);

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
    inviteCode: familyRes.data?.invite_code ?? null,
    totalMonthlySpend,
    monthlyBudget,
    memberBreakdown,
    topCategories,
    dailySpend,
    recentTransactions,
    source: "supabase",
  };
}
