import { NextResponse } from "next/server";

import { PLAN_DEFS } from "@/server/billing-service";
import { getRazorpayPublicConfig } from "@/server/razorpay";
import { getStripePublicConfig } from "@/server/stripe";

export async function GET() {
  return NextResponse.json(
    {
      plans: PLAN_DEFS,
      payment: {
        razorpay: getRazorpayPublicConfig(),
        stripe: getStripePublicConfig(),
      },
    },
    { status: 200 },
  );
}
