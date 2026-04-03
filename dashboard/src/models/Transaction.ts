import { Schema, model, models, Types } from "mongoose";

export type TransactionDoc = {
  _id: Types.ObjectId;
  familyId: Types.ObjectId;
  userId: Types.ObjectId;
  userEmail: string;
  clientTxnId?: string;
  amount: number;
  type: "debit" | "credit";
  category: string;
  merchant?: string;
  source: "sms" | "manual" | "vision" | "voice";
  txnTime: Date;
  createdAt: Date;
  updatedAt: Date;
};

const transactionSchema = new Schema<TransactionDoc>(
  {
    familyId: { type: Schema.Types.ObjectId, ref: "Family", required: true, index: true },
    userId: { type: Schema.Types.ObjectId, ref: "User", required: true, index: true },
    userEmail: { type: String, required: true, lowercase: true, trim: true },
    clientTxnId: { type: String, trim: true },
    amount: { type: Number, required: true, min: 0 },
    type: { type: String, enum: ["debit", "credit"], default: "debit" },
    category: { type: String, required: true, default: "Uncategorized" },
    merchant: { type: String, trim: true },
    source: { type: String, enum: ["sms", "manual", "vision", "voice"], default: "manual" },
    txnTime: { type: Date, default: Date.now, index: true },
  },
  { timestamps: true },
);

transactionSchema.index(
  { familyId: 1, userId: 1, clientTxnId: 1 },
  { unique: true, sparse: true, name: "uniq_family_user_client_txn" },
);

export const Transaction =
  models.Transaction || model<TransactionDoc>("Transaction", transactionSchema);
