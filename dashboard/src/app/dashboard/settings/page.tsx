"use client";

import { FormEvent, useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import EmptyState from "@/components/EmptyState";

type User = { id: string; email: string; name: string; familyId: string | null };

export default function SettingsPage() {
  const router = useRouter();
  const [user, setUser] = useState<User | null>(null);
  const [familyName, setFamilyName] = useState("My Family");
  const [inviteCode, setInviteCode] = useState("");
  const [amount, setAmount] = useState("0");
  const [category, setCategory] = useState("General");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const fetchMe = useCallback(async () => {
    const res = await fetch("/api/auth/me", { cache: "no-store" });
    const data = await res.json();
    if (!data.user) { router.replace("/auth"); return; }
    setUser(data.user);
  }, [router]);

  useEffect(() => { fetchMe(); }, [fetchMe]);

  async function createFamily(e: FormEvent) {
    e.preventDefault(); setBusy(true); setError(null); setSuccess(null);
    const res = await fetch("/api/family/create", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ name: familyName }) });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) { setError(data.error ?? "Could not create family"); setBusy(false); return; }
    setSuccess("Family created!"); await fetchMe(); setBusy(false);
  }

  async function joinFamily(e: FormEvent) {
    e.preventDefault(); setBusy(true); setError(null); setSuccess(null);
    const res = await fetch("/api/family/join", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ inviteCode }) });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) { setError(data.error ?? "Could not join family"); setBusy(false); return; }
    setSuccess("Joined family!"); await fetchMe(); setBusy(false);
  }

  async function addTransaction(e: FormEvent) {
    e.preventDefault(); setBusy(true); setError(null);
    const res = await fetch("/api/transactions", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ amount: Number(amount), category, type: "debit", source: "manual" }) });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) { setError(data.error ?? "Could not add transaction"); setBusy(false); return; }
    setSuccess("Transaction added!"); setAmount("0"); setBusy(false);
  }

  async function logout() {
    await fetch("/api/auth/logout", { method: "POST" });
    router.replace("/auth");
  }

  return (
    <div className="stack animate-slide">
      {/* Profile */}
      <div className="panel">
        <div className="panel-header">
          <h3 className="panel-title">Profile</h3>
        </div>
        {user ? (
          <div style={{ display: "flex", alignItems: "center", gap: "var(--space-5)" }}>
            <div style={{ width: 56, height: 56, borderRadius: "var(--radius-full)", background: "linear-gradient(135deg, var(--brand-primary), var(--brand-accent))", color: "white", display: "flex", alignItems: "center", justifyContent: "center", fontSize: "var(--text-xl)", fontWeight: 700 }}>
              {user.name?.charAt(0).toUpperCase()}
            </div>
            <div>
              <div style={{ fontWeight: 700, fontSize: "var(--text-lg)" }}>{user.name}</div>
              <div style={{ fontSize: "var(--text-sm)", color: "var(--text-tertiary)" }}>{user.email}</div>
              <div style={{ fontSize: "var(--text-xs)", color: "var(--text-tertiary)", marginTop: 4 }}>
                Family: {user.familyId ? "✅ Connected" : "❌ Not joined"}
              </div>
            </div>
            <button className="btn btn--danger btn--sm" onClick={logout} type="button" style={{ marginLeft: "auto" }}>Logout</button>
          </div>
        ) : <EmptyState icon="👤" title="Loading..." />}
      </div>

      {error && <div className="panel" style={{ borderColor: "var(--color-danger)", color: "var(--color-danger)", fontWeight: 600 }}>{error}</div>}
      {success && <div className="panel" style={{ borderColor: "var(--color-success)", color: "var(--color-success)", fontWeight: 600 }}>{success}</div>}

      {/* Family Setup (if no family) */}
      {user && !user.familyId && (
        <div className="grid-2">
          <div className="panel">
            <h4 style={{ fontWeight: 700, marginBottom: "var(--space-3)" }}>Create Family</h4>
            <form className="form-grid" onSubmit={createFamily}>
              <div className="form-group">
                <label className="form-label">Family Name</label>
                <input className="form-input" value={familyName} onChange={(e) => setFamilyName(e.target.value)} />
              </div>
              <button className="btn btn--primary" disabled={busy} type="submit">Create Family</button>
            </form>
          </div>
          <div className="panel">
            <h4 style={{ fontWeight: 700, marginBottom: "var(--space-3)" }}>Join Family</h4>
            <form className="form-grid" onSubmit={joinFamily}>
              <div className="form-group">
                <label className="form-label">Invite Code</label>
                <input className="form-input" value={inviteCode} onChange={(e) => setInviteCode(e.target.value)} placeholder="ABC123" />
              </div>
              <button className="btn btn--secondary" disabled={busy} type="submit">Join Family</button>
            </form>
          </div>
        </div>
      )}

      {/* Quick Add Transaction */}
      {user?.familyId && (
        <div className="panel">
          <div className="panel-header">
            <h3 className="panel-title">Quick Add Transaction</h3>
          </div>
          <form onSubmit={addTransaction} style={{ display: "grid", gridTemplateColumns: "1fr 1fr auto", gap: "var(--space-3)", alignItems: "end" }}>
            <div className="form-group">
              <label className="form-label">Amount</label>
              <input className="form-input" type="number" step="0.01" value={amount} onChange={(e) => setAmount(e.target.value)} />
            </div>
            <div className="form-group">
              <label className="form-label">Category</label>
              <input className="form-input" value={category} onChange={(e) => setCategory(e.target.value)} />
            </div>
            <button className="btn btn--primary" disabled={busy} type="submit">Add</button>
          </form>
        </div>
      )}
    </div>
  );
}
