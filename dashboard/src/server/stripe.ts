import Stripe from "stripe";

function getStripeSecretKey() {
  const key = process.env.STRIPE_SECRET_KEY?.trim();
  if (!key) throw new Error("Missing STRIPE_SECRET_KEY");
  if (!key.startsWith("sk_")) {
    throw new Error("STRIPE_SECRET_KEY must start with sk_. It looks like publishable/secret keys are swapped.");
  }
  return key;
}

export function isStripeConfigured() {
  const sk = process.env.STRIPE_SECRET_KEY?.trim() ?? "";
  const pk = process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY?.trim() ?? "";
  return Boolean(sk.startsWith("sk_") && pk.startsWith("pk_"));
}

export function getStripePublicConfig() {
  const rawKey = process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY?.trim() ?? "";
  return {
    publishableKey: rawKey.startsWith("pk_") ? rawKey : "",
    enabled: isStripeConfigured(),
  };
}

export function getStripeClient() {
  return new Stripe(getStripeSecretKey(), {
    apiVersion: "2024-06-20",
  });
}

export async function createCheckoutSession(params: {
  amountInr: number;
  planId: string;
  planName: string;
  userEmail: string;
  userName: string;
  familyId: string;
  userId: string;
  previousPlanId: string;
  successUrl: string;
  cancelUrl: string;
}) {
  const stripe = getStripeClient();
  const amountPaise = Math.max(100, Math.round(params.amountInr * 100));

  const session = await stripe.checkout.sessions.create({
    mode: "payment",
    success_url: `${params.successUrl}?checkout=success&session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${params.cancelUrl}?checkout=cancelled`,
    customer_email: params.userEmail,
    metadata: {
      familyId: params.familyId,
      userId: params.userId,
      targetPlanId: params.planId,
      previousPlanId: params.previousPlanId,
    },
    line_items: [
      {
        quantity: 1,
        price_data: {
          currency: "inr",
          unit_amount: amountPaise,
          product_data: {
            name: `DhanPath ${params.planName}`,
            description: `3-month plan for ${params.userName}`,
          },
        },
      },
    ],
  });

  if (!session.url) {
    throw new Error("Stripe checkout session URL missing");
  }

  return {
    id: session.id,
    url: session.url,
  };
}

export async function retrieveCheckoutSession(sessionId: string) {
  const stripe = getStripeClient();
  return stripe.checkout.sessions.retrieve(sessionId);
}
