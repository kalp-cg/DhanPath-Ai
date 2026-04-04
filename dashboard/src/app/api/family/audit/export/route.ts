import { NextRequest, NextResponse } from "next/server";

import { getAuthUserFromRequest } from "@/lib/auth";
import { connectToMongo } from "@/lib/mongodb";
import { AuditLog } from "@/models/AuditLog";
import { Family } from "@/models/Family";
import { User } from "@/models/User";
import { writeAuditLog } from "@/server/audit-log";

function csvCell(value: string | number | null | undefined) {
  const text = String(value ?? "");
  return `"${text.replace(/"/g, '""')}"`;
}

function parseDateParam(value: string | null): Date | null {
  if (!value) return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

export async function GET(request: NextRequest) {
  const auth = getAuthUserFromRequest(request);
  if (!auth) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  await connectToMongo();

  const user = await User.findById(auth.userId);
  if (!user?.familyId) {
    return NextResponse.json({ error: "no family found for user" }, { status: 404 });
  }

  const family = await Family.findById(user.familyId).lean();
  if (!family) {
    return NextResponse.json({ error: "family not found" }, { status: 404 });
  }

  const members = family.members as Array<{ userId: unknown; role: string }>;
  const requesterMember = members.find((member) => String(member.userId) === String(user._id));
  if (!requesterMember || requesterMember.role !== "admin") {
    return NextResponse.json({ error: "admin access required" }, { status: 403 });
  }

  const auditAction = request.nextUrl.searchParams.get("auditAction")?.trim() ?? "all";
  const auditActorId = request.nextUrl.searchParams.get("auditActorId")?.trim() ?? "all";
  const auditFrom = parseDateParam(request.nextUrl.searchParams.get("auditFrom"));
  const auditTo = parseDateParam(request.nextUrl.searchParams.get("auditTo"));

  const auditQuery: {
    familyId: unknown;
    action?: string;
    actorUserId?: unknown;
    createdAt?: { $gte?: Date; $lte?: Date };
  } = {
    familyId: family._id,
  };

  if (auditAction !== "all") {
    auditQuery.action = auditAction;
  }
  if (auditActorId !== "all") {
    auditQuery.actorUserId = auditActorId;
  }
  if (auditFrom || auditTo) {
    auditQuery.createdAt = {};
    if (auditFrom) {
      auditQuery.createdAt.$gte = auditFrom;
    }
    if (auditTo) {
      const inclusiveTo = new Date(auditTo);
      inclusiveTo.setHours(23, 59, 59, 999);
      auditQuery.createdAt.$lte = inclusiveTo;
    }
  }

  const logs = await AuditLog.find(auditQuery).sort({ createdAt: -1 }).limit(5000).lean();

  const userIds = Array.from(
    new Set(
      logs.flatMap((log) => [
        String(log.actorUserId),
        log.targetUserId ? String(log.targetUserId) : "",
      ]).filter(Boolean),
    ),
  );
  const users = await User.find({ _id: { $in: userIds } }).lean();
  const nameMap = new Map(users.map((entry) => [String(entry._id), entry.name ?? "Member"]));

  const header = [
    "created_at",
    "action",
    "actor_user_id",
    "actor_name",
    "target_user_id",
    "target_name",
    "metadata",
  ];

  const rows = logs.map((log) => [
    new Date(log.createdAt).toISOString(),
    log.action,
    String(log.actorUserId),
    nameMap.get(String(log.actorUserId)) ?? "Unknown",
    log.targetUserId ? String(log.targetUserId) : "",
    log.targetUserId ? (nameMap.get(String(log.targetUserId)) ?? "Member") : "",
    JSON.stringify(log.metadata ?? {}),
  ]);

  const csv = [header, ...rows]
    .map((line) => line.map((cell) => csvCell(cell)).join(","))
    .join("\n");

  const filenameDate = new Date().toISOString().slice(0, 10).replace(/-/g, "");
  const filename = `dhanpath-audit-events-${filenameDate}.csv`;

  await writeAuditLog({
    familyId: user.familyId,
    actorUserId: user._id,
    action: "audit_exported",
    metadata: {
      exportedRows: rows.length,
      filters: {
        auditAction,
        auditActorId,
        auditFrom: auditFrom ? auditFrom.toISOString().slice(0, 10) : "",
        auditTo: auditTo ? auditTo.toISOString().slice(0, 10) : "",
      },
      filename,
    },
  });

  return new NextResponse(csv, {
    status: 200,
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition": `attachment; filename=\"${filename}\"`,
      "Cache-Control": "no-store",
    },
  });
}
