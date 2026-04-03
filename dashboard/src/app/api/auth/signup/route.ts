import bcrypt from "bcryptjs";
import { NextRequest, NextResponse } from "next/server";

import { AUTH_COOKIE, signAuthToken } from "@/lib/auth";
import { toApiErrorMessage } from "@/lib/api-error";
import { connectToMongo } from "@/lib/mongodb";
import { User } from "@/models/User";

export async function POST(request: NextRequest) {
  try {
    const body = (await request.json().catch(() => null)) as
      | { email?: string; password?: string; name?: string }
      | null;

    const email = body?.email?.trim().toLowerCase() ?? "";
    const password = body?.password ?? "";
    const name = body?.name?.trim() || email.split("@")[0] || "User";

    if (!email || !password) {
      return NextResponse.json({ error: "email and password are required" }, { status: 400 });
    }
    if (password.length < 6) {
      return NextResponse.json({ error: "password must be at least 6 characters" }, { status: 400 });
    }

    await connectToMongo();

    const existing = await User.findOne({ email }).lean();
    if (existing) {
      return NextResponse.json({ error: "email already exists" }, { status: 409 });
    }

    const passwordHash = await bcrypt.hash(password, 10);
    const user = await User.create({ email, passwordHash, name });

    const token = signAuthToken({ userId: String(user._id), email });
    const res = NextResponse.json(
      {
        user: { id: String(user._id), email: user.email, name: user.name, familyId: user.familyId ?? null },
        token,
      },
      { status: 201 },
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
    console.error("signup error", error);
    return NextResponse.json({ error: toApiErrorMessage(error) }, { status: 500 });
  }
}
