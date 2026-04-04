import { NextRequest, NextResponse } from "next/server";

import { getAuthUserFromRequest } from "@/lib/auth";
import { connectToMongo } from "@/lib/mongodb";
import { Family } from "@/models/Family";
import { Transaction } from "@/models/Transaction";
import { User } from "@/models/User";
import { Types } from "mongoose";

import { getPlan, getOrCreateSubscription, getUsageSnapshot } from "@/server/billing-service";

type FamilyMemberLean = {
  userId: unknown;
  email: string;
  role: "admin" | "member";
};

type UserLean = {
  _id: unknown;
  email?: string;
  name?: string;
  familyId?: unknown;
};

type TxLean = {
  _id: unknown;
  userId: unknown;
  amount: number;
  type: "debit" | "credit";
  category: string;
  source: "sms" | "manual" | "vision" | "voice";
  txnTime: Date;
};

function daysAgo(days: number): Date {
  const date = new Date();
  date.setDate(date.getDate() - days);
  return date;
}

function pct(numerator: number, denominator: number): number {
  if (!Number.isFinite(numerator) || !Number.isFinite(denominator) || denominator <= 0) {
    return 0;
  }
  return Number(((numerator / denominator) * 100).toFixed(2));
}

export async function GET(request: NextRequest) {
  const auth = getAuthUserFromRequest(request);
  if (!auth) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  await connectToMongo();

  const user = (await User.findById(auth.userId).lean()) as UserLean | null;
  if (!user?.familyId) {
    return NextResponse.json({ error: "no family found for user" }, { status: 404 });
  }

  const family = await Family.findById(user.familyId).lean();
  if (!family) {
    return NextResponse.json({ error: "family not found" }, { status: 404 });
  }

  const familyUsers = (await User.find({
    $or: [{ familyId: family._id }, { familyId: String(family._id) }],
  }).lean()) as UserLean[];

  const rawMembers = ((family.members as FamilyMemberLean[]) ?? []).map((member) => ({
    userId: String(member.userId),
    email: member.email,
    role: member.role,
  }));

  const memberMap = new Map<string, { userId: string; email: string; role: "admin" | "member" }>();
  for (const member of rawMembers) {
    if (!member.userId) continue;
    memberMap.set(member.userId, {
      userId: member.userId,
      email: member.email.toLowerCase(),
      role: member.role === "admin" ? "admin" : "member",
    });
  }

  for (const familyUser of familyUsers) {
    const uid = String(familyUser._id ?? "");
    if (!uid) continue;
    const existing = memberMap.get(uid);
    memberMap.set(uid, {
      userId: uid,
      email: String(familyUser.email ?? existing?.email ?? "").toLowerCase(),
      role: String(family.ownerUserId) === uid ? "admin" : (existing?.role ?? "member"),
    });
  }

  const ownerUserId = String(family.ownerUserId);
  if (memberMap.has(ownerUserId)) {
    const owner = memberMap.get(ownerUserId);
    if (owner) {
      owner.role = "admin";
      memberMap.set(ownerUserId, owner);
    }
  }

  const members = Array.from(memberMap.values());
  const isCurrentUserAdmin = members.some(
    (member) => member.userId === String(user._id) && member.role === "admin",
  );

  if (!isCurrentUserAdmin) {
    return NextResponse.json({ error: "forbidden" }, { status: 403 });
  }

  const names = new Map<string, string>();
  for (const familyUser of familyUsers) {
    names.set(String(familyUser._id), String(familyUser.name ?? "Member"));
  }

  const now = new Date();
  const last30Date = daysAgo(30);
  const prev30Date = daysAgo(60);
  const last90Date = daysAgo(90);

  const [allTimeAggRaw, tx120, subscription] = await Promise.all([
    Transaction.aggregate([
      { $match: { familyId: family._id } },
      {
        $group: {
          _id: null,
          totalTransactions: { $sum: 1 },
          debitAmount: {
            $sum: { $cond: [{ $eq: ["$type", "debit"] }, "$amount", 0] },
          },
          creditAmount: {
            $sum: { $cond: [{ $eq: ["$type", "credit"] }, "$amount", 0] },
          },
          lastTxnAt: { $max: "$txnTime" },
        },
      },
    ]),
    Transaction.find({
      familyId: family._id,
      txnTime: { $gte: daysAgo(120) },
    })
      .sort({ txnTime: -1 })
      .lean(),
    getOrCreateSubscription({
      familyId: family._id as Types.ObjectId,
      ownerUserId: family.ownerUserId as Types.ObjectId,
    }),
  ]);

  const allTimeAgg = (allTimeAggRaw[0] ?? {
    totalTransactions: 0,
    debitAmount: 0,
    creditAmount: 0,
    lastTxnAt: null,
  }) as {
    totalTransactions: number;
    debitAmount: number;
    creditAmount: number;
    lastTxnAt: Date | null;
  };

  const txns = tx120 as TxLean[];
  const tx30 = txns.filter((tx) => new Date(tx.txnTime) >= last30Date);
  const txPrev30 = txns.filter((tx) => {
    const txnTime = new Date(tx.txnTime);
    return txnTime >= prev30Date && txnTime < last30Date;
  });
  const tx90 = txns.filter((tx) => new Date(tx.txnTime) >= last90Date);

  const debit30 = tx30.filter((tx) => tx.type === "debit");
  const credit30 = tx30.filter((tx) => tx.type === "credit");
  const debitPrev30 = txPrev30.filter((tx) => tx.type === "debit");

  const spend30 = debit30.reduce((sum, tx) => sum + Number(tx.amount ?? 0), 0);
  const income30 = credit30.reduce((sum, tx) => sum + Number(tx.amount ?? 0), 0);
  const spendPrev30 = debitPrev30.reduce((sum, tx) => sum + Number(tx.amount ?? 0), 0);

  const spendGrowthPct = spendPrev30 > 0
    ? Number((((spend30 - spendPrev30) / spendPrev30) * 100).toFixed(2))
    : spend30 > 0
      ? 100
      : 0;

  const automatedCount = tx30.filter((tx) => tx.source !== "manual").length;
  const activeMembers = new Set(tx30.map((tx) => String(tx.userId))).size;

  const memberStatsMap = new Map<string, {
    userId: string;
    name: string;
    role: "admin" | "member";
    spend30: number;
    income30: number;
    txnCount30: number;
    lastTxnAt: Date | null;
  }>();

  for (const member of members) {
    memberStatsMap.set(member.userId, {
      userId: member.userId,
      name: names.get(member.userId) ?? member.email.split("@")[0],
      role: member.role,
      spend30: 0,
      income30: 0,
      txnCount30: 0,
      lastTxnAt: null,
    });
  }

  for (const tx of tx30) {
    const userId = String(tx.userId);
    const bucket = memberStatsMap.get(userId);
    if (!bucket) continue;
    bucket.txnCount30 += 1;
    if (!bucket.lastTxnAt || new Date(tx.txnTime) > bucket.lastTxnAt) {
      bucket.lastTxnAt = new Date(tx.txnTime);
    }
    if (tx.type === "debit") {
      bucket.spend30 += Number(tx.amount ?? 0);
    } else {
      bucket.income30 += Number(tx.amount ?? 0);
    }
  }

  const memberStats = Array.from(memberStatsMap.values())
    .map((member) => ({
      ...member,
      spend30: Number(member.spend30.toFixed(2)),
      income30: Number(member.income30.toFixed(2)),
      spendSharePct: pct(member.spend30, spend30),
    }))
    .sort((a, b) => b.spend30 - a.spend30);

  const sourceMap = new Map<string, number>();
  for (const tx of tx30) {
    sourceMap.set(tx.source, (sourceMap.get(tx.source) ?? 0) + 1);
  }

  const topCategoriesMap = new Map<string, number>();
  for (const tx of debit30) {
    const cat = String(tx.category ?? "Uncategorized");
    topCategoriesMap.set(cat, (topCategoriesMap.get(cat) ?? 0) + Number(tx.amount ?? 0));
  }

  const topCategories = Array.from(topCategoriesMap.entries())
    .sort((a, b) => b[1] - a[1])
    .slice(0, 6)
    .map(([category, amount]) => ({
      category,
      amount: Number(amount.toFixed(2)),
      sharePct: pct(amount, spend30),
    }));

  const weeklySeriesMap = new Map<string, { start: Date; spend: number; income: number }>();
  const eightWeeksAgo = daysAgo(56);
  for (let i = 0; i < 8; i += 1) {
    const start = new Date(eightWeeksAgo);
    start.setDate(eightWeeksAgo.getDate() + i * 7);
    start.setHours(0, 0, 0, 0);
    const key = start.toISOString();
    weeklySeriesMap.set(key, { start, spend: 0, income: 0 });
  }

  for (const tx of tx90) {
    const d = new Date(tx.txnTime);
    if (d < eightWeeksAgo) continue;
    const daysDiff = Math.floor((d.getTime() - eightWeeksAgo.getTime()) / (1000 * 60 * 60 * 24));
    const bucketIndex = Math.min(7, Math.max(0, Math.floor(daysDiff / 7)));
    const bucketStart = new Date(eightWeeksAgo);
    bucketStart.setDate(eightWeeksAgo.getDate() + bucketIndex * 7);
    bucketStart.setHours(0, 0, 0, 0);
    const key = bucketStart.toISOString();
    const bucket = weeklySeriesMap.get(key);
    if (!bucket) continue;
    if (tx.type === "debit") {
      bucket.spend += Number(tx.amount ?? 0);
    } else {
      bucket.income += Number(tx.amount ?? 0);
    }
  }

  const weeklySeries = Array.from(weeklySeriesMap.values())
    .sort((a, b) => a.start.getTime() - b.start.getTime())
    .map((bucket) => ({
      label: `${bucket.start.getDate()} ${bucket.start.toLocaleString("en-US", { month: "short" })}`,
      spend: Number(bucket.spend.toFixed(2)),
      income: Number(bucket.income.toFixed(2)),
    }));

  const avgDebitTicket = debit30.length > 0 ? spend30 / debit30.length : 0;
  const lastTxnAt = allTimeAgg.lastTxnAt ? new Date(allTimeAgg.lastTxnAt) : null;
  const freshnessHours = lastTxnAt
    ? Math.max(0, Number(((now.getTime() - lastTxnAt.getTime()) / (1000 * 60 * 60)).toFixed(1)))
    : null;

  const debitValues90 = tx90.filter((tx) => tx.type === "debit").map((tx) => Number(tx.amount ?? 0));
  const avgDebit90 = debitValues90.length > 0
    ? debitValues90.reduce((sum, amount) => sum + amount, 0) / debitValues90.length
    : 0;
  const anomalyThreshold = avgDebit90 > 0 ? avgDebit90 * 2.8 : 0;
  const anomalyCount = anomalyThreshold > 0
    ? debit30.filter((tx) => Number(tx.amount ?? 0) >= anomalyThreshold).length
    : 0;

  const usage = await getUsageSnapshot({ familyId: family._id, monthlyTxnLimit: subscription.monthlyTxnLimit });
  const usagePct = pct(usage.used, usage.monthlyTxnLimit);
  const plan = getPlan(subscription.planId);

  const alerts: Array<{ id: string; severity: "info" | "warning" | "critical"; title: string; detail: string }> = [];

  if (usagePct >= 90) {
    alerts.push({
      id: "usage-critical",
      severity: "critical",
      title: "Transaction quota almost full",
      detail: `You have used ${usagePct}% of this month's quota.`,
    });
  } else if (usagePct >= 75) {
    alerts.push({
      id: "usage-warning",
      severity: "warning",
      title: "Transaction quota crossing safe limit",
      detail: `Usage reached ${usagePct}%. Consider upgrading before sync interruptions.`,
    });
  }

  if (spendGrowthPct >= 25) {
    alerts.push({
      id: "spend-spike",
      severity: "warning",
      title: "Monthly spending pace is rising quickly",
      detail: `Spending in the last 30 days is ${spendGrowthPct}% higher than the previous period.`,
    });
  }

  const dominantMember = memberStats[0];
  if (dominantMember && dominantMember.spendSharePct >= 65) {
    alerts.push({
      id: "member-concentration",
      severity: "info",
      title: "Spending is concentrated to one member",
      detail: `${dominantMember.name} accounts for ${dominantMember.spendSharePct}% of family spend in last 30 days.`,
    });
  }

  if (freshnessHours !== null && freshnessHours > 48) {
    alerts.push({
      id: "sync-stale",
      severity: "critical",
      title: "Data sync appears stale",
      detail: `No transactions received in the last ${freshnessHours} hours.`,
    });
  }

  if (alerts.length === 0) {
    alerts.push({
      id: "healthy",
      severity: "info",
      title: "Family finances look stable",
      detail: "No urgent risk signal detected in current command center checks.",
    });
  }

  return NextResponse.json({
    family: {
      id: String(family._id),
      name: family.name,
      members: members.length,
      activeMembers30d: activeMembers,
    },
    billing: {
      planId: subscription.planId,
      planName: plan.name,
      status: subscription.status,
      monthlyPriceInr: plan.monthlyPriceInr,
      monthlyTxnLimit: usage.monthlyTxnLimit,
      usageUsed: usage.used,
      usagePct,
    },
    metrics: {
      totalTransactionsAllTime: allTimeAgg.totalTransactions,
      debitAllTime: Number((allTimeAgg.debitAmount ?? 0).toFixed(2)),
      creditAllTime: Number((allTimeAgg.creditAmount ?? 0).toFixed(2)),
      spend30: Number(spend30.toFixed(2)),
      income30: Number(income30.toFixed(2)),
      net30: Number((income30 - spend30).toFixed(2)),
      spendGrowthPct,
      avgDebitTicket30: Number(avgDebitTicket.toFixed(2)),
      automationRate30: pct(automatedCount, tx30.length),
      anomalyCount30: anomalyCount,
      dataFreshnessHours: freshnessHours,
    },
    sourceMix30: Array.from(sourceMap.entries())
      .sort((a, b) => b[1] - a[1])
      .map(([source, count]) => ({ source, count, sharePct: pct(count, tx30.length) })),
    topCategories30: topCategories,
    memberStats30: memberStats,
    weeklySeries,
    alerts,
    generatedAt: now,
  });
}
