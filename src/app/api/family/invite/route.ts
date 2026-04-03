import { NextRequest, NextResponse } from "next/server";

import { createSupabaseStorageClient, hasSupabaseStorageEnv } from "@/lib/supabase-server";
import { requireAuthenticatedUser, requireFamilyMembership } from "@/server/auth";

type InviteBody = {
  familyId: string;
  email: string;
};

export async function POST(request: NextRequest) {
  if (!hasSupabaseStorageEnv()) {
    return NextResponse.json({ error: "Supabase storage env is missing" }, { status: 500 });
  }

  const auth = await requireAuthenticatedUser(request);
  if ("response" in auth) return auth.response;

  let body: InviteBody;
  try {
    body = (await request.json()) as InviteBody;
  } catch {
    return NextResponse.json({ error: "Invalid JSON payload" }, { status: 400 });
  }

  const familyId = body.familyId?.trim();
  const email = body.email?.trim().toLowerCase();
  if (!familyId || !email) {
    return NextResponse.json({ error: "familyId and email are required." }, { status: 400 });
  }

  const membership = await requireFamilyMembership({
    familyId,
    userId: auth.user.id,
    requireAdmin: true,
  });
  if (!membership.ok) return membership.response;

  const supabase = createSupabaseStorageClient();
  const inviteToken = crypto.randomUUID();
  const expiresAt = new Date(Date.now() + 1000 * 60 * 60 * 24 * 7).toISOString();

  const { error: inviteInsertError } = await supabase.from("family_invitations").insert({
    family_id: familyId,
    invited_email: email,
    token: inviteToken,
    invited_by: auth.user.id,
    status: "pending",
    expires_at: expiresAt,
    created_at: new Date().toISOString(),
  });
  if (inviteInsertError) {
    return NextResponse.json({ error: inviteInsertError.message }, { status: 500 });
  }

  const appUrl = process.env.NEXT_PUBLIC_APP_URL || process.env.NEXT_PUBLIC_SITE_URL || "http://localhost:3000";
  const redirectTo = `${appUrl}/family?inviteToken=${encodeURIComponent(inviteToken)}`;

  const { error: authInviteError } = await supabase.auth.admin.inviteUserByEmail(email, {
    redirectTo,
  });
  if (authInviteError) {
    return NextResponse.json({ error: authInviteError.message }, { status: 500 });
  }

  return NextResponse.json(
    {
      ok: true,
      invitedEmail: email,
      expiresAt,
    },
    { status: 201 },
  );
}
