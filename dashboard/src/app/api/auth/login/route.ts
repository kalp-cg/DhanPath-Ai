import bcrypt from "bcryptjs";
import { NextRequest, NextResponse } from "next/server";

import { AUTH_COOKIE, signAuthToken } from "@/lib/auth";
import { toApiErrorMessage } from "@/lib/api-error";
import { connectToMongo } from "@/lib/mongodb";
import { User } from "@/models/User";

export async function POST(request: NextRequest) {
  try {
    const body = (await request.json().catch(() => null)) as
      | { email?: string; password?: string }
      | null;

    const email = body?.email?.trim().toLowerCase() ?? "";
    const password = body?.password ?? "";

    if (!email || !password) {
      return NextResponse.json({ error: "email and password are required" }, { status: 400 });
    }

    await connectToMongo();
    const user = await User.findOne({ email });

    if (!user) {
      return NextResponse.json({ error: "invalid credentials" }, { status: 401 });
    }

    const ok = await bcrypt.compare(password, user.passwordHash);
    if (!ok) {
      return NextResponse.json({ error: "invalid credentials" }, { status: 401 });
    }

    const token = signAuthToken({ userId: String(user._id), email: user.email });
    const res = NextResponse.json(
      {
        user: {
          id: String(user._id),
          email: user.email,
          name: user.name,
          familyId: user.familyId ? String(user.familyId) : null,
        },
        token,
      },
      { status: 200 },
    );

    res.cookies.set(AUTH_COOKIE, token, {
      httpOnly: true,
      secure: process.env.NODE_ENV === "production",
      sameSite: "lax",
      path: "/",
      maxAge: 60 * 60 * 24 * 7,
    });

    return res;
  } catch (error) {
    console.error("login error", error);
    return NextResponse.json({ error: toApiErrorMessage(error) }, { status: 500 });
  }
}
