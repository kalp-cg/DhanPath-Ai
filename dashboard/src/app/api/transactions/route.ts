import { NextRequest, NextResponse } from "next/server";

import { createSupabaseStorageClient, hasSupabaseStorageEnv } from "@/lib/supabase-server";
import { requireAuthenticatedUser, requireFamilyMembership } from "@/server/auth";

type CreateTransactionBody = {
  familyId: string;
  amount: number;
  type?: "debit" | "credit";
  category?: string;
  merchant?: string;
  source?: "sms" | "manual" | "vision" | "voice";
};

export async function POST(request: NextRequest) {
  if (!hasSupabaseStorageEnv()) {
    return NextResponse.json(
      { error: "Supabase storage env is missing" },
      { status: 500 },
    );
  }

  let body: CreateTransactionBody;
  try {
    body = (await request.json()) as CreateTransactionBody;
  } catch {
    return NextResponse.json({ error: "Invalid JSON payload" }, { status: 400 });
  }

  if (!body.familyId || !Number.isFinite(body.amount)) {
    return NextResponse.json(
      { error: "familyId and amount are required" },
      { status: 400 },
    );
  }

  const auth = await requireAuthenticatedUser(request);
  if ("response" in auth) return auth.response;

  const membership = await requireFamilyMembership({
    familyId: body.familyId,
    userId: auth.user.id,
  });
  if (!membership.ok) return membership.response;

  const supabase = createSupabaseStorageClient();

  const { data, error } = await supabase
    .from("transactions")
    .insert({
      user_id: auth.user.id,
      family_id: body.familyId,
      amount: body.amount,
      type: body.type ?? "debit",
      category: body.category ?? "Uncategorized",
      merchant: body.merchant ?? null,
      source: body.source ?? "manual",
    })
    .select("id,user_id,family_id,amount,type,category,merchant,source,txn_time")
    .single();

  if (error || !data) {
    return NextResponse.json(
      { error: error?.message ?? "Failed to insert transaction" },
      { status: 500 },
    );
  }

  return NextResponse.json(data, { status: 201 });
}
