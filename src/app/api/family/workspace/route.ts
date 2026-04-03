import { NextRequest, NextResponse } from "next/server";

import { createSupabaseStorageClient, hasSupabaseStorageEnv } from "@/lib/supabase-server";
import { requireAuthenticatedUser } from "@/server/auth";

type CreateWorkspaceBody = {
  name: string;
};

function isMissingColumnError(message?: string): boolean {
  const m = (message ?? "").toLowerCase();
  return m.includes("could not find the") || m.includes("column");
}

export async function POST(request: NextRequest) {
  if (!hasSupabaseStorageEnv()) {
    return NextResponse.json(
      { error: "Supabase storage env is missing" },
      { status: 500 },
    );
  }

  const auth = await requireAuthenticatedUser(request);
  if ("response" in auth) return auth.response;

  let body: CreateWorkspaceBody;
  try {
    body = (await request.json()) as CreateWorkspaceBody;
  } catch {
    return NextResponse.json({ error: "Invalid JSON payload" }, { status: 400 });
  }

  if (!body.name) {
    return NextResponse.json(
      { error: "name is required" },
      { status: 400 },
    );
  }

  const supabase = createSupabaseStorageClient();
  const inviteCode = `JOIN-${crypto.randomUUID().slice(0, 8).toUpperCase()}`;

  let familyRow: { id: string; name: string; invite_code: string | null } | null = null;
  let familyError: { message?: string } | null = null;

  const createWithCreator = await supabase
    .from("families")
    .insert({
      name: body.name,
      invite_code: inviteCode,
      created_by: auth.user.id,
    })
    .select("id,name,invite_code")
    .single();
  familyRow = createWithCreator.data as { id: string; name: string; invite_code: string | null } | null;
  familyError = createWithCreator.error as { message?: string } | null;

  if (familyError && isMissingColumnError(familyError.message)) {
    const legacyCreate = await supabase
      .from("families")
      .insert({
        name: body.name,
        invite_code: inviteCode,
      })
      .select("id,name,invite_code")
      .single();
    familyRow = legacyCreate.data as { id: string; name: string; invite_code: string | null } | null;
    familyError = legacyCreate.error as { message?: string } | null;
  }

  if (familyError || !familyRow) {
    return NextResponse.json(
      { error: familyError?.message ?? "Failed to create family" },
      { status: 500 },
    );
  }

  let memberError: { message?: string } | null = null;
  const fullMembershipInsert = await supabase.from("family_members").insert({
    family_id: familyRow.id,
    user_id: auth.user.id,
    role: "admin",
    status: "accepted",
    joined_at: new Date().toISOString(),
  });
  memberError = fullMembershipInsert.error as { message?: string } | null;

  if (memberError && isMissingColumnError(memberError.message)) {
    const legacyMembershipInsert = await supabase.from("family_members").insert({
      family_id: familyRow.id,
      user_id: auth.user.id,
      role: "admin",
    });
    memberError = legacyMembershipInsert.error as { message?: string } | null;
  }
  if (memberError) {
    return NextResponse.json(
      { error: memberError.message },
      { status: 500 },
    );
  }

  await supabase.from("profiles").upsert({
    id: auth.user.id,
    email: auth.user.email,
  });

  return NextResponse.json(
    {
      familyId: familyRow.id,
      name: familyRow.name,
      inviteCode: familyRow.invite_code,
    },
    { status: 201 },
  );
}
