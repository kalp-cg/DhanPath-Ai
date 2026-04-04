import { NextRequest, NextResponse } from "next/server";
import { createHash } from "crypto";

import { getAuthUserFromRequest } from "@/lib/auth";
import { connectToMongo } from "@/lib/mongodb";
import { Transaction } from "@/models/Transaction";
import { User } from "@/models/User";
import { getOrCreateSubscription, getUsageSnapshot } from "@/server/billing-service";

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

  const memberId = request.nextUrl.searchParams.get("memberId")?.trim() ?? "all";
  const type = request.nextUrl.searchParams.get("type")?.trim() ?? "all";
  const category = request.nextUrl.searchParams.get("category")?.trim() ?? "all";
  const from = request.nextUrl.searchParams.get("from")?.trim() ?? "";
  const to = request.nextUrl.searchParams.get("to")?.trim() ?? "";
  const page = Math.max(1, Number(request.nextUrl.searchParams.get("page") ?? "1"));
  const pageSize = Math.max(10, Math.min(100, Number(request.nextUrl.searchParams.get("pageSize") ?? "20")));

  const query: {
    familyId: unknown;
    userId?: unknown;
    type?: "debit" | "credit";
    category?: string;
    txnTime?: { $gte?: Date; $lte?: Date };
  } = { familyId: user.familyId };

  if (memberId !== "all") {
    query.userId = memberId;
  }

  if (type === "debit" || type === "credit") {
    query.type = type;
  }

  if (category !== "all") {
    query.category = category;
  }

  if (from || to) {
    query.txnTime = {};
    if (from) {
      const fromDate = new Date(from);
      if (!Number.isNaN(fromDate.getTime())) {
        query.txnTime.$gte = fromDate;
      }
    }
    if (to) {
      const toDate = new Date(to);
      if (!Number.isNaN(toDate.getTime())) {
        toDate.setHours(23, 59, 59, 999);
        query.txnTime.$lte = toDate;
      }
    }
  }

  const totalTransactions = await Transaction.countDocuments(query);
  const totalPages = Math.max(1, Math.ceil(totalTransactions / pageSize));
  const safePage = Math.min(page, totalPages);
  const skip = (safePage - 1) * pageSize;

  const txns = await Transaction.find(query)
    .sort({ txnTime: -1 })
    .skip(skip)
    .limit(pageSize)
    .lean();

  const userIds = Array.from(new Set(txns.map((txn) => String(txn.userId))));
  const users = await User.find({ _id: { $in: userIds } }).lean();
  const nameMap = new Map(users.map((u) => [String(u._id), u.name ?? "Member"]));

  return NextResponse.json(
    {
      transactions: txns.map((txn) => ({
        ...txn,
        userName: nameMap.get(String(txn.userId)) ?? txn.userEmail,
      })),
      pagination: {
        page: safePage,
        pageSize,
        totalTransactions,
        totalPages,
        hasPrev: safePage > 1,
        hasNext: safePage < totalPages,
      },
    },
    { status: 200 },
  );
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

  const subscription = await getOrCreateSubscription({ familyId: user.familyId, ownerUserId: user._id });
  const usage = await getUsageSnapshot({ familyId: user.familyId, monthlyTxnLimit: subscription.monthlyTxnLimit });

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

    if (usage.remaining <= 0) {
      return NextResponse.json(
        {
          error: "monthly transaction limit reached for current plan",
          usage,
        },
        { status: 402 },
      );
    }

    const allowedIncoming = incoming.slice(0, usage.remaining);

    const ops = allowedIncoming.map((item) => ({
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
    const total = allowedIncoming.length;

    return NextResponse.json(
      {
        synced,
        total,
        duplicates: total - synced,
        truncated: allowedIncoming.length < incoming.length,
        skipped: Math.max(0, incoming.length - allowedIncoming.length),
      },
      { status: 200 },
    );
  }

  if (!body || !Number.isFinite(body.amount)) {
    return NextResponse.json({ error: "amount is required" }, { status: 400 });
  }

  if (usage.remaining <= 0) {
    return NextResponse.json(
      {
        error: "monthly transaction limit reached for current plan",
        usage,
      },
      { status: 402 },
    );
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
