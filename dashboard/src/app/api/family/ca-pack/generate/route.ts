import { NextRequest, NextResponse } from "next/server";

import { getAuthUserFromRequest } from "@/lib/auth";
import { connectToMongo } from "@/lib/mongodb";
import { CaPackSchedule } from "@/models/CaPackSchedule";
import { Family } from "@/models/Family";
import { User } from "@/models/User";
import { writeAuditLog } from "@/server/audit-log";
import { createCaPackToken } from "@/server/ca-pack";

function siteBaseUrl(request: NextRequest) {
  const configured = process.env.NEXT_PUBLIC_APP_URL?.trim();
  if (configured) return configured.replace(/\/$/, "");
  return request.nextUrl.origin;
}

export async function POST(request: NextRequest) {
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

  const requester = (family.members as Array<{ userId: unknown; role: string }>).find(
    (member) => String(member.userId) === String(user._id),
  );
  if (!requester || requester.role !== "admin") {
    return NextResponse.json({ error: "admin access required" }, { status: 403 });
  }

  const now = new Date();
  const body = (await request.json().catch(() => null)) as
    | { year?: number; month?: number; includeAudit?: boolean; expiresDays?: number }
    | null;

  const year = Number(body?.year ?? now.getFullYear());
  const month = Number(body?.month ?? now.getMonth() + 1);
  const includeAudit = Boolean(body?.includeAudit ?? true);
  const expiresDays = Number(body?.expiresDays ?? 7);

  if (!Number.isFinite(year) || year < 2020 || year > 2100) {
    return NextResponse.json({ error: "invalid year" }, { status: 400 });
  }
  if (!Number.isFinite(month) || month < 1 || month > 12) {
    return NextResponse.json({ error: "invalid month" }, { status: 400 });
  }

  const { token, expiresAt } = await createCaPackToken({
    familyId: user.familyId,
    createdByUserId: user._id,
    year,
    month,
    includeAudit,
    expiresDays,
  });

  const schedule = await CaPackSchedule.findOne({ familyId: user.familyId });
  const caEmail = schedule?.caEmail ?? "";

  const baseUrl = siteBaseUrl(request);
  const packPageUrl = `${baseUrl}/ca-pack/${token}`;
  const csvUrl = `${baseUrl}/api/family/ca-pack/${token}/csv`;
  const pdfUrl = `${baseUrl}/api/family/ca-pack/${token}/pdf`;

  const mailBody = encodeURIComponent(
    [
      `Hello CA,`,
      ``,
      `Please find this month's DhanPath family finance pack:`,
      `Pack: ${packPageUrl}`,
      `CSV: ${csvUrl}`,
      `PDF view: ${pdfUrl}`,
      ``,
      `Token expires: ${expiresAt.toISOString()}`,
    ].join("\n"),
  );
  const mailTo = caEmail
    ? `mailto:${caEmail}?subject=${encodeURIComponent(`DhanPath CA Pack ${year}-${String(month).padStart(2, "0")}`)}&body=${mailBody}`
    : "";

  await writeAuditLog({
    familyId: user.familyId,
    actorUserId: user._id,
    action: "ca_pack_generated",
    metadata: { year, month, includeAudit, expiresAt: expiresAt.toISOString() },
  });

  return NextResponse.json(
    {
      pack: {
        token,
        year,
        month,
        includeAudit,
        expiresAt,
        packPageUrl,
        csvUrl,
        pdfUrl,
        mailTo,
      },
    },
    { status: 200 },
  );
}
