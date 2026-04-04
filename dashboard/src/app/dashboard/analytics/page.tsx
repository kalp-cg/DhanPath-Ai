"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import EmptyState from "@/components/EmptyState";
import { SkeletonCard } from "@/components/Skeleton";

type Summary = {
  memberBreakdown: Array<{ userId: string; name: string; role: string; monthlySpend: number }>;
  members: Array<{ userId: string; name: string }>;
  topCategories: Array<{ category: string; amount: number }>;
  monthlyTimeline: Array<{ month: number; label: string; amount: number }>;
  yearlyTotals: Array<{ year: number; amount: number }>;
  totalMonthlySpend: number;
  availableYears: number[];
};

export default function AnalyticsPage() {
  const now = new Date();
  const [summary, setSummary] = useState<Summary | null>(null);
  const [loading, setLoading] = useState(true);
  const [selectedYear, setSelectedYear] = useState(now.getFullYear());
  const [selectedMonth, setSelectedMonth] = useState(now.getMonth() + 1);
  const [selectedMemberId, setSelectedMemberId] = useState("all");

  const money = useMemo(() => new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }), []);
  const monthTitle = new Date(selectedYear, selectedMonth - 1, 1).toLocaleString("en-US", { month: "long" });

  const fetchSummary = useCallback(async () => {
    const params = new URLSearchParams({
      year: String(selectedYear),
      month: String(selectedMonth),
      memberId: selectedMemberId,
      page: "1",
      pageSize: "1",
    });
    const res = await fetch(`/api/family/summary?${params.toString()}`, { cache: "no-store" });
    if (!res.ok) { setLoading(false); return; }
    const data = await res.json().catch(() => ({}));
    setSummary(data as Summary);
    setLoading(false);
  }, [selectedYear, selectedMonth, selectedMemberId]);

  useEffect(() => { setLoading(true); fetchSummary(); }, [fetchSummary]);

  useEffect(() => {
    if (!summary) return;
    if ((summary.availableYears ?? []).length === 0) return;
    if (!summary.availableYears.includes(selectedYear)) {
      setSelectedYear(summary.availableYears[0]);
      setSelectedMonth(1);
    }
  }, [summary, selectedYear]);

  if (loading) return <div className="stack"><SkeletonCard /><SkeletonCard /></div>;
  if (!summary) return <EmptyState icon="📈" title="No analytics data" subtitle="Start tracking transactions to see analytics" />;

  const categories = summary.topCategories ?? [];
  const timeline = summary.monthlyTimeline ?? [];
  const yearlyTotals = summary.yearlyTotals ?? [];
  const maxCat = Math.max(1, ...categories.map((c) => c.amount));
  const maxMonth = Math.max(1, ...timeline.map((m) => m.amount));
  const maxYear = Math.max(1, ...yearlyTotals.map((y) => y.amount));
  const totalCat = categories.reduce((s, c) => s + c.amount, 0);
  const timelineTotal = timeline.reduce((s, m) => s + m.amount, 0);

  return (
    <div className="stack animate-slide">
      {/* Period Filter */}
      <div className="panel" style={{ padding: "var(--space-3) var(--space-6)" }}>
        <div className="form-row" style={{ alignItems: "end" }}>
          <div className="form-group">
            <label className="form-label">Year</label>
            <select className="form-select" value={selectedYear} onChange={(e) => setSelectedYear(Number(e.target.value))}>
              {(summary.availableYears ?? [selectedYear]).map((y) => <option key={y} value={y}>{y}</option>)}
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

      {/* Category Breakdown */}
      <div className="grid-2">
        <div className="panel">
          <div className="panel-header">
            <h3 className="panel-title">Spending by Category</h3>
            <span className="panel-subtitle">{monthTitle} {selectedYear}</span>
          </div>
          {categories.length === 0 ? <EmptyState icon="📂" title="No data" /> : (
            <ul className="data-list">
              {categories.slice(0, 8).map((c) => {
                const pct = totalCat > 0 ? ((c.amount / totalCat) * 100).toFixed(0) : "0";
                return (
                  <li key={c.category} className="data-list-item">
                    <div className="data-list-main">
                      <div style={{ display: "flex", justifyContent: "space-between" }}>
                        <span style={{ fontWeight: 600, fontSize: "var(--text-sm)" }}>{c.category}</span>
                        <span style={{ fontSize: "var(--text-xs)", color: "var(--text-tertiary)" }}>{pct}%</span>
                      </div>
                      <div className="bar-track">
                        <div className="bar-fill category" style={{ width: `${Math.max(8, (c.amount / maxCat) * 100)}%` }} />
                      </div>
                    </div>
                    <strong style={{ fontSize: "var(--text-sm)", whiteSpace: "nowrap" }}>{money.format(c.amount)}</strong>
                  </li>
                );
              })}
            </ul>
          )}
        </div>

        {/* People Breakdown */}
        <div className="panel">
          <div className="panel-header">
            <h3 className="panel-title">People-wise Split</h3>
          </div>
          {(summary.memberBreakdown ?? []).length === 0 ? <EmptyState icon="👥" title="No members" /> : (
            <ul className="data-list">
              {(summary.memberBreakdown ?? []).map((m) => {
                const maxMember = Math.max(1, ...(summary.memberBreakdown ?? []).map((x) => x.monthlySpend));
                return (
                  <li key={m.userId} className="data-list-item">
                    <div style={{ display: "flex", alignItems: "center", gap: "var(--space-3)", flex: 1 }}>
                      <div style={{ width: 28, height: 28, borderRadius: "var(--radius-full)", background: "linear-gradient(135deg, var(--brand-primary), var(--brand-accent))", color: "white", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 11, fontWeight: 700 }}>{m.name?.charAt(0).toUpperCase()}</div>
                      <div className="data-list-main">
                        <span style={{ fontWeight: 600, fontSize: "var(--text-sm)" }}>{m.name}</span>
                        <div className="bar-track">
                          <div className="bar-fill people" style={{ width: `${Math.max(8, (m.monthlySpend / maxMember) * 100)}%` }} />
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

      {/* Monthly Timeline */}
      <div className="panel">
        <div className="panel-header">
          <h3 className="panel-title">Month-wise Trend</h3>
          <span className="panel-subtitle">{selectedYear}</span>
        </div>
        {timelineTotal <= 0 ? (
          <EmptyState icon="📈" title="No month trend for this filter" subtitle="Try another year or switch to All Members to view trend." />
        ) : (
          <div style={{ display: "flex", alignItems: "flex-end", gap: "var(--space-2)", height: 180, padding: "var(--space-4) 0" }}>
            {timeline.map((m) => {
              const h = Math.max(4, (m.amount / maxMonth) * 140);
              const isCurrent = m.month === selectedMonth;
              return (
                <div key={m.month} style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", gap: 4 }}>
                  {m.amount > 0 && <span style={{ fontSize: 10, fontWeight: 600, color: isCurrent ? "var(--brand-primary)" : "var(--text-tertiary)" }}>{money.format(m.amount).replace("₹", "")}</span>}
                  <div style={{ width: "100%", maxWidth: 36, height: h, borderRadius: "var(--radius-sm) var(--radius-sm) 2px 2px", background: isCurrent ? "linear-gradient(180deg, var(--brand-primary), var(--brand-accent))" : "var(--surface-tertiary)" }} />
                  <span style={{ fontSize: 10, fontWeight: isCurrent ? 700 : 400, color: isCurrent ? "var(--brand-primary)" : "var(--text-tertiary)" }}>{m.label?.substring(0, 3)}</span>
                </div>
              );
            })}
          </div>
        )}
      </div>

      <div className="panel">
        <div className="panel-header">
          <h3 className="panel-title">Member Comparison Chart</h3>
          <span className="panel-subtitle">Spend share by member</span>
        </div>
        {(summary.memberBreakdown ?? []).length === 0 ? <EmptyState icon="👥" title="No member chart data" /> : (
          <ul className="data-list">
            {(summary.memberBreakdown ?? []).map((m) => {
              const total = Math.max(1, (summary.memberBreakdown ?? []).reduce((s, x) => s + x.monthlySpend, 0));
              const sharePct = (m.monthlySpend / total) * 100;
              const maxMember = Math.max(1, ...(summary.memberBreakdown ?? []).map((x) => x.monthlySpend));
              return (
                <li key={`cmp-${m.userId}`} className="data-list-item">
                  <div className="data-list-main">
                    <div style={{ display: "flex", justifyContent: "space-between" }}>
                      <span style={{ fontWeight: 600, fontSize: "var(--text-sm)" }}>{m.name}</span>
                      <span style={{ fontSize: "var(--text-xs)", color: "var(--text-tertiary)" }}>{sharePct.toFixed(1)}%</span>
                    </div>
                    <div className="bar-track">
                      <div className="bar-fill people" style={{ width: `${Math.max(8, (m.monthlySpend / maxMember) * 100)}%` }} />
                    </div>
                  </div>
                  <strong style={{ whiteSpace: "nowrap" }}>{money.format(m.monthlySpend)}</strong>
                </li>
              );
            })}
          </ul>
        )}
      </div>

      {/* Yearly Totals */}
      {yearlyTotals.length > 0 && (
        <div className="panel">
          <div className="panel-header">
            <h3 className="panel-title">Year-wise Comparison</h3>
          </div>
          <ul className="data-list">
            {yearlyTotals.map((y) => (
              <li key={y.year} className="data-list-item">
                <div className="data-list-main">
                  <span style={{ fontWeight: 600 }}>{y.year}</span>
                  <div className="bar-track">
                    <div className="bar-fill year" style={{ width: `${Math.max(8, (y.amount / maxYear) * 100)}%` }} />
                  </div>
                </div>
                <strong>{money.format(y.amount)}</strong>
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}
