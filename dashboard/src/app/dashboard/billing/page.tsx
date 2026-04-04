"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import EmptyState from "@/components/EmptyState";

type Billing = {
  planId: string;
  planName: string;
  status: string;
  monthlyPriceInr: number;
  maxMembers: number;
  membersUsed: number;
  membersRemaining: number;
  trial: { trialEndsAt: string; trialDaysLeft: number; nextBillingAt: string };
  usage: { used: number; monthlyTxnLimit: number; remaining: number; periodStart: string; periodEnd: string };
  timeline: Array<{ at: string; kind: string; fromPlanId: string | null; toPlanId: string; amountInr: number; note?: string }>;
};

export default function BillingPage() {
  const [billing, setBilling] = useState<Billing | null>(null);
  const [error, setError] = useState<string | null>(null);

  const money = useMemo(() => new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }), []);

  const fetchBilling = useCallback(async () => {
    const now = new Date();
    const params = new URLSearchParams({ year: String(now.getFullYear()), month: String(now.getMonth() + 1), memberId: "all", page: "1", pageSize: "1" });
    const res = await fetch(`/api/family/summary?${params.toString()}`, { cache: "no-store" });
    if (!res.ok) return;
    const data = await res.json().catch(() => ({}));
    if (data.billing) setBilling(data.billing as Billing);
  }, []);

  useEffect(() => { fetchBilling(); }, [fetchBilling]);

  async function upgradePlan(planId: "pro" | "family_pro") {
    const res = await fetch("/api/billing/subscribe", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ planId }) });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) { setError(data.error ?? "Could not change plan"); return; }
    if (data.requiresPayment && typeof data.checkoutUrl === "string") { window.location.href = data.checkoutUrl; return; }
    setError(null); fetchBilling();
  }

  async function exportInvoices() {
    const res = await fetch("/api/billing/invoices/export");
    if (!res.ok) return;
    const blob = await res.blob(); const url = URL.createObjectURL(blob);
    const a = document.createElement("a"); a.href = url; a.download = "dhanpath-invoices.csv";
    document.body.appendChild(a); a.click(); a.remove(); URL.revokeObjectURL(url);
  }

  if (!billing) return <EmptyState icon="💎" title="Loading billing..." />;

  const usagePct = billing.usage.monthlyTxnLimit > 0 ? (billing.usage.used / billing.usage.monthlyTxnLimit) * 100 : 0;

  return (
    <div className="stack animate-slide">
      {error && <div className="panel" style={{ borderColor: "var(--color-danger)", color: "var(--color-danger)", fontWeight: 600 }}>{error}</div>}

      {/* Current Plan */}
      <div className="panel">
        <div className="panel-header">
          <h3 className="panel-title">Current Plan</h3>
          <span className="chip chip--brand">{billing.planName}</span>
        </div>
        <div className="kpi-grid" style={{ marginTop: "var(--space-4)" }}>
          <article className="kpi-card">
            <span className="kpi-card-label">Price</span>
            <div className="kpi-card-value">{money.format(billing.monthlyPriceInr)}<span style={{ fontSize: "var(--text-sm)", fontWeight: 400 }}>/mo</span></div>
          </article>
          <article className="kpi-card">
            <span className="kpi-card-label">Seats</span>
            <div className="kpi-card-value">{billing.membersUsed}/{billing.maxMembers}</div>
            <span className="kpi-card-subtitle">{billing.membersRemaining} remaining</span>
          </article>
          <article className="kpi-card">
            <span className="kpi-card-label">Usage</span>
            <div className="kpi-card-value">{billing.usage.used}/{billing.usage.monthlyTxnLimit}</div>
            <div className="bar-track" style={{ marginTop: "var(--space-1)" }}>
              <div className="bar-fill trend" style={{ width: `${Math.min(100, usagePct)}%` }} />
            </div>
          </article>
          <article className="kpi-card">
            <span className="kpi-card-label">Status</span>
            <div className="kpi-card-value" style={{ fontSize: "var(--text-lg)" }}>{billing.status}</div>
            {billing.status === "trialing" && <span className="chip chip--warning">{billing.trial.trialDaysLeft} days left</span>}
          </article>
        </div>
      </div>

      {/* Upgrade Options */}
      <div className="grid-2">
        <div className="panel" style={{ display: "flex", flexDirection: "column", gap: "var(--space-3)" }}>
          <h4 style={{ fontSize: "var(--text-lg)", fontWeight: 700 }}>🚀 Pro</h4>
          <p style={{ fontSize: "var(--text-sm)", color: "var(--text-secondary)" }}>Higher limits, advanced analytics, priority support</p>
          <button className="btn btn--primary" onClick={() => upgradePlan("pro")} type="button">Upgrade to Pro</button>
        </div>
        <div className="panel" style={{ display: "flex", flexDirection: "column", gap: "var(--space-3)" }}>
          <h4 style={{ fontSize: "var(--text-lg)", fontWeight: 700 }}>👨‍👩‍👧‍👦 Family Pro</h4>
          <p style={{ fontSize: "var(--text-sm)", color: "var(--text-secondary)" }}>Unlimited members, CA Pack, full audit trail</p>
          <button className="btn btn--primary" onClick={() => upgradePlan("family_pro")} type="button">Upgrade to Family Pro</button>
        </div>
      </div>

      {/* Billing Timeline */}
      <div className="panel">
        <div className="panel-header">
          <h3 className="panel-title">Billing History</h3>
          <button className="btn btn--ghost btn--sm" onClick={exportInvoices} type="button">Export CSV</button>
        </div>
        {(billing.timeline ?? []).length === 0 ? <EmptyState icon="📋" title="No billing events" /> : (
          <ul className="data-list">
            {(billing.timeline ?? []).map((evt, i) => (
              <li key={i} className="data-list-item">
                <div className="data-list-main">
                  <span style={{ fontWeight: 600, fontSize: "var(--text-sm)" }}>{evt.kind.replace(/_/g, " ")} · {evt.toPlanId}</span>
                  <span style={{ fontSize: "var(--text-xs)", color: "var(--text-tertiary)" }}>{new Date(evt.at).toLocaleString()}{evt.note ? ` · ${evt.note}` : ""}</span>
                </div>
                <strong style={{ fontSize: "var(--text-sm)" }}>{money.format(evt.amountInr)}</strong>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}
