import { NextRequest, NextResponse } from "next/server";

import { getAuthUserFromRequest } from "@/lib/auth";
import { connectToMongo } from "@/lib/mongodb";
import { Family } from "@/models/Family";
import { User } from "@/models/User";
import { getOrCreateSubscription } from "@/server/billing-service";

export async function POST(request: NextRequest) {
  const auth = getAuthUserFromRequest(request);
  if (!auth) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  const body = (await request.json().catch(() => null)) as { inviteCode?: string } | null;
  const inviteCode = body?.inviteCode?.trim().toUpperCase() ?? "";

  if (!inviteCode) {
    return NextResponse.json({ error: "inviteCode is required" }, { status: 400 });
  }

  await connectToMongo();

  const [user, family] = await Promise.all([
    User.findById(auth.userId),
    Family.findOne({ inviteCode }),
  ]);

  if (!user) {
    return NextResponse.json({ error: "user not found" }, { status: 404 });
  }
  if (!family) {
    return NextResponse.json({ error: "invalid invite code" }, { status: 404 });
  }

  if (user.familyId && String(user.familyId) !== String(family._id)) {
    return NextResponse.json({ error: "user already belongs to another family" }, { status: 409 });
  }

  const alreadyMember = family.members.some(
    (m: { userId: unknown }) => String(m.userId) === String(user._id),
  );

  if (!alreadyMember) {
    const subscription = await getOrCreateSubscription({ familyId: family._id, ownerUserId: family.ownerUserId });
    if (family.members.length >= subscription.maxMembers) {
      return NextResponse.json(
        {
          error: "family member limit reached for current plan",
          code: "SEAT_LIMIT_REACHED",
          details: {
            maxMembers: subscription.maxMembers,
            currentMembers: family.members.length,
          },
        },
        { status: 409 },
      );
    }
  }

  if (!alreadyMember) {
    family.members.push({ userId: user._id, email: user.email, role: "member" });
    await family.save();
  }

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
    { status: 200 },
  );
}
