import { NextRequest, NextResponse } from "next/server";

import { mockFamilySummary } from "@/lib/mock-family";
import { createSupabaseRlsClient, hasSupabaseEnv } from "@/lib/supabase-server";
import { FamilyMember, FamilySummary } from "@/types/family";

function getMonthStartIso(): string {
  const now = new Date();
  const first = new Date(now.getFullYear(), now.getMonth(), 1);
  return first.toISOString();
}

export async function GET(request: NextRequest) {
  const familyId =
    request.nextUrl.searchParams.get("familyId") ??
    process.env.NEXT_PUBLIC_FAMILY_ID ??
    mockFamilySummary.familyId;

  if (!hasSupabaseEnv()) {
    return NextResponse.json({ ...mockFamilySummary, familyId, source: "mock" });
  }

  const authHeader = request.headers.get("authorization") ?? "";
  const accessToken = authHeader.startsWith("Bearer ")
    ? authHeader.slice("Bearer ".length)
    : "";

  if (!accessToken) {
    return NextResponse.json(
      {
        error: "Missing bearer token. Sign in via /auth and send session token.",
      },
      { status: 401 },
    );
  }

  try {
    const supabase = createSupabaseRlsClient(accessToken);

    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser();

    if (userError || !user) {
      return NextResponse.json({ error: "Invalid user session" }, { status: 401 });
    }

    const [{ data: familyRow, error: familyError }, { data: memberRows, error: memberError }, { data: txRows, error: txError }] =
      await Promise.all([
        supabase.from("families").select("id,name").eq("id", familyId).single(),
        supabase.from("family_members").select("user_id,role").eq("family_id", familyId),
        supabase
          .from("transactions")
          .select("user_id,amount,category,txn_time")
          .eq("family_id", familyId)
          .gte("txn_time", getMonthStartIso()),
      ]);

    if (familyError || memberError || txError) {
      return NextResponse.json(
        {
          error:
            familyError?.message || memberError?.message || txError?.message,
        },
        { status: 403 },
      );
    }

    const userIds = (memberRows ?? []).map((row) => String(row.user_id));
    const { data: userRows } = userIds.length
      ? await supabase
          .from("users")
          .select("id,name")
          .in("id", userIds)
      : { data: [] as Array<{ id: string; name: string | null }> };

    const userNameMap = new Map<string, string>();
    for (const row of userRows ?? []) {
      userNameMap.set(String(row.id), row.name?.trim() || String(row.id).slice(0, 8));
    }

    const memberSpendMap = new Map<string, number>();
    const categorySpendMap = new Map<string, number>();

    for (const tx of txRows ?? []) {
      const userId = String(tx.user_id ?? "");
      const category = String(tx.category ?? "Uncategorized");
      const amount = Number(tx.amount ?? 0);

      if (!userId || Number.isNaN(amount)) {
        continue;
      }

      memberSpendMap.set(userId, (memberSpendMap.get(userId) ?? 0) + amount);
      categorySpendMap.set(category, (categorySpendMap.get(category) ?? 0) + amount);
    }

    const memberBreakdown: FamilyMember[] = (memberRows ?? []).map((member) => {
      const role: FamilyMember["role"] = member.role === "admin" ? "admin" : "member";
      return {
        userId: String(member.user_id),
        name:
          userNameMap.get(String(member.user_id)) ||
          String(member.user_id).slice(0, 8),
        role,
        monthlySpend: Number(memberSpendMap.get(String(member.user_id)) ?? 0),
      };
    });

    const topCategories = Array.from(categorySpendMap.entries())
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(([category, amount]) => ({ category, amount }));

    const totalMonthlySpend = memberBreakdown.reduce(
      (sum, member) => sum + member.monthlySpend,
      0,
    );

    const result: FamilySummary = {
      familyId,
      familyName: familyRow?.name ?? "Family Workspace",
      totalMonthlySpend,
      memberBreakdown,
      topCategories,
      source: "supabase",
    };

    return NextResponse.json(result);
  } catch {
    return NextResponse.json(
      {
        ...mockFamilySummary,
        familyId,
        source: "mock",
      },
      { status: 200 },
    );
  }
}
