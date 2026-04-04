import { NextRequest, NextResponse } from "next/server";

import { getAuthUserFromRequest } from "@/lib/auth";
import { connectToMongo } from "@/lib/mongodb";
import { Family } from "@/models/Family";
import { User } from "@/models/User";
import { getRazorpayPublicConfig } from "@/server/razorpay";
import { getOrCreateSubscription, getPlan, getTrialMeta, getUsageSnapshot } from "@/server/billing-service";
import { getStripePublicConfig } from "@/server/stripe";

export async function GET(request: NextRequest) {
  const auth = getAuthUserFromRequest(request);
  if (!auth) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  await connectToMongo();
  const user = await User.findById(auth.userId);
  if (!user?.familyId) {
    return NextResponse.json({ error: "no family found for user" }, { status: 404 });
  }

  const family = await Family.findById(user.familyId).lean();
  if (!family) {
    return NextResponse.json({ error: "family not found" }, { status: 404 });
  }

  const subscription = await getOrCreateSubscription({ familyId: user.familyId, ownerUserId: user._id });
  const usage = await getUsageSnapshot({ familyId: user.familyId, monthlyTxnLimit: subscription.monthlyTxnLimit });
  const plan = getPlan(subscription.planId);
  const pendingPlan = subscription.pendingPlanId ? getPlan(subscription.pendingPlanId) : null;
  const trial = getTrialMeta(subscription);
  const timeline = [...(subscription.billingEvents ?? [])]
    .sort((a, b) => new Date(b.at).getTime() - new Date(a.at).getTime())
    .slice(0, 12)
    .map((evt) => ({
      at: evt.at,
      kind: evt.kind,
      fromPlanId: evt.fromPlanId,
      toPlanId: evt.toPlanId,
      amountInr: evt.amountInr,
      note: evt.note,
    }));

  return NextResponse.json(
    {
      subscription: {
        planId: subscription.planId,
        pendingPlanId: subscription.pendingPlanId ?? null,
        planName: plan.name,
        pendingPlanName: pendingPlan?.name ?? null,
        status: subscription.status,
        monthlyPriceInr: plan.monthlyPriceInr,
        monthlyTxnLimit: subscription.monthlyTxnLimit,
        maxMembers: subscription.maxMembers,
        membersUsed: family.members.length,
        membersRemaining: Math.max(0, subscription.maxMembers - family.members.length),
        trial,
        payment: {
          provider: subscription.billingProvider ?? "none",
          lastPaymentStatus: subscription.lastPaymentStatus ?? "none",
          externalPaymentId: subscription.externalPaymentId ?? null,
          lastPaymentAt: subscription.lastPaymentAt ?? null,
          razorpay: getRazorpayPublicConfig(),
          stripe: getStripePublicConfig(),
        },
        usage,
        timeline,
      },
    },
    { status: 200 },
  );
}
