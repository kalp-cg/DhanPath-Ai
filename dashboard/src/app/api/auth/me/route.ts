import { NextRequest, NextResponse } from "next/server";

import { getAuthUserFromRequest } from "@/lib/auth";
import { connectToMongo } from "@/lib/mongodb";
import { User } from "@/models/User";

export async function GET(request: NextRequest) {
  const auth = getAuthUserFromRequest(request);
  if (!auth) {
    return NextResponse.json({ user: null }, { status: 200 });
  }

  await connectToMongo();
  const user = await User.findById(auth.userId).lean();

  if (!user) {
    return NextResponse.json({ user: null }, { status: 200 });
  }

  return NextResponse.json(
    {
      user: {
        id: String(user._id),
        email: user.email,
        name: user.name,
        familyId: user.familyId ? String(user.familyId) : null,
      },
    },
    { status: 200 },
  );
}
