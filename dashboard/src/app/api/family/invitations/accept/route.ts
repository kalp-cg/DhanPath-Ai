import { NextRequest, NextResponse } from "next/server";

import { createSupabaseStorageClient, hasSupabaseStorageEnv } from "@/lib/supabase-server";
import { requireAuthenticatedUser } from "@/server/auth";

type AcceptInviteBody = {
  token: string;
};

export async function POST(request: NextRequest) {
  if (!hasSupabaseStorageEnv()) {
    return NextResponse.json({ error: "Supabase storage env is missing" }, { status: 500 });
  }

  const auth = await requireAuthenticatedUser(request);
  if ("response" in auth) return auth.response;

  let body: AcceptInviteBody;
  try {
    body = (await request.json()) as AcceptInviteBody;
  } catch {
    return NextResponse.json({ error: "Invalid JSON payload" }, { status: 400 });
  }

  const token = body.token?.trim();
  if (!token) {
    return NextResponse.json({ error: "Invitation token is required." }, { status: 400 });
  }

  const supabase = createSupabaseStorageClient();
  const nowIso = new Date().toISOString();

  const { data: invite, error: inviteError } = await supabase
    .from("family_invitations")
    .select("id,family_id,invited_email,status,expires_at")
    .eq("token", token)
    .eq("status", "pending")
    .maybeSingle();
  if (inviteError || !invite) {
    return NextResponse.json({ error: "Invitation not found or already used." }, { status: 404 });
  }
  if (String(invite.invited_email).toLowerCase() !== auth.user.email) {
    return NextResponse.json({ error: "This invite is for a different email account." }, { status: 403 });
  }
  if (new Date(String(invite.expires_at)).getTime() <= new Date(nowIso).getTime()) {
    return NextResponse.json({ error: "Invitation has expired." }, { status: 410 });
  }

  const { error: memberError } = await supabase.from("family_members").upsert(
    {
      family_id: invite.family_id,
      user_id: auth.user.id,
      role: "member",
      status: "accepted",
      joined_at: nowIso,
    },
    { onConflict: "family_id,user_id" },
  );
  if (memberError) {
    return NextResponse.json({ error: memberError.message }, { status: 500 });
  }

  const { error: updateInviteError } = await supabase
    .from("family_invitations")
    .update({
      status: "accepted",
      accepted_at: nowIso,
      accepted_by: auth.user.id,
    })
    .eq("id", invite.id);
  if (updateInviteError) {
    return NextResponse.json({ error: updateInviteError.message }, { status: 500 });
  }

  await supabase.from("profiles").upsert({
    id: auth.user.id,
    email: auth.user.email,
  });

  return NextResponse.json(
    {
      ok: true,
      familyId: invite.family_id,
    },
    { status: 200 },
  );
}
