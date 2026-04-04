"use client";

import { useEffect, useMemo, useState } from "react";
import EmptyState from "@/components/EmptyState";
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/base-ui/accordion";

type AdviceItem = {
  _id: string;
  chatName: string;
  pinned?: boolean;
  prompt: string;
  targetAmount: number;
  targetMonths: number;
  monthlyIncome: number;
  monthlyExpense: number;
  feasible: boolean;
  suggestedMonthlySave: number;
  suggestedMonthlySpendCap: number;
  responseText: string;
  recommendations: string[];
  memberInsights: Array<{ userId: string; name: string; spend: number; note: string }>;
  createdAt: string;
};

export default function AiAdvisorPage() {
  const [chatName, setChatName] = useState("");
  const [prompt, setPrompt] = useState("");
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [planId, setPlanId] = useState("free");
  const [history, setHistory] = useState<AdviceItem[]>([]);
  const [quota, setQuota] = useState({ used: 0, limit: 1, remaining: 1 });
  const [page, setPage] = useState(1);
  const [hasMore, setHasMore] = useState(false);
  const [deleteTarget, setDeleteTarget] = useState<AdviceItem | null>(null);
  const [deleting, setDeleting] = useState(false);

  const money = useMemo(
    () => new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }),
    [],
  );

  async function load(pageToLoad = 1, append = false) {
    if (append) {
      setLoadingMore(true);
    } else {
      setLoading(true);
    }
    setError(null);
    const res = await fetch(`/api/ai/advisor?page=${pageToLoad}&pageSize=20`, { cache: "no-store" });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      setError(data.error ?? "Failed to load AI advisor");
      setLoading(false);
      setLoadingMore(false);
      return;
    }
    setPlanId(String(data.planId ?? "free"));
    setHistory((prev) => {
      const incoming = Array.isArray(data.history) ? (data.history as AdviceItem[]) : [];
      return append ? [...prev, ...incoming] : incoming;
    });
    setQuota({
      used: Number(data.quota?.used ?? 0),
      limit: Number(data.quota?.limit ?? 1),
      remaining: Number(data.quota?.remaining ?? 0),
    });
    setPage(Number(data.pagination?.page ?? pageToLoad));
    setHasMore(Boolean(data.pagination?.hasMore));
    setLoading(false);
    setLoadingMore(false);
  }

  useEffect(() => {
    load();
  }, []);

  async function submitAdvice() {
    const cleanName = chatName.trim();
    const clean = prompt.trim();
    if (!cleanName) {
      setError("Please enter chat name.");
      return;
    }
    if (!clean) {
      setError("Please enter your request with amount and timeline.");
      return;
    }

    setSubmitting(true);
    setError(null);

    const res = await fetch("/api/ai/advisor", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ chatName: cleanName, prompt: clean }),
    });

    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      setError(data.error ?? "Failed to generate advice");
      setSubmitting(false);
      if (data.quota) {
        setQuota({
          used: Number(data.quota.used ?? quota.used),
          limit: Number(data.quota.limit ?? quota.limit),
          remaining: Number(data.quota.remaining ?? quota.remaining),
        });
      }
      return;
    }

    if (data.item) {
      setHistory((prev) => {
        const next = [data.item as AdviceItem, ...prev];
        return next.sort((a, b) => Number(Boolean(b.pinned)) - Number(Boolean(a.pinned)) || new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
      });
    }
    if (data.quota) {
      setQuota({
        used: Number(data.quota.used ?? quota.used),
        limit: Number(data.quota.limit ?? quota.limit),
        remaining: Number(data.quota.remaining ?? quota.remaining),
      });
    }
    setChatName("");
    setPrompt("");
    setSubmitting(false);
  }

  async function togglePin(item: AdviceItem) {
    const res = await fetch("/api/ai/advisor", {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ adviceId: item._id, pinned: !item.pinned }),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      setError(data.error ?? "Failed to update favorite");
      return;
    }

    setHistory((prev) => {
      const mapped = prev.map((x) => (x._id === item._id ? ({ ...x, pinned: !x.pinned }) : x));
      return mapped.sort((a, b) => Number(Boolean(b.pinned)) - Number(Boolean(a.pinned)) || new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
    });
  }

  async function confirmDeleteChat() {
    if (!deleteTarget) return;
    setDeleting(true);
    const res = await fetch("/api/ai/advisor", {
      method: "DELETE",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ adviceId: deleteTarget._id }),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      setError(data.error ?? "Failed to delete chat");
      setDeleting(false);
      return;
    }

    setHistory((prev) => prev.filter((item) => item._id !== deleteTarget._id));
    setDeleteTarget(null);
    setDeleting(false);
  }

  if (loading) return <EmptyState icon="🤖" title="Loading AI Advisor..." />;

  return (
    <div className="stack animate-slide">
      <div className="panel ai-advisor-hero">
        <div className="panel-header">
          <h3 className="panel-title">AI Purchase & Savings Advisor</h3>
        </div>

        <div className="ai-advisor-meta-row">
          <span className="chip chip--brand">Plan: {planId}</span>
          <span className={`chip ${quota.remaining > 0 ? "chip--info" : "chip--warning"}`}>
            Chats: {quota.used}/{quota.limit} used in 3 months
          </span>
        </div>

        {quota.remaining <= 0 ? (
          <div className="ai-advisor-lock">
            <p>You reached your chat limit for this plan.</p>
            <button className="btn btn--primary btn--sm" type="button" onClick={() => window.location.assign("/dashboard/billing")}>Upgrade Plan</button>
          </div>
        ) : (
          <div className="ai-advisor-form">
            <div className="form-row" style={{ gridTemplateColumns: "1fr" }}>
              <div className="form-group">
                <label className="form-label">Chat Name</label>
                <input
                  className="form-input"
                  value={chatName}
                  onChange={(e) => setChatName(e.target.value)}
                  placeholder="Example: Phone plan for August"
                />
              </div>
              <div className="form-group">
                <label className="form-label">Your Request</label>
                <textarea
                  className="form-input"
                  value={prompt}
                  onChange={(e) => setPrompt(e.target.value)}
                  rows={4}
                  placeholder="Example: I want to buy a phone worth 50000 in 4 months"
                  style={{ resize: "vertical", minHeight: 96 }}
                />
              </div>
            </div>

            <div style={{ display: "flex", justifyContent: "space-between", gap: "var(--space-3)", alignItems: "center", flexWrap: "wrap" }}>
              <span style={{ fontSize: "var(--text-xs)", color: "var(--text-tertiary)" }}>Include amount and timeline for best results.</span>
              <button className="btn btn--primary" type="button" disabled={submitting} onClick={submitAdvice}>
                {submitting ? "Generating..." : "Get AI Suggestion"}
              </button>
            </div>
          </div>
        )}
      </div>

      {error && <div className="panel" style={{ borderColor: "var(--color-danger)", color: "var(--color-danger)", fontWeight: 600 }}>{error}</div>}

      {history.length === 0 ? (
        <EmptyState icon="🧠" title="No advice generated yet" subtitle="Ask your goal and all stored chats will appear here." />
      ) : (
        <div className="stack">
          <div className="panel-header">
            <h3 className="panel-title">Your Stored AI Chats</h3>
            <span className="panel-subtitle">Visible any time, regardless of plan limit</span>
          </div>

          <Accordion className="w-full ai-chat-accordion" type="multiple" defaultValue={[history[0]?._id ?? ""]}>
            {history.map((item) => (
              <AccordionItem key={item._id} value={item._id} className="panel ai-advice-card">
                <AccordionTrigger className="ai-chat-trigger">
                  <div className="ai-chat-title-wrap">
                    <span className="ai-chat-title-main">{item.chatName || "Untitled Chat"}</span>
                    <span className="panel-subtitle">{new Date(item.createdAt).toLocaleString()}</span>
                  </div>
                </AccordionTrigger>

                <AccordionContent className="ai-chat-content">
                  <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: "var(--space-2)", marginBottom: "var(--space-2)" }}>
                    <h3 className="panel-title" style={{ margin: 0 }}>{item.feasible ? "Feasible Plan" : "Not Feasible Right Now"}</h3>
                    <div style={{ display: "flex", gap: "var(--space-2)", alignItems: "center" }}>
                      <button className="btn btn--ghost btn--sm" type="button" onClick={() => togglePin(item)}>
                        {item.pinned ? "Unfavorite" : "Favorite"}
                      </button>
                      <button className="btn btn--danger btn--sm" type="button" onClick={() => setDeleteTarget(item)}>
                        Delete
                      </button>
                    </div>
                  </div>

                  <p className="ai-advice-prompt">{item.prompt}</p>
                  <p className="ai-advice-summary">{item.responseText}</p>

                  <div className="ai-advice-kpis">
                    <div className="ai-advice-kpi">
                      <span>Target</span>
                      <strong>{money.format(item.targetAmount)} / {item.targetMonths} mo</strong>
                    </div>
                    <div className="ai-advice-kpi">
                      <span>Suggested Save</span>
                      <strong>{money.format(item.suggestedMonthlySave)} /mo</strong>
                    </div>
                    <div className="ai-advice-kpi">
                      <span>Spend Cap</span>
                      <strong>{money.format(item.suggestedMonthlySpendCap)}</strong>
                    </div>
                    <div className={`ai-advice-kpi ${item.monthlyExpense > item.suggestedMonthlySpendCap && item.suggestedMonthlySpendCap > 0 ? "ai-advice-kpi--danger" : ""}`}>
                      <span>Current Spend</span>
                      <strong>{money.format(item.monthlyExpense)}</strong>
                    </div>
                  </div>

                  {item.monthlyExpense > item.suggestedMonthlySpendCap && item.suggestedMonthlySpendCap > 0 && (
                    <div className="ai-advice-overbudget">You exceeded AI recommended spend cap for this period.</div>
                  )}

                  {item.recommendations?.length > 0 && (
                    <ul className="ai-advice-list">
                      {item.recommendations.map((rec, idx) => (
                        <li key={`${item._id}-rec-${idx}`}>{rec}</li>
                      ))}
                    </ul>
                  )}

                  {item.memberInsights?.length > 0 && (
                    <div className="ai-advice-members">
                      {item.memberInsights.map((m) => (
                        <div key={`${item._id}-${m.userId}-${m.name}`} className="ai-advice-member-row">
                          <span>{m.name}</span>
                          <strong>{money.format(m.spend)}</strong>
                          <p>{m.note}</p>
                        </div>
                      ))}
                    </div>
                  )}
                </AccordionContent>
              </AccordionItem>
            ))}
          </Accordion>

          {hasMore && (
            <div style={{ display: "flex", justifyContent: "center" }}>
              <button className="btn btn--ghost" type="button" disabled={loadingMore} onClick={() => load(page + 1, true)}>
                {loadingMore ? "Loading..." : "Load More"}
              </button>
            </div>
          )}
        </div>
      )}

      {deleteTarget && (
        <div className="ai-delete-overlay" role="dialog" aria-modal="true" aria-label="Delete chat confirmation">
          <div className="ai-delete-modal">
            <h3>Delete this chat?</h3>
            <p>
              This will remove <strong>{deleteTarget.chatName || "this chat"}</strong> from your history view.
              Chat usage quota remains consumed and will not be restored.
            </p>
            <div className="ai-delete-actions">
              <button className="btn btn--ghost" type="button" disabled={deleting} onClick={() => setDeleteTarget(null)}>
                Cancel
              </button>
              <button className="btn btn--danger" type="button" disabled={deleting} onClick={confirmDeleteChat}>
                {deleting ? "Deleting..." : "Yes, Delete"}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
