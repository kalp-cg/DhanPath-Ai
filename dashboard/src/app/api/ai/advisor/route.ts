import { NextRequest, NextResponse } from "next/server";

import { getAuthUserFromRequest } from "@/lib/auth";
import { connectToMongo } from "@/lib/mongodb";
import { Transaction } from "@/models/Transaction";
import { AiAdvice } from "@/models/AiAdvice";
import { getOrCreateSubscription } from "@/server/billing-service";
import { resolveFamilyAccess } from "@/server/family-access";

function countAiAdvice(filter: Record<string, unknown>) {
  return AiAdvice.countDocuments(filter as never);
}

function findAiAdvice(filter: Record<string, unknown>) {
  return AiAdvice.find(filter as never);
}

function createAiAdvice(doc: Record<string, unknown>) {
  return AiAdvice.create(doc as never);
}

function updateAiAdvice(
  filter: Record<string, unknown>,
  update: Record<string, unknown>,
) {
  return AiAdvice.findOneAndUpdate(filter as never, update as never, { new: true }).lean();
}

const FALLBACK_MODELS = ["llama-3.3-70b-versatile", "llama-3.1-8b-instant"];
const QUOTA_BY_PLAN: Record<string, number> = {
  free: 1,
  pro: 5,
  family_pro: 10,
};

type TransactionLean = {
  userId: unknown;
  amount: number;
  type: "debit" | "credit";
  category: string;
  txnTime: Date;
};

function parsePositiveInt(value: string | null, fallback: number) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) return fallback;
  return Math.floor(parsed);
}

function parsePrompt(prompt: string, chatName?: string) {
  const normalized = `${chatName ?? ""} ${prompt}`.replace(/,/g, " ");

  const monthsMatch = normalized.match(/(\d+(?:\.\d+)?)\s*(month|months|mo)\b/i);
  const yearsMatch = normalized.match(/(\d+(?:\.\d+)?)\s*(year|years|yr|yrs)\b/i);
  const targetMonths = monthsMatch
    ? Math.max(1, Math.round(Number(monthsMatch[1])))
    : yearsMatch
      ? Math.max(1, Math.round(Number(yearsMatch[1]) * 12))
      : 3;

  const valueRegex = /(₹|rs\.?|inr)?\s*(\d+(?:\.\d+)?)\s*(k|thousand|lakh|lac|crore|cr)?/gi;
  let best = 0;
  for (const match of normalized.matchAll(valueRegex)) {
    const raw = Number(match[2] ?? 0);
    const unit = String(match[3] ?? "").toLowerCase();
    let multiplier = 1;
    if (unit === "k" || unit === "thousand") multiplier = 1_000;
    if (unit === "lakh" || unit === "lac") multiplier = 100_000;
    if (unit === "crore" || unit === "cr") multiplier = 10_000_000;
    const value = raw * multiplier;
    if (value > best) {
      best = value;
    }
  }

  if (best <= 0) {
    const plainNums = Array.from(normalized.matchAll(/\d+(?:\.\d+)?/g)).map((m) => Number(m[0]));
    best = plainNums.filter((n) => n >= 100).sort((a, b) => b - a)[0] ?? 0;
  }

  return {
    targetAmount: Math.round(best),
    targetMonths,
  };
}

