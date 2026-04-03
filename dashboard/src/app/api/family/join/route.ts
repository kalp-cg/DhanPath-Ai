import { NextResponse } from "next/server";

export async function POST() {
  return NextResponse.json(
    {
      error:
        "Invite-code join is deprecated. Use email invitation flow: /api/family/invite and /api/family/invitations/accept.",
    },
    { status: 410 },
  );
}
