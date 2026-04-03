import { Schema, model, models, Types } from "mongoose";

export type FamilyMember = {
  userId: Types.ObjectId;
  email: string;
  role: "admin" | "member";
};

export type FamilyDoc = {
  _id: Types.ObjectId;
  name: string;
  inviteCode: string;
  ownerUserId: Types.ObjectId;
  members: FamilyMember[];
  createdAt: Date;
  updatedAt: Date;
};

const familySchema = new Schema<FamilyDoc>(
  {
    name: { type: String, required: true, trim: true },
    inviteCode: { type: String, required: true, unique: true, uppercase: true, trim: true },
    ownerUserId: { type: Schema.Types.ObjectId, ref: "User", required: true },
    members: [
      {
        userId: { type: Schema.Types.ObjectId, ref: "User", required: true },
        email: { type: String, required: true, lowercase: true, trim: true },
        role: { type: String, enum: ["admin", "member"], required: true },
      },
    ],
  },
  { timestamps: true },
);

export const Family = models.Family || model<FamilyDoc>("Family", familySchema);