async function callGroq(params: {
  prompt: string;
  targetAmount: number;
  targetMonths: number;
  monthlyIncome: number;
  monthlyExpense: number;
  avgMonthlyExpense3M: number;
  topCategories: Array<{ category: string; amount: number }>;
  memberInsights: Array<{ userId: string; name: string; spend: number; note: string }>;
  feasible: boolean;
  requiredMonthlySave: number;
}) {
  const apiKey = process.env.GROQ_API_KEY?.trim();
  if (!apiKey) {
    throw new Error("Missing GROQ_API_KEY");
  }

  const system = [
    "You are a personal finance advisor for family spending.",
    "Use only provided transaction facts.",
    "If goal is unrealistic, include exactly this sentence:",
    "Based on your current transaction history, I think this is not feasible right now. You should increase your income first.",
    "Return strict JSON with keys:",
    "summary (string), feasible (boolean), suggestedMonthlySave (number), suggestedMonthlySpendCap (number), recommendations (string[]), memberInsights (array of {name:string, spend:number, note:string}).",
    "Keep recommendations practical and specific.",
  ].join(" ");

  const user = JSON.stringify({
    userPrompt: params.prompt,
    targetAmount: params.targetAmount,
    targetMonths: params.targetMonths,
    monthlyIncome: params.monthlyIncome,
    monthlyExpense: params.monthlyExpense,
    avgMonthlyExpense3M: params.avgMonthlyExpense3M,
    requiredMonthlySave: params.requiredMonthlySave,
    feasible: params.feasible,
    topCategories: params.topCategories,
    memberInsights: params.memberInsights,
  });

  const preferredModel = process.env.GROQ_MODEL?.trim();
  const modelCandidates = [preferredModel, ...FALLBACK_MODELS].filter(
    (value, index, arr): value is string => Boolean(value) && arr.indexOf(value) === index,
  );

  let data: {
    choices?: Array<{ message?: { content?: string } }>;
  } | null = null;
  let selectedModel = modelCandidates[0] ?? "";
  let lastError = "Unknown Groq error";

  for (const model of modelCandidates) {
    const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model,
        temperature: 0.25,
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: system },
          { role: "user", content: user },
        ],
      }),
    });

    if (res.ok) {
      data = (await res.json()) as {
        choices?: Array<{ message?: { content?: string } }>;
      };
      selectedModel = model;
      lastError = "";
      break;
    }

    const body = await res.text();
    lastError = `Groq API failed (${model}): ${res.status} ${body}`;

    const shouldTryNext =
      res.status === 400 &&
      /model_decommissioned|decommissioned|no longer supported|model_not_found/i.test(body);

    if (!shouldTryNext) {
      break;
    }
  }

  if (!data) {
    throw new Error(lastError);
  }

  const content = data.choices?.[0]?.message?.content ?? "";
  let parsed: {
    summary?: string;
    feasible?: boolean;
    suggestedMonthlySave?: number;
    suggestedMonthlySpendCap?: number;
    recommendations?: string[];
    memberInsights?: Array<{ name: string; spend: number; note: string }>;
  } = {};

  try {
    parsed = JSON.parse(content);
  } catch {
    parsed = {
      summary: "AI response could not be parsed. Please try again.",
      feasible: false,
      suggestedMonthlySave: params.requiredMonthlySave,
      suggestedMonthlySpendCap: Math.max(0, params.monthlyExpense - params.requiredMonthlySave),
      recommendations: ["Retry your request with a clearer target amount and timeline."],
      memberInsights: params.memberInsights.map((m) => ({ name: m.name, spend: m.spend, note: m.note })),
    };
  }

  return {
    ...parsed,
    model: selectedModel,
  };
}

async function getAccessAndQuota(request: NextRequest) {
  const auth = getAuthUserFromRequest(request);
  if (!auth) {
    return { error: NextResponse.json({ error: "unauthorized" }, { status: 401 }) };
  }

  await connectToMongo();

  const access = await resolveFamilyAccess(auth.userId);
  if (!access.ok) {
    return { error: NextResponse.json({ error: access.error }, { status: access.status }) };
  }

  const subscription = await getOrCreateSubscription({
    familyId: access.user.familyId as never,
    ownerUserId: access.family.ownerUserId as never,
  });

  const planId = subscription.planId;
  const limit = QUOTA_BY_PLAN[planId] ?? 1;
  const windowStart = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000);
  const used = await countAiAdvice({
    familyId: access.family._id as never,
    userId: access.user._id as never,
    createdAt: { $gte: windowStart },
  });

  return {
    authUserId: auth.userId,
    access,
    planId,
    limit,
    used,
    remaining: Math.max(0, limit - used),
  };
}

export async function GET(request: NextRequest) {
  const context = await getAccessAndQuota(request);
  if ("error" in context) return context.error;

  const url = new URL(request.url);
  const page = parsePositiveInt(url.searchParams.get("page"), 1);
  const pageSize = Math.min(50, parsePositiveInt(url.searchParams.get("pageSize"), 20));
  const skip = (page - 1) * pageSize;

  const baseFilter = {
    familyId: context.access.family._id as never,
    userId: context.access.user._id as never,
    isDeleted: { $ne: true },
  };

  const history = await findAiAdvice(baseFilter)
    .sort({ pinned: -1, createdAt: -1 })
    .skip(skip)
    .limit(pageSize)
    .lean();

  const total = await countAiAdvice(baseFilter);

  return NextResponse.json(
    {
      planId: context.planId,
      quota: {
        limit: context.limit,
        used: context.used,
        remaining: context.remaining,
      },
      history,
      pagination: {
        page,
        pageSize,
        total,
        hasMore: skip + history.length < total,
      },
    },
    { status: 200 },
  );
}

