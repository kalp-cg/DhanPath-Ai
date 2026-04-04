import { Schema, model, models, Types } from "mongoose";

export type CaPackScheduleDoc = {
  _id: Types.ObjectId;
  familyId: Types.ObjectId;
  createdByUserId: Types.ObjectId;
  caEmail: string;
  dayOfMonth: number;
  includeAudit: boolean;
  active: boolean;
  lastRunMonth: string | null;
  lastGeneratedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
};

const caPackScheduleSchema = new Schema<CaPackScheduleDoc>(
  {
    familyId: { type: Schema.Types.ObjectId, ref: "Family", required: true, unique: true, index: true },
    createdByUserId: { type: Schema.Types.ObjectId, ref: "User", required: true },
    caEmail: { type: String, required: true, lowercase: true, trim: true },
    dayOfMonth: { type: Number, required: true, min: 1, max: 28, default: 5 },
    includeAudit: { type: Boolean, required: true, default: true },
    active: { type: Boolean, required: true, default: true },
    lastRunMonth: { type: String, default: null },
    lastGeneratedAt: { type: Date, default: null },
  },
  { timestamps: true },
);

export const CaPackSchedule =
  models.CaPackSchedule || model<CaPackScheduleDoc>("CaPackSchedule", caPackScheduleSchema);
