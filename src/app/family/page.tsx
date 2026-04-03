"use client";

import { useEffect, useMemo, useState, useRef, useCallback } from "react";
import { ForecastResult } from "@/lib/forecast";
import { FamilySummary, Transaction } from "@/types/family";

/* ── Category helpers ─────────────────────────── */
const CAT_COLORS = [
  "#10b981", "#f59e0b", "#8b5cf6", "#3b82f6", "#f43f5e", "#ec4899",
];
const CAT_ICONS: Record<string, string> = {
  Food: "🍕", Shopping: "🛍️", Transport: "🚗", Bills: "📄",
  Health: "💊", Entertainment: "🎬", Education: "📚",
  Uncategorized: "📦",
};
const SOURCE_LABELS: Record<string, string> = {
  sms: "SMS", manual: "Manual", vision: "📷 Vision", voice: "🎤 Voice",
};

/* ── Types ────────────────────────────────────── */
type ApiState = {
  summary: FamilySummary | null;
  forecast: ForecastResult | null;
  loading: boolean;
  error: string | null;
};
type ChatMsg = { role: "user" | "ai"; text: string };

/* ══════════════════════════════════════════════
   Family Dashboard Page
   ══════════════════════════════════════════════ */
export default function FamilyDashboardPage() {
  const [state, setState] = useState<ApiState>({
    summary: null, forecast: null, loading: true, error: null,
  });
  const [chatMsgs, setChatMsgs] = useState<ChatMsg[]>([
    { role: "ai", text: "Hi! I'm DhanPath AI 🤖 — ask me anything about your family's spending." },
  ]);
  const [chatInput, setChatInput] = useState("");
  const [chatLoading, setChatLoading] = useState(false);
  const chatEndRef = useRef<HTMLDivElement>(null);

  /* ── Data Fetching ──────────────────────────── */
  useEffect(() => {
    let active = true;
    async function load() {
      try {
        const summaryRes = await fetch("/api/family/summary", { cache: "no-store" });
        if (!summaryRes.ok) {
          const err = (await summaryRes.json()) as { error?: string };
          throw new Error(err.error ?? "Summary API failed");
        }
        const summary = (await summaryRes.json()) as FamilySummary;

        const now = new Date();
        const dim = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
        const forecastRes = await fetch(
          `/api/forecast?monthlyBudget=${summary.monthlyBudget}&spentSoFar=${summary.totalMonthlySpend}&daysElapsed=${now.getDate()}&daysInMonth=${dim}`,
          { cache: "no-store" },
        );
        const forecast = (await forecastRes.json()) as ForecastResult;

        if (!active) return;
        setState({ summary, forecast, loading: false, error: null });
      } catch (error) {
        if (!active) return;
        setState({
          summary: null, forecast: null, loading: false,
          error: error instanceof Error ? error.message : "Failed to load",
        });
      }
    }
    load();
    return () => { active = false; };
  }, []);

  /* ── Chat handler ───────────────────────────── */
  const sendChat = useCallback(async () => {
    const q = chatInput.trim();
    if (!q || chatLoading) return;
    setChatInput("");
    setChatMsgs((p) => [...p, { role: "user", text: q }]);
    setChatLoading(true);
    try {
      const res = await fetch("/api/ai-chat", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ question: q, familyId: state.summary?.familyId }),
      });
      const data = await res.json();
      setChatMsgs((p) => [...p, { role: "ai", text: data.answer ?? "Sorry, try again." }]);
    } catch {
      setChatMsgs((p) => [...p, { role: "ai", text: "Connection error. Please try again." }]);
    } finally {
      setChatLoading(false);
    }
  }, [chatInput, chatLoading, state.summary?.familyId]);

  useEffect(() => { chatEndRef.current?.scrollIntoView({ behavior: "smooth" }); }, [chatMsgs]);

  /* ── Derived values ─────────────────────────── */
  const maxMemberSpend = useMemo(() => {
    if (!state.summary) return 1;
    return Math.max(...state.summary.memberBreakdown.map((m) => m.monthlySpend), 1);
  }, [state.summary]);

  const budgetRemaining = useMemo(() => {
    if (!state.summary) return 0;
    return state.summary.monthlyBudget - state.summary.totalMonthlySpend;
  }, [state.summary]);

  const budgetPct = useMemo(() => {
    if (!state.summary || state.summary.monthlyBudget <= 0) return 0;
    return Math.min(100, (state.summary.totalMonthlySpend / state.summary.monthlyBudget) * 100);
  }, [state.summary]);

  /* ── Loading ────────────────────────────────── */
  if (state.loading) {
    return (
      <div className="loading-shell">
        <div className="loading-spinner" />
        <p className="loading-text">Loading family dashboard…</p>
      </div>
    );
  }

  /* ── Error ──────────────────────────────────── */
  if (state.error || !state.summary || !state.forecast) {
    return (
      <div className="dash-shell">
        <div className="glass-card error-card">
          <h2><span className="card-icon">⚠️</span> Could not load dashboard</h2>
          <p style={{ color: "var(--text-secondary)" }}>{state.error ?? "Please try again."}</p>
        </div>
      </div>
    );
  }

  const { summary, forecast } = state;
  const now = new Date();

  /* ── Status class ───────────────────────────── */
  const statusClass = budgetPct < 60 ? "safe" : budgetPct < 85 ? "warn" : "danger";
  const statusLabel = budgetPct < 60 ? "On Track" : budgetPct < 85 ? "Caution" : "Over Budget";

  return (
    <div className="dash-shell">
      {/* ═══ Top Bar ═══ */}
      <nav className="topbar">
        <div className="topbar-brand">
          <div className="topbar-logo">₹</div>
          <h1>DhanPath AI</h1>
        </div>
        <div className="topbar-meta">
          <span className={`budget-status ${statusClass}`}>
            <span className="live-dot" />
            {statusLabel}
          </span>
          <span>{summary.familyName}</span>
          <span style={{ opacity: 0.5 }}>|</span>
          <span>{now.toLocaleDateString("en-IN", { month: "short", year: "numeric" })}</span>
        </div>
      </nav>

      {/* ═══ Stats Row ═══ */}
      <section className="stats-row">
        <div className="stat-card teal">
          <div className="stat-icon">💰</div>
          <div className="stat-label">Total Spent</div>
          <div className="stat-value">₹{summary.totalMonthlySpend.toLocaleString("en-IN")}</div>
          <div className="stat-sub">of ₹{summary.monthlyBudget.toLocaleString("en-IN")} budget</div>
        </div>
        <div className="stat-card gold">
          <div className="stat-icon">🏦</div>
          <div className="stat-label">Budget Left</div>
          <div className="stat-value" style={{ color: budgetRemaining >= 0 ? "var(--accent-teal)" : "var(--accent-rose)" }}>
            ₹{Math.abs(budgetRemaining).toLocaleString("en-IN")}
          </div>
          <div className="stat-sub">{budgetRemaining >= 0 ? "remaining" : "over budget"}</div>
        </div>
        <div className="stat-card rose">
          <div className="stat-icon">🔥</div>
          <div className="stat-label">Burn Rate</div>
          <div className="stat-value">₹{Math.round(forecast.burnRatePerDay).toLocaleString("en-IN")}</div>
          <div className="stat-sub">per day average</div>
        </div>
        <div className="stat-card violet">
          <div className="stat-icon">👨‍👩‍👦</div>
          <div className="stat-label">Members</div>
          <div className="stat-value">{summary.memberBreakdown.length}</div>
          <div className="stat-sub">{summary.memberBreakdown.filter((m) => m.role === "admin").length} admin</div>
        </div>
      </section>

      {/* ═══ Main Grid ═══ */}
      <div className="dash-grid">

        {/* ── Member Spend ─── */}
        <div className="glass-card">
          <h2><span className="card-icon">👥</span> Member Breakdown</h2>
          <div className="member-list">
            {summary.memberBreakdown.map((m) => (
              <div key={m.userId} className="member-row">
                <div className="member-avatar" style={{ background: m.avatarColor }}>
                  {m.name.slice(0, 2).toUpperCase()}
                </div>
                <div className="member-info">
                  <div className="member-name">{m.name}</div>
                  <span className={`member-role ${m.role === "admin" ? "admin" : "member-badge"}`}>
                    {m.role === "admin" ? "👑 Admin" : "Member"}
                  </span>
                </div>
                <div className="member-bar-wrap">
                  <div className="member-bar-track">
                    <div
                      className="member-bar-fill"
                      style={{
                        width: `${Math.max(8, (m.monthlySpend / maxMemberSpend) * 100)}%`,
                        background: `linear-gradient(90deg, ${m.avatarColor}, ${m.avatarColor}88)`,
                      }}
                    />
                  </div>
                  <span className="member-spend">₹{m.monthlySpend.toLocaleString("en-IN")}</span>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* ── Category Donut ── */}
        <div className="glass-card">
          <h2><span className="card-icon">📊</span> Category Split</h2>
          <DonutChart categories={summary.topCategories} total={summary.totalMonthlySpend} />
        </div>

        {/* ── Forecast Chart ── */}
        <div className="glass-card dash-grid-full">
          <h2>
            <span className="card-icon">📈</span> Budget Runway Forecast
            {forecast.willExhaustInMonth && forecast.projectedBudgetExhaustionDay && (
              <span className="budget-status danger" style={{ marginLeft: "auto", fontSize: "0.72rem" }}>
                ⚠️ Exhausts Day {forecast.projectedBudgetExhaustionDay}
              </span>
            )}
          </h2>
          <ForecastChart
            dailySpend={summary.dailySpend}
            monthlyBudget={summary.monthlyBudget}
            forecast={forecast}
          />
        </div>

        {/* ── Recent Transactions ── */}
        <div className="glass-card">
          <h2><span className="card-icon">📋</span> Recent Transactions</h2>
          <TransactionFeed transactions={summary.recentTransactions} />
        </div>

        {/* ── AI Chat ── */}
        <div className="glass-card">
          <h2><span className="card-icon">🤖</span> AI Finance Assistant</h2>
          <div className="chat-panel">
            <div className="chat-messages">
              {chatMsgs.map((msg, i) => (
                <div key={i} className={`chat-msg ${msg.role}`}>{msg.text}</div>
              ))}
              {chatLoading && (
                <div className="chat-msg ai" style={{ opacity: 0.6 }}>Thinking…</div>
              )}
              <div ref={chatEndRef} />
            </div>
            <div className="chat-input-row">
              <input
                className="chat-input"
                placeholder="Ask about your family's spending..."
                value={chatInput}
                onChange={(e) => setChatInput(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && sendChat()}
              />
              <button
                className="chat-send"
                onClick={sendChat}
                disabled={chatLoading || !chatInput.trim()}
                title="Send"
              >
                ➤
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

/* ══════════════════════════════════════════════
   Sub-Components
   ══════════════════════════════════════════════ */

/* ── Forecast Line Chart ──────────────────────── */
function ForecastChart({
  dailySpend,
  monthlyBudget,
  forecast,
}: {
  dailySpend: FamilySummary["dailySpend"];
  monthlyBudget: number;
  forecast: ForecastResult;
}) {
  const now = new Date();
  const daysInMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();

  const pad = { top: 20, right: 30, bottom: 35, left: 60 };
  const W = 800;
  const H = 300;
  const plotW = W - pad.left - pad.right;
  const plotH = H - pad.top - pad.bottom;

  const maxY = Math.max(monthlyBudget * 1.15, (forecast.projectedMonthSpend || monthlyBudget) * 1.05);
  const xScale = (d: number) => pad.left + ((d - 1) / (daysInMonth - 1)) * plotW;
  const yScale = (v: number) => pad.top + plotH - (v / maxY) * plotH;

  // Actual line
  const actualPoints = dailySpend.map((ds) => `${xScale(ds.dayOfMonth)},${yScale(ds.cumulativeSpend)}`);
  const actualLine = actualPoints.length > 0 ? `M${actualPoints.join(" L")}` : "";

  // Area under actual
  const areaPath = actualPoints.length > 0
    ? `M${xScale(dailySpend[0].dayOfMonth)},${yScale(0)} L${actualPoints.join(" L")} L${xScale(dailySpend[dailySpend.length - 1].dayOfMonth)},${yScale(0)} Z`
    : "";

  // Projected line
  const lastDay = dailySpend.length > 0 ? dailySpend[dailySpend.length - 1] : null;
  const projectedLine = lastDay && forecast.burnRatePerDay > 0
    ? `M${xScale(lastDay.dayOfMonth)},${yScale(lastDay.cumulativeSpend)} L${xScale(daysInMonth)},${yScale(lastDay.cumulativeSpend + forecast.burnRatePerDay * (daysInMonth - lastDay.dayOfMonth))}`
    : "";

  // Grid lines
  const gridYCount = 5;
  const gridYValues = Array.from({ length: gridYCount + 1 }, (_, i) => (maxY / gridYCount) * i);

  // X-axis labels (every 5 days)
  const xLabels = Array.from({ length: Math.ceil(daysInMonth / 5) + 1 }, (_, i) => {
    const d = i * 5 || 1;
    return d <= daysInMonth ? d : daysInMonth;
  });

  const exhaustionDay = forecast.projectedBudgetExhaustionDay;

  return (
    <div className="chart-container">
      <svg viewBox={`0 0 ${W} ${H}`} preserveAspectRatio="xMidYMid meet">
        {/* Grid */}
        {gridYValues.map((v, i) => (
          <g key={i}>
            <line className="chart-grid-line" x1={pad.left} y1={yScale(v)} x2={W - pad.right} y2={yScale(v)} />
            <text className="chart-label" x={pad.left - 8} y={yScale(v) + 3} textAnchor="end">
              {v >= 1000 ? `${Math.round(v / 1000)}k` : Math.round(v)}
            </text>
          </g>
        ))}

        {/* X labels */}
        {xLabels.map((d) => (
          <text key={d} className="chart-label" x={xScale(d)} y={H - 8} textAnchor="middle">{d}</text>
        ))}
        <text className="chart-label" x={W / 2} y={H} textAnchor="middle" style={{ fontSize: 11 }}>
          Day of Month
        </text>

        {/* Budget line */}
        <line
          className="chart-budget-line"
          x1={pad.left} y1={yScale(monthlyBudget)}
          x2={W - pad.right} y2={yScale(monthlyBudget)}
        />
        <text
          x={W - pad.right + 4} y={yScale(monthlyBudget) + 3}
          fill="var(--accent-rose)" fontSize={9} fontFamily="var(--font-mono, monospace)"
        >
          Budget
        </text>

        {/* Area */}
        {areaPath && <path d={areaPath} fill="url(#areaGrad)" className="chart-area" />}

        {/* Actual line */}
        {actualLine && <path d={actualLine} className="chart-actual" />}

        {/* Dots */}
        {dailySpend.map((ds, i) => (
          <circle key={i} className="chart-dot" cx={xScale(ds.dayOfMonth)} cy={yScale(ds.cumulativeSpend)} r={3} />
        ))}

        {/* Projected line */}
        {projectedLine && <path d={projectedLine} className="chart-projected" />}

        {/* Exhaustion marker */}
        {exhaustionDay && exhaustionDay <= daysInMonth && (
          <>
            <line
              className="chart-exhaustion-line"
              x1={xScale(exhaustionDay)} y1={pad.top}
              x2={xScale(exhaustionDay)} y2={H - pad.bottom}
            />
            <text className="chart-exhaustion-label" x={xScale(exhaustionDay)} y={pad.top - 5} textAnchor="middle">
              ⚠ Day {exhaustionDay}
            </text>
          </>
        )}

        {/* Gradient def */}
        <defs>
          <linearGradient id="areaGrad" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="var(--accent-teal)" stopOpacity="0.35" />
            <stop offset="100%" stopColor="var(--accent-teal)" stopOpacity="0.02" />
          </linearGradient>
        </defs>
      </svg>
    </div>
  );
}

/* ── Donut Chart ──────────────────────────────── */
function DonutChart({
  categories,
  total,
}: {
  categories: Array<{ category: string; amount: number }>;
  total: number;
}) {
  const size = 160;
  const cx = size / 2;
  const cy = size / 2;
  const outerR = 68;
  const innerR = 44;

  let currentAngle = -90;
  const arcs = categories.map((cat, i) => {
    const pct = total > 0 ? cat.amount / total : 0;
    const angle = pct * 360;
    const startAngle = currentAngle;
    const endAngle = currentAngle + angle;
    currentAngle = endAngle;

    const startRad = (startAngle * Math.PI) / 180;
    const endRad = (endAngle * Math.PI) / 180;
    const largeArc = angle > 180 ? 1 : 0;

    const x1o = cx + outerR * Math.cos(startRad);
    const y1o = cy + outerR * Math.sin(startRad);
    const x2o = cx + outerR * Math.cos(endRad);
    const y2o = cy + outerR * Math.sin(endRad);
    const x1i = cx + innerR * Math.cos(endRad);
    const y1i = cy + innerR * Math.sin(endRad);
    const x2i = cx + innerR * Math.cos(startRad);
    const y2i = cy + innerR * Math.sin(startRad);

    const d = [
      `M${x1o},${y1o}`,
      `A${outerR},${outerR} 0 ${largeArc} 1 ${x2o},${y2o}`,
      `L${x1i},${y1i}`,
      `A${innerR},${innerR} 0 ${largeArc} 0 ${x2i},${y2i}`,
      "Z",
    ].join(" ");

    return { d, color: CAT_COLORS[i % CAT_COLORS.length], cat };
  });

  return (
    <div className="donut-container">
      <svg className="donut-svg" viewBox={`0 0 ${size} ${size}`}>
        {arcs.map((arc, i) => (
          <path key={i} d={arc.d} fill={arc.color} opacity={0.85}>
            <title>{arc.cat.category}: ₹{arc.cat.amount.toLocaleString("en-IN")}</title>
          </path>
        ))}
        <text x={cx} y={cy - 6} textAnchor="middle" fill="var(--text-primary)" fontSize={14} fontWeight={800} fontFamily="var(--font-mono, monospace)">
          ₹{total >= 1000 ? `${(total / 1000).toFixed(1)}k` : total}
        </text>
        <text x={cx} y={cy + 10} textAnchor="middle" fill="var(--text-muted)" fontSize={9}>
          total
        </text>
      </svg>
      <div className="donut-legend">
        {categories.map((cat, i) => (
          <div key={cat.category} className="legend-item">
            <div className="legend-dot" style={{ background: CAT_COLORS[i % CAT_COLORS.length] }} />
            <span className="legend-label">{CAT_ICONS[cat.category] ?? "📦"} {cat.category}</span>
            <span className="legend-value">₹{cat.amount.toLocaleString("en-IN")}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

/* ── Transaction Feed ─────────────────────────── */
function TransactionFeed({ transactions }: { transactions: Transaction[] }) {
  if (transactions.length === 0) {
    return <p style={{ color: "var(--text-muted)", fontSize: "0.85rem" }}>No recent transactions.</p>;
  }

  return (
    <div className="tx-list">
      {transactions.map((tx) => {
        const icon = CAT_ICONS[tx.category] ?? "📦";
        const catColor = CAT_COLORS[
          Object.keys(CAT_ICONS).indexOf(tx.category) % CAT_COLORS.length
        ] ?? CAT_COLORS[0];
        const timeStr = formatRelativeTime(tx.txnTime);

        return (
          <div key={tx.id} className="tx-row">
            <div className="tx-icon-wrap" style={{ background: `${catColor}18`, color: catColor }}>
              {icon}
            </div>
            <div className="tx-details">
              <div className="tx-merchant">{tx.merchant ?? tx.category}</div>
              <div className="tx-meta">
                <span>{tx.userName}</span>
                <span>·</span>
                <span>{timeStr}</span>
                <span className="tx-source-badge">{SOURCE_LABELS[tx.source] ?? tx.source}</span>
              </div>
            </div>
            <div className={`tx-amount ${tx.type}`}>
              {tx.type === "debit" ? "−" : "+"}₹{tx.amount.toLocaleString("en-IN")}
            </div>
          </div>
        );
      })}
    </div>
  );
}

/* ── Helpers ──────────────────────────────────── */
function formatRelativeTime(iso: string): string {
  const diff = Date.now() - new Date(iso).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 1) return "Just now";
  if (mins < 60) return `${mins}m ago`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return `${hrs}h ago`;
  const days = Math.floor(hrs / 24);
  return `${days}d ago`;
}
