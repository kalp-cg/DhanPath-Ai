import { Schema, model, models, Types } from "mongoose";

export type SubscriptionStatus = "active" | "trialing" | "past_due" | "canceled";

export type BillingEvent = {
  at: Date;
  kind: "created" | "plan_changed" | "renewed";
  fromPlanId: "free" | "pro" | "family_pro" | null;
  toPlanId: "free" | "pro" | "family_pro";
  amountInr: number;
  actorUserId: Types.ObjectId;
  note?: string;
};

export type SubscriptionDoc = {
  _id: Types.ObjectId;
  familyId: Types.ObjectId;
  ownerUserId: Types.ObjectId;
  planId: "free" | "pro" | "family_pro";
  pendingPlanId?: "free" | "pro" | "family_pro" | null;
  status: SubscriptionStatus;
  monthlyTxnLimit: number;
  maxMembers: number;
  currentPeriodStart: Date;
  currentPeriodEnd: Date;
  trialEndsAt?: Date | null;
  nextBillingAt?: Date | null;
  billingProvider?: "none" | "razorpay";
  externalCustomerId?: string | null;
  externalSubscriptionId?: string | null;
  externalPaymentId?: string | null;
  lastPaymentAt?: Date | null;
  lastPaymentStatus?: "none" | "pending" | "paid" | "failed";
  billingEvents: BillingEvent[];
  canceledAt?: Date | null;
  createdAt: Date;
  updatedAt: Date;
};

const subscriptionSchema = new Schema<SubscriptionDoc>(
  {
    familyId: { type: Schema.Types.ObjectId, ref: "Family", required: true, unique: true, index: true },
    ownerUserId: { type: Schema.Types.ObjectId, ref: "User", required: true },
    planId: { type: String, enum: ["free", "pro", "family_pro"], default: "free", required: true },
    pendingPlanId: { type: String, enum: ["free", "pro", "family_pro"], default: null },
    status: { type: String, enum: ["active", "trialing", "past_due", "canceled"], default: "active", required: true },
    monthlyTxnLimit: { type: Number, required: true, default: 200 },
    maxMembers: { type: Number, required: true, default: 4 },
    currentPeriodStart: { type: Date, required: true, default: Date.now },
    currentPeriodEnd: { type: Date, required: true },
    trialEndsAt: { type: Date, default: null },
    nextBillingAt: { type: Date, default: null },
    billingProvider: { type: String, enum: ["none", "razorpay"], default: "none" },
    externalCustomerId: { type: String, default: null },
    externalSubscriptionId: { type: String, default: null },
    externalPaymentId: { type: String, default: null },
    lastPaymentAt: { type: Date, default: null },
    lastPaymentStatus: { type: String, enum: ["none", "pending", "paid", "failed"], default: "none" },
    billingEvents: [
      {
        at: { type: Date, required: true, default: Date.now },
        kind: { type: String, enum: ["created", "plan_changed", "renewed"], required: true },
        fromPlanId: { type: String, enum: ["free", "pro", "family_pro"], default: null },
        toPlanId: { type: String, enum: ["free", "pro", "family_pro"], required: true },
        amountInr: { type: Number, required: true, default: 0 },
        actorUserId: { type: Schema.Types.ObjectId, ref: "User", required: true },
        note: { type: String, trim: true },
      },
    ],
    canceledAt: { type: Date, default: null },
  },
  { timestamps: true },
);

export const Subscription = models.Subscription || model<SubscriptionDoc>("Subscription", subscriptionSchema);
