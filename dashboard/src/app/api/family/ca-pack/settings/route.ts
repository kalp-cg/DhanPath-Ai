import { NextRequest, NextResponse } from "next/server";

import { getAuthUserFromRequest } from "@/lib/auth";
import { connectToMongo } from "@/lib/mongodb";
import { CaPackSchedule } from "@/models/CaPackSchedule";
import { Family } from "@/models/Family";
import { User } from "@/models/User";
import { writeAuditLog } from "@/server/audit-log";

async function getAdminContext(request: NextRequest) {
  const auth = getAuthUserFromRequest(request);
  if (!auth) {
    return { error: NextResponse.json({ error: "unauthorized" }, { status: 401 }) };
  }

  await connectToMongo();

  const user = await User.findById(auth.userId);
  if (!user?.familyId) {
    return { error: NextResponse.json({ error: "no family found for user" }, { status: 404 }) };
  }

  const family = await Family.findById(user.familyId).lean();
  if (!family) {
    return { error: NextResponse.json({ error: "family not found" }, { status: 404 }) };
  }

  const requester = (family.members as Array<{ userId: unknown; role: string }>).find(
    (member) => String(member.userId) === String(user._id),
  );
  if (!requester || requester.role !== "admin") {
    return { error: NextResponse.json({ error: "admin access required" }, { status: 403 }) };
  }

  return { user, family };
}

export async function GET(request: NextRequest) {
  const ctx = await getAdminContext(request);
  if ("error" in ctx) return ctx.error;

  const schedule = await CaPackSchedule.findOne({ familyId: ctx.user.familyId }).lean();
  return NextResponse.json(
    {
      schedule: schedule
        ? {
            caEmail: schedule.caEmail,
            dayOfMonth: schedule.dayOfMonth,
            includeAudit: schedule.includeAudit,
            active: schedule.active,
            lastRunMonth: schedule.lastRunMonth,
            lastGeneratedAt: schedule.lastGeneratedAt,
          }
        : null,
    },
    { status: 200 },
  );
}

export async function POST(request: NextRequest) {
  const ctx = await getAdminContext(request);
  if ("error" in ctx) return ctx.error;

  const body = (await request.json().catch(() => null)) as
    | { caEmail?: string; dayOfMonth?: number; includeAudit?: boolean; active?: boolean }
    | null;

  const caEmail = body?.caEmail?.trim().toLowerCase() ?? "";
  const dayOfMonth = Number(body?.dayOfMonth ?? 5);
  const includeAudit = Boolean(body?.includeAudit ?? true);
  const active = Boolean(body?.active ?? true);

  if (!caEmail || !caEmail.includes("@")) {
    return NextResponse.json({ error: "valid caEmail is required" }, { status: 400 });
  }
  if (!Number.isFinite(dayOfMonth) || dayOfMonth < 1 || dayOfMonth > 28) {
    return NextResponse.json({ error: "dayOfMonth must be between 1 and 28" }, { status: 400 });
  }

  const schedule = await CaPackSchedule.findOneAndUpdate(
    { familyId: ctx.user.familyId },
    {
      $set: {
        familyId: ctx.user.familyId,
        createdByUserId: ctx.user._id,
        caEmail,
        dayOfMonth,
        includeAudit,
        active,
      },
    },
    { upsert: true, new: true },
  );

  await writeAuditLog({
    familyId: ctx.user.familyId,
    actorUserId: ctx.user._id,
    action: "ca_pack_schedule_updated",
    metadata: { caEmail, dayOfMonth, includeAudit, active },
  });

  return NextResponse.json(
    {
      schedule: {
        caEmail: schedule.caEmail,
        dayOfMonth: schedule.dayOfMonth,
        includeAudit: schedule.includeAudit,
        active: schedule.active,
        lastRunMonth: schedule.lastRunMonth,
        lastGeneratedAt: schedule.lastGeneratedAt,
      },
    },
    { status: 200 },
  );
}
