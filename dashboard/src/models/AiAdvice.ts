import { Schema, model, models, Types } from "mongoose";

export type AiAdviceDoc = {
  _id: Types.ObjectId;
  familyId: Types.ObjectId;
  userId: Types.ObjectId;
  chatName: string;
  pinned: boolean;
  isDeleted: boolean;
  deletedAt?: Date | null;
  planId: "free" | "pro" | "family_pro";
  model: string;
  prompt: string;
  targetAmount: number;
  targetMonths: number;
  selectedYear: number;
  selectedMonth: number;
  monthlyIncome: number;
  monthlyExpense: number;
  avgMonthlyExpense3M: number;
  feasible: boolean;
  suggestedMonthlySave: number;
  suggestedMonthlySpendCap: number;
  responseText: string;
  recommendations: string[];
  memberInsights: Array<{ userId: string; name: string; spend: number; note: string }>;
  createdAt: Date;
  updatedAt: Date;
};

const aiAdviceSchema = new Schema<AiAdviceDoc>(
  {
    familyId: { type: Schema.Types.ObjectId, ref: "Family", required: true, index: true },
    userId: { type: Schema.Types.ObjectId, ref: "User", required: true, index: true },
    chatName: { type: String, required: true, trim: true, maxlength: 120 },
    pinned: { type: Boolean, required: true, default: false },
    isDeleted: { type: Boolean, required: true, default: false, index: true },
    deletedAt: { type: Date, default: null },
    planId: { type: String, enum: ["free", "pro", "family_pro"], required: true },
    model: { type: String, required: true, default: "llama-3.3-70b-versatile" },
    prompt: { type: String, required: true, trim: true },
    targetAmount: { type: Number, required: true, min: 0 },
    targetMonths: { type: Number, required: true, min: 1 },
    selectedYear: { type: Number, required: true },
    selectedMonth: { type: Number, required: true },
    monthlyIncome: { type: Number, required: true, default: 0 },
    monthlyExpense: { type: Number, required: true, default: 0 },
    avgMonthlyExpense3M: { type: Number, required: true, default: 0 },
    feasible: { type: Boolean, required: true, default: false },
    suggestedMonthlySave: { type: Number, required: true, default: 0 },
    suggestedMonthlySpendCap: { type: Number, required: true, default: 0 },
    responseText: { type: String, required: true },
    recommendations: [{ type: String, trim: true }],
    memberInsights: [
      {
        userId: { type: String, required: true },
        name: { type: String, required: true },
        spend: { type: Number, required: true, default: 0 },
        note: { type: String, required: true },
      },
    ],
  },
  { timestamps: true },
);

aiAdviceSchema.index({ familyId: 1, userId: 1, createdAt: -1 });
aiAdviceSchema.index({ familyId: 1, userId: 1, pinned: -1, createdAt: -1 });

if (models.AiAdvice) {
  delete models.AiAdvice;
}

export const AiAdvice = model<AiAdviceDoc>("AiAdvice", aiAdviceSchema);