export async function POST(request: NextRequest) {
  const context = await getAccessAndQuota(request);
  if ("error" in context) return context.error;

  if (context.remaining <= 0) {
    return NextResponse.json(
      {
        error: "Chat limit reached for your plan.",
        quota: {
          limit: context.limit,
          used: context.used,
          remaining: 0,
        },
      },
      { status: 403 },
    );
  }

  const body = (await request.json().catch(() => null)) as {
    chatName?: string;
    prompt?: string;
  } | null;

  const chatName = String(body?.chatName ?? "").trim();
  if (!chatName) {
    return NextResponse.json({ error: "Chat name is required." }, { status: 400 });
  }

  const prompt = String(body?.prompt ?? "").trim();
  if (!prompt) {
    return NextResponse.json({ error: "Prompt is required." }, { status: 400 });
  }

  const now = new Date();

  const parsedPrompt = parsePrompt(prompt, chatName);
  if (!parsedPrompt.targetAmount || parsedPrompt.targetAmount <= 0) {
    return NextResponse.json(
      {
        error: "Please enter a valid amount in your request or chat name (example: I want to buy a phone worth 50000 in 4 months, or 50k in 4 months).",
      },
      { status: 400 },
    );
  }

  try {
    const txns = (await Transaction.find({ familyId: context.access.family._id })
      .sort({ txnTime: -1 })
      .limit(5000)
      .lean()) as TransactionLean[];

    const windowStart = new Date(now.getTime() - 90 * 24 * 60 * 60 * 1000);
    const recentTxns = txns.filter((tx) => new Date(tx.txnTime) >= windowStart);

    const income3m = recentTxns
      .filter((tx) => tx.type === "credit")
      .reduce((sum, tx) => sum + Number(tx.amount ?? 0), 0);

    const expense3m = recentTxns
      .filter((tx) => tx.type === "debit")
      .reduce((sum, tx) => sum + Number(tx.amount ?? 0), 0);

    const monthlyIncome = Number((income3m / 3).toFixed(2));
    const monthlyExpense = Number((expense3m / 3).toFixed(2));
    const avgMonthlyExpense3M = monthlyExpense;

    const catMap = new Map<string, number>();
    const memberSpend3m = new Map<string, number>();
    for (const tx of recentTxns) {
      if (tx.type !== "debit") continue;
      const amount = Number(tx.amount ?? 0);
      catMap.set(tx.category ?? "Uncategorized", (catMap.get(tx.category ?? "Uncategorized") ?? 0) + amount);
      const uid = String(tx.userId);
      memberSpend3m.set(uid, (memberSpend3m.get(uid) ?? 0) + amount);
    }

    const topCategories = Array.from(catMap.entries())
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(([category, amount]) => ({ category, amount: Number((amount / 3).toFixed(2)) }));

    const requiredMonthlySave = Number((parsedPrompt.targetAmount / parsedPrompt.targetMonths).toFixed(2));
    const disposable = Math.max(0, monthlyIncome - monthlyExpense);
    const feasible = disposable >= requiredMonthlySave;

    const memberInsights = context.access.members
      .map((m) => {
        const spend = Number(((memberSpend3m.get(m.userId) ?? 0) / 3).toFixed(2));
        const note = spend > requiredMonthlySave
          ? "This member is currently spending above the monthly saving requirement."
          : "This member is within manageable spending range.";
        return { userId: m.userId, name: m.name, spend, note };
      })
      .sort((a, b) => b.spend - a.spend)
      .slice(0, 6);

    const ai = await callGroq({
      prompt,
      targetAmount: parsedPrompt.targetAmount,
      targetMonths: parsedPrompt.targetMonths,
      monthlyIncome,
      monthlyExpense,
      avgMonthlyExpense3M,
      topCategories,
      memberInsights,
      feasible,
      requiredMonthlySave,
    }).catch(() => ({
      summary: feasible
        ? "This goal is likely feasible if you consistently save the suggested monthly amount and keep your current spending under control."
        : "Based on your current transaction history, I think this is not feasible right now. You should increase your income first.",
      feasible,
      suggestedMonthlySave: requiredMonthlySave,
      suggestedMonthlySpendCap: Math.max(0, monthlyIncome - requiredMonthlySave),
      recommendations: [
        "Cut discretionary spending in top categories for the next 3 months.",
        "Set an auto-transfer to savings at salary credit date.",
        "Review weekly spending with family and correct overspending early.",
      ],
      memberInsights: memberInsights.map((m) => ({
        name: m.name,
        spend: m.spend,
        note: m.note,
      })),
      model: "local-heuristic-fallback",
    }));

    if (!feasible) {
      ai.summary = `Based on your current transaction history, I think this is not feasible right now. You should increase your income first. ${ai.summary ?? ""}`.trim();
      ai.feasible = false;
    }

    const suggestedMonthlySave = Number((ai.suggestedMonthlySave ?? requiredMonthlySave).toFixed(2));
    const suggestedMonthlySpendCap = Number((ai.suggestedMonthlySpendCap ?? Math.max(0, monthlyIncome - suggestedMonthlySave)).toFixed(2));

    const doc = await createAiAdvice({
      familyId: context.access.family._id as never,
      userId: context.access.user._id as never,
      chatName,
      pinned: false,
      planId: context.planId,
      model: ai.model || (process.env.GROQ_MODEL?.trim() || FALLBACK_MODELS[0]),
      prompt,
      targetAmount: parsedPrompt.targetAmount,
      targetMonths: parsedPrompt.targetMonths,
      selectedYear: now.getFullYear(),
      selectedMonth: now.getMonth() + 1,
      monthlyIncome,
      monthlyExpense,
      avgMonthlyExpense3M,
      feasible: Boolean(ai.feasible ?? feasible),
      suggestedMonthlySave,
      suggestedMonthlySpendCap,
      responseText: ai.summary ?? "No summary generated.",
      recommendations: Array.isArray(ai.recommendations) ? ai.recommendations.slice(0, 8).map(String) : [],
      memberInsights: Array.isArray(ai.memberInsights)
        ? ai.memberInsights.slice(0, 8).map((m) => ({
            userId: context.access.members.find((x) => x.name === m.name)?.userId ?? "",
            name: String(m.name ?? "Member"),
            spend: Number(m.spend ?? 0),
            note: String(m.note ?? "Monitor this member's trend."),
          }))
        : memberInsights,
    });

    return NextResponse.json(
      {
        item: doc,
        quota: {
          limit: context.limit,
          used: context.used + 1,
          remaining: Math.max(0, context.limit - (context.used + 1)),
        },
      },
      { status: 200 },
    );
  } catch (error) {
    return NextResponse.json(
      {
        error:
          error instanceof Error
            ? `AI advisor failed: ${error.message}`
            : "AI advisor failed. Please try again.",
      },
      { status: 502 },
    );
  }
}

