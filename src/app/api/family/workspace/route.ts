import { NextRequest, NextResponse } from "next/server";

import { createSupabaseStorageClient, hasSupabaseStorageEnv } from "@/lib/supabase-server";

type CreateWorkspaceBody = {
  name: string;
  createdByUserId: string;
  inviteCode: string;
};

export async function POST(request: NextRequest) {
  if (!hasSupabaseStorageEnv()) {
    return NextResponse.json(
      { error: "Supabase storage env is missing" },
      { status: 500 },
    );
  }

  let body: CreateWorkspaceBody;
  try {
    body = (await request.json()) as CreateWorkspaceBody;
  } catch {
    return NextResponse.json({ error: "Invalid JSON payload" }, { status: 400 });
  }

  if (!body.name || !body.createdByUserId || !body.inviteCode) {
    return NextResponse.json(
      { error: "name, createdByUserId and inviteCode are required" },
      { status: 400 },
    );
  }

  const supabase = createSupabaseStorageClient();

  const { data: familyRow, error: familyError } = await supabase
    .from("families")
    .insert({
      name: body.name,
      created_by: body.createdByUserId,
      invite_code: body.inviteCode,
    })
    .select("id,name,invite_code,created_by")
    .single();

  if (familyError || !familyRow) {
    return NextResponse.json(
      { error: familyError?.message ?? "Failed to create family" },
      { status: 500 },
    );
  }

  const { error: memberError } = await supabase.from("family_members").insert({
    family_id: familyRow.id,
    user_id: body.createdByUserId,
    role: "admin",
  });

  if (memberError) {
    return NextResponse.json(
      { error: memberError.message },
      { status: 500 },
    );
  }

  return NextResponse.json(
    {
      familyId: familyRow.id,
      name: familyRow.name,
      inviteCode: familyRow.invite_code,
      createdBy: familyRow.created_by,
    },
    { status: 201 },
  );
}
