"use client";

import { FormEvent, useCallback, useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";

type User = { id: string; email: string; name: string; familyId: string | null };

type FullTransaction = {
  _id: string;
  userId: string;
  userName: string;
  userEmail: string;
  amount: number;
  type: "debit" | "credit";
  category: string;
  merchant: string | null;
  source: string;
  txnTime: string;
};

type CaSchedule = {
  caEmail: string;
  dayOfMonth: number;
  includeAudit: boolean;
  active: boolean;
  lastRunMonth: string | null;
  lastGeneratedAt: string | null;
};

type GeneratedCaPack = {
  token: string;
  year: number;
  month: number;
  includeAudit: boolean;
  expiresAt: string;
  packPageUrl: string;
  csvUrl: string;
  pdfUrl: string;
  mailTo: string;
};

type Summary = {
  currentUserId: string;
  isCurrentUserAdmin: boolean;
  familyId: string;
  ownerUserId: string;
  familyName: string;
  inviteCode: string;
  members: Array<{ userId: string; name: string; email: string; role: "admin" | "member" }>;
  recentAudit: Array<{
    id: string;
    action:
      | "member_role_changed"
      | "member_removed"
      | "plan_changed"
      | "invoice_exported"
      | "audit_exported"
      | "transaction_report_exported"
      | "ca_pack_generated"
      | "ca_pack_schedule_updated"
      | "family_created"
      | "family_joined";
    actorUserId: string;
    actorName: string;
    targetUserId: string | null;
    targetName: string | null;
    metadata: Record<string, unknown>;
    createdAt: string;
  }>;
  auditPagination: {
    page: number;
    pageSize: number;
    totalRecords: number;
    totalPages: number;
    hasPrev: boolean;
    hasNext: boolean;
  };
  auditFilters: {
    action: string;
    actorId: string;
    from: string;
    to: string;
  };
  selectedYear: number;
  selectedMonth: number;
  availableYears: number[];
  totalMonthlySpend: number;
  memberBreakdown: Array<{ userId: string; name: string; role: string; monthlySpend: number }>;
  topCategories: Array<{ category: string; amount: number }>;
  monthlyTimeline: Array<{ month: number; label: string; amount: number }>;
  yearlyTotals: Array<{ year: number; amount: number }>;
  memberTransactionStats: Array<{
    userId: string;
    userName: string;
    totalSpend: number;
    transactionCount: number;
  }>;
  selectedMemberId: string;
  billing: {
    planId: string;
    planName: string;
    status: string;
    monthlyPriceInr: number;
    maxMembers: number;
    membersUsed: number;
    membersRemaining: number;
    trial: {
      trialEndsAt: string;
      trialDaysLeft: number;
      nextBillingAt: string;
    };
    usage: {
      used: number;
      monthlyTxnLimit: number;
      remaining: number;
      periodStart: string;
      periodEnd: string;
    };
    timeline: Array<{
      at: string;
      kind: "created" | "plan_changed" | "renewed";
      fromPlanId: string | null;
      toPlanId: string;
      amountInr: number;
      note?: string;
    }>;
  };
  pagination: {
    page: number;
    pageSize: number;
    totalTransactions: number;
    totalPages: number;
    hasPrev: boolean;
    hasNext: boolean;
  };
  recentTransactions: Array<{
    id: string;
    userId: string;
    userName: string;
    amount: number;
    type: "debit" | "credit";
    category: string;
    merchant: string | null;
    source: string;
    txnTime: string;
  }>;
};

export default function FamilyPage() {
  const router = useRouter();
  const [user, setUser] = useState<User | null>(null);
  const [summary, setSummary] = useState<Summary | null>(null);
  const [familyName, setFamilyName] = useState("My Family");
  const [inviteCode, setInviteCode] = useState("");
  const [amount, setAmount] = useState("0");
  const [category, setCategory] = useState("General");
  const [selectedYear, setSelectedYear] = useState(() => new Date().getFullYear());
  const [selectedMonth, setSelectedMonth] = useState(() => new Date().getMonth() + 1);
  const [selectedMemberId, setSelectedMemberId] = useState("all");
  const [page, setPage] = useState(1);
  const [auditPage, setAuditPage] = useState(1);
  const [auditAction, setAuditAction] = useState("all");
  const [auditActorId, setAuditActorId] = useState("all");
  const [auditFrom, setAuditFrom] = useState("");
  const [auditTo, setAuditTo] = useState("");
  const [fullTxns, setFullTxns] = useState<FullTransaction[]>([]);
  const [fullTxPage, setFullTxPage] = useState(1);
  const [fullTxType, setFullTxType] = useState("all");
  const [fullTxMemberId, setFullTxMemberId] = useState("all");
  const [fullTxCategory, setFullTxCategory] = useState("all");
  const [fullTxYear, setFullTxYear] = useState(String(new Date().getFullYear()));
  const [fullTxMonth, setFullTxMonth] = useState(String(new Date().getMonth() + 1));
  const [fullTxFrom, setFullTxFrom] = useState("");
  const [fullTxTo, setFullTxTo] = useState("");
  const [fullTxPagination, setFullTxPagination] = useState({
    page: 1,
    pageSize: 20,
    totalTransactions: 0,
    totalPages: 1,
    hasPrev: false,
    hasNext: false,
  });
  const [caSchedule, setCaSchedule] = useState<CaSchedule>({
    caEmail: "",
    dayOfMonth: 5,
    includeAudit: true,
    active: true,
    lastRunMonth: null,
    lastGeneratedAt: null,
  });
  const [generatedCaPack, setGeneratedCaPack] = useState<GeneratedCaPack | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const money = useMemo(
    () =>
      new Intl.NumberFormat("en-IN", {
        style: "currency",
        currency: "INR",
        maximumFractionDigits: 0,
      }),
    [],
  );

  const hasFamily = useMemo(() => Boolean(user?.familyId), [user?.familyId]);
  const monthTitle = useMemo(
    () => new Date(selectedYear, selectedMonth - 1, 1).toLocaleString("en-US", { month: "long" }),
    [selectedYear, selectedMonth],
  );

  const analytics = useMemo(() => {
    const memberBreakdown = summary?.memberBreakdown ?? [];
    const topCategories = summary?.topCategories ?? [];
    const monthlyTimeline = summary?.monthlyTimeline ?? [];
    const yearlyTotals = summary?.yearlyTotals ?? [];

    const maxMemberSpend = Math.max(1, ...memberBreakdown.map((m) => m.monthlySpend));
    const maxCategorySpend = Math.max(1, ...topCategories.map((c) => c.amount));
    const maxMonthSpend = Math.max(1, ...monthlyTimeline.map((m) => m.amount));
    const maxYearSpend = Math.max(1, ...yearlyTotals.map((y) => y.amount));

    const totalYearSpend = monthlyTimeline.reduce((sum, m) => sum + m.amount, 0);
    const activeMonths = monthlyTimeline.filter((m) => m.amount > 0).length || 1;
    const avgMonthlySpend = totalYearSpend / activeMonths;

    const daysInMonth = new Date(selectedYear, selectedMonth, 0).getDate();
    const observedDays = Math.max(1, new Date().getDate());
    const totalMonthlySpend = summary?.totalMonthlySpend ?? 0;
    const projectedMonthEnd = (totalMonthlySpend / observedDays) * daysInMonth;

    const topSpender =
      memberBreakdown.length > 0
        ? [...memberBreakdown].sort((a, b) => b.monthlySpend - a.monthlySpend)[0]
        : null;

    return {
      maxMemberSpend,
      maxCategorySpend,
      maxMonthSpend,
      maxYearSpend,
      avgMonthlySpend,
      projectedMonthEnd,
      topSpender,
    };
  }, [selectedMonth, selectedYear, summary]);

  const fetchMe = useCallback(async () => {
    const res = await fetch("/api/auth/me", { cache: "no-store" });
    const data = await res.json();
    if (!data.user) {
      router.replace("/auth");
      return null;
    }
    setUser(data.user);
    return data.user as User;
  }, [router]);

  const fetchSummary = useCallback(async () => {
    const params = new URLSearchParams({
      year: String(selectedYear),
      month: String(selectedMonth),
      memberId: selectedMemberId,
      page: String(page),
      pageSize: "10",
      auditAction,
      auditActorId,
      auditFrom,
      auditTo,
      auditPage: String(auditPage),
      auditPageSize: "10",
    });

    const res = await fetch(`/api/family/summary?${params.toString()}`, { cache: "no-store" });
    if (!res.ok) {
      setSummary(null);
      return;
    }

    const data = await res.json().catch(() => ({}));
    const normalized: Summary = {
      familyId: String(data.familyId ?? ""),
      ownerUserId: String(data.ownerUserId ?? ""),
      currentUserId: String(data.currentUserId ?? ""),
      isCurrentUserAdmin: Boolean(data.isCurrentUserAdmin),
      familyName: String(data.familyName ?? "Family"),
      inviteCode: String(data.inviteCode ?? "-"),
      members: Array.isArray(data.members)
        ? data.members.map((member: { userId?: unknown; name?: unknown; email?: unknown; role?: unknown }) => ({
            userId: String(member.userId ?? ""),
            name: String(member.name ?? "Member"),
            email: String(member.email ?? ""),
            role: member.role === "admin" ? "admin" : "member",
          }))
        : [],
      recentAudit: Array.isArray(data.recentAudit)
        ? data.recentAudit.map(
            (entry: {
              id?: unknown;
              action?: unknown;
              actorUserId?: unknown;
              actorName?: unknown;
              targetUserId?: unknown;
              targetName?: unknown;
              metadata?: unknown;
              createdAt?: unknown;
            }) => ({
              id: String(entry.id ?? ""),
              action: (String(entry.action ?? "family_joined") as Summary["recentAudit"][number]["action"]),
              actorUserId: String(entry.actorUserId ?? ""),
              actorName: String(entry.actorName ?? "Unknown"),
              targetUserId: entry.targetUserId ? String(entry.targetUserId) : null,
              targetName: entry.targetName ? String(entry.targetName) : null,
              metadata:
                entry.metadata && typeof entry.metadata === "object"
                  ? (entry.metadata as Record<string, unknown>)
                  : {},
              createdAt: String(entry.createdAt ?? ""),
            }),
          )
        : [],
      auditPagination:
        data.auditPagination && typeof data.auditPagination === "object"
          ? {
              page: Number(data.auditPagination.page ?? 1),
              pageSize: Number(data.auditPagination.pageSize ?? 10),
              totalRecords: Number(data.auditPagination.totalRecords ?? 0),
              totalPages: Number(data.auditPagination.totalPages ?? 1),
              hasPrev: Boolean(data.auditPagination.hasPrev),
              hasNext: Boolean(data.auditPagination.hasNext),
            }
          : {
              page: 1,
              pageSize: 10,
              totalRecords: 0,
              totalPages: 1,
              hasPrev: false,
              hasNext: false,
            },
      auditFilters:
        data.auditFilters && typeof data.auditFilters === "object"
          ? {
              action: String(data.auditFilters.action ?? "all"),
              actorId: String(data.auditFilters.actorId ?? "all"),
              from: String(data.auditFilters.from ?? ""),
              to: String(data.auditFilters.to ?? ""),
            }
          : {
              action: "all",
              actorId: "all",
              from: "",
              to: "",
            },
      selectedYear: Number(data.selectedYear ?? selectedYear),
      selectedMonth: Number(data.selectedMonth ?? selectedMonth),
      availableYears: Array.isArray(data.availableYears) ? data.availableYears : [selectedYear],
      totalMonthlySpend: Number(data.totalMonthlySpend ?? 0),
      memberBreakdown: Array.isArray(data.memberBreakdown) ? data.memberBreakdown : [],
      topCategories: Array.isArray(data.topCategories) ? data.topCategories : [],
      monthlyTimeline: Array.isArray(data.monthlyTimeline) ? data.monthlyTimeline : [],
      yearlyTotals: Array.isArray(data.yearlyTotals) ? data.yearlyTotals : [],
      memberTransactionStats: Array.isArray(data.memberTransactionStats) ? data.memberTransactionStats : [],
      selectedMemberId: typeof data.selectedMemberId === "string" ? data.selectedMemberId : "all",
      billing:
        data.billing && typeof data.billing === "object"
          ? {
              planId: String(data.billing.planId ?? "free"),
              planName: String(data.billing.planName ?? "Free"),
              status: String(data.billing.status ?? "active"),
              monthlyPriceInr: Number(data.billing.monthlyPriceInr ?? 0),
              maxMembers: Number(data.billing.maxMembers ?? 4),
              membersUsed: Number(data.billing.membersUsed ?? 1),
              membersRemaining: Number(data.billing.membersRemaining ?? 0),
              trial:
                data.billing.trial && typeof data.billing.trial === "object"
                  ? {
                      trialEndsAt: String(data.billing.trial.trialEndsAt ?? ""),
                      trialDaysLeft: Number(data.billing.trial.trialDaysLeft ?? 0),
                      nextBillingAt: String(data.billing.trial.nextBillingAt ?? ""),
                    }
                  : {
                      trialEndsAt: "",
                      trialDaysLeft: 0,
                      nextBillingAt: "",
                    },
              usage:
                data.billing.usage && typeof data.billing.usage === "object"
                  ? {
                      used: Number(data.billing.usage.used ?? 0),
                      monthlyTxnLimit: Number(data.billing.usage.monthlyTxnLimit ?? 200),
                      remaining: Number(data.billing.usage.remaining ?? 0),
                      periodStart: String(data.billing.usage.periodStart ?? ""),
                      periodEnd: String(data.billing.usage.periodEnd ?? ""),
                    }
                  : {
                      used: 0,
                      monthlyTxnLimit: 200,
                      remaining: 200,
                      periodStart: "",
                      periodEnd: "",
                    },
              timeline: Array.isArray(data.billing.timeline) ? data.billing.timeline : [],
            }
          : {
              planId: "free",
              planName: "Free",
              status: "active",
              monthlyPriceInr: 0,
              maxMembers: 4,
              membersUsed: 1,
              membersRemaining: 3,
              trial: {
                trialEndsAt: "",
                trialDaysLeft: 0,
                nextBillingAt: "",
              },
              usage: {
                used: 0,
                monthlyTxnLimit: 200,
                remaining: 200,
                periodStart: "",
                periodEnd: "",
              },
              timeline: [],
            },
      pagination:
        data.pagination && typeof data.pagination === "object"
          ? {
              page: Number(data.pagination.page ?? 1),
              pageSize: Number(data.pagination.pageSize ?? 10),
              totalTransactions: Number(data.pagination.totalTransactions ?? 0),
              totalPages: Number(data.pagination.totalPages ?? 1),
              hasPrev: Boolean(data.pagination.hasPrev),
              hasNext: Boolean(data.pagination.hasNext),
            }
          : {
              page: 1,
              pageSize: 10,
              totalTransactions: 0,
              totalPages: 1,
              hasPrev: false,
              hasNext: false,
            },
      recentTransactions: Array.isArray(data.recentTransactions) ? data.recentTransactions : [],
    };

    setSummary(normalized);
  }, [
    page,
    selectedMemberId,
    selectedYear,
    selectedMonth,
    auditAction,
    auditActorId,
    auditFrom,
    auditTo,
    auditPage,
  ]);

  const fetchAllTransactions = useCallback(async () => {
    let rangeFrom = "";
    let rangeTo = "";
    if (fullTxYear !== "all") {
      const year = Number(fullTxYear);
      if (fullTxMonth === "all") {
        rangeFrom = `${year}-01-01`;
        rangeTo = `${year}-12-31`;
      } else {
        const month = Number(fullTxMonth);
        const start = new Date(year, month - 1, 1);
        const end = new Date(year, month, 0);
        rangeFrom = start.toISOString().slice(0, 10);
        rangeTo = end.toISOString().slice(0, 10);
      }
    }

    const params = new URLSearchParams({
      page: String(fullTxPage),
      pageSize: "20",
      type: fullTxType,
      memberId: fullTxMemberId,
      category: fullTxCategory,
      from: rangeFrom || fullTxFrom,
      to: rangeTo || fullTxTo,
    });

    const res = await fetch(`/api/transactions?${params.toString()}`, { cache: "no-store" });
    if (!res.ok) {
      return;
    }

    const data = await res.json().catch(() => ({}));
    const rows = Array.isArray(data.transactions)
      ? data.transactions.map((txn: Record<string, unknown>) => ({
          _id: String(txn._id ?? ""),
          userId: String(txn.userId ?? ""),
          userName: String(txn.userName ?? "Member"),
          userEmail: String(txn.userEmail ?? ""),
          amount: Number(txn.amount ?? 0),
          type: txn.type === "credit" ? "credit" : "debit",
          category: String(txn.category ?? "Uncategorized"),
          merchant: txn.merchant ? String(txn.merchant) : null,
          source: String(txn.source ?? "manual"),
          txnTime: String(txn.txnTime ?? ""),
        }))
      : [];
    setFullTxns(rows);
    setFullTxPagination({
      page: Number(data.pagination?.page ?? 1),
      pageSize: Number(data.pagination?.pageSize ?? 20),
      totalTransactions: Number(data.pagination?.totalTransactions ?? 0),
      totalPages: Number(data.pagination?.totalPages ?? 1),
      hasPrev: Boolean(data.pagination?.hasPrev),
      hasNext: Boolean(data.pagination?.hasNext),
    });
  }, [
    fullTxCategory,
    fullTxFrom,
    fullTxMemberId,
    fullTxMonth,
    fullTxPage,
    fullTxTo,
    fullTxType,
    fullTxYear,
  ]);

  const fetchCaSchedule = useCallback(async () => {
    const res = await fetch("/api/family/ca-pack/settings", { cache: "no-store" });
    if (!res.ok) return;
    const data = await res.json().catch(() => ({}));
    if (!data.schedule) return;
    setCaSchedule({
      caEmail: String(data.schedule.caEmail ?? ""),
      dayOfMonth: Number(data.schedule.dayOfMonth ?? 5),
      includeAudit: Boolean(data.schedule.includeAudit ?? true),
      active: Boolean(data.schedule.active ?? true),
      lastRunMonth: data.schedule.lastRunMonth ? String(data.schedule.lastRunMonth) : null,
      lastGeneratedAt: data.schedule.lastGeneratedAt ? String(data.schedule.lastGeneratedAt) : null,
    });
  }, []);

  useEffect(() => {
    let mounted = true;

    async function boot() {
      const me = await fetchMe();
      if (mounted && me?.familyId) {
        await Promise.all([fetchSummary(), fetchAllTransactions(), fetchCaSchedule()]);
      }
    }

    boot();
    const interval = setInterval(() => {
      void fetchSummary();
      void fetchAllTransactions();
      void fetchCaSchedule();
    }, 5000);
    return () => {
      mounted = false;
      clearInterval(interval);
    };
  }, [fetchAllTransactions, fetchCaSchedule, fetchMe, fetchSummary]);

  async function createFamily(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);

    const res = await fetch("/api/family/create", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name: familyName }),
    });
    const data = await res.json().catch(() => ({}));

    if (!res.ok) {
      setError(data.error ?? "could not create family");
      setBusy(false);
      return;
    }

    await fetchMe();
    await fetchSummary();
    setBusy(false);
  }

  async function joinFamily(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);

    const res = await fetch("/api/family/join", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ inviteCode }),
    });
    const data = await res.json().catch(() => ({}));

    if (!res.ok) {
      setError(data.error ?? "could not join family");
      setBusy(false);
      return;
    }

    await fetchMe();
    await fetchSummary();
    setBusy(false);
  }

  async function addTransaction(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);

    const res = await fetch("/api/transactions", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ amount: Number(amount), category, type: "debit", source: "manual" }),
    });
    const data = await res.json().catch(() => ({}));

    if (!res.ok) {
      setError(data.error ?? "could not add transaction");
      setBusy(false);
      return;
    }

    setAmount("0");
    await fetchSummary();
    await fetchAllTransactions();
    setBusy(false);
  }

  async function logout() {
    await fetch("/api/auth/logout", { method: "POST" });
    router.replace("/auth");
  }

  async function copyInviteCode() {
    if (!summary?.inviteCode) return;
    try {
      await navigator.clipboard.writeText(summary.inviteCode);
      setError(null);
    } catch {
      setError("could not copy invite code");
    }
  }

  async function upgradePlan(planId: "pro" | "family_pro") {
    const res = await fetch("/api/billing/subscribe", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ planId }),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      setError(data.error ?? "could not change plan");
      return;
    }

    if (data.requiresPayment && typeof data.checkoutUrl === "string" && data.checkoutUrl.length > 0) {
      window.location.href = data.checkoutUrl;
      return;
    }

    setError(null);
    await fetchSummary();
  }

  async function changeMemberRole(targetUserId: string, role: "admin" | "member") {
    const res = await fetch("/api/family/members", {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ targetUserId, role }),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      setError(data.error ?? "could not update member role");
      return;
    }
    setError(null);
    await fetchSummary();
  }

  async function removeMember(targetUserId: string) {
    const res = await fetch(`/api/family/members?targetUserId=${encodeURIComponent(targetUserId)}`, {
      method: "DELETE",
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      setError(data.error ?? "could not remove member");
      return;
    }
    setError(null);
    await fetchSummary();
  }

  async function exportInvoicesCsv() {
    const res = await fetch("/api/billing/invoices/export", { method: "GET" });
    if (!res.ok) {
      const data = await res.json().catch(() => ({}));
      setError(data.error ?? "could not export invoices");
      return;
    }

    const blob = await res.blob();
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement("a");
    const contentDisposition = res.headers.get("content-disposition") ?? "";
    const match = contentDisposition.match(/filename=\"?([^\"]+)\"?/i);
    anchor.href = url;
    anchor.download = match?.[1] ?? "dhanpath-billing-events.csv";
    document.body.appendChild(anchor);
    anchor.click();
    anchor.remove();
    URL.revokeObjectURL(url);
    setError(null);
  }

  async function exportFilteredAuditCsv() {
    const params = new URLSearchParams({
      auditAction,
      auditActorId,
      auditFrom,
      auditTo,
    });

    const res = await fetch(`/api/family/audit/export?${params.toString()}`, { method: "GET" });
    if (!res.ok) {
      const data = await res.json().catch(() => ({}));
      setError(data.error ?? "could not export audit events");
      return;
    }

    const blob = await res.blob();
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement("a");
    const contentDisposition = res.headers.get("content-disposition") ?? "";
    const match = contentDisposition.match(/filename=\"?([^\"]+)\"?/i);
    anchor.href = url;
    anchor.download = match?.[1] ?? "dhanpath-audit-events.csv";
    document.body.appendChild(anchor);
    anchor.click();
    anchor.remove();
    URL.revokeObjectURL(url);
    setError(null);
  }

  async function exportTransactionsReport(format: "csv" | "html") {
    let rangeFrom = "";
    let rangeTo = "";
    if (fullTxYear !== "all") {
      const year = Number(fullTxYear);
      if (fullTxMonth === "all") {
        rangeFrom = `${year}-01-01`;
        rangeTo = `${year}-12-31`;
      } else {
        const month = Number(fullTxMonth);
        const start = new Date(year, month - 1, 1);
        const end = new Date(year, month, 0);
        rangeFrom = start.toISOString().slice(0, 10);
        rangeTo = end.toISOString().slice(0, 10);
      }
    }

    const params = new URLSearchParams({
      format,
      type: fullTxType,
      memberId: fullTxMemberId,
      category: fullTxCategory,
      from: rangeFrom || fullTxFrom,
      to: rangeTo || fullTxTo,
    });

    const endpoint = `/api/family/transactions/report?${params.toString()}`;
    if (format === "html") {
      window.open(endpoint, "_blank", "noopener,noreferrer");
      return;
    }

    const res = await fetch(endpoint, { method: "GET" });
    if (!res.ok) {
      const data = await res.json().catch(() => ({}));
      setError(data.error ?? "could not export transaction report");
      return;
    }

    const blob = await res.blob();
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement("a");
    const contentDisposition = res.headers.get("content-disposition") ?? "";
    const match = contentDisposition.match(/filename=\"?([^\"]+)\"?/i);
    anchor.href = url;
    anchor.download = match?.[1] ?? "dhanpath-transactions-report.csv";
    document.body.appendChild(anchor);
    anchor.click();
    anchor.remove();
    URL.revokeObjectURL(url);
    setError(null);
  }

  async function saveCaSchedule() {
    const res = await fetch("/api/family/ca-pack/settings", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(caSchedule),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      setError(data.error ?? "could not save CA schedule");
      return;
    }
    setError(null);
    await fetchCaSchedule();
  }

  async function generateCaPack() {
    const now = new Date();
    const res = await fetch("/api/family/ca-pack/generate", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        year: now.getFullYear(),
        month: now.getMonth() + 1,
        includeAudit: caSchedule.includeAudit,
        expiresDays: 10,
      }),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      setError(data.error ?? "could not generate CA pack");
      return;
    }
    setGeneratedCaPack(data.pack as GeneratedCaPack);
    setError(null);
    await fetchSummary();
  }

  function clearAuditFilters() {
    setAuditAction("all");
    setAuditActorId("all");
    setAuditFrom("");
    setAuditTo("");
    setAuditPage(1);
  }

  const storyText = useMemo(() => {
    if (!summary) return "No data yet.";
    const topCategory = summary.topCategories[0];
    const topCatText = topCategory
      ? `${topCategory.category} led with ${money.format(topCategory.amount)}.`
      : "No major category spikes yet.";

    const topSpenderText = analytics.topSpender
      ? `${analytics.topSpender.name} contributed most at ${money.format(analytics.topSpender.monthlySpend)}.`
      : "No member trend yet.";

    return `${monthTitle} spend is ${money.format(summary.totalMonthlySpend)}. ${topCatText} ${topSpenderText}`;
  }, [analytics.topSpender, money, monthTitle, summary]);

  const suggestions = useMemo(() => {
    if (!summary) return [] as string[];
    const topCategory = summary.topCategories[0];
    const next1 = topCategory
      ? `Cap ${topCategory.category} by 10% to save about ${money.format(topCategory.amount * 0.1)} next month.`
      : "Add at least 10 transactions to unlock category optimization.";

    const next2 =
      analytics.projectedMonthEnd > summary.totalMonthlySpend
        ? `At current pace, month-end may reach ${money.format(analytics.projectedMonthEnd)}. Set a weekly review reminder.`
        : "Current pace is stable. Keep daily entries to maintain clean forecasting.";

    const next3 =
      summary.memberBreakdown.length > 1
        ? "Assign category owners per person to improve accountability and reduce overlap spending."
        : "Invite family members and enable one-tap sync to see true people-wise spend analytics.";

    return [next1, next2, next3];
  }, [analytics.projectedMonthEnd, money, summary]);

  const canManageRole = useCallback(
    (member: { userId: string; role: "admin" | "member" }) => {
      const isCurrentUser = member.userId === summary?.currentUserId;
      const isOwnerLike = member.userId === summary?.ownerUserId;
      return !isOwnerLike && !(isCurrentUser && member.role === "admin");
    },
    [summary?.currentUserId, summary?.ownerUserId],
  );

  const canRemoveMember = useCallback(
    (member: { userId: string }) => {
      const isCurrentUser = member.userId === summary?.currentUserId;
      const isOwnerLike = member.userId === summary?.ownerUserId;
      return !isCurrentUser && !isOwnerLike;
    },
    [summary?.currentUserId, summary?.ownerUserId],
  );

  const actionLabelMap: Record<Summary["recentAudit"][number]["action"], string> = {
    member_role_changed: "Role Changed",
    member_removed: "Member Removed",
    plan_changed: "Plan Changed",
    invoice_exported: "Invoice Exported",
    audit_exported: "Audit Exported",
    transaction_report_exported: "Transaction Report Exported",
    ca_pack_generated: "CA Pack Generated",
    ca_pack_schedule_updated: "CA Pack Schedule Updated",
    family_created: "Family Created",
    family_joined: "Family Joined",
  };

  return (
    <main className="shell family-shell">
      <section className="panel header-panel">
        <div>
          <h1>Family Workspace</h1>
          <p>{user ? `${user.name} (${user.email})` : "Loading user..."}</p>
        </div>
        <button className="ghost" onClick={logout} type="button">
          Logout
        </button>
      </section>

      {!hasFamily ? (
        <section className="panel stack">
          <h2>Create or Join Family</h2>

          <form className="form-grid" onSubmit={createFamily}>
            <label>
              Family Name
              <input value={familyName} onChange={(e) => setFamilyName(e.target.value)} />
            </label>
            <button className="primary" disabled={busy} type="submit">
              Create Family
            </button>
          </form>

          <form className="form-grid" onSubmit={joinFamily}>
            <label>
              Invite Code
              <input value={inviteCode} onChange={(e) => setInviteCode(e.target.value)} placeholder="ABC123" />
            </label>
            <button className="secondary" disabled={busy} type="submit">
              Join Family
            </button>
          </form>

          {error && <p className="error">{error}</p>}
        </section>
      ) : (
        <>
          <section className="panel metrics">
            <div className="metrics-top">
              <div>
                <h2>{summary?.familyName ?? "Family"}</h2>
                <p>
                  Invite Code: <strong>{summary?.inviteCode ?? "-"}</strong>
                </p>
              </div>
              <button className="ghost" type="button" onClick={copyInviteCode}>
                Copy Invite
              </button>
            </div>

            <div className="kpi-grid">
              <article className="kpi-card">
                <p>Total Spend ({monthTitle})</p>
                <h3>{money.format(summary?.totalMonthlySpend ?? 0)}</h3>
              </article>
              <article className="kpi-card">
                <p>Projected Month End</p>
                <h3>{money.format(analytics.projectedMonthEnd)}</h3>
              </article>
              <article className="kpi-card">
                <p>Avg Active Month</p>
                <h3>{money.format(analytics.avgMonthlySpend)}</h3>
              </article>
              <article className="kpi-card">
                <p>Top Spender</p>
                <h3>{analytics.topSpender?.name ?? "-"}</h3>
              </article>
            </div>

            <div className="billing-strip">
              <p>
                Plan: <strong>{summary?.billing.planName ?? "Free"}</strong> · Usage: <strong>{summary?.billing.usage.used ?? 0}</strong>
                /{summary?.billing.usage.monthlyTxnLimit ?? 0} txns this month
              </p>
              <p>
                Seats: <strong>{summary?.billing.membersUsed ?? 0}</strong>/{summary?.billing.maxMembers ?? 0} · Next billing:{" "}
                <strong>
                  {summary?.billing.trial.nextBillingAt
                    ? new Date(summary.billing.trial.nextBillingAt).toLocaleDateString()
                    : "-"}
                </strong>
                {summary?.billing.status === "trialing" ? ` · Trial ${summary.billing.trial.trialDaysLeft} days left` : ""}
              </p>
              <div className="billing-actions">
                <button className="ghost" type="button" onClick={() => upgradePlan("pro")}>Upgrade to Pro</button>
                <button className="ghost" type="button" onClick={() => upgradePlan("family_pro")}>Upgrade to Family Pro</button>
                <button className="ghost" type="button" onClick={exportInvoicesCsv}>Export Invoices CSV</button>
              </div>
            </div>
          </section>

          {summary?.isCurrentUserAdmin ? (
            <section className="panel">
              <h3>Member Access Control</h3>
              <ul className="list member-admin-list">
                {(summary?.members ?? []).map((member) => {
                  return (
                    <li key={member.userId}>
                      <div className="list-main">
                        <span>
                          {member.name} ({member.email})
                        </span>
                        <small>Role: {member.role}</small>
                      </div>
                      <div className="member-actions">
                        <small className="chip admin-only">Admin Only</small>
                        <button
                          type="button"
                          className="ghost"
                          disabled={!canManageRole(member)}
                          onClick={() => changeMemberRole(member.userId, member.role === "admin" ? "member" : "admin")}
                        >
                          {member.role === "admin" ? "Make Member" : "Make Admin"}
                        </button>
                        <button
                          type="button"
                          className="ghost"
                          disabled={!canRemoveMember(member)}
                          onClick={() => removeMember(member.userId)}
                        >
                          Remove
                        </button>
                      </div>
                    </li>
                  );
                })}
              </ul>
            </section>
          ) : null}

          <section className="panel filter-panel">
            <div className="filter-row">
              <label>
                Year
                <select
                  value={selectedYear}
                  onChange={(e) => {
                    setSelectedYear(Number(e.target.value));
                    setPage(1);
                  }}
                >
                  {(summary?.availableYears ?? [selectedYear]).map((year) => (
                    <option key={year} value={year}>
                      {year}
                    </option>
                  ))}
                </select>
              </label>
              <label>
                Month
                <select
                  value={selectedMonth}
                  onChange={(e) => {
                    setSelectedMonth(Number(e.target.value));
                    setPage(1);
                  }}
                >
                  {Array.from({ length: 12 }, (_, idx) => (
                    <option key={idx + 1} value={idx + 1}>
                      {new Date(2026, idx, 1).toLocaleString("en-US", { month: "long" })}
                    </option>
                  ))}
                </select>
              </label>
            </div>
          </section>

          <section className="panel stack">
            <h3>Add Manual Transaction</h3>
            <form className="inline-form" onSubmit={addTransaction}>
              <input
                type="number"
                step="0.01"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                placeholder="Amount"
              />
              <input value={category} onChange={(e) => setCategory(e.target.value)} placeholder="Category" />
              <button className="primary" disabled={busy} type="submit">
                Add
              </button>
            </form>
            {error && <p className="error">{error}</p>}
          </section>

          <section className="panel grid-two">
            <div>
              <h3>People-wise Payment Split</h3>
              <ul className="list">
                {(summary?.memberBreakdown ?? []).map((m) => (
                  <li key={m.userId}>
                    <div className="list-main">
                      <span>
                        {m.name} <small>({m.role})</small>
                      </span>
                      <div className="bar-track">
                        <div
                          className="bar-fill people"
                          style={{ width: `${Math.max(6, (m.monthlySpend / analytics.maxMemberSpend) * 100)}%` }}
                        />
                      </div>
                    </div>
                    <strong>{money.format(m.monthlySpend)}</strong>
                  </li>
                ))}
              </ul>
            </div>

            <div>
              <h3>Top Categories ({monthTitle})</h3>
              <ul className="list">
                {(summary?.topCategories ?? []).map((c) => (
                  <li key={c.category}>
                    <div className="list-main">
                      <span>{c.category}</span>
                      <div className="bar-track">
                        <div
                          className="bar-fill category"
                          style={{ width: `${Math.max(8, (c.amount / analytics.maxCategorySpend) * 100)}%` }}
                        />
                      </div>
                    </div>
                    <strong>{money.format(c.amount)}</strong>
                  </li>
                ))}
              </ul>
            </div>
          </section>

          <section className="panel">
            <h3>Member Totals ({monthTitle})</h3>
            <div className="member-pills">
              <button
                type="button"
                className={selectedMemberId === "all" ? "pill active" : "pill"}
                onClick={() => {
                  setSelectedMemberId("all");
                  setPage(1);
                }}
              >
                All Members
              </button>
              {(summary?.memberTransactionStats ?? []).map((member) => (
                <button
                  key={member.userId}
                  type="button"
                  className={selectedMemberId === member.userId ? "pill active" : "pill"}
                  onClick={() => {
                    setSelectedMemberId(member.userId);
                    setPage(1);
                  }}
                >
                  {member.userName}
                </button>
              ))}
            </div>

            <ul className="list">
              {(summary?.memberTransactionStats ?? []).map((member) => (
                <li key={member.userId}>
                  <div className="list-main">
                    <span>{member.userName}</span>
                    <small>{member.transactionCount} transactions</small>
                  </div>
                  <strong>{money.format(member.totalSpend)}</strong>
                </li>
              ))}
            </ul>
          </section>

          <section className="panel grid-two">
            <div>
              <h3>Month-wise Spend ({selectedYear})</h3>
              <ul className="list">
                {(summary?.monthlyTimeline ?? []).map((m) => (
                  <li key={m.month}>
                    <div className="list-main">
                      <span>{m.label}</span>
                      <div className="bar-track">
                        <div
                          className="bar-fill trend"
                          style={{ width: `${Math.max(4, (m.amount / analytics.maxMonthSpend) * 100)}%` }}
                        />
                      </div>
                    </div>
                    <strong>{money.format(m.amount)}</strong>
                  </li>
                ))}
              </ul>
            </div>

            <div>
              <h3>Year-wise Spend</h3>
              <ul className="list">
                {(summary?.yearlyTotals ?? []).map((y) => (
                  <li key={y.year}>
                    <div className="list-main">
                      <span>{y.year}</span>
                      <div className="bar-track">
                        <div
                          className="bar-fill year"
                          style={{ width: `${Math.max(8, (y.amount / analytics.maxYearSpend) * 100)}%` }}
                        />
                      </div>
                    </div>
                    <strong>{money.format(y.amount)}</strong>
                  </li>
                ))}
              </ul>
            </div>
          </section>

          <section className="panel story-panel">
            <h3>Spending Story and Suggestions</h3>
            <p>{storyText}</p>
            <ul className="suggest-grid">
              {suggestions.map((item) => (
                <li key={item}>{item}</li>
              ))}
            </ul>
          </section>

          <section className="panel">
            <h3>Billing Timeline</h3>
            <ul className="list">
              {(summary?.billing.timeline ?? []).map((event) => (
                <li key={`${event.kind}-${event.at}-${event.toPlanId}`}>
                  <div className="list-main">
                    <span>
                      {event.kind.replace("_", " ")} · {event.fromPlanId ? `${event.fromPlanId} -> ` : ""}{event.toPlanId}
                    </span>
                    <small>{new Date(event.at).toLocaleString()}</small>
                    {event.note ? <small>{event.note}</small> : null}
                  </div>
                  <strong>{money.format(event.amountInr)}</strong>
                </li>
              ))}
            </ul>
          </section>

          <section className="panel">
            <h3>Recent Access Activity</h3>
            <div className="filter-row audit-filter-row">
              <label>
                Action
                <select
                  value={auditAction}
                  onChange={(e) => {
                    setAuditAction(e.target.value);
                    setAuditPage(1);
                  }}
                >
                  <option value="all">All Actions</option>
                  <option value="member_role_changed">Role Changed</option>
                  <option value="member_removed">Member Removed</option>
                  <option value="plan_changed">Plan Changed</option>
                  <option value="invoice_exported">Invoice Exported</option>
                  <option value="audit_exported">Audit Exported</option>
                  <option value="transaction_report_exported">Transaction Report Exported</option>
                  <option value="family_created">Family Created</option>
                  <option value="family_joined">Family Joined</option>
                </select>
              </label>
              <label>
                Actor
                <select
                  value={auditActorId}
                  onChange={(e) => {
                    setAuditActorId(e.target.value);
                    setAuditPage(1);
                  }}
                >
                  <option value="all">All Members</option>
                  {(summary?.members ?? []).map((member) => (
                    <option key={member.userId} value={member.userId}>
                      {member.name}
                    </option>
                  ))}
                </select>
              </label>
              <label>
                From
                <input
                  type="date"
                  value={auditFrom}
                  onChange={(e) => {
                    setAuditFrom(e.target.value);
                    setAuditPage(1);
                  }}
                />
              </label>
              <label>
                To
                <input
                  type="date"
                  value={auditTo}
                  onChange={(e) => {
                    setAuditTo(e.target.value);
                    setAuditPage(1);
                  }}
                />
              </label>
            </div>
            <div className="audit-actions">
              <button type="button" className="ghost" onClick={clearAuditFilters}>
                Clear Filters
              </button>
              <button type="button" className="ghost" onClick={exportFilteredAuditCsv}>
                Export Filtered Audit CSV
              </button>
            </div>
            <ul className="list">
              {(summary?.recentAudit ?? []).map((entry) => (
                <li key={entry.id}>
                  <div className="list-main">
                    <span>
                      {entry.actorName}
                      {entry.targetName ? ` -> ${entry.targetName}` : ""}
                    </span>
                    <small>{new Date(entry.createdAt).toLocaleString()}</small>
                    <small className="chip neutral">{actionLabelMap[entry.action] ?? entry.action}</small>
                  </div>
                  <strong>{entry.actorUserId === summary?.currentUserId ? "You" : "Member"}</strong>
                </li>
              ))}
            </ul>
            <div className="pager">
              <button
                type="button"
                className="ghost"
                disabled={!summary?.auditPagination?.hasPrev}
                onClick={() => setAuditPage((prev) => Math.max(1, prev - 1))}
              >
                Previous
              </button>
              <span>
                Page {summary?.auditPagination?.page ?? 1} of {summary?.auditPagination?.totalPages ?? 1} · Total {summary?.auditPagination?.totalRecords ?? 0}
              </span>
              <button
                type="button"
                className="ghost"
                disabled={!summary?.auditPagination?.hasNext}
                onClick={() => setAuditPage((prev) => prev + 1)}
              >
                Next
              </button>
            </div>
          </section>

          <section className="panel">
            <h3>Transactions</h3>
            <div className="filter-row audit-filter-row">
              <label>
                Year
                <select
                  value={fullTxYear}
                  onChange={(e) => {
                    setFullTxYear(e.target.value);
                    setFullTxPage(1);
                  }}
                >
                  <option value="all">All Years</option>
                  {(summary?.availableYears ?? [selectedYear]).map((year) => (
                    <option key={year} value={String(year)}>
                      {year}
                    </option>
                  ))}
                </select>
              </label>
              <label>
                Month
                <select
                  value={fullTxMonth}
                  onChange={(e) => {
                    setFullTxMonth(e.target.value);
                    setFullTxPage(1);
                  }}
                >
                  <option value="all">All Months</option>
                  {Array.from({ length: 12 }, (_, idx) => (
                    <option key={idx + 1} value={String(idx + 1)}>
                      {new Date(2026, idx, 1).toLocaleString("en-US", { month: "long" })}
                    </option>
                  ))}
                </select>
              </label>
              <label>
                Member
                <select
                  value={fullTxMemberId}
                  onChange={(e) => {
                    setFullTxMemberId(e.target.value);
                    setFullTxPage(1);
                  }}
                >
                  <option value="all">All Members</option>
                  {(summary?.members ?? []).map((member) => (
                    <option key={member.userId} value={member.userId}>
                      {member.name}
                    </option>
                  ))}
                </select>
              </label>
              <label>
                Type
                <select
                  value={fullTxType}
                  onChange={(e) => {
                    setFullTxType(e.target.value);
                    setFullTxPage(1);
                  }}
                >
                  <option value="all">All Types</option>
                  <option value="debit">Debit</option>
                  <option value="credit">Credit</option>
                </select>
              </label>
              <label>
                Category
                <input
                  value={fullTxCategory === "all" ? "" : fullTxCategory}
                  placeholder="All categories"
                  onChange={(e) => {
                    const value = e.target.value.trim();
                    setFullTxCategory(value.length > 0 ? value : "all");
                    setFullTxPage(1);
                  }}
                />
              </label>
            </div>
            <div className="audit-actions">
              <button
                type="button"
                className="ghost"
                onClick={() => {
                  setFullTxMemberId("all");
                  setFullTxType("all");
                  setFullTxCategory("all");
                  setFullTxYear(String(new Date().getFullYear()));
                  setFullTxMonth(String(new Date().getMonth() + 1));
                  setFullTxFrom("");
                  setFullTxTo("");
                  setFullTxPage(1);
                }}
              >
                Clear Transaction Filters
              </button>
              <button type="button" className="ghost" onClick={() => exportTransactionsReport("csv")}>Export CSV for CA</button>
              <button type="button" className="ghost" onClick={() => exportTransactionsReport("html")}>Open PDF View for CA</button>
            </div>

            <ul className="list txn-list">
              {fullTxns.map((txn) => (
                <li key={txn._id}>
                  <div className="list-main">
                    <span>
                      {txn.userName} · {txn.category} · {txn.merchant ?? "Unknown merchant"}
                    </span>
                    <small>{new Date(txn.txnTime).toLocaleString()}</small>
                    <small className={`chip ${txn.type === "credit" ? "credit" : "debit"}`}>
                      {txn.type.toUpperCase()} · {txn.source}
                    </small>
                  </div>
                  <strong>{money.format(txn.amount)}</strong>
                </li>
              ))}
            </ul>

            <div className="pager">
              <button
                type="button"
                className="ghost"
                disabled={!fullTxPagination.hasPrev}
                onClick={() => setFullTxPage((prev) => Math.max(1, prev - 1))}
              >
                Previous
              </button>
              <span>
                Page {fullTxPagination.page} of {fullTxPagination.totalPages} · Total {fullTxPagination.totalTransactions}
              </span>
              <button
                type="button"
                className="ghost"
                disabled={!fullTxPagination.hasNext}
                onClick={() => setFullTxPage((prev) => prev + 1)}
              >
                Next
              </button>
            </div>
          </section>

          <section className="panel">
            <h3>Scheduled CA Pack</h3>
            <div className="filter-row audit-filter-row">
              <label>
                CA Email
                <input
                  type="email"
                  value={caSchedule.caEmail}
                  onChange={(e) => setCaSchedule((prev) => ({ ...prev, caEmail: e.target.value }))}
                  placeholder="ca@example.com"
                />
              </label>
              <label>
                Day Of Month
                <input
                  type="number"
                  min={1}
                  max={28}
                  value={caSchedule.dayOfMonth}
                  onChange={(e) =>
                    setCaSchedule((prev) => ({
                      ...prev,
                      dayOfMonth: Math.max(1, Math.min(28, Number(e.target.value) || 1)),
                    }))
                  }
                />
              </label>
              <label>
                Include Audit Activity
                <select
                  value={caSchedule.includeAudit ? "yes" : "no"}
                  onChange={(e) => setCaSchedule((prev) => ({ ...prev, includeAudit: e.target.value === "yes" }))}
                >
                  <option value="yes">Yes</option>
                  <option value="no">No</option>
                </select>
              </label>
              <label>
                Schedule Status
                <select
                  value={caSchedule.active ? "active" : "paused"}
                  onChange={(e) => setCaSchedule((prev) => ({ ...prev, active: e.target.value === "active" }))}
                >
                  <option value="active">Active</option>
                  <option value="paused">Paused</option>
                </select>
              </label>
            </div>
            <div className="audit-actions">
              <button type="button" className="ghost" onClick={saveCaSchedule}>Save CA Schedule</button>
              <button type="button" className="ghost" onClick={generateCaPack}>Generate This Month Pack</button>
            </div>
            <p>
              Last Run Month: <strong>{caSchedule.lastRunMonth ?? "-"}</strong> · Last Generated:{" "}
              <strong>{caSchedule.lastGeneratedAt ? new Date(caSchedule.lastGeneratedAt).toLocaleString() : "-"}</strong>
            </p>

            {generatedCaPack ? (
              <div className="ca-pack-links">
                <p>
                  Generated Pack: <strong>{generatedCaPack.year}-{String(generatedCaPack.month).padStart(2, "0")}</strong> · Expires:{" "}
                  <strong>{new Date(generatedCaPack.expiresAt).toLocaleString()}</strong>
                </p>
                <div className="audit-actions">
                  <a className="ghost link-btn" href={generatedCaPack.packPageUrl} target="_blank" rel="noreferrer">Open Share Page</a>
                  <a className="ghost link-btn" href={generatedCaPack.csvUrl} target="_blank" rel="noreferrer">Download CSV</a>
                  <a className="ghost link-btn" href={generatedCaPack.pdfUrl} target="_blank" rel="noreferrer">Open PDF View</a>
                  {generatedCaPack.mailTo ? (
                    <a className="ghost link-btn" href={generatedCaPack.mailTo}>Email To CA</a>
                  ) : null}
                </div>
              </div>
            ) : null}
          </section>
        </>
      )}
    </main>
  );
}
