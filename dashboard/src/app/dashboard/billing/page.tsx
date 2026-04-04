"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { AnimatePresence, motion } from "motion/react";
import { ArrowRight, Check, Sparkles, X } from "lucide-react";
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
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [isStartingCheckout, setIsStartingCheckout] = useState(false);
  const [showSuccessPopup, setShowSuccessPopup] = useState(false);
  const [activatedPlanName, setActivatedPlanName] = useState("");

  const money = useMemo(() => new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }), []);
  const planLabel = (planId: string) => {
    if (planId === "family_pro") return "Family Plus";
    if (planId === "pro") return "Growth";
    return "Starter";
  };

  const fetchBilling = useCallback(async () => {
    setLoading(true);
    setError(null);

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 15000);

    try {
      const res = await fetch("/api/billing/subscription", {
        cache: "no-store",
        signal: controller.signal,
      });

      if (!res.ok) {
        const body = await res.json().catch(() => ({}));
        setBilling(null);
        setError(String(body.error ?? "Unable to load billing details"));
        return;
      }

      const data = await res.json().catch(() => ({}));
      if (data.subscription) {
        setBilling(data.subscription as Billing);
      } else {
        setBilling(null);
        setError("Billing details are unavailable right now");
      }
    } catch (err) {
      const message = err instanceof Error && err.name === "AbortError"
        ? "Billing request timed out. Please refresh and try again."
        : "Billing request failed. Please try again.";
      setBilling(null);
      setError(message);
    } finally {
      clearTimeout(timer);
      setLoading(false);
    }
  }, []);

  useEffect(() => { fetchBilling(); }, [fetchBilling]);

  useEffect(() => {
    if (typeof window === "undefined") return;
    const params = new URLSearchParams(window.location.search);
    const status = params.get("checkout");
    const sessionId = params.get("session_id");
    if (status !== "success" || !sessionId) return;

    let active = true;
    (async () => {
      const res = await fetch("/api/billing/confirm", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ sessionId }),
      });
      const data = await res.json().catch(() => ({}));
      if (!active) return;

      if (res.ok) {
        const activePlan = planLabel(String(data.subscription?.planId ?? ""));
        setActivatedPlanName(activePlan);
        setShowSuccessPopup(true);
        setNotice(null);
        setError(null);
        await fetchBilling();
      } else {
        setError(data.error ?? "Payment verification failed.");
      }

      window.history.replaceState({}, "", "/dashboard/billing");
    })();

    return () => {
      active = false;
    };
  }, [fetchBilling]);

  useEffect(() => {
    if (typeof window === "undefined") return;
    const params = new URLSearchParams(window.location.search);
    const status = params.get("checkout");
    if (status === "cancelled") {
      setNotice("Checkout cancelled. No changes were made.");
      window.history.replaceState({}, "", "/dashboard/billing");
    }
  }, []);

  useEffect(() => {
    if (!showSuccessPopup) return;
    const timer = window.setTimeout(() => setShowSuccessPopup(false), 3400);
    return () => window.clearTimeout(timer);
  }, [showSuccessPopup]);

  async function startStripeCheckout(planId: "pro" | "family_pro") {
    try {
      setIsStartingCheckout(true);
      setError(null);
      const res = await fetch("/api/billing/subscribe", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ planId }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) {
        setError(data.error ?? "Could not start Stripe checkout");
        setIsStartingCheckout(false);
        return;
      }
      if (data.requiresPayment && typeof data.checkoutUrl === "string") {
        window.location.href = data.checkoutUrl;
        return;
      }
      setIsStartingCheckout(false);
      fetchBilling();
    } catch {
      setError("Stripe checkout failed. Please try again.");
      setIsStartingCheckout(false);
    }
  }

  async function switchToFreePlan() {
    const res = await fetch("/api/billing/subscribe", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ planId: "free" }),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      setError(data.error ?? "Could not switch to free plan");
      return;
    }
    setNotice("Switched to Starter plan.");
    setError(null);
    fetchBilling();
  }

  async function exportInvoices() {
    const res = await fetch("/api/billing/invoices/export");
    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      setError(String(body.error ?? "Could not export invoices"));
      return;
    }
    const blob = await res.blob(); const url = URL.createObjectURL(blob);
    const a = document.createElement("a"); a.href = url; a.download = "dhanpath-invoices.csv";
    document.body.appendChild(a); a.click(); a.remove(); URL.revokeObjectURL(url);
  }

  if (loading) return <EmptyState icon="💎" title="Loading billing..." />;

  if (!billing) return <EmptyState icon="💎" title="Billing unavailable" subtitle={error ?? "Try refreshing in a moment."} />;

  const usagePct = billing.usage.monthlyTxnLimit > 0 ? (billing.usage.used / billing.usage.monthlyTxnLimit) * 100 : 0;
  const activePlanId = billing.planId;
  const plans = [
    {
      id: "free" as const,
      title: "Starter",
      badge: "Free",
      price: 0,
      cycle: "/3 months",
      blurb: "Best for early tracking and family onboarding.",
      perks: ["Up to 4 members", "Basic analytics", "Manual + mobile sync"],
    },
    {
      id: "pro" as const,
      title: "Growth",
      badge: "Popular",
      price: 199,
      cycle: "/3 months",
      blurb: "For consistent monthly tracking with better controls.",
      perks: ["Up to 8 members", "Deeper analytics panels", "Priority processing"],
    },
    {
      id: "family_pro" as const,
      title: "Family Plus",
      badge: "Advanced",
      price: 299,
      cycle: "/3 months",
      blurb: "For larger families and accountant-grade reporting.",
      perks: ["Up to 20 members", "Advanced reports", "Premium support"],
    },
  ];

  return (
    <div className="stack animate-slide">
      {notice && <div className="wm-copy-alert wm-copy-alert--success"><strong>Billing Update</strong><span>{notice}</span></div>}
      {error && <div className="panel" style={{ borderColor: "var(--color-danger)", color: "var(--color-danger)", fontWeight: 600 }}>{error}</div>}

      {/* Current Plan */}
      <div className="panel">
        <div className="panel-header">
          <h3 className="panel-title">Current Plan</h3>
          <span className="chip chip--brand">{billing.planName}</span>
        </div>
        <div className="kpi-grid" style={{ marginTop: "var(--space-4)" }}>
          <article className="kpi-card">
            <span className="kpi-card-label">Current Price</span>
            <div className="kpi-card-value">{billing.monthlyPriceInr === 0 ? "Free" : money.format(billing.monthlyPriceInr)}<span style={{ fontSize: "var(--text-sm)", fontWeight: 400 }}>{billing.monthlyPriceInr === 0 ? "" : "/3 months"}</span></div>
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

      {/* Plan Catalog */}
      <div className="panel">
        <div className="panel-header">
          <h3 className="panel-title">Billing & Subscription</h3>
          <span className="panel-subtitle">Secure test checkout with Stripe</span>
        </div>

        <div className="billing-cycle-pill" aria-label="Billing interval">
          <button className="billing-cycle-pill-btn billing-cycle-pill-btn--active" type="button">3-Month Plans</button>
        </div>

        <div className="billing-plan-grid" style={{ marginTop: "var(--space-4)" }}>
          {plans.map((plan) => {
            const isActive = activePlanId === plan.id;
            const isDark = plan.id === "pro";
            const isFreePlan = plan.id === "free";
            const ctaLabel = isFreePlan
              ? (isActive ? "Current Plan" : "Switch to Free")
              : (isActive ? "Current Plan" : "Checkout with Stripe");

            return (
              <article key={plan.id} className={`billing-plan-card ${isDark ? "billing-plan-card--featured" : ""}`}>
                <div className="billing-plan-head">
                  <h4>{plan.title}</h4>
                  <span className={`billing-plan-badge ${isDark ? "billing-plan-badge--featured" : ""}`}>{plan.badge}</span>
                </div>

                <div className="billing-plan-price-wrap">
                  <span className="billing-plan-price">{plan.price === 0 ? "Free" : money.format(plan.price)}</span>
                  <span className="billing-plan-cycle">{plan.cycle}</span>
                </div>

                <p className="billing-plan-blurb">{plan.blurb}</p>

                <button
                  className={`btn ${isActive ? "btn--ghost" : "btn--primary"}`}
                  disabled={isActive || isStartingCheckout}
                  onClick={() => {
                    if (isActive) return;
                    if (isFreePlan) {
                      switchToFreePlan();
                      return;
                    }
                    startStripeCheckout(plan.id);
                  }}
                  type="button"
                >
                  {ctaLabel}
                </button>

                <ul className="billing-plan-list">
                  {plan.perks.map((perk) => (
                    <li key={perk}>{perk}</li>
                  ))}
                </ul>
              </article>
            );
          })}
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

      <AnimatePresence>
        {showSuccessPopup && (
          <motion.div
            className="billing-success-overlay"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
          >
            <motion.div
              className="billing-success-popup"
              initial={{ opacity: 0, y: 18, scale: 0.96 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              exit={{ opacity: 0, y: 10, scale: 0.98 }}
              transition={{ type: "spring", duration: 0.3, bounce: 0 }}
              role="status"
              aria-live="polite"
            >
              <button className="billing-success-close" type="button" onClick={() => setShowSuccessPopup(false)} title="Close">
                <X size={16} />
              </button>

              <span className="billing-success-icon" aria-hidden="true">
                <Sparkles size={24} />
              </span>

              <h3>Congratulations! You made it.</h3>
              <p>Your account is promoted to the plan you selected. Premium limits and controls are now unlocked.</p>
              <strong>{activatedPlanName} plan is now active</strong>

              <div className="billing-success-actions">
                <button className="btn btn--primary" type="button" onClick={() => setShowSuccessPopup(false)}>
                  <span style={{ display: "inline-flex", alignItems: "center", gap: 7 }}>
                    Continue to Dashboard <ArrowRight size={15} />
                  </span>
                </button>
                <button className="btn btn--ghost btn--sm" type="button" onClick={() => setShowSuccessPopup(false)}>I will do it later</button>
              </div>

              <span className="billing-success-footnote">
                <Check size={13} /> Payment verified securely via Stripe test mode.
              </span>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
