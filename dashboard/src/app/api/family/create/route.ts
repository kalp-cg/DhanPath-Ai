import { randomBytes } from "crypto";
import { NextRequest, NextResponse } from "next/server";

import { getAuthUserFromRequest } from "@/lib/auth";
import { connectToMongo } from "@/lib/mongodb";
import { Family } from "@/models/Family";
import { User } from "@/models/User";

function makeInviteCode() {
  return randomBytes(3).toString("hex").toUpperCase();
}

export async function POST(request: NextRequest) {
  const auth = getAuthUserFromRequest(request);
  if (!auth) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  const body = (await request.json().catch(() => null)) as { name?: string } | null;
  const name = body?.name?.trim() || "My Family";

  await connectToMongo();

  const user = await User.findById(auth.userId);
  if (!user) {
    return NextResponse.json({ error: "user not found" }, { status: 404 });
  }
  if (user.familyId) {
    return NextResponse.json({ error: "user already has family" }, { status: 409 });
  }

  let inviteCode = makeInviteCode();
  while (await Family.findOne({ inviteCode }).lean()) {
    inviteCode = makeInviteCode();
  }

  const family = await Family.create({
    name,
    inviteCode,
    ownerUserId: user._id,
    members: [{ userId: user._id, email: user.email, role: "admin" }],
  });

  user.familyId = family._id;
  await user.save();

  return NextResponse.json(
    {
      family: {
        id: String(family._id),
        name: family.name,
        inviteCode: family.inviteCode,
      },
    },
    { status: 201 },
  );
}
