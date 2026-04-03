import { NextRequest, NextResponse } from "next/server";

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
        type?: "debit" | "credit";
        category?: string;
        merchant?: string;
        source?: "sms" | "manual" | "vision" | "voice";
      }
    | null;

  if (!body || !Number.isFinite(body.amount)) {
    return NextResponse.json({ error: "amount is required" }, { status: 400 });
  }

  await connectToMongo();
  const user = await User.findById(auth.userId);

  if (!user?.familyId) {
    return NextResponse.json({ error: "user must join or create family first" }, { status: 409 });
  }

  const tx = await Transaction.create({
    familyId: user.familyId,
    userId: user._id,
    userEmail: user.email,
    amount: Math.abs(Number(body.amount)),
    type: body.type ?? "debit",
    category: body.category?.trim() || "Uncategorized",
    merchant: body.merchant?.trim() || null,
    source: body.source ?? "manual",
    txnTime: new Date(),
  });

  return NextResponse.json({ transaction: tx }, { status: 201 });
}
