"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";

import { ForecastResult } from "@/lib/forecast";
import { createSupabaseBrowserClient } from "@/lib/supabase-browser";
import { FamilySummary } from "@/types/family";

type ApiState = {
  summary: FamilySummary | null;
  forecast: ForecastResult | null;
  loading: boolean;
  error: string | null;
};

export default function FamilyDashboardPage() {
  const [state, setState] = useState<ApiState>({
    summary: null,
    forecast: null,
    loading: true,
    error: null,
  });

  useEffect(() => {
    let active = true;

    async function load() {
      try {
        const supabase = createSupabaseBrowserClient();
        const {
          data: { session },
        } = await supabase.auth.getSession();

        if (!session?.access_token) {
          if (!active) return;
          setState({
            summary: null,
            forecast: null,
            loading: false,
            error: "Please sign in first to access family data.",
          });
          return;
        }

        const summaryRes = await fetch("/api/family/summary", {
          cache: "no-store",
          headers: {
            Authorization: `Bearer ${session.access_token}`,
          },
        });

        if (!summaryRes.ok) {
          const err = (await summaryRes.json()) as { error?: string };
          throw new Error(err.error ?? "Summary API failed");
        }

        const summary = (await summaryRes.json()) as FamilySummary;

        const now = new Date();
        const daysInMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
        const forecastRes = await fetch(
          `/api/forecast?monthlyBudget=40000&spentSoFar=${summary.totalMonthlySpend}&daysElapsed=${now.getDate()}&daysInMonth=${daysInMonth}`,
          { cache: "no-store" },
        );
        const forecast = (await forecastRes.json()) as ForecastResult;

        if (!active) return;
        setState({ summary, forecast, loading: false, error: null });
      } catch (error) {
        if (!active) return;
        setState({
          summary: null,
          forecast: null,
          loading: false,
          error: error instanceof Error ? error.message : "Failed to load dashboard",
        });
      }
    }

    load();
    return () => {
      active = false;
    };
  }, []);

  const maxSpend = useMemo(() => {
    if (!state.summary || state.summary.memberBreakdown.length === 0) return 1;
    return Math.max(...state.summary.memberBreakdown.map((m) => m.monthlySpend), 1);
  }, [state.summary]);

  if (state.loading) {
    return <div className="page-shell">Loading family dashboard...</div>;
  }

  if (state.error || !state.summary || !state.forecast) {
    return (
      <div className="page-shell">
        <section className="card">
          <h2>Could not load dashboard</h2>
          <p>{state.error ?? "Try again."}</p>
          <div className="chips" style={{ marginTop: 12 }}>
            <Link className="cta primary" href="/auth">
              Sign In
            </Link>
          </div>
        </section>
      </div>
    );
  }

  return (
    <div className="page-shell">
      <header className="hero">
        <p className="eyebrow">DhanPath Family Control Room</p>
        <h1>{state.summary.familyName}</h1>
        <p>
          Total spend this month: <strong>Rs {state.summary.totalMonthlySpend.toLocaleString("en-IN")}</strong>
        </p>
        <p>
          Data source: <strong>{state.summary.source}</strong>
        </p>
      </header>

      <section className="grid two">
        <article className="card">
          <h2>Member Spend</h2>
          {state.summary.memberBreakdown.map((member) => (
            <div key={member.userId} className="bar-row">
              <div className="bar-label">
                <span>{member.name}</span>
                <span>{member.role}</span>
              </div>
              <div className="bar-track">
                <div
                  className="bar-fill"
                  style={{ width: `${Math.max(8, (member.monthlySpend / maxSpend) * 100)}%` }}
                />
              </div>
              <div className="bar-value">Rs {member.monthlySpend.toLocaleString("en-IN")}</div>
            </div>
          ))}
        </article>

        <article className="card">
          <h2>Budget Runway</h2>
          <p>Burn rate/day: Rs {Math.round(state.forecast.burnRatePerDay).toLocaleString("en-IN")}</p>
          <p>Projected monthly spend: Rs {Math.round(state.forecast.projectedMonthSpend).toLocaleString("en-IN")}</p>
          <p>
            Exhaustion day: {state.forecast.projectedBudgetExhaustionDay
              ? `Day ${state.forecast.projectedBudgetExhaustionDay}`
              : "Within budget"}
          </p>
          <p className={state.forecast.willExhaustInMonth ? "warn" : "safe"}>
            {state.forecast.willExhaustInMonth
              ? "Warning: Current pace may exhaust budget this month"
              : "Healthy pace: Budget likely to remain in range"}
          </p>
        </article>
      </section>

      <section className="card">
        <h2>Top Categories</h2>
        <div className="chips">
          {state.summary.topCategories.map((item) => (
            <span key={item.category} className="chip">
              {item.category}: Rs {item.amount.toLocaleString("en-IN")}
            </span>
          ))}
        </div>
      </section>
    </div>
  );
}
