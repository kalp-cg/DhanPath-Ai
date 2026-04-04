import { Schema, model, models, Types } from "mongoose";

export type CaPackShareTokenDoc = {
  _id: Types.ObjectId;
  familyId: Types.ObjectId;
  createdByUserId: Types.ObjectId;
  token: string;
  year: number;
  month: number;
  includeAudit: boolean;
  expiresAt: Date;
  createdAt: Date;
  updatedAt: Date;
};

const caPackShareTokenSchema = new Schema<CaPackShareTokenDoc>(
  {
    familyId: { type: Schema.Types.ObjectId, ref: "Family", required: true, index: true },
    createdByUserId: { type: Schema.Types.ObjectId, ref: "User", required: true },
    token: { type: String, required: true, unique: true, index: true },
    year: { type: Number, required: true },
    month: { type: Number, required: true, min: 1, max: 12 },
    includeAudit: { type: Boolean, required: true, default: true },
    expiresAt: { type: Date, required: true, index: true },
  },
  { timestamps: true },
);

export const CaPackShareToken =
  models.CaPackShareToken || model<CaPackShareTokenDoc>("CaPackShareToken", caPackShareTokenSchema);
