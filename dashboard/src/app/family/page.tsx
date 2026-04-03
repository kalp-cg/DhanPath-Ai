"use client";

import { FormEvent, useCallback, useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";

type User = { id: string; email: string; name: string; familyId: string | null };

type Summary = {
  familyId: string;
  familyName: string;
  inviteCode: string;
  totalMonthlySpend: number;
  memberBreakdown: Array<{ userId: string; name: string; role: string; monthlySpend: number }>;
  topCategories: Array<{ category: string; amount: number }>;
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
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const hasFamily = useMemo(() => Boolean(user?.familyId), [user?.familyId]);

  const fetchMe = useCallback(async () => {
    const res = await fetch("/api/auth/me", { cache: "no-store" });
    const data = await res.json();
    if (!data.user) {
      router.replace("/auth");
      return null;
    }
    setUser(data.user);
    return data.user as User;
  }, [router]);

  const fetchSummary = useCallback(async () => {
    const res = await fetch("/api/family/summary", { cache: "no-store" });
    if (!res.ok) {
      setSummary(null);
      return;
    }
    const data = await res.json();
    setSummary(data);
  }, []);

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
            <h2>{summary?.familyName ?? "Family"}</h2>
            <p>
              Invite Code: <strong>{summary?.inviteCode ?? "-"}</strong>
            </p>
            <p>
              Monthly Spend: <strong>Rs {summary?.totalMonthlySpend?.toFixed(2) ?? "0.00"}</strong>
            </p>
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
          </section>

          <section className="panel grid-two">
            <div>
              <h3>Member Spend</h3>
              <ul className="list">
                {summary?.memberBreakdown?.map((m) => (
                  <li key={m.userId}>
                    <span>{m.name}</span>
                    <strong>Rs {m.monthlySpend.toFixed(2)}</strong>
                  </li>
                )) ?? <li>No members yet.</li>}
              </ul>
            </div>

            <div>
              <h3>Top Categories</h3>
              <ul className="list">
                {summary?.topCategories?.map((c) => (
                  <li key={c.category}>
                    <span>{c.category}</span>
                    <strong>Rs {c.amount.toFixed(2)}</strong>
                  </li>
                )) ?? <li>No spending yet.</li>}
              </ul>
            </div>
          </section>

          <section className="panel">
            <h3>Recent Transactions</h3>
            <ul className="list">
              {summary?.recentTransactions?.map((t) => (
                <li key={t.id}>
                  <span>
                    {t.userName} · {t.category} · {new Date(t.txnTime).toLocaleString()}
                  </span>
                  <strong>Rs {Number(t.amount).toFixed(2)}</strong>
                </li>
              )) ?? <li>No transactions yet.</li>}
            </ul>
          </section>
        </>
      )}
    </main>
  );
}
