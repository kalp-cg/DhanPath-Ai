"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import EmptyState from "@/components/EmptyState";
import KPICard from "@/components/KPICard";
import { SkeletonCard } from "@/components/Skeleton";

type CommandCenterResponse = {
  family: {
    id: string;
    name: string;
    members: number;
    activeMembers30d: number;
  };
  billing: {
    planId: string;
    planName: string;
    status: string;
    monthlyPriceInr: number;
    monthlyTxnLimit: number;
    usageUsed: number;
    usagePct: number;
  };
  metrics: {
    totalTransactionsAllTime: number;
    debitAllTime: number;
    creditAllTime: number;
    spend30: number;
    income30: number;
    net30: number;
    spendGrowthPct: number;
    avgDebitTicket30: number;
    automationRate30: number;
    anomalyCount30: number;
    dataFreshnessHours: number | null;
  };
  sourceMix30: Array<{ source: string; count: number; sharePct: number }>;
  topCategories30: Array<{ category: string; amount: number; sharePct: number }>;
  memberStats30: Array<{
    userId: string;
    name: string;
    role: "admin" | "member";
    spend30: number;
    income30: number;
    txnCount30: number;
    lastTxnAt: string | null;
    spendSharePct: number;
  }>;
  weeklySeries: Array<{ label: string; spend: number; income: number }>;
  alerts: Array<{ id: string; severity: "info" | "warning" | "critical"; title: string; detail: string }>;
  generatedAt: string;
};

function severityChip(severity: "info" | "warning" | "critical") {
  if (severity === "critical") return "chip chip--debit";
  if (severity === "warning") return "chip chip--warning";
  return "chip chip--info";
}

