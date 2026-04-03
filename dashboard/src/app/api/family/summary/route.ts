import { NextRequest, NextResponse } from "next/server";

import { getAuthUserFromRequest } from "@/lib/auth";
import { connectToMongo } from "@/lib/mongodb";
import { Family } from "@/models/Family";
import { Transaction } from "@/models/Transaction";
import { User } from "@/models/User";

type FamilyMemberLean = {
  userId: unknown;
  email: string;
  role: string;
};

type UserLean = {
  _id: unknown;
  name?: string;
};

type TransactionLean = {
  _id: unknown;
  userId: unknown;
  userEmail: string;
  amount: number;
  type: "debit" | "credit";
  category: string;
  merchant?: string | null;
  source: string;
  txnTime: Date;
};

function monthStart() {
  const now = new Date();
  return new Date(now.getFullYear(), now.getMonth(), 1);
}

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

  const family = await Family.findById(user.familyId).lean();
  if (!family) {
    return NextResponse.json({ error: "family not found" }, { status: 404 });
  }

  const txns = (await Transaction.find({
    familyId: family._id,
    txnTime: { $gte: monthStart() },
  })
    .sort({ txnTime: -1 })
    .limit(500)
    .lean()) as TransactionLean[];

  const members = family.members as FamilyMemberLean[];
  const userIds = members.map((m: FamilyMemberLean) => m.userId);
  const users = (await User.find({ _id: { $in: userIds } }).lean()) as UserLean[];
  const nameMap = new Map(
    users.map((u: UserLean) => [String(u._id), u.name ?? "Member"]),
  );

  const memberSpend = new Map<string, number>();
  const catSpend = new Map<string, number>();

  for (const tx of txns) {
    const uid = String(tx.userId);
    const amt = Number(tx.amount ?? 0);
    if (tx.type === "debit") {
      memberSpend.set(uid, (memberSpend.get(uid) ?? 0) + amt);
      const cat = tx.category ?? "Uncategorized";
      catSpend.set(cat, (catSpend.get(cat) ?? 0) + amt);
    }
  }

  const memberBreakdown = members.map((m: FamilyMemberLean) => ({
    userId: String(m.userId),
    name: nameMap.get(String(m.userId)) ?? m.email.split("@")[0],
    role: m.role,
    monthlySpend: Number((memberSpend.get(String(m.userId)) ?? 0).toFixed(2)),
  }));

  const topCategories = Array.from(catSpend.entries())
    .sort((a, b) => b[1] - a[1])
    .slice(0, 6)
    .map(([category, amount]) => ({ category, amount: Number(amount.toFixed(2)) }));

  const totalMonthlySpend = Number(
    memberBreakdown.reduce((sum, m) => sum + m.monthlySpend, 0).toFixed(2),
  );

  const recentTransactions = txns.slice(0, 20).map((tx: TransactionLean) => ({
    id: String(tx._id),
    userId: String(tx.userId),
    userName: nameMap.get(String(tx.userId)) ?? tx.userEmail,
    amount: tx.amount,
    type: tx.type,
    category: tx.category,
    merchant: tx.merchant ?? null,
    source: tx.source,
    txnTime: tx.txnTime,
  }));

  return NextResponse.json(
    {
      familyId: String(family._id),
      familyName: family.name,
      inviteCode: family.inviteCode,
      totalMonthlySpend,
      memberBreakdown,
      topCategories,
      recentTransactions,
      source: "mongodb",
    },
    { status: 200 },
  );
}
