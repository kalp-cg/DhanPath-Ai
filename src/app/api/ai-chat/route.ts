import { NextRequest, NextResponse } from "next/server";

import { askGemini } from "@/lib/gemini";
import { hasSupabaseStorageEnv, createSupabaseStorageClient } from "@/lib/supabase-server";

export async function POST(request: NextRequest) {
  let body: { question: string; familyId?: string };
  try {
    body = (await request.json()) as { question: string; familyId?: string };
  } catch {
    return NextResponse.json({ error: "Invalid JSON" }, { status: 400 });
  }

  if (!body.question?.trim()) {
    return NextResponse.json({ error: "question is required" }, { status: 400 });
  }

  // Build transaction context from Supabase if available
  let contextBlock = "";

  if (hasSupabaseStorageEnv() && body.familyId) {
    try {
      const supabase = createSupabaseStorageClient();
      const now = new Date();
      const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).toISOString();

      const { data: txns } = await supabase
        .from("transactions")
        .select("amount,category,merchant,type,txn_time")
        .eq("family_id", body.familyId)
        .gte("txn_time", monthStart)
        .order("txn_time", { ascending: false })
        .limit(100);

      if (txns && txns.length > 0) {
        const totalSpent = txns
          .filter((t) => t.type === "debit")
          .reduce((s, t) => s + Number(t.amount ?? 0), 0);

        const categoryMap = new Map<string, number>();
        for (const t of txns) {
          if (t.type === "debit") {
            const cat = t.category ?? "Uncategorized";
            categoryMap.set(cat, (categoryMap.get(cat) ?? 0) + Number(t.amount ?? 0));
          }
        }

        const categoryBreakdown = Array.from(categoryMap.entries())
          .sort((a, b) => b[1] - a[1])
          .map(([c, a]) => `${c}: Rs ${a.toLocaleString("en-IN")}`)
          .join(", ");

        contextBlock = `
FAMILY TRANSACTION CONTEXT (this month):
- Total transactions: ${txns.length}
- Total spent: Rs ${totalSpent.toLocaleString("en-IN")}
- Category breakdown: ${categoryBreakdown}
- Monthly budget: Rs 40,000
- Days elapsed: ${now.getDate()}
`;
      }
    } catch (err) {
      console.error("Context fetch error:", err);
    }
  }

  const systemPrompt = `You are DhanPath AI, a friendly Indian family finance assistant. You help families understand their spending, stay within budget, and save money. Respond concisely in 2-4 sentences. Use Rs (₹) for currency. Be encouraging and practical.

${contextBlock}

User question: ${body.question}`;

  const answer = await askGemini(systemPrompt);

  return NextResponse.json({ answer });
}
