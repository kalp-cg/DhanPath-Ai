import { NextRequest, NextResponse } from "next/server";
import { createHash } from "crypto";

import { getAuthUserFromRequest } from "@/lib/auth";
import { connectToMongo } from "@/lib/mongodb";
import { Transaction } from "@/models/Transaction";
import { User } from "@/models/User";

export async function GET(request: NextRequest) {
  const auth = getAuthUserFromRequest(request);
  if (!auth) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  await connectToMongo();

  const user = await User.findById(auth.userId).lean();
  if (!user?.familyId) {
    return NextResponse.json({ error: "no family found for user" }, { status: 404 });
  }

  const txns = await Transaction.find({ familyId: user.familyId })
    .sort({ txnTime: -1 })
    .limit(50)
    .lean();

  return NextResponse.json({ transactions: txns }, { status: 200 });
}

export async function POST(request: NextRequest) {
  const auth = getAuthUserFromRequest(request);
  if (!auth) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  const body = (await request.json().catch(() => null)) as
    | {
        amount?: number;
        type?: "debit" | "credit" | "income" | "expense";
        category?: string;
        merchant?: string;
        source?: "sms" | "manual" | "vision" | "voice";
        txnTime?: string;
        clientTxnId?: string;
        transactions?: Array<{
          amount?: number;
          type?: "debit" | "credit" | "income" | "expense";
          category?: string;
          merchant?: string;
          source?: "sms" | "manual" | "vision" | "voice";
          txnTime?: string;
          clientTxnId?: string;
        }>;
      }
    | null;

  await connectToMongo();
  const user = await User.findById(auth.userId);

  if (!user?.familyId) {
    return NextResponse.json({ error: "user must join or create family first" }, { status: 409 });
  }

  const normalizeType = (inputType?: string): "debit" | "credit" => {
    if (!inputType) return "debit";
    const value = inputType.toLowerCase();
    if (value === "credit" || value === "income") return "credit";
    return "debit";
  };

  const normalizeTxnTime = (value?: string): Date => {
    if (!value) return new Date();
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? new Date() : parsed;
  };

  const buildClientTxnId = (item: {
    amount?: number;
    type?: string;
    category?: string;
    merchant?: string;
    txnTime?: string;
    clientTxnId?: string;
  }): string => {
    const provided = item.clientTxnId?.trim();
    if (provided) return provided;

    const base = [
      String(Number(item.amount ?? 0).toFixed(2)),
      normalizeType(item.type),
      item.category?.trim().toLowerCase() ?? "uncategorized",
      item.merchant?.trim().toLowerCase() ?? "",
      normalizeTxnTime(item.txnTime).toISOString(),
    ].join("|");

    return createHash("sha1").update(base).digest("hex").slice(0, 24);
  };

  if (Array.isArray(body?.transactions)) {
    const incoming = body.transactions.filter((item) => Number.isFinite(item.amount));
    if (incoming.length === 0) {
      return NextResponse.json({ error: "transactions array is empty or invalid" }, { status: 400 });
    }

    const ops = incoming.map((item) => ({
      updateOne: {
        filter: {
          familyId: user.familyId,
          userId: user._id,
          clientTxnId: buildClientTxnId(item),
        },
        update: {
          $setOnInsert: {
            familyId: user.familyId,
            userId: user._id,
            userEmail: user.email,
            clientTxnId: buildClientTxnId(item),
            amount: Math.abs(Number(item.amount ?? 0)),
            type: normalizeType(item.type),
            category: item.category?.trim() || "Uncategorized",
            merchant: item.merchant?.trim() || null,
            source: item.source ?? "sms",
            txnTime: normalizeTxnTime(item.txnTime),
          },
        },
        upsert: true,
      },
    }));

    const result = await Transaction.bulkWrite(ops, { ordered: false });
    const synced = result.upsertedCount ?? 0;
    const total = incoming.length;

    return NextResponse.json(
      {
        synced,
        total,
        duplicates: total - synced,
      },
      { status: 200 },
    );
  }

  if (!body || !Number.isFinite(body.amount)) {
    return NextResponse.json({ error: "amount is required" }, { status: 400 });
  }

  const tx = await Transaction.create({
    familyId: user.familyId,
    userId: user._id,
    userEmail: user.email,
    clientTxnId: buildClientTxnId(body),
    amount: Math.abs(Number(body.amount)),
    type: normalizeType(body.type),
    category: body.category?.trim() || "Uncategorized",
    merchant: body.merchant?.trim() || null,
    source: body.source ?? "manual",
    txnTime: normalizeTxnTime(body.txnTime),
  });

  return NextResponse.json({ transaction: tx }, { status: 201 });
}
