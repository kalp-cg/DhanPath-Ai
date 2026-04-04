import { NextRequest, NextResponse } from "next/server";

import { connectToMongo } from "@/lib/mongodb";
import { Subscription } from "@/models/Subscription";
import { getPlan } from "@/server/billing-service";
import { verifyWebhookSignature } from "@/server/razorpay";

type RazorpayWebhookPaymentLinkPaid = {
  event: string;
  payload?: {
    payment_link?: {
      entity?: {
        id?: string;
        notes?: {
          familyId?: string;
          userId?: string;
          targetPlanId?: "free" | "pro" | "family_pro";
          previousPlanId?: "free" | "pro" | "family_pro";
        };
      };
    };
    payment?: {
      entity?: {
        id?: string;
        status?: string;
      };
    };
  };
};

export async function POST(request: NextRequest) {
  const payloadText = await request.text();
  const signature = request.headers.get("x-razorpay-signature");

  try {
    const valid = verifyWebhookSignature(payloadText, signature);
    if (!valid) {
      return NextResponse.json({ error: "invalid webhook signature" }, { status: 401 });
    }
  } catch (error) {
    return NextResponse.json({ error: error instanceof Error ? error.message : "webhook auth failed" }, { status: 500 });
  }

  const body = JSON.parse(payloadText) as RazorpayWebhookPaymentLinkPaid;
  const event = body.event ?? "";

  if (event !== "payment_link.paid" && event !== "payment.captured") {
    return NextResponse.json({ ok: true, ignored: event }, { status: 200 });
  }

  const notes = body.payload?.payment_link?.entity?.notes;
  const familyId = notes?.familyId?.trim() ?? "";
  const targetPlanId = notes?.targetPlanId;
  if (!familyId || !targetPlanId) {
    return NextResponse.json({ error: "missing familyId/targetPlanId in notes" }, { status: 400 });
  }

  await connectToMongo();

  const subscription = await Subscription.findOne({ familyId });
  if (!subscription) {
    return NextResponse.json({ error: "subscription not found" }, { status: 404 });
  }

  const plan = getPlan(targetPlanId);
  subscription.planId = plan.id;
  subscription.pendingPlanId = null;
  subscription.monthlyTxnLimit = plan.monthlyTxnLimit;
  subscription.maxMembers = plan.maxMembers;
  subscription.status = "active";
  subscription.billingProvider = plan.id === "free" ? "none" : "razorpay";
  subscription.externalPaymentId = body.payload?.payment?.entity?.id ?? subscription.externalPaymentId;
  subscription.lastPaymentStatus = "paid";
  subscription.lastPaymentAt = new Date();
  subscription.nextBillingAt = subscription.currentPeriodEnd;
  subscription.billingEvents = subscription.billingEvents ?? [];
  subscription.billingEvents.push({
    at: new Date(),
    kind: "plan_changed",
    fromPlanId: notes?.previousPlanId ?? subscription.planId,
    toPlanId: plan.id,
    amountInr: plan.monthlyPriceInr,
    actorUserId: subscription.ownerUserId,
    note: `Razorpay ${event}`,
  });
  await subscription.save();

  return NextResponse.json({ ok: true }, { status: 200 });
}
