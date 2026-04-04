import { Types } from "mongoose";

import { AuditLog, type AuditAction } from "@/models/AuditLog";

export async function writeAuditLog(params: {
  familyId: Types.ObjectId;
  actorUserId: Types.ObjectId;
  action: AuditAction;
  targetUserId?: Types.ObjectId | null;
  metadata?: Record<string, unknown>;
}) {
  await AuditLog.create({
    familyId: params.familyId,
    actorUserId: params.actorUserId,
    action: params.action,
    targetUserId: params.targetUserId ?? null,
    metadata: params.metadata ?? {},
  });
}
