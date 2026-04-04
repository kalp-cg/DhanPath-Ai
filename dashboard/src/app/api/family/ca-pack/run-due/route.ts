import { NextRequest, NextResponse } from "next/server";

import { connectToMongo } from "@/lib/mongodb";
import { CaPackSchedule } from "@/models/CaPackSchedule";
import { createCaPackToken } from "@/server/ca-pack";

function ensureCronAuth(request: NextRequest) {
  const expected = process.env.CA_PACK_CRON_SECRET?.trim();
  if (!expected) return false;
  const got = request.headers.get("x-ca-pack-cron-secret")?.trim();
  return got === expected;
}

function getMonthKey(date: Date) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}`;
}

function siteBaseUrl(request: NextRequest) {
  const configured = process.env.NEXT_PUBLIC_APP_URL?.trim();
  if (configured) return configured.replace(/\/$/, "");
  return request.nextUrl.origin;
}

export async function POST(request: NextRequest) {
  if (!ensureCronAuth(request)) {
    return NextResponse.json({ error: "unauthorized cron execution" }, { status: 401 });
  }

  await connectToMongo();

  const now = new Date();
  const monthKey = getMonthKey(now);
  const day = now.getDate();
  const schedules = await CaPackSchedule.find({ active: true }).lean();
  const baseUrl = siteBaseUrl(request);

  const generated: Array<{ familyId: string; token: string; packPageUrl: string; caEmail: string }> = [];

  for (const schedule of schedules) {
    if (day < schedule.dayOfMonth) continue;
    if (schedule.lastRunMonth === monthKey) continue;

    const { token } = await createCaPackToken({
      familyId: schedule.familyId,
      createdByUserId: schedule.createdByUserId,
      year: now.getFullYear(),
      month: now.getMonth() + 1,
      includeAudit: schedule.includeAudit,
      expiresDays: 10,
    });

    await CaPackSchedule.findByIdAndUpdate(schedule._id, {
      $set: {
        lastRunMonth: monthKey,
        lastGeneratedAt: now,
      },
    });

    generated.push({
      familyId: String(schedule.familyId),
      token,
      packPageUrl: `${baseUrl}/ca-pack/${token}`,
      caEmail: schedule.caEmail,
    });
  }

  return NextResponse.json(
    {
      monthKey,
      generatedCount: generated.length,
      generated,
    },
    { status: 200 },
  );
}
