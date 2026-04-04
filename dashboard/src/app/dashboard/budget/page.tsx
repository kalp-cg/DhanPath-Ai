"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import EmptyState from "@/components/EmptyState";
import { SkeletonCard } from "@/components/Skeleton";

type Summary = {
  totalMonthlySpend: number;
  availableYears: number[];
  members: Array<{ userId: string; name: string }>;
  topCategories: Array<{ category: string; amount: number }>;
};

type ActionPlan = {
  focusCategory: string;
  cutPercent: number;
  goalAmount: number;
  baselineMonthlySpend: number;
  monthlySaving: number;
  yearlySaving: number;
  goalMonths: number | null;
  updatedAt: string;
};

export default function BudgetPage() {
  const now = new Date();
  const [loading, setLoading] = useState(true);
  const [summary, setSummary] = useState<Summary | null>(null);
  const [plan, setPlan] = useState<ActionPlan | null>(null);
  const [selectedYear, setSelectedYear] = useState(now.getFullYear());
  const [selectedMonth, setSelectedMonth] = useState(now.getMonth() + 1);
  const [selectedMemberId, setSelectedMemberId] = useState("all");

  const money = useMemo(
    () => new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }),
    [],
  );

  const fetchSummary = useCallback(async () => {
    const params = new URLSearchParams({
      year: String(selectedYear),
      month: String(selectedMonth),
      memberId: selectedMemberId,
      page: "1",
      pageSize: "1",
    });
    const [summaryRes, planRes] = await Promise.all([
      fetch(`/api/family/summary?${params.toString()}`, { cache: "no-store" }),
      fetch("/api/family/action-plan", { cache: "no-store" }),
    ]);

    if (!summaryRes.ok) {
      setLoading(false);
      return;
    }
    const data = await summaryRes.json().catch(() => ({}));
    setSummary(data as Summary);

    if (planRes.ok) {
      const planData = await planRes.json().catch(() => ({}));
      setPlan((planData?.plan ?? null) as ActionPlan | null);
    }
    setLoading(false);
  }, [selectedYear, selectedMonth, selectedMemberId]);

  useEffect(() => {
    setLoading(true);
    fetchSummary();
  }, [fetchSummary]);

  if (loading) {
    return (
      <div className="stack">
        <SkeletonCard />
        <SkeletonCard />
      </div>
    );
  }

  if (!summary) {
    return <EmptyState icon="B" title="No budget data" subtitle="Unable to load budget summary." />;
  }

  const spend = Number(summary.totalMonthlySpend ?? 0);
  const suggestedBudget = plan
    ? Math.max(1000, plan.baselineMonthlySpend - plan.monthlySaving)
    : spend > 0
      ? spend * 1.15
      : 10000;
  const usedPct = suggestedBudget > 0 ? Math.min(100, (spend / suggestedBudget) * 100) : 0;
  const remaining = Math.max(0, suggestedBudget - spend);
  const monthName = new Date(selectedYear, selectedMonth - 1, 1).toLocaleString("en-US", { month: "long" });
  const maxCategory = Math.max(1, ...(summary.topCategories ?? []).map((c) => c.amount));

  return (
    <div className="stack animate-slide">
      <div className="panel" style={{ padding: "var(--space-3) var(--space-6)" }}>
        <div className="form-row" style={{ alignItems: "end" }}>
          <div className="form-group">
            <label className="form-label">Year</label>
            <select className="form-select" value={selectedYear} onChange={(e) => setSelectedYear(Number(e.target.value))}>
              {(summary.availableYears ?? [selectedYear]).map((y) => (
                <option key={y} value={y}>{y}</option>
              ))}
            </select>
          </div>
          <div className="form-group">
            <label className="form-label">Month</label>
            <select className="form-select" value={selectedMonth} onChange={(e) => setSelectedMonth(Number(e.target.value))}>
              {Array.from({ length: 12 }, (_, i) => (
                <option key={i + 1} value={i + 1}>{new Date(2026, i, 1).toLocaleString("en-US", { month: "long" })}</option>
              ))}
            </select>
          </div>
          <div className="form-group">
            <label className="form-label">Member</label>
            <select className="form-select" value={selectedMemberId} onChange={(e) => setSelectedMemberId(e.target.value)}>
              <option value="all">All Members</option>
              {(summary.members ?? []).map((m) => (
                <option key={m.userId} value={m.userId}>{m.name}</option>
              ))}
            </select>
          </div>
        </div>
      </div>

      <div className="kpi-grid">
        <article className="kpi-card kpi-card--danger">
          <span className="kpi-card-label">Actual Spend ({monthName})</span>
          <div className="kpi-card-value">{money.format(spend)}</div>
        </article>
        <article className="kpi-card kpi-card--info">
          <span className="kpi-card-label">Suggested Budget</span>
          <div className="kpi-card-value">{money.format(suggestedBudget)}</div>
        </article>
        <article className="kpi-card kpi-card--success">
          <span className="kpi-card-label">Remaining Buffer</span>
          <div className="kpi-card-value">{money.format(remaining)}</div>
        </article>
        <article className="kpi-card">
          <span className="kpi-card-label">Budget Usage</span>
          <div className="kpi-card-value">{usedPct.toFixed(1)}%</div>
        </article>
      </div>

      {plan && (
        <div className="panel" style={{ padding: "var(--space-4) var(--space-6)", background: "linear-gradient(135deg, rgba(15, 118, 110, 0.06), rgba(14, 165, 233, 0.05))" }}>
          <div style={{ display: "flex", justifyContent: "space-between", gap: "var(--space-2)", flexWrap: "wrap" }}>
            <div>
              <div style={{ fontWeight: 700 }}>Active Applied Plan</div>
              <div style={{ fontSize: "var(--text-xs)", color: "var(--text-tertiary)" }}>
                Focus: {plan.focusCategory === "all" ? "Total Spend" : plan.focusCategory} · Cut {plan.cutPercent}% · Updated {new Date(plan.updatedAt).toLocaleString()}
              </div>
            </div>
            <span className="chip chip--credit">Saving Target: {money.format(plan.monthlySaving)}/month</span>
          </div>
        </div>
      )}

      <div className="panel">
        <div className="panel-header">
          <h3 className="panel-title">Budget Utilization Chart</h3>
          <span className="panel-subtitle">Current period</span>
        </div>
        <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-2)" }}>
          <div className="bar-track" style={{ height: 14 }}>
            <div className="bar-fill trend" style={{ width: `${Math.max(2, usedPct)}%` }} />
          </div>
          <div style={{ display: "flex", justifyContent: "space-between", fontSize: "var(--text-xs)", color: "var(--text-tertiary)" }}>
            <span>Used: {money.format(spend)}</span>
            <span>Budget: {money.format(suggestedBudget)}</span>
          </div>
        </div>
      </div>

      <div className="panel">
        <div className="panel-header">
          <h3 className="panel-title">Category Pressure Points</h3>
          <span className="panel-subtitle">Top categories this month</span>
        </div>
        {(summary.topCategories ?? []).length === 0 ? (
          <EmptyState icon="C" title="No category spend" subtitle="Add transactions to see category budget pressure." />
        ) : (
          <ul className="data-list">
            {(summary.topCategories ?? []).map((cat) => (
              <li key={cat.category} className="data-list-item">
                <div className="data-list-main">
                  <div style={{ display: "flex", justifyContent: "space-between" }}>
                    <span style={{ fontWeight: 600 }}>{cat.category}</span>
                    <span style={{ fontSize: "var(--text-xs)", color: "var(--text-tertiary)" }}>
                      {((cat.amount / Math.max(1, spend)) * 100).toFixed(1)}%
                    </span>
                  </div>
                  <div className="bar-track">
                    <div className="bar-fill category" style={{ width: `${Math.max(8, (cat.amount / maxCategory) * 100)}%` }} />
                  </div>
                </div>
                <strong>{money.format(cat.amount)}</strong>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}
