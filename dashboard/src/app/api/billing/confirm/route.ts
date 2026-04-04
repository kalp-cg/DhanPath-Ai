import { NextRequest, NextResponse } from "next/server";

import { getAuthUserFromRequest } from "@/lib/auth";
import { connectToMongo } from "@/lib/mongodb";
import { Subscription } from "@/models/Subscription";
import { User } from "@/models/User";
import { getPlan } from "@/server/billing-service";
import { retrieveCheckoutSession } from "@/server/stripe";
import { writeAuditLog } from "@/server/audit-log";

export async function POST(request: NextRequest) {
  const auth = getAuthUserFromRequest(request);
  if (!auth) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  const body = (await request.json().catch(() => null)) as { sessionId?: string } | null;
  const sessionId = body?.sessionId?.trim() ?? "";
  if (!sessionId) {
    return NextResponse.json({ error: "sessionId is required" }, { status: 400 });
  }

  const session = await retrieveCheckoutSession(sessionId);
  if (session.payment_status !== "paid") {
    return NextResponse.json({ error: "payment not completed" }, { status: 409 });
  }

  const targetPlanId = (session.metadata?.targetPlanId ?? "") as "free" | "pro" | "family_pro";
  const previousPlanId = (session.metadata?.previousPlanId ?? "") as "free" | "pro" | "family_pro";
  const familyId = session.metadata?.familyId?.trim() ?? "";
  const userId = session.metadata?.userId?.trim() ?? "";

  if (!targetPlanId || !familyId || !userId) {
    return NextResponse.json({ error: "incomplete checkout metadata" }, { status: 400 });
  }

  if (userId !== auth.userId) {
    return NextResponse.json({ error: "checkout does not belong to this user" }, { status: 403 });
  }

  await connectToMongo();
  const user = await User.findById(auth.userId).lean();
  if (!user?.familyId || String(user.familyId) !== familyId) {
    return NextResponse.json({ error: "family mismatch" }, { status: 403 });
  }

  const subscription = await Subscription.findOne({ familyId });
  if (!subscription) {
    return NextResponse.json({ error: "subscription not found" }, { status: 404 });
  }

  const previous = subscription.planId;
  const plan = getPlan(targetPlanId);
  subscription.planId = plan.id;
  subscription.pendingPlanId = null;
  subscription.monthlyTxnLimit = plan.monthlyTxnLimit;
  subscription.maxMembers = plan.maxMembers;
  subscription.status = "active";
  subscription.billingProvider = plan.id === "free" ? "none" : "stripe";
  subscription.externalPaymentId = session.id;
  subscription.externalCustomerId = typeof session.customer === "string" ? session.customer : subscription.externalCustomerId;
  subscription.lastPaymentStatus = "paid";
  subscription.lastPaymentAt = new Date();
  subscription.nextBillingAt = subscription.currentPeriodEnd;
  subscription.billingEvents = subscription.billingEvents ?? [];
  subscription.billingEvents.push({
    at: new Date(),
    kind: "plan_changed",
    fromPlanId: previousPlanId || previous,
    toPlanId: plan.id,
    amountInr: plan.monthlyPriceInr,
    actorUserId: subscription.ownerUserId,
    note: `Stripe session ${session.id}`,
  });
  await subscription.save();

  await writeAuditLog({
    familyId: subscription.familyId,
    actorUserId: subscription.ownerUserId,
    action: "plan_changed",
    metadata: {
      fromPlanId: previousPlanId || previous,
      toPlanId: plan.id,
      amountInr: plan.monthlyPriceInr,
      mode: "payment_confirmed",
      checkoutSessionId: session.id,
    },
  });

  return NextResponse.json({
    ok: true,
    subscription: {
      planId: subscription.planId,
      status: subscription.status,
      monthlyTxnLimit: subscription.monthlyTxnLimit,
      maxMembers: subscription.maxMembers,
      lastPaymentStatus: subscription.lastPaymentStatus,
    },
  });
}
