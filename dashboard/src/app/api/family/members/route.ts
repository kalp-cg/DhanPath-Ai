import { NextRequest, NextResponse } from "next/server";

import { getAuthUserFromRequest } from "@/lib/auth";
import { connectToMongo } from "@/lib/mongodb";
import { Family } from "@/models/Family";
import { User } from "@/models/User";

type FamilyMember = {
  userId: unknown;
  email: string;
  role: "admin" | "member";
};

function toPublicMember(member: FamilyMember, nameMap: Map<string, string>) {
  const id = String(member.userId);
  return {
    userId: id,
    email: member.email,
    role: member.role,
    name: nameMap.get(id) ?? member.email.split("@")[0],
  };
}

async function getFamilyContext(request: NextRequest) {
  const auth = getAuthUserFromRequest(request);
  if (!auth) {
    return { error: NextResponse.json({ error: "unauthorized" }, { status: 401 }) };
  }

  await connectToMongo();

  const requester = await User.findById(auth.userId);
  if (!requester?.familyId) {
    return { error: NextResponse.json({ error: "no family found for user" }, { status: 404 }) };
  }

  const family = await Family.findById(requester.familyId);
  if (!family) {
    return { error: NextResponse.json({ error: "family not found" }, { status: 404 }) };
  }

  const members = family.members as FamilyMember[];
  const requesterMember = members.find((m) => String(m.userId) === String(requester._id));
  if (!requesterMember || requesterMember.role !== "admin") {
    return { error: NextResponse.json({ error: "admin access required" }, { status: 403 }) };
  }

  return { requester, family, members };
}

export async function PATCH(request: NextRequest) {
  const ctx = await getFamilyContext(request);
  if ("error" in ctx) return ctx.error;

  const body = (await request.json().catch(() => null)) as
    | { targetUserId?: string; role?: "admin" | "member" }
    | null;

  const targetUserId = body?.targetUserId?.trim();
  const role = body?.role;
  if (!targetUserId || (role !== "admin" && role !== "member")) {
    return NextResponse.json({ error: "targetUserId and valid role are required" }, { status: 400 });
  }

  const targetMember = ctx.members.find((m) => String(m.userId) === targetUserId);
  if (!targetMember) {
    return NextResponse.json({ error: "target member not found" }, { status: 404 });
  }

  if (String(ctx.family.ownerUserId) === targetUserId && role !== "admin") {
    return NextResponse.json({ error: "owner must remain admin" }, { status: 409 });
  }

  targetMember.role = role;
  await ctx.family.save();

  const users = await User.find({ _id: { $in: ctx.members.map((m) => m.userId) } }).lean();
  const nameMap = new Map(users.map((u) => [String(u._id), u.name ?? "Member"]));

  return NextResponse.json(
    {
      message: "member role updated",
      members: ctx.members.map((m) => toPublicMember(m, nameMap)),
    },
    { status: 200 },
  );
}

export async function DELETE(request: NextRequest) {
  const ctx = await getFamilyContext(request);
  if ("error" in ctx) return ctx.error;

  const targetUserId = request.nextUrl.searchParams.get("targetUserId")?.trim() ?? "";
  if (!targetUserId) {
    return NextResponse.json({ error: "targetUserId is required" }, { status: 400 });
  }

  if (String(ctx.family.ownerUserId) === targetUserId) {
    return NextResponse.json({ error: "cannot remove family owner" }, { status: 409 });
  }

  if (String(ctx.requester._id) === targetUserId) {
    return NextResponse.json({ error: "admin cannot remove self" }, { status: 409 });
  }

  const before = ctx.members.length;
  ctx.family.members = ctx.members.filter((m) => String(m.userId) !== targetUserId);
  if (ctx.family.members.length === before) {
    return NextResponse.json({ error: "target member not found" }, { status: 404 });
  }

  await Promise.all([
    ctx.family.save(),
    User.findByIdAndUpdate(targetUserId, { $unset: { familyId: 1 } }),
  ]);

  const users = await User.find({ _id: { $in: (ctx.family.members as FamilyMember[]).map((m) => m.userId) } }).lean();
  const nameMap = new Map(users.map((u) => [String(u._id), u.name ?? "Member"]));

  return NextResponse.json(
    {
      message: "member removed",
      members: (ctx.family.members as FamilyMember[]).map((m) => toPublicMember(m, nameMap)),
    },
    { status: 200 },
  );
}
