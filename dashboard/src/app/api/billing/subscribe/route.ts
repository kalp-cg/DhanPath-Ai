import { NextRequest, NextResponse } from "next/server";

import { getAuthUserFromRequest } from "@/lib/auth";
import { connectToMongo } from "@/lib/mongodb";
import { User } from "@/models/User";
import { getOrCreateSubscription, getPlan, PLAN_DEFS } from "@/server/billing-service";
import { createCheckoutSession, isStripeConfigured } from "@/server/stripe";
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

  if (plan.id === "free") {
    subscription.planId = plan.id;
    subscription.pendingPlanId = null;
    subscription.monthlyTxnLimit = plan.monthlyTxnLimit;
    subscription.maxMembers = plan.maxMembers;
    subscription.status = "active";
    subscription.billingProvider = "none";
    subscription.externalCustomerId = null;
    subscription.externalSubscriptionId = null;
    subscription.externalPaymentId = null;
    subscription.lastPaymentStatus = "none";
    subscription.nextBillingAt = subscription.currentPeriodEnd;
    subscription.billingEvents = subscription.billingEvents ?? [];
    subscription.billingEvents.push({
      at: new Date(),
      kind: "plan_changed",
      fromPlanId: previousPlanId,
      toPlanId: plan.id,
      amountInr: plan.monthlyPriceInr,
      actorUserId: user._id,
      note: previousPlanId === plan.id ? "Plan re-confirmed" : "Downgraded to free",
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
        mode: "direct",
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

  if (!isStripeConfigured()) {
    return NextResponse.json(
      { error: "payment gateway not configured" },
      { status: 503 },
    );
  }

  const baseUrl = `${request.nextUrl.protocol}//${request.nextUrl.host}`;
  let payment: { id: string; url: string };
  try {
    payment = await createCheckoutSession({
      amountInr: plan.monthlyPriceInr,
      planId: plan.id,
      planName: plan.name,
      userEmail: user.email,
      userName: user.name,
      familyId: String(user.familyId),
      userId: String(user._id),
      previousPlanId,
      successUrl: `${baseUrl}/dashboard/billing`,
      cancelUrl: `${baseUrl}/dashboard/billing`,
    });
  } catch (error) {
    return NextResponse.json(
      {
        error: error instanceof Error
          ? `Stripe checkout failed: ${error.message}`
          : "Stripe checkout failed",
      },
      { status: 502 },
    );
  }

  subscription.pendingPlanId = plan.id;
  subscription.status = "past_due";
  subscription.billingProvider = "stripe";
  subscription.externalPaymentId = payment.id;
  subscription.lastPaymentStatus = "pending";
  await subscription.save();

  await writeAuditLog({
    familyId: user.familyId,
    actorUserId: user._id,
    action: "plan_changed",
    metadata: {
      fromPlanId: previousPlanId,
      toPlanId: plan.id,
      amountInr: plan.monthlyPriceInr,
      mode: "payment_initiated",
      checkoutSessionId: payment.id,
    },
  });

  return NextResponse.json(
    {
      message: "payment required",
      requiresPayment: true,
      checkoutUrl: payment.url,
      checkoutSessionId: payment.id,
      subscription: {
        planId: subscription.planId,
        pendingPlanId: subscription.pendingPlanId,
        status: subscription.status,
        lastPaymentStatus: subscription.lastPaymentStatus,
      },
    },
    { status: 200 },
  );
}
