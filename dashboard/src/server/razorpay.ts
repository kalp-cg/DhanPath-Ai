import { createHmac } from "crypto";

type RazorpayPaymentLinkResponse = {
  id: string;
  short_url: string;
  status: string;
};

function getKeyId() {
  const keyId = process.env.RAZORPAY_KEY_ID?.trim();
  if (!keyId) throw new Error("Missing RAZORPAY_KEY_ID");
  return keyId;
}

function getKeySecret() {
  const keySecret = process.env.RAZORPAY_KEY_SECRET?.trim();
  if (!keySecret) throw new Error("Missing RAZORPAY_KEY_SECRET");
  return keySecret;
}

function authHeader() {
  const token = Buffer.from(`${getKeyId()}:${getKeySecret()}`).toString("base64");
  return `Basic ${token}`;
}

export function getRazorpayPublicConfig() {
  return {
    keyId: process.env.RAZORPAY_KEY_ID?.trim() ?? "",
    enabled: Boolean(process.env.RAZORPAY_KEY_ID?.trim() && process.env.RAZORPAY_KEY_SECRET?.trim()),
  };
}

export async function createPaymentLink(params: {
  amountInr: number;
  customerName: string;
  customerEmail: string;
  description: string;
  notes: Record<string, string>;
}) {
  const amountPaise = Math.max(100, Math.round(params.amountInr * 100));
  const payload = {
    amount: amountPaise,
    currency: "INR",
    description: params.description,
    customer: {
      name: params.customerName,
      email: params.customerEmail,
    },
    notify: {
      email: true,
      sms: false,
    },
    reminder_enable: true,
    callback_method: "get",
    notes: params.notes,
  };

  const response = await fetch("https://api.razorpay.com/v1/payment_links", {
    method: "POST",
    headers: {
      Authorization: authHeader(),
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Razorpay payment link failed: ${response.status} ${body}`);
  }

  const data = (await response.json()) as RazorpayPaymentLinkResponse;
  return {
    id: data.id,
    url: data.short_url,
    status: data.status,
  };
}

export function verifyWebhookSignature(payload: string, signature: string | null) {
  const secret = process.env.RAZORPAY_WEBHOOK_SECRET?.trim();
  if (!secret) {
    throw new Error("Missing RAZORPAY_WEBHOOK_SECRET");
  }
  if (!signature) return false;

  const digest = createHmac("sha256", secret).update(payload).digest("hex");
  return digest === signature;
}
