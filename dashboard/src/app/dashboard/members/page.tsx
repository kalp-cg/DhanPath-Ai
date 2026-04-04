"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import EmptyState from "@/components/EmptyState";

type Member = { userId: string; name: string; email: string; role: "admin" | "member" };
type Summary = {
  currentUserId: string;
  ownerUserId: string;
  isCurrentUserAdmin: boolean;
  familyName: string;
  inviteCode: string;
  members: Member[];
  memberTransactionStats: Array<{ userId: string; userName: string; totalSpend: number; transactionCount: number }>;
};

export default function MembersPage() {
  const [summary, setSummary] = useState<Summary | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [selectedMemberId, setSelectedMemberId] = useState("all");

  const money = useMemo(() => new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }), []);

  const fetchSummary = useCallback(async () => {
    const now = new Date();
    const params = new URLSearchParams({
      year: String(now.getFullYear()),
      month: String(now.getMonth() + 1),
      memberId: selectedMemberId,
      page: "1",
      pageSize: "1",
    });
    const res = await fetch(`/api/family/summary?${params.toString()}`, { cache: "no-store" });
    if (!res.ok) return;
    const data = await res.json().catch(() => ({}));
    setSummary(data as Summary);
  }, [selectedMemberId]);

  useEffect(() => { fetchSummary(); }, [fetchSummary]);

  async function changeRole(targetUserId: string, role: "admin" | "member") {
    const res = await fetch("/api/family/members", { method: "PATCH", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ targetUserId, role }) });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) { setError(data.error ?? "Could not update role"); return; }
    setError(null); fetchSummary();
  }

  async function removeMember(targetUserId: string) {
    const res = await fetch(`/api/family/members?targetUserId=${encodeURIComponent(targetUserId)}`, { method: "DELETE" });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) { setError(data.error ?? "Could not remove member"); return; }
    setError(null); fetchSummary();
  }

  async function copyInviteCode() {
    if (!summary?.inviteCode) return;
    await navigator.clipboard.writeText(summary.inviteCode).catch(() => {});
  }

  if (!summary) return <EmptyState icon="👥" title="Loading members..." />;

  const statsMap = new Map((summary.memberTransactionStats ?? []).map((s) => [s.userId, s]));
  const members = summary.members ?? [];
  const filteredMembers = selectedMemberId === "all"
    ? members
    : members.filter((m) => m.userId === selectedMemberId);
  const comparison = members.map((member) => {
    const stats = statsMap.get(member.userId);
    return {
      userId: member.userId,
      name: member.name,
      totalSpend: Number(stats?.totalSpend ?? 0),
      transactionCount: Number(stats?.transactionCount ?? 0),
      isSelf: member.userId === summary.currentUserId,
    };
  });
  const maxSpend = Math.max(1, ...comparison.map((c) => c.totalSpend));
  const maxTx = Math.max(1, ...comparison.map((c) => c.transactionCount));

  return (
    <div className="stack animate-slide">
      {/* Invite Code */}
      <div className="panel" style={{ display: "flex", alignItems: "center", justifyContent: "space-between", flexWrap: "wrap", gap: "var(--space-3)" }}>
        <div>
          <div style={{ fontSize: "var(--text-sm)", color: "var(--text-secondary)" }}>Family Invite Code</div>
          <div style={{ fontSize: "var(--text-2xl)", fontWeight: 800, letterSpacing: "0.08em", color: "var(--brand-primary)" }}>{summary.inviteCode}</div>
        </div>
        <button className="btn btn--primary btn--sm" onClick={copyInviteCode} type="button">📋 Copy Code</button>
      </div>

      <div className="panel" style={{ padding: "var(--space-4) var(--space-6)" }}>
        <div className="form-row" style={{ alignItems: "end" }}>
          <div className="form-group">
            <label className="form-label">View Member</label>
            <select className="form-select" value={selectedMemberId} onChange={(e) => setSelectedMemberId(e.target.value)}>
              <option value="all">All Members</option>
              {members.map((m) => (
                <option key={m.userId} value={m.userId}>
                  {m.userId === summary.currentUserId ? `${m.name} (You)` : m.name}
                </option>
              ))}
            </select>
          </div>
        </div>
      </div>

      <div className="panel">
        <div className="panel-header">
          <h3 className="panel-title">Member-wise Spend Chart</h3>
          <span className="panel-subtitle">Compare spend and transaction volume</span>
        </div>
        {comparison.length === 0 ? (
          <EmptyState icon="👤" title="No member stats" subtitle="Add transactions to unlock member analytics" />
        ) : (
          <ul className="data-list">
            {comparison.map((c) => (
              <li key={c.userId} className="data-list-item" style={{ flexDirection: "column", alignItems: "stretch", gap: "var(--space-2)" }}>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                  <span style={{ fontWeight: 600 }}>{c.name}{c.isSelf ? " (You)" : ""}</span>
                  <span className="chip chip--neutral">{c.transactionCount} txns</span>
                </div>
                <div style={{ display: "flex", alignItems: "center", gap: "var(--space-2)" }}>
                  <span style={{ minWidth: 72, fontSize: "var(--text-xs)", color: "var(--text-tertiary)" }}>Spend</span>
                  <div className="bar-track" style={{ flex: 1 }}>
                    <div className="bar-fill people" style={{ width: `${Math.max(8, (c.totalSpend / maxSpend) * 100)}%` }} />
                  </div>
                  <strong style={{ whiteSpace: "nowrap" }}>{money.format(c.totalSpend)}</strong>
                </div>
                <div style={{ display: "flex", alignItems: "center", gap: "var(--space-2)" }}>
                  <span style={{ minWidth: 72, fontSize: "var(--text-xs)", color: "var(--text-tertiary)" }}>Volume</span>
                  <div className="bar-track" style={{ flex: 1 }}>
                    <div className="bar-fill trend" style={{ width: `${Math.max(8, (c.transactionCount / maxTx) * 100)}%` }} />
                  </div>
                  <strong style={{ whiteSpace: "nowrap" }}>{c.transactionCount}</strong>
                </div>
              </li>
            ))}
          </ul>
        )}
      </div>

      {error && <div className="panel" style={{ borderColor: "var(--color-danger)", color: "var(--color-danger)", fontWeight: 600 }}>{error}</div>}

      {/* Members List */}
      <div className="panel">
        <div className="panel-header">
          <h3 className="panel-title">Family Members</h3>
          <span className="panel-subtitle">{summary.members?.length ?? 0} members</span>
        </div>
        <ul className="data-list">
          {filteredMembers.map((member) => {
            const stats = statsMap.get(member.userId);
            const isOwner = member.userId === summary.ownerUserId;
            const isSelf = member.userId === summary.currentUserId;
            const canManage = summary.isCurrentUserAdmin && !isOwner && !(isSelf && member.role === "admin");
            const canRemove = summary.isCurrentUserAdmin && !isSelf && !isOwner;

            return (
              <li key={member.userId} className="data-list-item" style={{ flexDirection: "column", gap: "var(--space-3)" }}>
                <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", width: "100%", gap: "var(--space-3)" }}>
                  <div style={{ display: "flex", alignItems: "center", gap: "var(--space-3)" }}>
                    <div style={{ width: 40, height: 40, borderRadius: "var(--radius-full)", background: "linear-gradient(135deg, var(--brand-primary), var(--brand-accent))", color: "white", display: "flex", alignItems: "center", justifyContent: "center", fontSize: "var(--text-sm)", fontWeight: 700 }}>
                      {member.name?.charAt(0).toUpperCase()}
                    </div>
                    <div>
                      <div style={{ display: "flex", alignItems: "center", gap: "var(--space-2)" }}>
                        <span style={{ fontWeight: 600 }}>{member.name}</span>
                        <span className={`chip chip--${member.role === "admin" ? "admin" : "neutral"}`}>{member.role}</span>
                        {isOwner && <span className="chip chip--brand">Owner</span>}
                        {isSelf && <span className="chip chip--info">You</span>}
                      </div>
                      <span style={{ fontSize: "var(--text-xs)", color: "var(--text-tertiary)" }}>{member.email}</span>
                    </div>
                  </div>
                  {stats && (
                    <div style={{ textAlign: "right" }}>
                      <div style={{ fontWeight: 700, fontSize: "var(--text-sm)" }}>{money.format(stats.totalSpend)}</div>
                      <div style={{ fontSize: "var(--text-xs)", color: "var(--text-tertiary)" }}>{stats.transactionCount} txns</div>
                    </div>
                  )}
                </div>
                {summary.isCurrentUserAdmin && (
                  <div style={{ display: "flex", gap: "var(--space-2)", justifyContent: "flex-end" }}>
                    {canManage && (
                      <button className="btn btn--ghost btn--sm" onClick={() => changeRole(member.userId, member.role === "admin" ? "member" : "admin")} type="button">
                        {member.role === "admin" ? "Make Member" : "Make Admin"}
                      </button>
                    )}
                    {canRemove && (
                      <button className="btn btn--danger btn--sm" onClick={() => removeMember(member.userId)} type="button">Remove</button>
                    )}
                  </div>
                )}
              </li>
            );
          })}
        </ul>
      </div>
    </div>
  );
}