export default function CommandCenterPage() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [data, setData] = useState<CommandCenterResponse | null>(null);
  const [isAdmin, setIsAdmin] = useState<boolean | null>(null);

  const money = useMemo(
    () =>
      new Intl.NumberFormat("en-IN", {
        style: "currency",
        currency: "INR",
        maximumFractionDigits: 0,
      }),
    [],
  );

  const fetchCommandCenter = useCallback(async () => {
    if (isAdmin === false) return;
    setLoading(true);
    setError(null);

    try {
      const res = await fetch("/api/dashboard/command-center", { cache: "no-store" });
      const payload = await res.json().catch(() => ({}));

      if (!res.ok) {
        if (res.status === 403) {
          setError("Command Center is available only for family admins.");
        } else {
          setError(typeof payload?.error === "string" ? payload.error : "Failed to load command center.");
        }
        setData(null);
        return;
      }

      setData(payload as CommandCenterResponse);
    } catch {
      setError("Unable to reach command center service. Please retry.");
      setData(null);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    let canceled = false;

    async function bootstrap() {
      const now = new Date();
      const params = new URLSearchParams({
        year: String(now.getFullYear()),
        month: String(now.getMonth() + 1),
        memberId: "all",
        page: "1",
        pageSize: "1",
      });

      try {
        const res = await fetch(`/api/family/summary?${params.toString()}`, { cache: "no-store" });
        if (!res.ok) {
          if (!canceled) {
            setLoading(false);
            setError("Unable to verify admin access for command center.");
          }
          return;
        }
        const summary = await res.json().catch(() => ({}));
        const admin = Boolean(summary?.isCurrentUserAdmin);
        if (!canceled) setIsAdmin(admin);
      } catch {
        if (!canceled) {
          setLoading(false);
          setError("Unable to verify admin access for command center.");
        }
      }
    }

    bootstrap();
    return () => {
      canceled = true;
    };
  }, []);

  useEffect(() => {
    if (isAdmin === null) return;
    if (isAdmin === false) {
      setLoading(false);
      setError("Command Center is available only for family admins.");
      return;
    }

    fetchCommandCenter();
    const interval = setInterval(fetchCommandCenter, 30000);
    return () => clearInterval(interval);
  }, [fetchCommandCenter, isAdmin]);

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

  if (error) {
    return (
      <EmptyState
        icon="warn"
        title="Unable to load Command Center"
        subtitle={error}
        actionLabel="Retry"
        onAction={fetchCommandCenter}
      />
    );
  }

  if (!data) {
    return <EmptyState icon="chart" title="No command center data" subtitle="Transactions are required to generate metrics." />;
  }

  const trendMax = Math.max(
    1,
    ...data.weeklySeries.map((item) => Math.max(item.spend, item.income)),
  );

  return (
    <div className="stack animate-slide">
      <section className="command-hero panel">
        <div>
          <p className="command-kicker">Founder Dashboard</p>
          <h2 className="command-title">Command Center</h2>
          <p className="command-subtitle">
            Real-time family finance pulse for {data.family.name}. Last updated {new Date(data.generatedAt).toLocaleString()}.
          </p>
        </div>
        <div className="command-hero-meta">
          <span className="chip chip--brand">{data.billing.planName}</span>
          <span className="chip chip--neutral">{data.family.activeMembers30d}/{data.family.members} active in 30d</span>
          <span className="chip chip--warning">Quota {data.billing.usagePct}%</span>
        </div>
      </section>

      <div className="kpi-grid">
        <KPICard icon="spend" label="Spend (30d)" value={money.format(data.metrics.spend30)} variant="danger" />
        <KPICard icon="income" label="Income (30d)" value={money.format(data.metrics.income30)} variant="success" />
        <KPICard icon="growth" label="Spend Growth" value={`${data.metrics.spendGrowthPct}%`} variant="warning" />
        <KPICard icon="auto" label="Automation Rate" value={`${data.metrics.automationRate30}%`} variant="info" />
      </div>

      <div className="grid-2">
        <section className="panel">
          <div className="panel-header">
            <h3 className="panel-title">Risk Radar</h3>
            <span className="panel-subtitle">Live Alerts</span>
          </div>
          <div className="command-alerts">
            {data.alerts.map((alert) => (
              <article key={alert.id} className="command-alert">
                <div className="command-alert-head">
                  <strong>{alert.title}</strong>
                  <span className={severityChip(alert.severity)}>{alert.severity}</span>
                </div>
                <p>{alert.detail}</p>
              </article>
            ))}
          </div>
        </section>

        <section className="panel">
          <div className="panel-header">
            <h3 className="panel-title">Operational Health</h3>
            <span className="panel-subtitle">System + Billing</span>
          </div>
          <div className="command-health-grid">
            <div className="command-health-card">
              <span>Net Cashflow (30d)</span>
              <strong>{money.format(data.metrics.net30)}</strong>
            </div>
            <div className="command-health-card">
              <span>Average Debit Ticket</span>
              <strong>{money.format(data.metrics.avgDebitTicket30)}</strong>
            </div>
            <div className="command-health-card">
              <span>Anomaly Signals</span>
              <strong>{data.metrics.anomalyCount30}</strong>
            </div>
            <div className="command-health-card">
              <span>Data Freshness</span>
              <strong>
                {data.metrics.dataFreshnessHours === null
                  ? "No data"
                  : `${data.metrics.dataFreshnessHours} hrs`}
              </strong>
            </div>
          </div>
        </section>
      </div>

      <div className="grid-2">
        <section className="panel">
          <div className="panel-header">
            <h3 className="panel-title">Weekly Velocity</h3>
            <span className="panel-subtitle">Last 8 Weeks</span>
          </div>
          <div className="command-velocity">
            {data.weeklySeries.map((item) => (
              <div key={item.label} className="command-velocity-col">
                <div className="command-velocity-bars">
                  <div
                    className="command-bar command-bar--income"
                    style={{ height: `${Math.max(6, (item.income / trendMax) * 120)}px` }}
                    title={`Income ${money.format(item.income)}`}
                  />
                  <div
                    className="command-bar command-bar--spend"
                    style={{ height: `${Math.max(6, (item.spend / trendMax) * 120)}px` }}
                    title={`Spend ${money.format(item.spend)}`}
                  />
                </div>
                <span className="command-velocity-label">{item.label}</span>
              </div>
            ))}
          </div>
        </section>

        <section className="panel">
          <div className="panel-header">
            <h3 className="panel-title">Source Funnel</h3>
            <span className="panel-subtitle">30 Day Capture Mix</span>
          </div>
          {data.sourceMix30.length === 0 ? (
            <EmptyState icon="sources" title="No source data" subtitle="No transactions captured in this period." />
          ) : (
            <ul className="data-list">
              {data.sourceMix30.map((item) => (
                <li key={item.source} className="data-list-item">
                  <div className="data-list-main">
                    <strong style={{ fontSize: "var(--text-sm)" }}>{item.source.toUpperCase()}</strong>
                    <div className="bar-track">
                      <div className="bar-fill trend" style={{ width: `${Math.max(8, item.sharePct)}%` }} />
                    </div>
                  </div>
                  <span style={{ whiteSpace: "nowrap" }}>{item.count} ({item.sharePct}%)</span>
                </li>
              ))}
            </ul>
          )}
        </section>
      </div>

      <div className="grid-2">
        <section className="panel">
          <div className="panel-header">
            <h3 className="panel-title">Top Categories</h3>
            <span className="panel-subtitle">Debits in 30 Days</span>
          </div>
          {data.topCategories30.length === 0 ? (
            <EmptyState icon="categories" title="No category distribution" subtitle="No debit transactions found in last 30 days." />
          ) : (
            <ul className="data-list">
              {data.topCategories30.map((item) => (
                <li key={item.category} className="data-list-item">
                  <div className="data-list-main">
                    <strong style={{ fontSize: "var(--text-sm)" }}>{item.category}</strong>
                    <div className="bar-track">
                      <div className="bar-fill category" style={{ width: `${Math.max(8, item.sharePct)}%` }} />
                    </div>
                  </div>
                  <span style={{ whiteSpace: "nowrap" }}>{money.format(item.amount)}</span>
                </li>
              ))}
            </ul>
          )}
        </section>

        <section className="panel">
          <div className="panel-header">
            <h3 className="panel-title">Member Command Board</h3>
            <span className="panel-subtitle">Last 30 Days</span>
          </div>
          {data.memberStats30.length === 0 ? (
            <EmptyState icon="members" title="No member stats" subtitle="Invite members and sync transactions to unlock this panel." />
          ) : (
            <ul className="data-list">
              {data.memberStats30.map((member) => (
                <li key={member.userId} className="data-list-item">
                  <div className="data-list-main">
                    <div className="command-member-row">
                      <strong>{member.name}</strong>
                      <span className={member.role === "admin" ? "chip chip--warning" : "chip chip--neutral"}>{member.role}</span>
                    </div>
                    <div className="command-member-meta">
                      <span>Spend {money.format(member.spend30)}</span>
                      <span>{member.txnCount30} txns</span>
                      <span>{member.spendSharePct}% share</span>
                    </div>
                    <div className="bar-track">
                      <div className="bar-fill people" style={{ width: `${Math.max(8, member.spendSharePct)}%` }} />
                    </div>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </section>
      </div>
    </div>
  );
}
