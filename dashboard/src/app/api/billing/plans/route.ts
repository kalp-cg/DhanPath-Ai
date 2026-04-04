import { NextResponse } from "next/server";

import { PLAN_DEFS } from "@/server/billing-service";

export async function GET() {
  return NextResponse.json({ plans: PLAN_DEFS }, { status: 200 });
}
