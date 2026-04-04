"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import EmptyState from "@/components/EmptyState";
import { SkeletonCard } from "@/components/Skeleton";

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

type PeopleWiseInsight = {
  userId: string;
  userName: string;
  debitTotal: number;
  creditTotal: number;
  netTotal: number;
  transactionCount: number;
  spendSharePct: number;
  flowSharePct: number;
};

type Pagination = {
  page: number;
  pageSize: number;
  totalTransactions: number;
  totalPages: number;
  hasPrev: boolean;
  hasNext: boolean;
};

export default function TransactionsPage() {
  const [txns, setTxns] = useState<FullTransaction[]>([]);
  const [peopleWise, setPeopleWise] = useState<PeopleWiseInsight[]>([]);
  const [totals, setTotals] = useState({ totalDebit: 0, totalCredit: 0, totalNet: 0, totalTransactions: 0 });
  const [pagination, setPagination] = useState<Pagination>({ page: 1, pageSize: 20, totalTransactions: 0, totalPages: 1, hasPrev: false, hasNext: false });
  const [loading, setLoading] = useState(true);

  // Filters
  const [year, setYear] = useState("all");
  const [month, setMonth] = useState("all");
  const [memberId, setMemberId] = useState("all");
  const [type, setType] = useState("all");
  const [category, setCategory] = useState("all");
  const [page, setPage] = useState(1);

  // Members list for filter
  const [members, setMembers] = useState<Array<{ userId: string; name: string }>>([]);

  const money = useMemo(() => new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }), []);

  const fetchMembers = useCallback(async () => {
    const res = await fetch("/api/family/summary?year=2026&month=1&memberId=all&page=1&pageSize=1", { cache: "no-store" });
    if (!res.ok) return;
    const data = await res.json().catch(() => ({}));
    if (Array.isArray(data.members)) {
      setMembers(data.members.map((m: { userId?: string; name?: string }) => ({ userId: String(m.userId ?? ""), name: String(m.name ?? "Member") })));
    }
  }, []);

  const fetchTransactions = useCallback(async () => {
    const formatLocalDate = (d: Date) => {
      const y = d.getFullYear();
      const m = String(d.getMonth() + 1).padStart(2, "0");
      const day = String(d.getDate()).padStart(2, "0");
      return `${y}-${m}-${day}`;
    };

    let from = "", to = "";
    if (year !== "all") {
      const y = Number(year);
      if (month === "all") {
        from = `${y}-01-01`; to = `${y}-12-31`;
      } else {
        const m = Number(month);
        const start = new Date(y, m - 1, 1);
        const end = new Date(y, m, 0);
        from = formatLocalDate(start);
        to = formatLocalDate(end);
      }
    }

    const params = new URLSearchParams({ page: String(page), pageSize: "20", type, memberId, category, from, to });
    const res = await fetch(`/api/transactions?${params.toString()}`, { cache: "no-store" });
    if (!res.ok) { setLoading(false); return; }

    const data = await res.json().catch(() => ({}));
    const rows = Array.isArray(data.transactions) ? data.transactions.map((t: Record<string, unknown>) => ({
      _id: String(t._id ?? ""), userId: String(t.userId ?? ""), userName: String(t.userName ?? "Member"),
      userEmail: String(t.userEmail ?? ""), amount: Number(t.amount ?? 0),
      type: t.type === "credit" ? "credit" as const : "debit" as const,
      category: String(t.category ?? "Uncategorized"), merchant: t.merchant ? String(t.merchant) : null,
      source: String(t.source ?? "manual"), txnTime: String(t.txnTime ?? ""),
    })) : [];
    setTxns(rows);

    const pw = data.peopleWise ?? {};
    const totalsRaw = pw.totals ?? {};
    setTotals({
      totalDebit: Number(totalsRaw.totalDebit ?? 0), totalCredit: Number(totalsRaw.totalCredit ?? 0),
      totalNet: Number(totalsRaw.totalNet ?? 0), totalTransactions: Number(totalsRaw.totalTransactions ?? 0),
    });
    setPeopleWise(Array.isArray(pw.members) ? pw.members.map((m: Record<string, unknown>) => ({
      userId: String(m.userId ?? ""), userName: String(m.userName ?? "Member"),
      debitTotal: Number(m.debitTotal ?? 0), creditTotal: Number(m.creditTotal ?? 0),
      netTotal: Number(m.netTotal ?? 0), transactionCount: Number(m.transactionCount ?? 0),
      spendSharePct: Number(m.spendSharePct ?? 0), flowSharePct: Number(m.flowSharePct ?? 0),
    })) : []);

    setPagination({
      page: Number(data.pagination?.page ?? 1), pageSize: Number(data.pagination?.pageSize ?? 20),
      totalTransactions: Number(data.pagination?.totalTransactions ?? 0),
      totalPages: Number(data.pagination?.totalPages ?? 1),
      hasPrev: Boolean(data.pagination?.hasPrev), hasNext: Boolean(data.pagination?.hasNext),
    });
    setLoading(false);
  }, [page, year, month, type, memberId, category]);

  useEffect(() => { fetchMembers(); }, [fetchMembers]);
  useEffect(() => { setLoading(true); fetchTransactions(); }, [fetchTransactions]);

  function clearFilters() {
    setYear("all"); setMonth("all");
    setMemberId("all"); setType("all"); setCategory("all"); setPage(1);
  }

  async function exportReport(format: "csv" | "html") {
    const formatLocalDate = (d: Date) => {
      const y = d.getFullYear();
      const m = String(d.getMonth() + 1).padStart(2, "0");
      const day = String(d.getDate()).padStart(2, "0");
      return `${y}-${m}-${day}`;
    };

    let from = "", to = "";
    if (year !== "all") {
      const y = Number(year);
      if (month === "all") { from = `${y}-01-01`; to = `${y}-12-31`; }
      else {
        const m = Number(month);
        const start = new Date(y, m - 1, 1); const end = new Date(y, m, 0);
        from = formatLocalDate(start); to = formatLocalDate(end);
      }
    }
    const params = new URLSearchParams({ format, type, memberId, category, from, to });
    const endpoint = `/api/family/transactions/report?${params.toString()}`;
    if (format === "html") { window.open(endpoint, "_blank", "noopener"); return; }
    const res = await fetch(endpoint); if (!res.ok) return;
    const blob = await res.blob(); const url = URL.createObjectURL(blob);
    const anchor = document.createElement("a"); anchor.href = url;
    anchor.download = "dhanpath-transactions.csv"; document.body.appendChild(anchor);
    anchor.click(); anchor.remove(); URL.revokeObjectURL(url);
  }

  if (loading) return <div className="stack"><SkeletonCard /><SkeletonCard /><SkeletonCard /></div>;

  const maxFlow = Math.max(1, ...peopleWise.map((m) => m.debitTotal + m.creditTotal));

  return (
    <div className="stack animate-slide">
      {/* Totals KPIs */}
      <div className="kpi-grid">
        <article className="kpi-card kpi-card--danger">
          <span className="kpi-card-label">Total Debit</span>
          <div className="kpi-card-value">{money.format(totals.totalDebit)}</div>
        </article>
        <article className="kpi-card kpi-card--success">
          <span className="kpi-card-label">Total Credit</span>
          <div className="kpi-card-value">{money.format(totals.totalCredit)}</div>
        </article>
        <article className={`kpi-card ${totals.totalNet >= 0 ? "kpi-card--info" : "kpi-card--warning"}`}>
          <span className="kpi-card-label">Net Position</span>
          <div className="kpi-card-value">{money.format(totals.totalNet)}</div>
        </article>
        <article className="kpi-card">
          <span className="kpi-card-label">Transactions</span>
          <div className="kpi-card-value">{totals.totalTransactions}</div>
        </article>
      </div>

      {/* Filters */}
      <div className="panel">
        <div className="panel-header">
          <h3 className="panel-title">Filters</h3>
          <div style={{ display: "flex", gap: "var(--space-2)" }}>
            <button className="btn btn--ghost btn--sm" onClick={clearFilters} type="button">Clear</button>
            <button className="btn btn--ghost btn--sm" onClick={() => exportReport("csv")} type="button">Export CSV</button>
            <button className="btn btn--ghost btn--sm" onClick={() => exportReport("html")} type="button">PDF View</button>
          </div>
        </div>
        <div className="form-row">
          <div className="form-group">
            <label className="form-label">Year</label>
            <select className="form-select" value={year} onChange={(e) => { setYear(e.target.value); setPage(1); }}>
              <option value="all">All Years</option>
              {[2024, 2025, 2026].map((y) => <option key={y} value={String(y)}>{y}</option>)}
            </select>
          </div>
          <div className="form-group">
            <label className="form-label">Month</label>
            <select className="form-select" value={month} onChange={(e) => { setMonth(e.target.value); setPage(1); }}>
              <option value="all">All Months</option>
              {Array.from({ length: 12 }, (_, idx) => (
                <option key={idx + 1} value={String(idx + 1)}>
                  {new Date(2026, idx, 1).toLocaleString("en-US", { month: "long" })}
                </option>
              ))}
            </select>
          </div>
          <div className="form-group">
            <label className="form-label">Member</label>
            <select className="form-select" value={memberId} onChange={(e) => { setMemberId(e.target.value); setPage(1); }}>
              <option value="all">All Members</option>
              {members.map((m) => <option key={m.userId} value={m.userId}>{m.name}</option>)}
            </select>
          </div>
          <div className="form-group">
            <label className="form-label">Type</label>
            <select className="form-select" value={type} onChange={(e) => { setType(e.target.value); setPage(1); }}>
              <option value="all">All Types</option>
              <option value="debit">Debit</option>
              <option value="credit">Credit</option>
            </select>
          </div>
        </div>
      </div>

      {/* People-wise Insights */}
      {peopleWise.length > 0 && (
        <div className="panel">
          <div className="panel-header">
            <h3 className="panel-title">People-wise Clarity</h3>
            <span className="panel-subtitle">{totals.totalTransactions} transactions</span>
          </div>
          <ul className="data-list">
            {peopleWise.map((m) => (
              <li key={m.userId} className="data-list-item" style={{ flexDirection: "column", alignItems: "stretch", gap: "var(--space-3)" }}>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                  <div style={{ display: "flex", alignItems: "center", gap: "var(--space-3)" }}>
                    <div style={{
                      width: 28, height: 28, borderRadius: "var(--radius-full)",
                      background: "linear-gradient(135deg, var(--brand-primary), var(--brand-accent))",
                      color: "white", display: "flex", alignItems: "center", justifyContent: "center",
                      fontSize: 11, fontWeight: 700,
                    }}>{m.userName?.charAt(0).toUpperCase()}</div>
                    <span style={{ fontWeight: 600, fontSize: "var(--text-sm)" }}>{m.userName}</span>
                    <span className="chip chip--neutral">{m.transactionCount} txns · {m.flowSharePct.toFixed(1)}% flow</span>
                  </div>
                  <div style={{ display: "flex", gap: "var(--space-3)", textAlign: "right" }}>
                    <strong style={{ color: "var(--color-danger)", fontSize: "var(--text-sm)" }}>-{money.format(m.debitTotal)}</strong>
                    <strong style={{ color: "var(--color-success)", fontSize: "var(--text-sm)" }}>+{money.format(m.creditTotal)}</strong>
                  </div>
                </div>
                <div style={{ display: "flex", gap: "var(--space-2)", flexDirection: "column" }}>
                  <div style={{ display: "flex", alignItems: "center", gap: "var(--space-2)" }}>
                    <span style={{ fontSize: "var(--text-xs)", color: "var(--text-tertiary)", width: 40 }}>Debit</span>
                    <div className="bar-track" style={{ flex: 1 }}>
                      <div className="bar-fill debit-flow" style={{ width: `${Math.max(6, (m.debitTotal / maxFlow) * 100)}%` }} />
                    </div>
                  </div>
                  <div style={{ display: "flex", alignItems: "center", gap: "var(--space-2)" }}>
                    <span style={{ fontSize: "var(--text-xs)", color: "var(--text-tertiary)", width: 40 }}>Credit</span>
                    <div className="bar-track" style={{ flex: 1 }}>
                      <div className="bar-fill credit-flow" style={{ width: `${Math.max(6, (m.creditTotal / maxFlow) * 100)}%` }} />
                    </div>
                  </div>
                </div>
              </li>
            ))}
          </ul>
        </div>
      )}

      {/* Transaction List */}
      <div className="panel">
        <div className="panel-header">
          <h3 className="panel-title">All Transactions</h3>
        </div>
        {txns.length === 0 ? (
          <EmptyState icon="💳" title="No transactions found" subtitle="Try adjusting your filters" />
        ) : (
          <>
            <ul className="data-list">
              {txns.map((txn) => (
                <li key={txn._id} className="data-list-item">
                  <div className="data-list-main">
                    <div style={{ display: "flex", alignItems: "center", gap: "var(--space-2)", flexWrap: "wrap" }}>
                      <span style={{ fontWeight: 600, fontSize: "var(--text-sm)" }}>{txn.merchant ?? txn.category}</span>
                      <span className={`chip chip--${txn.type === "credit" ? "credit" : "debit"}`}>{txn.type.toUpperCase()}</span>
                      <span className="chip chip--neutral">{txn.source}</span>
                    </div>
                    <span style={{ fontSize: "var(--text-xs)", color: "var(--text-tertiary)" }}>
                      {txn.userName} · {txn.category} · {new Date(txn.txnTime).toLocaleString()}
                    </span>
                  </div>
                  <strong style={{
                    fontSize: "var(--text-md)", fontWeight: 700,
                    color: txn.type === "credit" ? "var(--color-success)" : "var(--color-danger)",
                    whiteSpace: "nowrap",
                  }}>
                    {txn.type === "credit" ? "+" : "-"}{money.format(txn.amount)}
                  </strong>
                </li>
              ))}
            </ul>
            <div className="pager">
              <button className="btn btn--ghost btn--sm" disabled={!pagination.hasPrev} onClick={() => setPage((p) => Math.max(1, p - 1))} type="button">← Previous</button>
              <span className="pager-info">Page {pagination.page} of {pagination.totalPages} · {pagination.totalTransactions} total</span>
              <button className="btn btn--ghost btn--sm" disabled={!pagination.hasNext} onClick={() => setPage((p) => p + 1)} type="button">Next →</button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
