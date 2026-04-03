import { NextRequest, NextResponse } from "next/server";

import { createSupabaseStorageClient } from "@/lib/supabase-server";

export type AuthenticatedUser = {
  id: string;
  email: string;
};

function getBearerToken(request: NextRequest): string | null {
  const authHeader = request.headers.get("authorization");
  if (!authHeader) return null;
  const [scheme, token] = authHeader.split(" ");
  if (scheme?.toLowerCase() !== "bearer" || !token) return null;
  return token;
}

function isMissingColumnError(message?: string): boolean {
  const m = (message ?? "").toLowerCase();
  return m.includes("could not find the") || m.includes("column");
}

export async function requireAuthenticatedUser(
  request: NextRequest,
): Promise<{ user: AuthenticatedUser } | { response: NextResponse }> {
  const token = getBearerToken(request);
  if (!token) {
    return {
      response: NextResponse.json(
        { error: "Authorization token is required." },
        { status: 401 },
      ),
    };
  }

  const supabase = createSupabaseStorageClient();
  const { data, error } = await supabase.auth.getUser(token);
  if (error || !data.user?.id || !data.user.email) {
    return {
      response: NextResponse.json(
        { error: "Invalid or expired auth token." },
        { status: 401 },
      ),
    };
  }

  return {
    user: {
      id: data.user.id,
      email: data.user.email.toLowerCase(),
    },
  };
}

export async function requireFamilyMembership({
  familyId,
  userId,
  requireAdmin = false,
}: {
  familyId: string;
  userId: string;
  requireAdmin?: boolean;
}): Promise<{ ok: true } | { ok: false; response: NextResponse }> {
  const supabase = createSupabaseStorageClient();
  let data: { role: string; status?: string } | null = null;
  let error: { message?: string } | null = null;

  const withStatus = await supabase
    .from("family_members")
    .select("role,status")
    .eq("family_id", familyId)
    .eq("user_id", userId)
    .in("status", ["accepted", "active"])
    .maybeSingle();
  data = (withStatus.data as { role: string; status?: string } | null) ?? null;
  error = withStatus.error as { message?: string } | null;

  if (error && isMissingColumnError(error.message)) {
    const legacy = await supabase
      .from("family_members")
      .select("role")
      .eq("family_id", familyId)
      .eq("user_id", userId)
      .maybeSingle();
    data = (legacy.data as { role: string } | null) ?? null;
    error = legacy.error as { message?: string } | null;
  }

  if (error || !data) {
    return {
      ok: false,
      response: NextResponse.json(
        { error: "You are not a member of this workspace." },
        { status: 403 },
      ),
    };
  }

  if (requireAdmin && data.role !== "admin") {
    return {
      ok: false,
      response: NextResponse.json(
        { error: "Only workspace admins can perform this action." },
        { status: 403 },
      ),
    };
  }

  return { ok: true };
}
