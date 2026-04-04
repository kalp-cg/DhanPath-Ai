import { NextRequest, NextResponse } from "next/server";

import { getAuthUserFromRequest } from "@/lib/auth";
import { connectToMongo } from "@/lib/mongodb";
import { Transaction } from "@/models/Transaction";
import { resolveFamilyAccess } from "@/server/family-access";

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

function parsePositiveInt(value: string | null, fallback: number) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) return fallback;
  return Math.floor(parsed);
}

function monthRange(year: number, month: number) {
  const start = new Date(year, month - 1, 1);
  const end = new Date(year, month, 1);
  return { start, end };
}

export async function GET(request: NextRequest) {
  const auth = getAuthUserFromRequest(request);
  if (!auth) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  await connectToMongo();

  const access = await resolveFamilyAccess(auth.userId);
  if (!access.ok) {
    return NextResponse.json({ error: access.error }, { status: access.status });
  }

  const { user, family, members, isAdmin } = access;

  const url = new URL(request.url);
  const now = new Date();
  const selectedYear = parsePositiveInt(url.searchParams.get("year"), now.getFullYear());
  const selectedMonthRaw = parsePositiveInt(url.searchParams.get("month"), now.getMonth() + 1);
  const selectedMonth = Math.min(12, Math.max(1, selectedMonthRaw));
  const pageSize = Math.min(50, Math.max(1, parsePositiveInt(url.searchParams.get("pageSize"), 20)));
  const selectedMemberId = (url.searchParams.get("memberId") ?? "all").trim();

  const memberFilter =
    selectedMemberId && selectedMemberId !== "all"
      ? { userId: selectedMemberId }
      : {};

  const txns = (await Transaction.find({
    familyId: family._id,
    ...memberFilter,
  })
    .sort({ txnTime: -1 })
    .limit(5000)
    .lean()) as TransactionLean[];

  const nameMap = new Map(members.map((m) => [m.userId, m.name]));

  const { start: periodStart, end: periodEnd } = monthRange(selectedYear, selectedMonth);
  const periodTxns = txns.filter((tx) => {
    const at = new Date(tx.txnTime);
    return at >= periodStart && at < periodEnd;
  });

  const debitTxnsAll = txns.filter((tx) => tx.type === "debit");

  const memberSpend = new Map<string, number>();
  const catSpend = new Map<string, number>();
  const memberTxCount = new Map<string, number>();

  for (const tx of periodTxns) {
    const uid = String(tx.userId);
    const amt = Number(tx.amount ?? 0);
    memberTxCount.set(uid, (memberTxCount.get(uid) ?? 0) + 1);
    if (tx.type === "debit") {
      memberSpend.set(uid, (memberSpend.get(uid) ?? 0) + amt);
      const cat = tx.category ?? "Uncategorized";
      catSpend.set(cat, (catSpend.get(cat) ?? 0) + amt);
    }
  }

  const memberBreakdown = members.map((m) => ({
    userId: m.userId,
    name: m.name,
    role: m.role,
    monthlySpend: Number((memberSpend.get(m.userId) ?? 0).toFixed(2)),
  }));

  const memberTransactionStats = members.map((m) => ({
    userId: m.userId,
    userName: m.name,
    totalSpend: Number((memberSpend.get(m.userId) ?? 0).toFixed(2)),
    transactionCount: Number(memberTxCount.get(m.userId) ?? 0),
  }));

  const topCategories = Array.from(catSpend.entries())
    .sort((a, b) => b[1] - a[1])
    .slice(0, 6)
    .map(([category, amount]) => ({ category, amount: Number(amount.toFixed(2)) }));

  const totalMonthlySpend = Number(
    memberBreakdown.reduce((sum, m) => sum + m.monthlySpend, 0).toFixed(2),
  );

  const recentTransactions = periodTxns.slice(0, pageSize).map((tx: TransactionLean) => ({
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

  const monthTotals = new Map<number, number>();
  for (const tx of debitTxnsAll) {
    const at = new Date(tx.txnTime);
    if (at.getFullYear() !== selectedYear) continue;
    const monthKey = at.getMonth() + 1;
    monthTotals.set(monthKey, (monthTotals.get(monthKey) ?? 0) + Number(tx.amount ?? 0));
  }

  const monthlyTimeline = Array.from({ length: 12 }, (_, idx) => {
    const month = idx + 1;
    return {
      month,
      label: new Date(selectedYear, idx, 1).toLocaleString("en-US", { month: "short" }),
      amount: Number((monthTotals.get(month) ?? 0).toFixed(2)),
    };
  });

  const yearlySpend = new Map<number, number>();
  for (const tx of debitTxnsAll) {
    const year = new Date(tx.txnTime).getFullYear();
    yearlySpend.set(year, (yearlySpend.get(year) ?? 0) + Number(tx.amount ?? 0));
  }

  const yearlyTotals = Array.from(yearlySpend.entries())
    .sort((a, b) => b[0] - a[0])
    .map(([year, amount]) => ({ year, amount: Number(amount.toFixed(2)) }));

  const availableYears = Array.from(
    new Set([
      ...txns.map((tx) => new Date(tx.txnTime).getFullYear()),
      selectedYear,
    ]),
  ).sort((a, b) => b - a);

  return NextResponse.json(
    {
      currentUserId: String(user._id),
      ownerUserId: String(family.ownerUserId),
      isCurrentUserAdmin: isAdmin,
      familyId: String(family._id),
      familyName: family.name,
      inviteCode: family.inviteCode,
      members: members.map((m) => ({
        userId: m.userId,
        name: m.name,
        email: m.email,
        role: m.role,
      })),
      totalMonthlySpend,
      memberBreakdown,
      memberTransactionStats,
      topCategories,
      monthlyTimeline,
      yearlyTotals,
      availableYears,
      recentTransactions,
      source: "mongodb",
    },
    { status: 200 },
  );
}
