import { Schema, model, models, Types } from "mongoose";

export type ActionPlanDoc = {
  _id: Types.ObjectId;
  familyId: Types.ObjectId;
  createdByUserId: Types.ObjectId;
  focusCategory: string;
  cutPercent: number;
  goalAmount: number;
  baselineMonthlySpend: number;
  monthlySaving: number;
  yearlySaving: number;
  goalMonths: number | null;
  notes?: string | null;
  createdAt: Date;
  updatedAt: Date;
};

const actionPlanSchema = new Schema<ActionPlanDoc>(
  {
    familyId: { type: Schema.Types.ObjectId, ref: "Family", required: true, unique: true, index: true },
    createdByUserId: { type: Schema.Types.ObjectId, ref: "User", required: true },
    focusCategory: { type: String, required: true, trim: true, default: "all" },
    cutPercent: { type: Number, required: true, min: 0, max: 100 },
    goalAmount: { type: Number, required: true, min: 0 },
    baselineMonthlySpend: { type: Number, required: true, min: 0 },
    monthlySaving: { type: Number, required: true, min: 0 },
    yearlySaving: { type: Number, required: true, min: 0 },
    goalMonths: { type: Number, default: null },
    notes: { type: String, default: null, trim: true },
  },
  { timestamps: true },
);

export const ActionPlan = models.ActionPlan || model<ActionPlanDoc>("ActionPlan", actionPlanSchema);
