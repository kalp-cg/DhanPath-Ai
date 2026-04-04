import { NextRequest, NextResponse } from "next/server";

import { connectToMongo } from "@/lib/mongodb";
import { CaPackShareToken } from "@/models/CaPackShareToken";
import { buildCaPackCsv, buildCaPackData } from "@/server/ca-pack";

export async function GET(_request: NextRequest, context: { params: Promise<{ token: string }> }) {
  const params = await context.params;
  const token = params.token?.trim();
  if (!token) {
    return NextResponse.json({ error: "invalid token" }, { status: 400 });
  }

  await connectToMongo();

  const share = await CaPackShareToken.findOne({ token });
  if (!share) {
    return NextResponse.json({ error: "share token not found" }, { status: 404 });
  }
  if (new Date(share.expiresAt).getTime() < Date.now()) {
    return NextResponse.json({ error: "share token expired" }, { status: 410 });
  }

  const data = await buildCaPackData({
    familyId: share.familyId,
    year: share.year,
    month: share.month,
    includeAudit: share.includeAudit,
  });
  if (!data) {
    return NextResponse.json({ error: "family not found" }, { status: 404 });
  }

  const csv = buildCaPackCsv(data);
  const filename = `dhanpath-ca-pack-${share.year}-${String(share.month).padStart(2, "0")}.csv`;

  return new NextResponse(csv, {
    status: 200,
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition": `attachment; filename=\"${filename}\"`,
      "Cache-Control": "no-store",
    },
  });
}
