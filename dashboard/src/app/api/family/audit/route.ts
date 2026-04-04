import { NextRequest, NextResponse } from "next/server";

import { getAuthUserFromRequest } from "@/lib/auth";
import { connectToMongo } from "@/lib/mongodb";
import { AuditLog } from "@/models/AuditLog";
import { User } from "@/models/User";
import { resolveFamilyAccess } from "@/server/family-access";

type AuditQuery = {
  familyId: unknown;
  action?: string;
  actorUserId?: unknown;
  createdAt?: { $gte?: Date; $lte?: Date };
};

function parseDateParam(value: string | null): Date | null {
  if (!value) return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

function parsePositiveInt(value: string | null, fallback: number): number {
  const parsed = Number(value ?? fallback);
  if (!Number.isFinite(parsed) || parsed < 1) return fallback;
  return Math.floor(parsed);
}

export async function GET(request: NextRequest) {
  const auth = getAuthUserFromRequest(request);
  if (!auth) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  await connectToMongo();

  const access = await resolveFamilyAccess(auth.userId);
  if (!access.ok) {
    return NextResponse.json({ error: access.error }, { status: access.status });
  }
  if (!access.isAdmin) {
    return NextResponse.json({ error: "admin access required" }, { status: 403 });
  }

  const { user, family, members } = access;

  const action = request.nextUrl.searchParams.get("action")?.trim() ?? "all";
  const actorId = request.nextUrl.searchParams.get("actorId")?.trim() ?? "all";
  const from = parseDateParam(request.nextUrl.searchParams.get("from"));
  const to = parseDateParam(request.nextUrl.searchParams.get("to"));
  const page = parsePositiveInt(request.nextUrl.searchParams.get("page"), 1);
  const pageSize = Math.min(50, parsePositiveInt(request.nextUrl.searchParams.get("pageSize"), 15));

  const auditQuery: AuditQuery = {
    familyId: family._id,
  };

  if (action !== "all") {
    auditQuery.action = action;
  }
  if (actorId !== "all") {
    auditQuery.actorUserId = actorId;
  }
  if (from || to) {
    auditQuery.createdAt = {};
    if (from) {
      auditQuery.createdAt.$gte = from;
    }
    if (to) {
      const inclusiveTo = new Date(to);
      inclusiveTo.setHours(23, 59, 59, 999);
      auditQuery.createdAt.$lte = inclusiveTo;
    }
  }

  const totalRecords = await AuditLog.countDocuments(auditQuery);
  const totalPages = Math.max(1, Math.ceil(totalRecords / pageSize));
  const safePage = Math.min(page, totalPages);
  const skip = (safePage - 1) * pageSize;

  const logs = await AuditLog.find(auditQuery)
    .sort({ createdAt: -1 })
    .skip(skip)
    .limit(pageSize)
    .lean();

  const userIds = Array.from(
    new Set(
      logs
        .flatMap((log) => [
          String(log.actorUserId),
          log.targetUserId ? String(log.targetUserId) : "",
        ])
        .filter(Boolean),
    ),
  );
  const users = await User.find({ _id: { $in: userIds } }).lean();
  const nameMap = new Map(users.map((entry) => [String(entry._id), entry.name ?? "Member"]));

  const audit = logs.map((entry) => ({
    id: String(entry._id),
    action: entry.action,
    actorUserId: String(entry.actorUserId),
    actorName: nameMap.get(String(entry.actorUserId)) ?? "Unknown",
    targetUserId: entry.targetUserId ? String(entry.targetUserId) : null,
    targetName: entry.targetUserId
      ? (nameMap.get(String(entry.targetUserId)) ?? "Member")
      : null,
    metadata:
      entry.metadata && typeof entry.metadata === "object"
        ? (entry.metadata as Record<string, unknown>)
        : {},
    createdAt: new Date(entry.createdAt).toISOString(),
  }));

  const membersResponse = members.map((member) => ({
    userId: String(member.userId),
    name: nameMap.get(String(member.userId)) ?? member.name,
  }));

  return NextResponse.json(
    {
      currentUserId: String(user._id),
      members: membersResponse,
      audit,
      pagination: {
        page: safePage,
        pageSize,
        totalRecords,
        totalPages,
        hasPrev: safePage > 1,
        hasNext: safePage < totalPages,
      },
      filters: {
        action,
        actorId,
        from: from ? from.toISOString().slice(0, 10) : "",
        to: to ? to.toISOString().slice(0, 10) : "",
      },
    },
    { status: 200 },
  );
}
