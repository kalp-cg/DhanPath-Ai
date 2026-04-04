import { NextRequest, NextResponse } from "next/server";
import { Types } from "mongoose";

import { getAuthUserFromRequest } from "@/lib/auth";
import { connectToMongo } from "@/lib/mongodb";
import { ActionPlan } from "@/models/ActionPlan";
import { resolveFamilyAccess } from "@/server/family-access";

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

  const plan = await ActionPlan.findOne({ familyId: access.family._id }).lean();
  if (!plan) {
    return NextResponse.json({ plan: null }, { status: 200 });
  }

  return NextResponse.json(
    {
      plan: {
        id: String(plan._id),
        focusCategory: plan.focusCategory,
        cutPercent: plan.cutPercent,
        goalAmount: plan.goalAmount,
        baselineMonthlySpend: plan.baselineMonthlySpend,
        monthlySaving: plan.monthlySaving,
        yearlySaving: plan.yearlySaving,
        goalMonths: plan.goalMonths,
        notes: plan.notes ?? null,
        updatedAt: plan.updatedAt,
      },
    },
    { status: 200 },
  );
}

export async function POST(request: NextRequest) {
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

  const body = (await request.json().catch(() => null)) as
    | {
        focusCategory?: string;
        cutPercent?: number;
        goalAmount?: number;
        baselineMonthlySpend?: number;
        monthlySaving?: number;
        yearlySaving?: number;
        goalMonths?: number | null;
        notes?: string;
      }
    | null;

  const focusCategory = String(body?.focusCategory ?? "all").trim() || "all";
  const cutPercent = Number(body?.cutPercent ?? 0);
  const goalAmount = Number(body?.goalAmount ?? 0);
  const baselineMonthlySpend = Number(body?.baselineMonthlySpend ?? 0);
  const monthlySaving = Number(body?.monthlySaving ?? 0);
  const yearlySaving = Number(body?.yearlySaving ?? 0);
  const goalMonthsRaw = body?.goalMonths;
  const goalMonths = goalMonthsRaw == null ? null : Number(goalMonthsRaw);
  const notes = typeof body?.notes === "string" ? body.notes.trim() : "";

  if (!Number.isFinite(cutPercent) || cutPercent < 0 || cutPercent > 100) {
    return NextResponse.json({ error: "cutPercent must be between 0 and 100" }, { status: 400 });
  }
  if (!Number.isFinite(goalAmount) || goalAmount < 0) {
    return NextResponse.json({ error: "goalAmount must be >= 0" }, { status: 400 });
  }
  if (!Number.isFinite(baselineMonthlySpend) || baselineMonthlySpend < 0) {
    return NextResponse.json({ error: "baselineMonthlySpend must be >= 0" }, { status: 400 });
  }
  if (!Number.isFinite(monthlySaving) || monthlySaving < 0) {
    return NextResponse.json({ error: "monthlySaving must be >= 0" }, { status: 400 });
  }
  if (!Number.isFinite(yearlySaving) || yearlySaving < 0) {
    return NextResponse.json({ error: "yearlySaving must be >= 0" }, { status: 400 });
  }
  if (goalMonths !== null && (!Number.isFinite(goalMonths) || goalMonths < 0)) {
    return NextResponse.json({ error: "goalMonths must be null or >= 0" }, { status: 400 });
  }

  const plan = await ActionPlan.findOneAndUpdate(
    { familyId: access.family._id },
    {
      $set: {
        familyId: access.family._id,
        createdByUserId: access.user._id as Types.ObjectId,
        focusCategory,
        cutPercent: Number(cutPercent.toFixed(2)),
        goalAmount: Number(goalAmount.toFixed(2)),
        baselineMonthlySpend: Number(baselineMonthlySpend.toFixed(2)),
        monthlySaving: Number(monthlySaving.toFixed(2)),
        yearlySaving: Number(yearlySaving.toFixed(2)),
        goalMonths: goalMonths === null ? null : Math.ceil(goalMonths),
        notes: notes || null,
      },
    },
    { new: true, upsert: true },
  );

  return NextResponse.json(
    {
      plan: {
        id: String(plan._id),
        focusCategory: plan.focusCategory,
        cutPercent: plan.cutPercent,
        goalAmount: plan.goalAmount,
        baselineMonthlySpend: plan.baselineMonthlySpend,
        monthlySaving: plan.monthlySaving,
        yearlySaving: plan.yearlySaving,
        goalMonths: plan.goalMonths,
        notes: plan.notes ?? null,
        updatedAt: plan.updatedAt,
      },
    },
    { status: 200 },
  );
}
