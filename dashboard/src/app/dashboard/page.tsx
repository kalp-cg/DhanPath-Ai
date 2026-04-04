"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import KPICard from "@/components/KPICard";
import EmptyState from "@/components/EmptyState";
import { SkeletonCard } from "@/components/Skeleton";

type Summary = {
  familyName: string;
  inviteCode: string;
  totalMonthlySpend: number;
  memberBreakdown: Array<{ userId: string; name: string; role: string; monthlySpend: number }>;
  topCategories: Array<{ category: string; amount: number }>;
  monthlyTimeline: Array<{ month: number; label: string; amount: number }>;
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
  billing: {
    planName: string;
    status: string;
    usage: { used: number; monthlyTxnLimit: number; remaining: number };
    trial: { trialDaysLeft: number };
    membersUsed: number;
    maxMembers: number;
  };
  members: Array<{ userId: string; name: string; email: string; role: string }>;
};

export default function OverviewPage() {
  const router = useRouter();
  const [summary, setSummary] = useState<Summary | null>(null);
  const [loading, setLoading] = useState(true);
  const [selectedMemberId, setSelectedMemberId] = useState("all");

  const money = useMemo(
    () =>
      new Intl.NumberFormat("en-IN", {
        style: "currency",
        currency: "INR",
        maximumFractionDigits: 0,
      }),
    [],
  );

  const now = new Date();
  const selectedYear = now.getFullYear();
  const selectedMonth = now.getMonth() + 1;
  const monthTitle = now.toLocaleString("en-US", { month: "long" });

  const fetchSummary = useCallback(async () => {
    const params = new URLSearchParams({
      year: String(selectedYear),
      month: String(selectedMonth),
      memberId: selectedMemberId,
      page: "1",
      pageSize: "5",
    });

    const res = await fetch(`/api/family/summary?${params.toString()}`, { cache: "no-store" });
    if (!res.ok) {
      setSummary(null);
      setLoading(false);
      return;
    }

    const data = await res.json().catch(() => ({}));
    setSummary(data as Summary);
    setLoading(false);
  }, [selectedYear, selectedMonth, selectedMemberId]);

  useEffect(() => {
    fetchSummary();
    const interval = setInterval(fetchSummary, 30000); // 30s instead of 5s
    return () => clearInterval(interval);
  }, [fetchSummary]);

  const analytics = useMemo(() => {
    if (!summary) return { projected: 0, avg: 0, topSpender: null as string | null };
    const daysInMonth = new Date(selectedYear, selectedMonth, 0).getDate();
    const observedDays = Math.max(1, new Date().getDate());
    const projected = (summary.totalMonthlySpend / observedDays) * daysInMonth;
    const timeline = summary.monthlyTimeline ?? [];
    const totalYearSpend = timeline.reduce((sum, m) => sum + m.amount, 0);
    const activeMonths = timeline.filter((m) => m.amount > 0).length || 1;
    const avg = totalYearSpend / activeMonths;
    const sorted = [...(summary.memberBreakdown ?? [])].sort((a, b) => b.monthlySpend - a.monthlySpend);
    const topSpender = sorted[0]?.name ?? null;
    return { projected, avg, topSpender };
  }, [summary, selectedYear, selectedMonth]);

  if (loading) {
    return (
      <div className="stack">
        <div className="kpi-grid">
          <SkeletonCard />
          <SkeletonCard />
          <SkeletonCard />
          <SkeletonCard />
        </div>
      </div>
    );
  }

  if (!summary) {
    return (
      <EmptyState
        icon="🏠"
        title="No family workspace yet"
        subtitle="Create or join a family to see your financial overview"
        actionLabel="Set Up Family"
        onAction={() => router.push("/dashboard/settings")}
      />
    );
  }

  const maxCat = Math.max(1, ...(summary.topCategories ?? []).map((c) => c.amount));
  const monthTimelineTotal = (summary.monthlyTimeline ?? []).reduce((sum, m) => sum + Number(m.amount ?? 0), 0);

  return (
    <div className="stack animate-slide">
      {/* Quick Info Strip */}
      <div className="panel" style={{ padding: "var(--space-4) var(--space-6)", display: "flex", alignItems: "center", justifyContent: "space-between", gap: "var(--space-4)", flexWrap: "wrap" }}>
        <div style={{ display: "flex", alignItems: "center", gap: "var(--space-3)" }}>
          <span className="family-strip-icon" aria-hidden="true">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
              <circle cx="8" cy="10" r="2.5" />
              <circle cx="16" cy="11" r="2" />
              <path d="M4 19a5 5 0 0 1 8 0" />
              <path d="M13 19a4 4 0 0 1 7-1" />
            </svg>
          </span>
          <div>
            <div style={{ fontWeight: 700, fontSize: "var(--text-lg)" }}>{summary.familyName}</div>
            <div style={{ fontSize: "var(--text-xs)", color: "var(--text-tertiary)" }}>Code: <strong>{summary.inviteCode}</strong> · {summary.members?.length ?? 0} members</div>
          </div>
        </div>
        <div style={{ display: "flex", gap: "var(--space-2)", flexWrap: "wrap" }}>
          <span className="chip chip--brand">{summary.billing?.planName ?? "Free"} Plan</span>
          <span className="chip chip--neutral">{summary.billing?.usage?.used ?? 0}/{summary.billing?.usage?.monthlyTxnLimit ?? 0} txns</span>
          {summary.billing?.status === "trialing" && (
            <span className="chip chip--warning">Trial: {summary.billing.trial.trialDaysLeft}d left</span>
          )}
        </div>
        <div className="form-group" style={{ minWidth: 220 }}>
          <label className="form-label">Member</label>
          <select className="form-select" value={selectedMemberId} onChange={(e) => setSelectedMemberId(e.target.value)}>
            <option value="all">All Members</option>
            {(summary.members ?? []).map((m) => (
              <option key={m.userId} value={m.userId}>{m.name}</option>
            ))}
          </select>
        </div>
      </div>

      {/* KPI Cards */}
      <div className="kpi-grid">
        <KPICard
          icon="💰"
          label={`Spend (${monthTitle})`}
          value={money.format(summary.totalMonthlySpend)}
          variant="danger"
        />
        <KPICard
          icon="📈"
          label="Projected Month End"
          value={money.format(analytics.projected)}
          variant="warning"
        />
        <KPICard
          icon="📊"
          label="Avg Active Month"
          value={money.format(analytics.avg)}
          variant="info"
        />
        <KPICard
          icon="👤"
          label="Top Spender"
          value={analytics.topSpender ?? "—"}
          variant="default"
        />
      </div>

      {/* Two Column: Categories + Members */}
      <div className="grid-2">
        {/* Top Categories */}
        <div className="panel">
          <div className="panel-header">
            <h3 className="panel-title">Top Categories</h3>
            <span className="panel-subtitle">{monthTitle} {selectedYear}</span>
          </div>
          {(summary.topCategories ?? []).length === 0 ? (
            <EmptyState icon="📂" title="No categories yet" subtitle="Transactions will show category breakdown" />
          ) : (
            <ul className="data-list">
              {(summary.topCategories ?? []).slice(0, 6).map((c) => (
                <li key={c.category} className="data-list-item">
                  <div className="data-list-main">
                    <span style={{ fontWeight: 600, fontSize: "var(--text-sm)" }}>{c.category}</span>
                    <div className="bar-track">
                      <div
                        className="bar-fill category"
                        style={{ width: `${Math.max(8, (c.amount / maxCat) * 100)}%` }}
                      />
                    </div>
                  </div>
                  <strong style={{ fontSize: "var(--text-sm)", whiteSpace: "nowrap" }}>{money.format(c.amount)}</strong>
                </li>
              ))}
            </ul>
          )}
        </div>

        {/* Member Breakdown */}
        <div className="panel">
          <div className="panel-header">
            <h3 className="panel-title">People-wise Split</h3>
            <span className="panel-subtitle">{summary.memberBreakdown?.length ?? 0} members</span>
          </div>
          {(summary.memberBreakdown ?? []).length === 0 ? (
            <EmptyState icon="👥" title="No member data" subtitle="Invite family members to see spend splits" />
          ) : (
            <ul className="data-list">
              {(summary.memberBreakdown ?? []).map((m) => {
                const maxMember = Math.max(1, ...(summary.memberBreakdown ?? []).map((x) => x.monthlySpend));
                return (
                  <li key={m.userId} className="data-list-item">
                    <div style={{ display: "flex", alignItems: "center", gap: "var(--space-3)", flex: 1, minWidth: 0 }}>
                      <div style={{
                        width: 32, height: 32, borderRadius: "var(--radius-full)",
                        background: "linear-gradient(135deg, var(--brand-primary), var(--brand-accent))",
                        color: "white", display: "flex", alignItems: "center", justifyContent: "center",
                        fontSize: "var(--text-xs)", fontWeight: 700, flexShrink: 0,
                      }}>
                        {m.name?.charAt(0).toUpperCase() ?? "?"}
                      </div>
                      <div className="data-list-main">
                        <div style={{ display: "flex", alignItems: "center", gap: "var(--space-2)" }}>
                          <span style={{ fontWeight: 600, fontSize: "var(--text-sm)" }}>{m.name}</span>
                          <span className={`chip chip--${m.role === "admin" ? "admin" : "neutral"}`}>{m.role}</span>
                        </div>
                        <div className="bar-track">
                          <div
                            className="bar-fill people"
                            style={{ width: `${Math.max(8, (m.monthlySpend / maxMember) * 100)}%` }}
                          />
                        </div>
                      </div>
                    </div>
                    <strong style={{ fontSize: "var(--text-sm)", whiteSpace: "nowrap" }}>{money.format(m.monthlySpend)}</strong>
                  </li>
                );
              })}
            </ul>
          )}
        </div>
      </div>

      {/* Recent Transactions */}
      <div className="panel">
        <div className="panel-header">
          <h3 className="panel-title">Recent Transactions</h3>
          <button className="btn btn--ghost btn--sm" onClick={() => router.push("/dashboard/transactions")} type="button">
            View All →
          </button>
        </div>
        {(summary.recentTransactions ?? []).length === 0 ? (
          <EmptyState icon="💳" title="No transactions yet" subtitle="Sync from the mobile app or add manually" />
        ) : (
          <ul className="data-list">
            {(summary.recentTransactions ?? []).slice(0, 5).map((txn) => (
              <li key={txn.id} className="data-list-item">
                <div className="data-list-main">
                  <div style={{ display: "flex", alignItems: "center", gap: "var(--space-2)" }}>
                    <span style={{ fontWeight: 600, fontSize: "var(--text-sm)" }}>
                      {txn.merchant ?? txn.category}
                    </span>
                    <span className={`chip chip--${txn.type === "credit" ? "credit" : "debit"}`}>
                      {txn.type.toUpperCase()}
                    </span>
                    <span className="chip chip--neutral">{txn.source}</span>
                  </div>
                  <span style={{ fontSize: "var(--text-xs)", color: "var(--text-tertiary)" }}>
                    {txn.userName} · {new Date(txn.txnTime).toLocaleString()}
                  </span>
                </div>
                <strong style={{
                  fontSize: "var(--text-md)",
                  color: txn.type === "credit" ? "var(--color-success)" : "var(--color-danger)",
                  whiteSpace: "nowrap",
                }}>
                  {txn.type === "credit" ? "+" : "-"}{money.format(txn.amount)}
                </strong>
              </li>
            ))}
          </ul>
        )}
      </div>

      {/* Monthly Timeline */}
      <div className="panel">
        <div className="panel-header">
          <h3 className="panel-title">Monthly Spending Trend</h3>
          <span className="panel-subtitle">{selectedYear}</span>
        </div>
        {(summary.monthlyTimeline ?? []).length === 0 || monthTimelineTotal <= 0 ? (
          <EmptyState icon="📈" title="No trend data" subtitle="Track spending for a few months to see trends" />
        ) : (
          <div style={{ display: "flex", alignItems: "flex-end", gap: "var(--space-2)", height: 160, padding: "var(--space-4) 0" }}>
            {(summary.monthlyTimeline ?? []).map((m) => {
              const maxMonth = Math.max(1, ...(summary.monthlyTimeline ?? []).map((x) => x.amount));
              const height = Math.max(4, (m.amount / maxMonth) * 120);
              const isCurrentMonth = m.month === selectedMonth;
              return (
                <div key={m.month} style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", gap: "var(--space-1)" }}>
                  {m.amount > 0 && (
                    <span style={{ fontSize: "var(--text-xs)", fontWeight: 600, color: isCurrentMonth ? "var(--brand-primary)" : "var(--text-tertiary)" }}>
                      {money.format(m.amount).replace("₹", "")}
                    </span>
                  )}
                  <div style={{
                    width: "100%",
                    maxWidth: 40,
                    height,
                    borderRadius: "var(--radius-sm) var(--radius-sm) 2px 2px",
                    background: isCurrentMonth
                      ? "linear-gradient(180deg, var(--brand-primary), var(--brand-accent))"
                      : "var(--surface-tertiary)",
                    transition: "height var(--transition-slow)",
                  }} />
                  <span style={{ fontSize: 10, fontWeight: isCurrentMonth ? 700 : 400, color: isCurrentMonth ? "var(--brand-primary)" : "var(--text-tertiary)" }}>
                    {m.label?.substring(0, 3)}
                  </span>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
