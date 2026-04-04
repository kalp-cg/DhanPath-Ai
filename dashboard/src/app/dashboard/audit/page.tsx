"use client";

import { useCallback, useEffect, useState } from "react";
import EmptyState from "@/components/EmptyState";

type AuditEntry = { id: string; action: string; actorUserId: string; actorName: string; targetUserId: string | null; targetName: string | null; metadata: Record<string, unknown>; createdAt: string };
type Member = { userId: string; name: string };

const actionLabels: Record<string, string> = {
  member_role_changed: "Role Changed", member_removed: "Member Removed", plan_changed: "Plan Changed",
  invoice_exported: "Invoice Export", audit_exported: "Audit Export", transaction_report_exported: "Txn Report Export",
  ca_pack_generated: "CA Pack Generated", ca_pack_schedule_updated: "CA Schedule Updated",
  family_created: "Family Created", family_joined: "Family Joined",
};

export default function AuditPage() {
  const [audit, setAudit] = useState<AuditEntry[]>([]);
  const [members, setMembers] = useState<Member[]>([]);
  const [currentUserId, setCurrentUserId] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [pagination, setPagination] = useState({ page: 1, totalPages: 1, totalRecords: 0, hasPrev: false, hasNext: false });
  const [action, setAction] = useState("all");
  const [actorId, setActorId] = useState("all");
  const [from, setFrom] = useState("");
  const [to, setTo] = useState("");
  const [page, setPage] = useState(1);

  const fetchAudit = useCallback(async () => {
    setLoading(true);
    setError(null);
    const params = new URLSearchParams({
      action,
      actorId,
      from,
      to,
      page: String(page),
      pageSize: "15",
    });
    const res = await fetch(`/api/family/audit?${params.toString()}`, { cache: "no-store" });
    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      setError(String(body.error ?? "Failed to load audit log"));
      setLoading(false);
      return;
    }
    const data = await res.json().catch(() => ({}));
    setAudit(Array.isArray(data.audit) ? data.audit : []);
    setMembers(Array.isArray(data.members) ? data.members : []);
    setCurrentUserId(String(data.currentUserId ?? ""));
    if (data.pagination) setPagination(data.pagination);
    setLoading(false);
  }, [action, actorId, from, to, page]);

  useEffect(() => { fetchAudit(); }, [fetchAudit]);

  async function exportCsv() {
    const params = new URLSearchParams({ auditAction: action, auditActorId: actorId, auditFrom: from, auditTo: to });
    const res = await fetch(`/api/family/audit/export?${params.toString()}`);
    if (!res.ok) return;
    const blob = await res.blob(); const url = URL.createObjectURL(blob);
    const a = document.createElement("a"); a.href = url; a.download = "dhanpath-audit.csv";
    document.body.appendChild(a); a.click(); a.remove(); URL.revokeObjectURL(url);
  }

  return (
    <div className="stack animate-slide">
      {error && (
        <div className="panel" style={{ borderColor: "var(--color-danger)", color: "var(--color-danger)", fontWeight: 600 }}>
          {error}
        </div>
      )}

      {/* Filters */}
      <div className="panel">
        <div className="panel-header">
          <h3 className="panel-title">Filter Audit Log</h3>
          <div style={{ display: "flex", gap: "var(--space-2)" }}>
            <button className="btn btn--ghost btn--sm" onClick={() => { setAction("all"); setActorId("all"); setFrom(""); setTo(""); setPage(1); }} type="button">Clear</button>
            <button className="btn btn--ghost btn--sm" onClick={exportCsv} type="button">Export CSV</button>
          </div>
        </div>
        <div className="form-row">
          <div className="form-group">
            <label className="form-label">Action</label>
            <select className="form-select" value={action} onChange={(e) => { setAction(e.target.value); setPage(1); }}>
              <option value="all">All Actions</option>
              {Object.entries(actionLabels).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
            </select>
          </div>
          <div className="form-group">
            <label className="form-label">Actor</label>
            <select className="form-select" value={actorId} onChange={(e) => { setActorId(e.target.value); setPage(1); }}>
              <option value="all">All Members</option>
              {members.map((m) => <option key={m.userId} value={m.userId}>{m.name}</option>)}
            </select>
          </div>
          <div className="form-group">
            <label className="form-label">From</label>
            <input className="form-input" type="date" value={from} onChange={(e) => { setFrom(e.target.value); setPage(1); }} />
          </div>
          <div className="form-group">
            <label className="form-label">To</label>
            <input className="form-input" type="date" value={to} onChange={(e) => { setTo(e.target.value); setPage(1); }} />
          </div>
        </div>
      </div>

      {/* Audit List */}
      <div className="panel">
        <div className="panel-header">
          <h3 className="panel-title">Activity Log</h3>
          <span className="panel-subtitle">{pagination.totalRecords} records</span>
        </div>
        {loading ? <EmptyState icon="📋" title="Loading audit events..." subtitle="Please wait" /> : audit.length === 0 ? <EmptyState icon="📋" title="No audit events" subtitle="Actions will appear here as they happen" /> : (
          <>
            <ul className="data-list">
              {audit.map((entry) => (
                <li key={entry.id} className="data-list-item">
                  <div className="data-list-main">
                    <div style={{ display: "flex", alignItems: "center", gap: "var(--space-2)", flexWrap: "wrap" }}>
                      <span style={{ fontWeight: 600, fontSize: "var(--text-sm)" }}>{entry.actorName}{entry.targetName ? ` → ${entry.targetName}` : ""}</span>
                      <span className="chip chip--neutral">{actionLabels[entry.action] ?? entry.action}</span>
                    </div>
                    <span style={{ fontSize: "var(--text-xs)", color: "var(--text-tertiary)" }}>{new Date(entry.createdAt).toLocaleString()}</span>
                  </div>
                  <span className="chip chip--info">{entry.actorUserId === currentUserId ? "You" : "Member"}</span>
                </li>
              ))}
            </ul>
            <div className="pager">
              <button className="btn btn--ghost btn--sm" disabled={!pagination.hasPrev} onClick={() => setPage((p) => Math.max(1, p - 1))} type="button">← Previous</button>
              <span className="pager-info">Page {pagination.page} of {pagination.totalPages}</span>
              <button className="btn btn--ghost btn--sm" disabled={!pagination.hasNext} onClick={() => setPage((p) => p + 1)} type="button">Next →</button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
