import { Types } from "mongoose";

import { Subscription } from "@/models/Subscription";
import { Transaction } from "@/models/Transaction";

export type PlanDef = {
  id: "free" | "pro" | "family_pro";
  name: string;
  monthlyTxnLimit: number;
  maxMembers: number;
  monthlyPriceInr: number;
  features: string[];
};

export const PLAN_DEFS: PlanDef[] = [
  {
    id: "free",
    name: "Free",
    monthlyTxnLimit: 200,
    maxMembers: 4,
    monthlyPriceInr: 0,
    features: ["Family workspace", "Basic analytics", "Manual + phone sync"],
  },
  {
    id: "pro",
    name: "Pro",
    monthlyTxnLimit: 2000,
    maxMembers: 8,
    monthlyPriceInr: 299,
    features: ["Advanced analytics", "Priority sync", "Extended history"],
  },
  {
    id: "family_pro",
    name: "Family Pro",
    monthlyTxnLimit: 10000,
    maxMembers: 20,
    monthlyPriceInr: 699,
    features: ["All Pro features", "Large family usage", "Premium support"],
  },
];

function periodBounds(now: Date) {
  const start = new Date(now.getFullYear(), now.getMonth(), 1);
  const end = new Date(now.getFullYear(), now.getMonth() + 1, 1);
  return { start, end };
}

export async function getOrCreateSubscription(params: {
  familyId: Types.ObjectId;
  ownerUserId: Types.ObjectId;
}) {
  const now = new Date();
  const { start, end } = periodBounds(now);

  let sub = await Subscription.findOne({ familyId: params.familyId });
  if (!sub) {
    const plan = getPlan("free");
    const trialEndsAt = new Date(now);
    trialEndsAt.setDate(trialEndsAt.getDate() + 14);

    sub = await Subscription.create({
      familyId: params.familyId,
      ownerUserId: params.ownerUserId,
      planId: "free",
      status: "trialing",
      monthlyTxnLimit: plan.monthlyTxnLimit,
      maxMembers: plan.maxMembers,
      currentPeriodStart: start,
      currentPeriodEnd: end,
      trialEndsAt,
      nextBillingAt: end,
      billingEvents: [
        {
          at: now,
          kind: "created",
          fromPlanId: null,
          toPlanId: "free",
          amountInr: 0,
          actorUserId: params.ownerUserId,
          note: "Subscription created with free trial",
        },
      ],
    });
    return sub;
  }

  if (!sub.maxMembers || sub.maxMembers < 1) {
    const plan = getPlan(sub.planId);
    sub.maxMembers = plan.maxMembers;
  }

  if (sub.status === "trialing" && sub.trialEndsAt && sub.trialEndsAt <= now) {
    sub.status = "active";
  }

  if (sub.currentPeriodEnd <= now) {
    sub.currentPeriodStart = start;
    sub.currentPeriodEnd = end;
    sub.nextBillingAt = end;
    sub.billingEvents.push({
      at: now,
      kind: "renewed",
      fromPlanId: sub.planId,
      toPlanId: sub.planId,
      amountInr: getPlan(sub.planId).monthlyPriceInr,
      actorUserId: sub.ownerUserId,
      note: "Monthly renewal",
    });
    await sub.save();
  } else if (sub.isModified()) {
    await sub.save();
  }

  return sub;
}

export async function getUsageSnapshot(params: {
  familyId: Types.ObjectId;
  monthlyTxnLimit: number;
}) {
  const now = new Date();
  const { start, end } = periodBounds(now);

  const used = await Transaction.countDocuments({
    familyId: params.familyId,
    txnTime: { $gte: start, $lt: end },
  });

  return {
    used,
    monthlyTxnLimit: params.monthlyTxnLimit,
    remaining: Math.max(0, params.monthlyTxnLimit - used),
    periodStart: start,
    periodEnd: end,
  };
}

export function getPlan(planId: string) {
  return PLAN_DEFS.find((p) => p.id === planId) ?? PLAN_DEFS[0];
}

export function getTrialMeta(sub: {
  status: string;
  trialEndsAt?: Date | null;
  nextBillingAt?: Date | null;
}) {
  const now = new Date();
  const trialEndsAt = sub.trialEndsAt ?? null;
  const nextBillingAt = sub.nextBillingAt ?? null;
  const trialDaysLeft =
    sub.status === "trialing" && trialEndsAt
      ? Math.max(0, Math.ceil((trialEndsAt.getTime() - now.getTime()) / (1000 * 60 * 60 * 24)))
      : 0;

  return {
    trialEndsAt,
    trialDaysLeft,
    nextBillingAt,
  };
}
