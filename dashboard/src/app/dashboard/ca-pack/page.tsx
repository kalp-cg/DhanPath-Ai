"use client";

import { useCallback, useEffect, useState } from "react";

type CaSchedule = { caEmail: string; dayOfMonth: number; includeAudit: boolean; active: boolean; lastRunMonth: string | null; lastGeneratedAt: string | null };
type GeneratedPack = { token: string; year: number; month: number; expiresAt: string; packPageUrl: string; csvUrl: string; pdfUrl: string; mailTo: string };

export default function CaPackPage() {
  const [schedule, setSchedule] = useState<CaSchedule>({ caEmail: "", dayOfMonth: 5, includeAudit: true, active: true, lastRunMonth: null, lastGeneratedAt: null });
  const [pack, setPack] = useState<GeneratedPack | null>(null);
  const [error, setError] = useState<string | null>(null);

  const fetchSchedule = useCallback(async () => {
    const res = await fetch("/api/family/ca-pack/settings", { cache: "no-store" });
    if (!res.ok) return;
    const data = await res.json().catch(() => ({}));
    if (data.schedule) setSchedule(data.schedule);
  }, []);

  useEffect(() => { fetchSchedule(); }, [fetchSchedule]);

  async function save() {
    const res = await fetch("/api/family/ca-pack/settings", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(schedule) });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) { setError(data.error ?? "Failed to save"); return; }
    setError(null); fetchSchedule();
  }

  async function generate() {
    const now = new Date();
    const res = await fetch("/api/family/ca-pack/generate", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ year: now.getFullYear(), month: now.getMonth() + 1, includeAudit: schedule.includeAudit, expiresDays: 10 }) });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) { setError(data.error ?? "Failed to generate"); return; }
    setPack(data.pack as GeneratedPack); setError(null);
  }

  return (
    <div className="stack animate-slide">
      {error && <div className="panel" style={{ borderColor: "var(--color-danger)", color: "var(--color-danger)", fontWeight: 600 }}>{error}</div>}

      <div className="panel">
        <div className="panel-header">
          <h3 className="panel-title">CA Pack Schedule</h3>
          <span className={`chip chip--${schedule.active ? "credit" : "neutral"}`}>{schedule.active ? "Active" : "Paused"}</span>
        </div>
        <div className="form-row" style={{ marginTop: "var(--space-4)" }}>
          <div className="form-group">
            <label className="form-label">CA Email</label>
            <input className="form-input" type="email" value={schedule.caEmail} onChange={(e) => setSchedule((s) => ({ ...s, caEmail: e.target.value }))} placeholder="ca@example.com" />
          </div>
          <div className="form-group">
            <label className="form-label">Day of Month</label>
            <input className="form-input" type="number" min={1} max={28} value={schedule.dayOfMonth} onChange={(e) => setSchedule((s) => ({ ...s, dayOfMonth: Math.max(1, Math.min(28, Number(e.target.value) || 1)) }))} />
          </div>
          <div className="form-group">
            <label className="form-label">Include Audit</label>
            <select className="form-select" value={schedule.includeAudit ? "yes" : "no"} onChange={(e) => setSchedule((s) => ({ ...s, includeAudit: e.target.value === "yes" }))}>
              <option value="yes">Yes</option>
              <option value="no">No</option>
            </select>
          </div>
          <div className="form-group">
            <label className="form-label">Status</label>
            <select className="form-select" value={schedule.active ? "active" : "paused"} onChange={(e) => setSchedule((s) => ({ ...s, active: e.target.value === "active" }))}>
              <option value="active">Active</option>
              <option value="paused">Paused</option>
            </select>
          </div>
        </div>
        <div style={{ display: "flex", gap: "var(--space-3)", marginTop: "var(--space-4)" }}>
          <button className="btn btn--primary" onClick={save} type="button">Save Schedule</button>
          <button className="btn btn--secondary" onClick={generate} type="button">Generate This Month</button>
        </div>
        <div style={{ marginTop: "var(--space-3)", fontSize: "var(--text-sm)", color: "var(--text-tertiary)" }}>
          Last Run: <strong>{schedule.lastRunMonth ?? "-"}</strong> · Last Generated: <strong>{schedule.lastGeneratedAt ? new Date(schedule.lastGeneratedAt).toLocaleString() : "-"}</strong>
        </div>
      </div>

      {pack && (
        <div className="panel">
          <div className="panel-header">
            <h3 className="panel-title">Generated Pack</h3>
            <span className="chip chip--brand">{pack.year}-{String(pack.month).padStart(2, "0")}</span>
          </div>
          <p style={{ fontSize: "var(--text-sm)", color: "var(--text-tertiary)", marginBottom: "var(--space-3)" }}>
            Expires: {new Date(pack.expiresAt).toLocaleString()}
          </p>
          <div style={{ display: "flex", gap: "var(--space-2)", flexWrap: "wrap" }}>
            <a className="btn btn--ghost btn--sm" href={pack.packPageUrl} target="_blank" rel="noreferrer">📄 Share Page</a>
            <a className="btn btn--ghost btn--sm" href={pack.csvUrl} target="_blank" rel="noreferrer">📊 CSV</a>
            <a className="btn btn--ghost btn--sm" href={pack.pdfUrl} target="_blank" rel="noreferrer">📑 PDF</a>
            {pack.mailTo && <a className="btn btn--primary btn--sm" href={pack.mailTo}>📧 Email CA</a>}
          </div>
        </div>
      )}
    </div>
  );
}
