"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import EmptyState from "@/components/EmptyState";
import { SkeletonCard } from "@/components/Skeleton";

type Summary = {
  totalMonthlySpend: number;
  availableYears: number[];
  members: Array<{ userId: string; name: string }>;
  monthlyTimeline: Array<{ month: number; label: string; amount: number }>;
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

export default function GoalsPage() {
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
    return <EmptyState icon="G" title="No goals data" subtitle="Unable to load savings goals." />;
  }

  const monthSpend = Number(summary.totalMonthlySpend ?? 0);
  const avgMonthSpend = (summary.monthlyTimeline ?? []).filter((m) => m.amount > 0).length > 0
    ? (summary.monthlyTimeline ?? []).reduce((sum, m) => sum + m.amount, 0) /
      (summary.monthlyTimeline ?? []).filter((m) => m.amount > 0).length
    : monthSpend;

  const emergencyTarget = Math.max(50000, avgMonthSpend * 3);
  const emergencyProgress = Math.min(100, (monthSpend > 0 ? (avgMonthSpend / emergencyTarget) * 100 : 0));

  const topCategory = (summary.topCategories ?? [])[0];
  const cutTarget = topCategory ? topCategory.amount * 0.15 : monthSpend * 0.1;
  const cutProgress = topCategory && topCategory.amount > 0
    ? Math.min(100, (cutTarget / topCategory.amount) * 100)
    : 0;

  const annualSavingTarget = plan?.goalAmount ?? Math.max(120000, avgMonthSpend * 12 * 0.18);
  const monthlyContributionGoal = plan?.monthlySaving ?? (annualSavingTarget / 12);
  const yearlyProgress = monthSpend > 0
    ? Math.min(100, (monthlyContributionGoal / Math.max(1, monthSpend)) * 100)
    : 0;

  const goals = [
    {
      key: "emergency",
      title: "Emergency Buffer",
      subtitle: "Build 3-month spending cushion",
      target: emergencyTarget,
      progress: emergencyProgress,
      meta: `Target: ${money.format(emergencyTarget)}`,
    },
    {
      key: "category-cut",
      title: "Category Cut Goal",
      subtitle: topCategory ? `Reduce ${topCategory.category} by 15%` : "Reduce top category spending",
      target: cutTarget,
      progress: cutProgress,
      meta: `Monthly saving opportunity: ${money.format(cutTarget)}`,
    },
    {
      key: "annual",
      title: "Annual Savings Goal",
      subtitle: "Discipline-driven yearly savings",
      target: annualSavingTarget,
      progress: yearlyProgress,
      meta: `Need per month: ${money.format(monthlyContributionGoal)}`,
    },
  ];

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

      {plan && (
        <div className="panel" style={{ padding: "var(--space-4) var(--space-6)", background: "linear-gradient(135deg, rgba(15, 118, 110, 0.06), rgba(14, 165, 233, 0.05))" }}>
          <div style={{ display: "flex", justifyContent: "space-between", gap: "var(--space-2)", flexWrap: "wrap" }}>
            <div>
              <div style={{ fontWeight: 700 }}>Command Center Plan Linked</div>
              <div style={{ fontSize: "var(--text-xs)", color: "var(--text-tertiary)" }}>
                Target: {money.format(plan.goalAmount)} · Monthly contribution: {money.format(plan.monthlySaving)} · Updated {new Date(plan.updatedAt).toLocaleString()}
              </div>
            </div>
            <span className="chip chip--brand">ETA: {plan.goalMonths === null ? "-" : `${plan.goalMonths} months`}</span>
          </div>
        </div>
      )}

      <div className="kpi-grid">
        <article className="kpi-card kpi-card--warning">
          <span className="kpi-card-label">Current Month Spend</span>
          <div className="kpi-card-value">{money.format(monthSpend)}</div>
        </article>
        <article className="kpi-card kpi-card--info">
          <span className="kpi-card-label">Active Monthly Average</span>
          <div className="kpi-card-value">{money.format(avgMonthSpend)}</div>
        </article>
        <article className="kpi-card kpi-card--success">
          <span className="kpi-card-label">Annual Saving Target</span>
          <div className="kpi-card-value">{money.format(annualSavingTarget)}</div>
        </article>
      </div>

      <div className="panel">
        <div className="panel-header">
          <h3 className="panel-title">Goal Progress Chart</h3>
          <span className="panel-subtitle">Track each target visually</span>
        </div>
        <ul className="data-list">
          {goals.map((goal) => (
            <li key={goal.key} className="data-list-item" style={{ flexDirection: "column", alignItems: "stretch", gap: "var(--space-2)" }}>
              <div style={{ display: "flex", justifyContent: "space-between", gap: "var(--space-2)" }}>
                <div>
                  <div style={{ fontWeight: 700 }}>{goal.title}</div>
                  <div style={{ fontSize: "var(--text-xs)", color: "var(--text-tertiary)" }}>{goal.subtitle}</div>
                </div>
                <span className="chip chip--brand">{goal.progress.toFixed(1)}%</span>
              </div>
              <div className="bar-track">
                <div className="bar-fill trend" style={{ width: `${Math.max(4, goal.progress)}%` }} />
              </div>
              <div style={{ fontSize: "var(--text-xs)", color: "var(--text-tertiary)" }}>{goal.meta}</div>
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}
