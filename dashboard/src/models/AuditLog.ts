import { Schema, model, models, Types } from "mongoose";

export type AuditAction =
  | "member_role_changed"
  | "member_removed"
  | "plan_changed"
  | "invoice_exported"
  | "family_created"
  | "family_joined";

export type AuditLogDoc = {
  _id: Types.ObjectId;
  familyId: Types.ObjectId;
  actorUserId: Types.ObjectId;
  action: AuditAction;
  targetUserId?: Types.ObjectId | null;
  metadata?: Record<string, unknown>;
  createdAt: Date;
  updatedAt: Date;
};

const auditLogSchema = new Schema<AuditLogDoc>(
  {
    familyId: { type: Schema.Types.ObjectId, ref: "Family", required: true, index: true },
    actorUserId: { type: Schema.Types.ObjectId, ref: "User", required: true, index: true },
    action: {
      type: String,
      enum: [
        "member_role_changed",
        "member_removed",
        "plan_changed",
        "invoice_exported",
        "family_created",
        "family_joined",
      ],
      required: true,
      index: true,
    },
    targetUserId: { type: Schema.Types.ObjectId, ref: "User", default: null },
    metadata: { type: Schema.Types.Mixed, default: {} },
  },
  { timestamps: true },
);

auditLogSchema.index({ familyId: 1, createdAt: -1 });

export const AuditLog = models.AuditLog || model<AuditLogDoc>("AuditLog", auditLogSchema);
