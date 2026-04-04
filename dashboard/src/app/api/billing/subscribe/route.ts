import { NextRequest, NextResponse } from "next/server";

import { getAuthUserFromRequest } from "@/lib/auth";
import { connectToMongo } from "@/lib/mongodb";
import { User } from "@/models/User";
import { getOrCreateSubscription, getPlan, PLAN_DEFS } from "@/server/billing-service";
import { writeAuditLog } from "@/server/audit-log";

export async function POST(request: NextRequest) {
  const auth = getAuthUserFromRequest(request);
  if (!auth) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  const body = (await request.json().catch(() => null)) as { planId?: string } | null;
  const requestedPlanId = body?.planId ?? "";
  const plan = PLAN_DEFS.find((p) => p.id === requestedPlanId);

  if (!plan) {
    return NextResponse.json({ error: "invalid planId" }, { status: 400 });
  }

  await connectToMongo();
  const user = await User.findById(auth.userId);
  if (!user?.familyId) {
    return NextResponse.json({ error: "no family found for user" }, { status: 404 });
  }

  const subscription = await getOrCreateSubscription({ familyId: user.familyId, ownerUserId: user._id });
  const previousPlanId = subscription.planId;
  subscription.planId = plan.id;
  subscription.monthlyTxnLimit = plan.monthlyTxnLimit;
  subscription.maxMembers = plan.maxMembers;
  subscription.status = "active";
  subscription.nextBillingAt = subscription.currentPeriodEnd;
  subscription.billingEvents = subscription.billingEvents ?? [];
  subscription.billingEvents.push({
    at: new Date(),
    kind: "plan_changed",
    fromPlanId: previousPlanId,
    toPlanId: plan.id,
    amountInr: plan.monthlyPriceInr,
    actorUserId: user._id,
    note: previousPlanId === plan.id ? "Plan re-confirmed" : "Plan changed",
  });
  await subscription.save();

  await writeAuditLog({
    familyId: user.familyId,
    actorUserId: user._id,
    action: "plan_changed",
    metadata: {
      fromPlanId: previousPlanId,
      toPlanId: plan.id,
      amountInr: plan.monthlyPriceInr,
    },
  });

  const savedPlan = getPlan(subscription.planId);
  return NextResponse.json(
    {
      message: "plan updated",
      subscription: {
        planId: subscription.planId,
        planName: savedPlan.name,
        status: subscription.status,
        monthlyPriceInr: savedPlan.monthlyPriceInr,
        monthlyTxnLimit: subscription.monthlyTxnLimit,
      },
    },
    { status: 200 },
  );
}
