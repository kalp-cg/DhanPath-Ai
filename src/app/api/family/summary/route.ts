import { NextRequest, NextResponse } from "next/server";

import { mockFamilySummary } from "@/lib/mock-family";
import { hasSupabaseStorageEnv } from "@/lib/supabase-server";
import { fetchFamilySummaryFromStorage } from "@/server/family-summary-service";

export async function GET(request: NextRequest) {
  const familyId =
    request.nextUrl.searchParams.get("familyId") ??
    process.env.NEXT_PUBLIC_FAMILY_ID ??
    mockFamilySummary.familyId;

  if (!hasSupabaseStorageEnv()) {
    return NextResponse.json({ ...mockFamilySummary, familyId, source: "mock" });
  }

  try {
    const result = await fetchFamilySummaryFromStorage(familyId);
    return NextResponse.json(result, { status: 200 });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown backend failure";
    return NextResponse.json(
      {
        ...mockFamilySummary,
        familyId,
        source: "mock",
        backendError: message,
      },
      { status: 200 },
    );
  }
}
