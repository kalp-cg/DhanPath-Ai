import { NextRequest, NextResponse } from "next/server";

import { createSupabaseStorageClient, hasSupabaseStorageEnv } from "@/lib/supabase-server";
import { requireAuthenticatedUser } from "@/server/auth";

function isSchemaMissing(message?: string): boolean {
  const m = (message ?? "").toLowerCase();
  return (
    m.includes("does not exist") ||
    m.includes("could not find the") ||
    m.includes("column")
  );
}

export async function GET(request: NextRequest) {
  if (!hasSupabaseStorageEnv()) {
    return NextResponse.json({ error: "Supabase storage env is missing" }, { status: 500 });
  }

  const auth = await requireAuthenticatedUser(request);
  if ("response" in auth) return auth.response;

  const supabase = createSupabaseStorageClient();
  const nowIso = new Date().toISOString();
  const { data, error } = await supabase
    .from("family_invitations")
    .select("id,family_id,invited_email,token,status,expires_at,created_at")
    .eq("invited_email", auth.user.email)
    .eq("status", "pending")
    .gt("expires_at", nowIso)
    .order("created_at", { ascending: false });

  if (error) {
    if (isSchemaMissing(error.message)) {
      return NextResponse.json(
        {
          invites: [],
          warning:
            "Invitation tables are not fully migrated yet. Run dashboard/docs/SAAS_SUPABASE_SCHEMA.sql.",
        },
        { status: 200 },
      );
    }
    return NextResponse.json({ error: error.message }, { status: 500 });
  }

  const familyIds = Array.from(new Set((data ?? []).map((row) => String(row.family_id))));
  const { data: families } = familyIds.length
    ? await supabase.from("families").select("id,name").in("id", familyIds)
    : { data: [] as Array<{ id: string; name: string | null }> };
  const familyNameMap = new Map<string, string>(
    (families ?? []).map((family) => [String(family.id), family.name ?? "Family Workspace"]),
  );

  const invites = (data ?? []).map((row) => ({
    id: row.id,
    familyId: row.family_id,
    token: row.token,
    invitedEmail: row.invited_email,
    expiresAt: row.expires_at,
    familyName: familyNameMap.get(String(row.family_id)) ?? "Family Workspace",
  }));

  return NextResponse.json({ invites }, { status: 200 });
}
