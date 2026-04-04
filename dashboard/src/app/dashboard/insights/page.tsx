"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import EmptyState from "@/components/EmptyState";

export default function InsightsPage() {
  const [summary, setSummary] = useState<Record<string, unknown> | null>(null);

  const money = useMemo(() => new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }), []);

  const fetchSummary = useCallback(async () => {
    const now = new Date();
    const params = new URLSearchParams({ year: String(now.getFullYear()), month: String(now.getMonth() + 1), memberId: "all", page: "1", pageSize: "1" });
    const res = await fetch(`/api/family/summary?${params.toString()}`, { cache: "no-store" });
    if (!res.ok) return;
    const data = await res.json().catch(() => ({}));
    setSummary(data);
  }, []);

  useEffect(() => { fetchSummary(); }, [fetchSummary]);

  const insights = useMemo(() => {
    if (!summary) return [];
    const tips: Array<{ icon: "focus" | "trend" | "person" | "team" | "report" | "spark"; severity: "info" | "warning" | "critical"; title: string; body: string }> = [];
    const topCat = Array.isArray(summary.topCategories) ? summary.topCategories[0] as { category: string; amount: number } | undefined : undefined;
    const monthlySpend = Number(summary.totalMonthlySpend ?? 0);
    const members = Array.isArray(summary.memberBreakdown) ? summary.memberBreakdown : [];
    const timeline = Array.isArray(summary.monthlyTimeline) ? summary.monthlyTimeline : [];

    if (topCat) {
      tips.push({ icon: "focus", severity: "warning", title: `${topCat.category} is your top category`, body: `You've spent ${money.format(topCat.amount)} here. Try capping it by 10% next month to save ~${money.format(topCat.amount * 0.1)}.` });
    }

    const daysInMonth = new Date(new Date().getFullYear(), new Date().getMonth() + 1, 0).getDate();
    const dayOfMonth = new Date().getDate();
    const projected = dayOfMonth > 0 ? (monthlySpend / dayOfMonth) * daysInMonth : 0;
    if (projected > monthlySpend * 1.1) {
      tips.push({ icon: "trend", severity: "warning", title: "Spending is on track to exceed budget", body: `At the current pace, you'll spend ${money.format(projected)} by month end. Consider setting a weekly review.` });
    }

    if (members.length > 1) {
      const sorted = [...members].sort((a: Record<string, unknown>, b: Record<string, unknown>) => Number(b.monthlySpend ?? 0) - Number(a.monthlySpend ?? 0));
      const top = sorted[0] as Record<string, unknown>;
      if (top) tips.push({ icon: "person", severity: "info", title: `${top.name} is the top spender`, body: `They've spent ${money.format(Number(top.monthlySpend ?? 0))} this month. Consider assigning category ownership.` });
    } else {
      tips.push({ icon: "team", severity: "info", title: "Invite more family members", body: "Full family tracking gives better insights and helps with accountability." });
    }

    const activeMonths = timeline.filter((m: Record<string, unknown>) => Number(m.amount ?? 0) > 0).length;
    if (activeMonths >= 3) {
      const totalYear = timeline.reduce((s: number, m: Record<string, unknown>) => s + Number(m.amount ?? 0), 0);
      const avg = totalYear / activeMonths;
      tips.push({ icon: "report", severity: monthlySpend > avg * 1.15 ? "critical" : "info", title: monthlySpend > avg ? "Spending above average" : "Spending is healthy", body: `Your monthly average is ${money.format(avg)}. This month is ${money.format(monthlySpend)}.` });
    }

    tips.push({ icon: "spark", severity: "info", title: "Pro tip: Review weekly", body: "Families who review expenses weekly save 15-20% more than those who only check monthly." });

    return tips;
  }, [summary, money]);

  if (!summary) return <EmptyState icon="💡" title="Loading insights..." />;

  const iconFor = (kind: "focus" | "trend" | "person" | "team" | "report" | "spark") => {
    const common = { width: "20", height: "20", viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", strokeWidth: "1.8", strokeLinecap: "round" as const, strokeLinejoin: "round" as const };
    if (kind === "focus") return <svg {...common}><circle cx="12" cy="12" r="7" /><circle cx="12" cy="12" r="2" /></svg>;
    if (kind === "trend") return <svg {...common}><path d="M4 18h16" /><path d="m6 14 4-4 3 2 5-5" /></svg>;
    if (kind === "person") return <svg {...common}><circle cx="12" cy="8" r="3" /><path d="M5 20a7 7 0 0 1 14 0" /></svg>;
    if (kind === "team") return <svg {...common}><circle cx="9" cy="9" r="2.5" /><circle cx="16" cy="10" r="2" /><path d="M4.5 19a5 5 0 0 1 9 0" /><path d="M14 19a4 4 0 0 1 6-2" /></svg>;
    if (kind === "report") return <svg {...common}><path d="M5 4h14v16H5z" /><path d="M8 9h8M8 13h8M8 17h5" /></svg>;
    return <svg {...common}><path d="M12 3v4" /><path d="M12 17v4" /><path d="M4.2 7.2 7 10" /><path d="M17 14l2.8 2.8" /><path d="M3 12h4" /><path d="M17 12h4" /><circle cx="12" cy="12" r="3" /></svg>;
  };

  const severityColors: Record<string, string> = { info: "var(--color-info)", warning: "var(--color-warning)", critical: "var(--color-danger)" };
  const severityBg: Record<string, string> = { info: "var(--color-info-soft)", warning: "var(--color-warning-soft)", critical: "var(--color-danger-soft)" };

  return (
    <div className="stack animate-slide">
      <div className="panel">
        <div className="panel-header">
          <h3 className="panel-title">Smart Insights & Tips</h3>
          <span className="panel-subtitle">{insights.length} recommendations</span>
        </div>
        {insights.length === 0 ? <EmptyState icon="💡" title="No tips yet" subtitle="Track more transactions for personalized insights" /> : (
          <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-3)" }}>
            {insights.map((tip, i) => (
              <div key={i} style={{
                display: "flex", gap: "var(--space-4)", padding: "var(--space-4)",
                borderRadius: "var(--radius-md)", background: severityBg[tip.severity],
                borderLeft: `4px solid ${severityColors[tip.severity]}`,
              }}>
                <span className="insight-icon" aria-hidden="true">{iconFor(tip.icon)}</span>
                <div style={{ flex: 1 }}>
                  <div style={{ fontWeight: 600, fontSize: "var(--text-sm)", marginBottom: 4 }}>{tip.title}</div>
                  <div style={{ fontSize: "var(--text-sm)", color: "var(--text-secondary)", lineHeight: 1.5 }}>{tip.body}</div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Spending Story */}
      <div className="panel">
        <div className="panel-header">
          <h3 className="panel-title">Spending Story</h3>
        </div>
        <p style={{ fontSize: "var(--text-md)", color: "var(--text-secondary)", lineHeight: 1.7 }}>
          {(() => {
            const monthlySpend = Number(summary.totalMonthlySpend ?? 0);
            const topCat = Array.isArray(summary.topCategories) ? summary.topCategories[0] as { category: string; amount: number } | undefined : undefined;
            const month = new Date().toLocaleString("en-US", { month: "long" });
            let story = `Your ${month} spend so far is ${money.format(monthlySpend)}. `;
            if (topCat) story += `${topCat.category} led with ${money.format(topCat.amount)}. `;
            return story + "Keep tracking daily for stronger insights.";
          })()}
        </p>
      </div>
    </div>
  );
}