export async function PATCH(request: NextRequest) {
  const context = await getAccessAndQuota(request);
  if ("error" in context) return context.error;

  const body = (await request.json().catch(() => null)) as {
    adviceId?: string;
    pinned?: boolean;
  } | null;

  const adviceId = String(body?.adviceId ?? "").trim();
  if (!adviceId) {
    return NextResponse.json({ error: "adviceId is required" }, { status: 400 });
  }

  const pinned = Boolean(body?.pinned);

  const updated = await updateAiAdvice(
    {
      _id: adviceId as never,
      familyId: context.access.family._id as never,
      userId: context.access.user._id as never,
      isDeleted: { $ne: true },
    },
    { $set: { pinned } },
  );

  if (!updated) {
    return NextResponse.json({ error: "Chat not found" }, { status: 404 });
  }

  return NextResponse.json({ item: updated }, { status: 200 });
}

export async function DELETE(request: NextRequest) {
  const context = await getAccessAndQuota(request);
  if ("error" in context) return context.error;

  const body = (await request.json().catch(() => null)) as {
    adviceId?: string;
  } | null;

  const adviceId = String(body?.adviceId ?? "").trim();
  if (!adviceId) {
    return NextResponse.json({ error: "adviceId is required" }, { status: 400 });
  }

  const updated = await updateAiAdvice(
    {
      _id: adviceId as never,
      familyId: context.access.family._id as never,
      userId: context.access.user._id as never,
      isDeleted: { $ne: true },
    },
    { $set: { isDeleted: true, deletedAt: new Date(), pinned: false } },
  );

  if (!updated) {
    return NextResponse.json({ error: "Chat not found" }, { status: 404 });
  }

  return NextResponse.json({ ok: true }, { status: 200 });
}
