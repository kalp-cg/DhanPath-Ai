"use client";

import { FormEvent, useCallback, useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";

type User = { id: string; email: string; name: string; familyId: string | null };

type Summary = {
  familyId: string;
  familyName: string;
  inviteCode: string;
  selectedYear: number;
  selectedMonth: number;
  availableYears: number[];
  totalMonthlySpend: number;
  memberBreakdown: Array<{ userId: string; name: string; role: string; monthlySpend: number }>;
  topCategories: Array<{ category: string; amount: number }>;
  monthlyTimeline: Array<{ month: number; label: string; amount: number }>;
  yearlyTotals: Array<{ year: number; amount: number }>;
  recentTransactions: Array<{
    id: string;
    userName: string;
    amount: number;
    type: "debit" | "credit";
    category: string;
    source: string;
    txnTime: string;
  }>;
};

export default function FamilyPage() {
  const router = useRouter();
  const [user, setUser] = useState<User | null>(null);
  const [summary, setSummary] = useState<Summary | null>(null);
  const [familyName, setFamilyName] = useState("My Family");
  const [inviteCode, setInviteCode] = useState("");
  const [amount, setAmount] = useState("0");
  const [category, setCategory] = useState("General");
  const [selectedYear, setSelectedYear] = useState(() => new Date().getFullYear());
  const [selectedMonth, setSelectedMonth] = useState(() => new Date().getMonth() + 1);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const money = useMemo(
    () =>
      new Intl.NumberFormat("en-IN", {
        style: "currency",
        currency: "INR",
        maximumFractionDigits: 0,
      }),
    [],
  );

  const hasFamily = useMemo(() => Boolean(user?.familyId), [user?.familyId]);
  const monthTitle = useMemo(
    () => new Date(selectedYear, selectedMonth - 1, 1).toLocaleString("en-US", { month: "long" }),
    [selectedYear, selectedMonth],
  );

  const analytics = useMemo(() => {
    if (!summary) {
      return {
        maxMemberSpend: 1,
        maxCategorySpend: 1,
        maxMonthSpend: 1,
        maxYearSpend: 1,
        totalYearSpend: 0,
        avgMonthlySpend: 0,
        projectedMonthEnd: 0,
        topSpender: null as { userId: string; name: string; role: string; monthlySpend: number } | null,
      };
    }

    const maxMemberSpend = Math.max(1, ...summary.memberBreakdown.map((m) => m.monthlySpend));
    const maxCategorySpend = Math.max(1, ...summary.topCategories.map((c) => c.amount));
    const maxMonthSpend = Math.max(1, ...summary.monthlyTimeline.map((m) => m.amount));
    const maxYearSpend = Math.max(1, ...summary.yearlyTotals.map((y) => y.amount));

    const totalYearSpend = summary.monthlyTimeline.reduce((sum, m) => sum + m.amount, 0);
    const activeMonths = summary.monthlyTimeline.filter((m) => m.amount > 0).length || 1;
    const avgMonthlySpend = totalYearSpend / activeMonths;

    const daysInMonth = new Date(selectedYear, selectedMonth, 0).getDate();
    const observedDays = Math.max(1, new Date().getDate());
    const projectedMonthEnd = (summary.totalMonthlySpend / observedDays) * daysInMonth;

    const topSpender =
      summary.memberBreakdown.length > 0
        ? [...summary.memberBreakdown].sort((a, b) => b.monthlySpend - a.monthlySpend)[0]
        : null;

    return {
      maxMemberSpend,
      maxCategorySpend,
      maxMonthSpend,
      maxYearSpend,
      totalYearSpend,
      avgMonthlySpend,
      projectedMonthEnd,
      topSpender,
    };
  }, [selectedMonth, selectedYear, summary]);

  const fetchMe = useCallback(async () => {
    const res = await fetch("/api/auth/me", { cache: "no-store" });
    const data = await res.json();
    if (!data.user) {
      router.replace("/auth");
      return null;
    }
    setUser(data.user);
    return data.user as User;
  }, [router, setUser]);

  const fetchSummary = useCallback(async () => {
    const params = new URLSearchParams({
      year: String(selectedYear),
      month: String(selectedMonth),
    });
    const res = await fetch(`/api/family/summary?${params.toString()}`, { cache: "no-store" });
    if (!res.ok) {
      setSummary(null);
      return;
    }
    const data = await res.json();
    setSummary(data);
  }, [selectedYear, selectedMonth, setSummary]);

  useEffect(() => {
    let mounted = true;

    async function boot() {
      const me = await fetchMe();
      if (mounted && me?.familyId) {
        await fetchSummary();
      }
    }

    boot();
    const interval = setInterval(fetchSummary, 5000);
    return () => {
      mounted = false;
      clearInterval(interval);
    };
  }, [fetchMe, fetchSummary]);

  async function createFamily(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);

    const res = await fetch("/api/family/create", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name: familyName }),
    });
    const data = await res.json().catch(() => ({}));

    if (!res.ok) {
      setError(data.error ?? "could not create family");
      setBusy(false);
      return;
    }

    await fetchMe();
    await fetchSummary();
    setBusy(false);
  }

  async function joinFamily(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);

    const res = await fetch("/api/family/join", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ inviteCode }),
    });
    const data = await res.json().catch(() => ({}));

    if (!res.ok) {
      setError(data.error ?? "could not join family");
      setBusy(false);
      return;
    }

    await fetchMe();
    await fetchSummary();
    setBusy(false);
  }

  async function addTransaction(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);

    const res = await fetch("/api/transactions", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ amount: Number(amount), category, type: "debit", source: "manual" }),
    });
    const data = await res.json().catch(() => ({}));

    if (!res.ok) {
      setError(data.error ?? "could not add transaction");
      setBusy(false);
      return;
    }

    setAmount("0");
    await fetchSummary();
    setBusy(false);
  }

  async function logout() {
    await fetch("/api/auth/logout", { method: "POST" });
    router.replace("/auth");
  }

  async function copyInviteCode() {
    if (!summary?.inviteCode) return;
    try {
      await navigator.clipboard.writeText(summary.inviteCode);
      setError(null);
    } catch {
      setError("could not copy invite code");
    }
  }

  const storyText = useMemo(() => {
    if (!summary) return "No data yet.";
    const topCategory = summary.topCategories[0];
    const topCatText = topCategory
      ? `${topCategory.category} led with ${money.format(topCategory.amount)}.`
      : "No major category spikes yet.";

    const topSpenderText = analytics.topSpender
      ? `${analytics.topSpender.name} contributed most at ${money.format(analytics.topSpender.monthlySpend)}.`
      : "No member trend yet.";

    return `${monthTitle} spend is ${money.format(summary.totalMonthlySpend)}. ${topCatText} ${topSpenderText}`;
  }, [analytics.topSpender, money, monthTitle, summary]);

  const suggestions = useMemo(() => {
    if (!summary) return [] as string[];
    const topCategory = summary.topCategories[0];
    const next1 = topCategory
      ? `Cap ${topCategory.category} by 10% to save about ${money.format(topCategory.amount * 0.1)} next month.`
      : "Add at least 10 transactions to unlock category optimization.";

    const next2 =
      analytics.projectedMonthEnd > summary.totalMonthlySpend
        ? `At current pace, month-end may reach ${money.format(analytics.projectedMonthEnd)}. Set a weekly review reminder.`
        : "Current pace is stable. Keep daily entries to maintain clean forecasting.";

    const next3 =
      summary.memberBreakdown.length > 1
        ? "Assign category owners per person to improve accountability and reduce overlap spending."
        : "Invite family members and enable one-tap sync to see true people-wise spend analytics.";

    return [next1, next2, next3];
  }, [analytics.projectedMonthEnd, money, summary]);

  return (
    <main className="shell family-shell">
      <section className="panel header-panel">
        <div>
          <h1>Family Workspace</h1>
          <p>{user ? `${user.name} (${user.email})` : "Loading user..."}</p>
        </div>
        <button className="ghost" onClick={logout} type="button">
          Logout
        </button>
      </section>

      {!hasFamily ? (
        <section className="panel stack">
          <h2>Create or Join Family</h2>

          <form className="form-grid" onSubmit={createFamily}>
            <label>
              Family Name
              <input value={familyName} onChange={(e) => setFamilyName(e.target.value)} />
            </label>
            <button className="primary" disabled={busy} type="submit">
              Create Family
            </button>
          </form>

          <form className="form-grid" onSubmit={joinFamily}>
            <label>
              Invite Code
              <input value={inviteCode} onChange={(e) => setInviteCode(e.target.value)} placeholder="ABC123" />
            </label>
            <button className="secondary" disabled={busy} type="submit">
              Join Family
            </button>
          </form>

          {error && <p className="error">{error}</p>}
        </section>
      ) : (
        <>
          <section className="panel metrics">
            <div className="metrics-top">
              <div>
                <h2>{summary?.familyName ?? "Family"}</h2>
                <p>
                  Invite Code: <strong>{summary?.inviteCode ?? "-"}</strong>
                </p>
              </div>
              <button className="ghost" type="button" onClick={copyInviteCode}>
                Copy Invite
              </button>
            </div>

            <div className="kpi-grid">
              <article className="kpi-card">
                <p>Total Spend ({monthTitle})</p>
                <h3>{money.format(summary?.totalMonthlySpend ?? 0)}</h3>
              </article>
              <article className="kpi-card">
                <p>Projected Month End</p>
                <h3>{money.format(analytics.projectedMonthEnd)}</h3>
              </article>
              <article className="kpi-card">
                <p>Avg Active Month</p>
                <h3>{money.format(analytics.avgMonthlySpend)}</h3>
              </article>
              <article className="kpi-card">
                <p>Top Spender</p>
                <h3>{analytics.topSpender?.name ?? "-"}</h3>
              </article>
            </div>
          </section>

          <section className="panel filter-panel">
            <div className="filter-row">
              <label>
                Year
                <select value={selectedYear} onChange={(e) => setSelectedYear(Number(e.target.value))}>
                  {(summary?.availableYears ?? [selectedYear]).map((year) => (
                    <option key={year} value={year}>
                      {year}
                    </option>
                  ))}
                </select>
              </label>
              <label>
                Month
                <select value={selectedMonth} onChange={(e) => setSelectedMonth(Number(e.target.value))}>
                  {Array.from({ length: 12 }, (_, idx) => (
                    <option key={idx + 1} value={idx + 1}>
                      {new Date(2026, idx, 1).toLocaleString("en-US", { month: "long" })}
                    </option>
                  ))}
                </select>
              </label>
            </div>
          </section>

          <section className="panel stack">
            <h3>Add Manual Transaction</h3>
            <form className="inline-form" onSubmit={addTransaction}>
              <input
                type="number"
                step="0.01"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                placeholder="Amount"
              />
              <input value={category} onChange={(e) => setCategory(e.target.value)} placeholder="Category" />
              <button className="primary" disabled={busy} type="submit">
                Add
              </button>
            </form>
            {error && <p className="error">{error}</p>}
          </section>

          <section className="panel grid-two">
            <div>
              <h3>People-wise Payment Split</h3>
              <ul className="list">
                {summary?.memberBreakdown?.map((m) => (
                  <li key={m.userId}>
                    <div className="list-main">
                      <span>
                        {m.name} <small>({m.role})</small>
                      </span>
                      <div className="bar-track">
                        <div
                          className="bar-fill people"
                          style={{ width: `${Math.max(6, (m.monthlySpend / analytics.maxMemberSpend) * 100)}%` }}
                        />
                      </div>
                    </div>
                    <strong>{money.format(m.monthlySpend)}</strong>
                  </li>
                )) ?? <li>No members yet.</li>}
              </ul>
            </div>

            <div>
              <h3>Top Categories ({monthTitle})</h3>
              <ul className="list">
                {summary?.topCategories?.map((c) => (
                  <li key={c.category}>
                    <div className="list-main">
                      <span>{c.category}</span>
                      <div className="bar-track">
                        <div
                          className="bar-fill category"
                          style={{ width: `${Math.max(8, (c.amount / analytics.maxCategorySpend) * 100)}%` }}
                        />
                      </div>
                    </div>
                    <strong>{money.format(c.amount)}</strong>
                  </li>
                )) ?? <li>No spending yet.</li>}
              </ul>
            </div>
          </section>

          <section className="panel grid-two">
            <div>
              <h3>Month-wise Spend ({selectedYear})</h3>
              <ul className="list">
                {summary?.monthlyTimeline?.map((m) => (
                  <li key={m.month}>
                    <div className="list-main">
                      <span>{m.label}</span>
                      <div className="bar-track">
                        <div
                          className="bar-fill trend"
                          style={{ width: `${Math.max(4, (m.amount / analytics.maxMonthSpend) * 100)}%` }}
                        />
                      </div>
                    </div>
                    <strong>{money.format(m.amount)}</strong>
                  </li>
                )) ?? <li>No monthly data yet.</li>}
              </ul>
            </div>

            <div>
              <h3>Year-wise Spend</h3>
              <ul className="list">
                {summary?.yearlyTotals?.map((y) => (
                  <li key={y.year}>
                    <div className="list-main">
                      <span>{y.year}</span>
                      <div className="bar-track">
                        <div
                          className="bar-fill year"
                          style={{ width: `${Math.max(8, (y.amount / analytics.maxYearSpend) * 100)}%` }}
                        />
                      </div>
                    </div>
                    <strong>{money.format(y.amount)}</strong>
                  </li>
                )) ?? <li>No yearly data yet.</li>}
              </ul>
            </div>
          </section>

          <section className="panel story-panel">
            <h3>Spending Story and Suggestions</h3>
            <p>{storyText}</p>
            <ul className="suggest-grid">
              {suggestions.map((item) => (
                <li key={item}>{item}</li>
              ))}
            </ul>
          </section>

          <section className="panel">
            <h3>
              Transactions for {monthTitle} {selectedYear}
            </h3>
            <ul className="list txn-list">
              {summary?.recentTransactions?.map((t) => (
                <li key={t.id}>
                  <div className="list-main">
                    <span>
                      {t.userName} · {t.category} · {new Date(t.txnTime).toLocaleString()}
                    </span>
                    <small className={`chip ${t.type === "credit" ? "credit" : "debit"}`}>
                      {t.type.toUpperCase()} · {t.source}
                    </small>
                  </div>
                  <strong>{money.format(Number(t.amount))}</strong>
                </li>
              )) ?? <li>No transactions yet.</li>}
            </ul>
          </section>
        </>
      )}
    </main>
  );
}
