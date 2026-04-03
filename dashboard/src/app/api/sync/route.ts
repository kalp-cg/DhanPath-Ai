import { NextRequest, NextResponse } from "next/server";

import { createSupabaseStorageClient, hasSupabaseStorageEnv } from "@/lib/supabase-server";
import { requireAuthenticatedUser, requireFamilyMembership } from "@/server/auth";

/**
 * POST /api/sync
 *
 * Accepts a batch of transactions from the Flutter app (or any client)
 * and upserts them into the Supabase `transactions` table.
 *
 * Body:
 *  {
 *    familyId:   string,  // UUID of the family workspace
 *    transactions: Array<{
 *      amount:        number,
 *      merchantName:  string,
 *      category:      string,
 *      type:          "expense" | "income" | "credit" | "transfer",
 *      date:          string,  // ISO 8601
 *      clientTxnId?:  string,  // idempotency key from client
 *      bankName?:     string,
 *      accountNumber?: string,
 *      smsBody?:      string,
 *      transactionHash?: string,   // for deduplication
 *    }>
 *  }
 */

type SyncTransaction = {
  amount: number;
  merchantName: string;
  category: string;
  type: string;
  date: string;
  clientTxnId?: string;
  bankName?: string;
  accountNumber?: string;
  smsBody?: string;
  transactionHash?: string;
};

type SyncBody = {
  familyId: string;
  transactions: SyncTransaction[];
};

export async function POST(request: NextRequest) {
  if (!hasSupabaseStorageEnv()) {
    return NextResponse.json({ error: "Storage not configured" }, { status: 500 });
  }

  let body: SyncBody;
  try {
    body = (await request.json()) as SyncBody;
  } catch {
    return NextResponse.json({ error: "Invalid JSON payload" }, { status: 400 });
  }

  if (!body.familyId || !Array.isArray(body.transactions)) {
    return NextResponse.json(
      { error: "familyId and transactions[] are required" },
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

  // Map Flutter local fields → Supabase columns
  const rows = body.transactions.map((tx, idx) => ({
    user_id: auth.user.id,
    family_id: body.familyId,
    amount: Math.abs(tx.amount),
    type: tx.type === "expense" ? "debit" : tx.type === "income" ? "credit" : "debit",
    category: tx.category || "Uncategorized",
    merchant: tx.merchantName || null,
    source: tx.smsBody ? "sms" : "manual",
    txn_time: tx.date,
    client_txn_id:
      tx.clientTxnId ||
      tx.transactionHash ||
      `${auth.user.id}:${body.familyId}:${tx.date}:${Math.abs(tx.amount)}:${tx.merchantName || ""}:${idx}`,
    transaction_hash: tx.transactionHash ?? null,
  }));

  const { data, error } = await supabase
    .from("transactions")
    .upsert(rows, { onConflict: "family_id,user_id,client_txn_id" })
    .select("id");

  if (error) {
    return NextResponse.json(
      { error: "Sync failed: " + error.message },
      { status: 500 },
    );
  }

  return NextResponse.json(
    { synced: data?.length ?? 0, message: `Synced ${data?.length ?? 0} transactions` },
    { status: 200 },
  );
}
