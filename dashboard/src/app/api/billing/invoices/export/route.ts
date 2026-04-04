import { NextRequest, NextResponse } from "next/server";

import { getAuthUserFromRequest } from "@/lib/auth";
import { connectToMongo } from "@/lib/mongodb";
import { User } from "@/models/User";
import { writeAuditLog } from "@/server/audit-log";
import { getOrCreateSubscription, getPlan } from "@/server/billing-service";

function csvCell(value: string | number | null | undefined) {
  const text = String(value ?? "");
  return `"${text.replace(/"/g, '""')}"`;
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

  const sub = await getOrCreateSubscription({ familyId: user.familyId, ownerUserId: user._id });
  const currentPlan = getPlan(sub.planId);
  const events = [...(sub.billingEvents ?? [])].sort(
    (a, b) => new Date(b.at).getTime() - new Date(a.at).getTime(),
  );

  const header = [
    "event_at",
    "event_kind",
    "from_plan",
    "to_plan",
    "amount_inr",
    "current_status",
    "current_plan",
    "period_start",
    "period_end",
    "next_billing_at",
    "note",
  ];

  const rows = events.map((evt) => [
    new Date(evt.at).toISOString(),
    evt.kind,
    evt.fromPlanId ?? "",
    evt.toPlanId,
    evt.amountInr,
    sub.status,
    currentPlan.name,
    new Date(sub.currentPeriodStart).toISOString(),
    new Date(sub.currentPeriodEnd).toISOString(),
    sub.nextBillingAt ? new Date(sub.nextBillingAt).toISOString() : "",
    evt.note ?? "",
  ]);

  const csv = [header, ...rows]
    .map((line) => line.map((cell) => csvCell(cell)).join(","))
    .join("\n");

  const filenameDate = new Date().toISOString().slice(0, 10).replace(/-/g, "");
  const filename = `dhanpath-billing-events-${filenameDate}.csv`;

  await writeAuditLog({
    familyId: user.familyId,
    actorUserId: user._id,
    action: "invoice_exported",
    metadata: {
      exportedRows: rows.length,
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
