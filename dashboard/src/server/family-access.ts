import { Types } from "mongoose";

import { Family } from "@/models/Family";
import { User } from "@/models/User";

export type ResolvedFamilyMember = {
  userId: string;
  email: string;
  name: string;
  role: "admin" | "member";
};

type UserLean = {
  _id: unknown;
  email?: string;
  name?: string;
  familyId?: unknown;
};

type FamilyMemberLean = {
  userId: unknown;
  email: string;
  role: string;
};

type AccessError = {
  ok: false;
  status: 401 | 404;
  error: string;
};

type AccessOk = {
  ok: true;
  user: UserLean;
  family: {
    _id: unknown;
    ownerUserId: unknown;
    members: FamilyMemberLean[];
    name: string;
    inviteCode: string;
  };
  members: ResolvedFamilyMember[];
  isAdmin: boolean;
};

export type FamilyAccessResult = AccessError | AccessOk;

export async function resolveFamilyAccess(authUserId: string): Promise<FamilyAccessResult> {
  const user = (await User.findById(authUserId).lean()) as UserLean | null;
  if (!user) {
    return { ok: false, status: 401, error: "unauthorized" };
  }
  if (!user.familyId) {
    return { ok: false, status: 404, error: "no family found for user" };
  }

  const family = (await Family.findById(user.familyId).lean()) as AccessOk["family"] | null;
  if (!family) {
    return { ok: false, status: 404, error: "family not found" };
  }

  const rawMembers = (family.members ?? []) as FamilyMemberLean[];
  const familyUsers = (await User.find({
    $or: [{ familyId: family._id }, { familyId: String(family._id) }],
  }).lean()) as UserLean[];

  const userById = new Map<string, UserLean>();
  for (const familyUser of familyUsers) {
    userById.set(String(familyUser._id), familyUser);
  }

  const ownerUserId = String(family.ownerUserId);
  const currentUserId = String(user._id);

  if (!userById.has(ownerUserId)) {
    const ownerUser = (await User.findById(family.ownerUserId).lean()) as UserLean | null;
    if (ownerUser) userById.set(ownerUserId, ownerUser);
  }

  if (!userById.has(currentUserId)) {
    userById.set(currentUserId, user);
  }

  const memberMap = new Map<string, { userId: string; email: string; role: "admin" | "member" }>();

  for (const member of rawMembers) {
    const uid = String(member.userId ?? "");
    if (!uid) continue;
    memberMap.set(uid, {
      userId: uid,
      email: String(member.email ?? "").toLowerCase(),
      role: member.role === "admin" ? "admin" : "member",
    });
  }

  for (const [uid, profile] of userById.entries()) {
    const existing = memberMap.get(uid);
    memberMap.set(uid, {
      userId: uid,
      email: String(profile.email ?? existing?.email ?? "").toLowerCase(),
      role: uid === ownerUserId ? "admin" : (existing?.role ?? "member"),
    });
  }

  if (memberMap.has(ownerUserId)) {
    const owner = memberMap.get(ownerUserId);
    if (owner) {
      owner.role = "admin";
      memberMap.set(ownerUserId, owner);
    }
  }

  const members = Array.from(memberMap.values()).map((member) => ({
    userId: member.userId,
    email: member.email,
    role: member.role,
    name:
      String(userById.get(member.userId)?.name ?? "").trim() ||
      (member.email.includes("@") ? member.email.split("@")[0] : "Member"),
  }));

  // Keep family.members in sync with reconciled member view to avoid future role drift.
  const shouldSyncMembers =
    rawMembers.length !== members.length ||
    rawMembers.some((member) => {
      const uid = String(member.userId ?? "");
      const normalized = memberMap.get(uid);
      if (!normalized) return true;
      return (
        normalized.role !== (member.role === "admin" ? "admin" : "member") ||
        normalized.email !== String(member.email ?? "").toLowerCase()
      );
    });

  if (shouldSyncMembers) {
    await Family.findByIdAndUpdate(family._id, {
      $set: {
        members: members.map((member) => ({
          userId: member.userId as unknown as Types.ObjectId,
          email: member.email,
          role: member.role,
        })),
      },
    });
  }

  const isAdmin = members.some((member) => member.userId === currentUserId && member.role === "admin");

  return {
    ok: true,
    user,
    family,
    members,
    isAdmin,
  };
}
