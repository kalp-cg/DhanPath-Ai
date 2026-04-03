import { NextRequest, NextResponse } from "next/server";

import { createSupabaseStorageClient, hasSupabaseStorageEnv } from "@/lib/supabase-server";
import { fetchFamilySummaryFromStorage } from "@/server/family-summary-service";
import { requireAuthenticatedUser } from "@/server/auth";

function isMissingColumnError(message?: string): boolean {
  const m = (message ?? "").toLowerCase();
  return m.includes("could not find the") || m.includes("column");
}

export async function GET(request: NextRequest) {
  if (!hasSupabaseStorageEnv()) {
    return NextResponse.json(
      { error: "Backend storage is not configured." },
      { status: 500 },
    );
  }

  const auth = await requireAuthenticatedUser(request);
  if ("response" in auth) return auth.response;

  let familyId =
    request.nextUrl.searchParams.get("familyId") ??
    process.env.NEXT_PUBLIC_FAMILY_ID ??
    null;

  if (!familyId) {
    const supabase = createSupabaseStorageClient();
    let firstMembership: { family_id: string } | null = null;
    let error: { message?: string } | null = null;

    const withStatus = await supabase
      .from("family_members")
      .select("family_id,status")
      .eq("user_id", auth.user.id)
      .in("status", ["accepted", "active"])
      .limit(1)
      .maybeSingle();
    firstMembership = (withStatus.data as { family_id: string } | null) ?? null;
    error = withStatus.error as { message?: string } | null;

    if (error && isMissingColumnError(error.message)) {
      const legacy = await supabase
        .from("family_members")
        .select("family_id")
        .eq("user_id", auth.user.id)
        .limit(1)
        .maybeSingle();
      firstMembership = (legacy.data as { family_id: string } | null) ?? null;
      error = legacy.error as { message?: string } | null;
    }
    if (error || !firstMembership?.family_id) {
      return NextResponse.json(
        { error: "No accepted family workspace found for this account." },
        { status: 404 },
      );
    }
    familyId = String(firstMembership.family_id);
  }

  try {
    const result = await fetchFamilySummaryFromStorage(familyId, auth.user.id);
    return NextResponse.json(result, { status: 200 });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown backend failure";
    const status = message.includes("do not have access") ? 403 : 500;
    return NextResponse.json(
      { error: message },
      { status },
    );
  }
}
