import { Schema, model, models, Types } from "mongoose";

export type UserDoc = {
  _id: Types.ObjectId;
  email: string;
  passwordHash: string;
  name: string;
  familyId?: Types.ObjectId;
  createdAt: Date;
  updatedAt: Date;
};

const userSchema = new Schema<UserDoc>(
  {
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },
    passwordHash: { type: String, required: true },
    name: { type: String, required: true, trim: true },
    familyId: { type: Schema.Types.ObjectId, ref: "Family" },
  },
  { timestamps: true },
);

export const User = models.User || model<UserDoc>("User", userSchema);
