"use client";

import { useEffect, useMemo, useState, useRef, useCallback } from "react";
import { ForecastResult } from "@/lib/forecast";
import { FamilySummary } from "@/types/family";
import { createSupabaseBrowserClient } from "@/lib/supabase-browser";
import { BudgetCard } from "@/components/ui/budget-card";
import { ActivitiesCard } from "@/components/ui/activities-card";
import { Card, CardHeader, CardTitle, CardContent, CardDescription } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import {
  Wallet, TrendingDown, Users, Send,
  ShoppingCart, Utensils, Car, FileText,
  Heart, Film, Package, Bot, Sparkles, AlertCircle, LayoutDashboard, Crown, Mail, LogOut
} from "lucide-react";

/* ── Category helpers ─────────────────────────── */
const CAT_COLORS = ["#10b981", "#f59e0b", "#8b5cf6", "#3b82f6", "#f43f5e", "#ec4899"];
const CAT_ICONS: Record<string, React.ReactNode> = {
  Food: <Utensils className="h-4 w-4" />,
  Shopping: <ShoppingCart className="h-4 w-4" />,
  Transport: <Car className="h-4 w-4" />,
  Bills: <FileText className="h-4 w-4" />,
  Health: <Heart className="h-4 w-4" />,
  Entertainment: <Film className="h-4 w-4" />,
};
const SOURCE_LABELS: Record<string, string> = {
  sms: "SMS", manual: "Manual", vision: "Vision", voice: "Voice",
};

/* ── Types ────────────────────────────────────── */
type ApiState = {
  summary: FamilySummary | null;
  forecast: ForecastResult | null;
  loading: boolean;
  error: string | null;
};
type ChatMsg = { role: "user" | "ai"; text: string };
type PendingInvite = {
  id: string;
  familyId: string;
  token: string;
  familyName: string;
  expiresAt: string;
};

/* ══════════════════════════════════════════════
   Family Dashboard Page — Dynamic SaaS Edition
   ══════════════════════════════════════════════ */
export default function FamilyDashboardPage() {
  const supabase = useRef(createSupabaseBrowserClient()).current;
  const [hasCheckedAuth, setHasCheckedAuth] = useState(false);
  const [sessionToken, setSessionToken] = useState<string | null>(null);
  const [currentUserId, setCurrentUserId] = useState<string | null>(null);
  const [currentUserEmail, setCurrentUserEmail] = useState<string | null>(null);
  const [localFamilyId, setLocalFamilyId] = useState<string | null>(
    typeof window === "undefined" ? null : localStorage.getItem("dhanpath_family_id"),
  );

  // Auth/invite tracking
  const [loginEmail, setLoginEmail] = useState("");
  const [loginMessage, setLoginMessage] = useState("");
  const [workspaceName, setWorkspaceName] = useState("");
  const [memberInviteEmail, setMemberInviteEmail] = useState("");
  const [pendingInvites, setPendingInvites] = useState<PendingInvite[]>([]);
  const [authLoading, setAuthLoading] = useState(false);
  const [authError, setAuthError] = useState("");
  const [inviteLoading, setInviteLoading] = useState(false);
  const [inviteFeedback, setInviteFeedback] = useState("");

  const [state, setState] = useState<ApiState>({
    summary: null, forecast: null, loading: true, error: null,
  });

  const [chatMsgs, setChatMsgs] = useState<ChatMsg[]>([
    { role: "ai", text: "Hello. I'm DhanPath AI. How can I assist you with your family's finances today?" },
  ]);
  const [chatInput, setChatInput] = useState("");
  const [chatLoading, setChatLoading] = useState(false);
  const chatEndRef = useRef<HTMLDivElement>(null);

  const authHeaders = useCallback(
    (tokenOverride?: string | null): Record<string, string> => {
    const token = tokenOverride ?? sessionToken;
    if (!token) return {};
    return {
      Authorization: `Bearer ${token}`,
    };
  }, [sessionToken]);

  const fetchPendingInvites = useCallback(async (token: string) => {
    const res = await fetch("/api/family/invitations/pending", {
      headers: authHeaders(token),
      cache: "no-store",
    });
    const data = (await res.json()) as { invites?: PendingInvite[]; error?: string };
    if (!res.ok) {
      throw new Error(data.error ?? "Failed to load pending invitations");
    }
    setPendingInvites(data.invites ?? []);
  }, [authHeaders]);

  const acceptInvite = useCallback(
    async (token: string, accessTokenOverride?: string) => {
      const activeToken = accessTokenOverride ?? sessionToken;
      if (!activeToken) return;
      const res = await fetch("/api/family/invitations/accept", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...authHeaders(activeToken),
        },
        body: JSON.stringify({ token }),
      });
      const data = (await res.json()) as { familyId?: string; error?: string };
      if (!res.ok || !data.familyId) {
        throw new Error(data.error ?? "Failed to accept invitation");
      }
      localStorage.setItem("dhanpath_family_id", data.familyId);
      setLocalFamilyId(data.familyId);
      await fetchPendingInvites(activeToken);
    },
    [sessionToken, authHeaders, fetchPendingInvites],
  );

  /* ── Init Check ─────────────────────────────── */
  useEffect(() => {
    let active = true;
    const bootstrap = async () => {
      const { data } = await supabase.auth.getSession();
      const accessToken = data.session?.access_token ?? null;
      const user = data.session?.user ?? null;
      if (!active) return;

      setSessionToken(accessToken);
      setCurrentUserId(user?.id ?? null);
      setCurrentUserEmail(user?.email?.toLowerCase() ?? null);
      if (!accessToken) {
        setHasCheckedAuth(true);
        return;
      }

      const inviteToken = new URLSearchParams(window.location.search).get("inviteToken");
      if (inviteToken) {
        try {
          await acceptInvite(inviteToken, accessToken);
          const nextUrl = new URL(window.location.href);
          nextUrl.searchParams.delete("inviteToken");
          window.history.replaceState({}, "", nextUrl.toString());
        } catch (error) {
          setAuthError(error instanceof Error ? error.message : "Could not accept invite.");
        }
      }

      try {
        await fetchPendingInvites(accessToken);
      } catch (error) {
        setAuthError(error instanceof Error ? error.message : "Could not fetch invites.");
      } finally {
        setHasCheckedAuth(true);
      }
    };
    bootstrap();

    const { data: sub } = supabase.auth.onAuthStateChange((_event, session) => {
      setSessionToken(session?.access_token ?? null);
      setCurrentUserId(session?.user?.id ?? null);
      setCurrentUserEmail(session?.user?.email?.toLowerCase() ?? null);
    });
    return () => {
      active = false;
      sub.subscription.unsubscribe();
    };
  }, [supabase, acceptInvite, fetchPendingInvites]);

  /* ── Data Fetching ──────────────────────────── */
  const loadDashboard = useCallback(async (fid: string) => {
    setState((p) => ({ ...p, loading: true, error: null }));
    try {
      const summaryRes = await fetch(`/api/family/summary?familyId=${fid}`, {
        cache: "no-store",
        headers: authHeaders(),
      });
      if (!summaryRes.ok) {
        const err = (await summaryRes.json()) as { error?: string };
        throw new Error(err.error ?? "Failed to load workspace.");
      }
      const summary = (await summaryRes.json()) as FamilySummary;

      const now = new Date();
      const dim = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
      const forecastRes = await fetch(
        `/api/forecast?monthlyBudget=${summary.monthlyBudget}&spentSoFar=${summary.totalMonthlySpend}&daysElapsed=${now.getDate()}&daysInMonth=${dim}`,
        { cache: "no-store" },
      );
      const forecast = (await forecastRes.json()) as ForecastResult;

      setState({ summary, forecast, loading: false, error: null });
    } catch (error) {
      setState({
        summary: null, forecast: null, loading: false,
        error: error instanceof Error ? error.message : "Failed to load",
      });
      localStorage.removeItem("dhanpath_family_id");
      setLocalFamilyId(null);
    }
  }, [authHeaders]);

  useEffect(() => {
    if (hasCheckedAuth && sessionToken && localFamilyId) {
      loadDashboard(localFamilyId);
    }
  }, [hasCheckedAuth, sessionToken, localFamilyId, loadDashboard]);

  const handleEmailSignIn = async () => {
    if (!loginEmail.trim()) return;
    setAuthLoading(true);
    setAuthError("");
    setLoginMessage("");
    try {
      const { error } = await supabase.auth.signInWithOtp({
        email: loginEmail.trim().toLowerCase(),
        options: {
          emailRedirectTo: `${window.location.origin}/family`,
        },
      });
      if (error) throw error;
      setLoginMessage("Magic link sent. Check your inbox and open the link to continue.");
    } catch (error) {
      setAuthError(error instanceof Error ? error.message : "Failed to send magic link.");
    } finally {
      setAuthLoading(false);
    }
  };

  const handleCreateWorkspace = async () => {
    if (!workspaceName.trim()) return;
    setAuthLoading(true);
    setAuthError("");
    try {
      const res = await fetch("/api/family/workspace", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...authHeaders(),
        },
        body: JSON.stringify({
          name: workspaceName.trim(),
        }),
      });
      const data = (await res.json()) as { familyId?: string; error?: string };
      if (!res.ok) throw new Error(data.error || "Failed to create workspace");
      if (!data.familyId) throw new Error("Workspace was created but no familyId returned.");
      localStorage.setItem("dhanpath_family_id", data.familyId);
      setLocalFamilyId(data.familyId);
    } catch (err) {
      setAuthError(err instanceof Error ? err.message : "Error creating workspace");
    } finally {
      setAuthLoading(false);
    }
  };

  const handleSendInvite = async () => {
    if (!memberInviteEmail.trim() || !localFamilyId) return;
    setInviteLoading(true);
    setInviteFeedback("");
    try {
      const res = await fetch("/api/family/invite", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...authHeaders(),
        },
        body: JSON.stringify({
          familyId: localFamilyId,
          email: memberInviteEmail.trim().toLowerCase(),
        }),
      });
      const data = (await res.json()) as { invitedEmail?: string; error?: string };
      if (!res.ok) throw new Error(data.error || "Failed to send invite");
      setMemberInviteEmail("");
      setInviteFeedback(`Invite sent to ${data.invitedEmail ?? "member email"}.`);
    } catch (err) {
      setInviteFeedback(err instanceof Error ? err.message : "Failed to send invite");
    } finally {
      setInviteLoading(false);
    }
  };

  const handleLogout = async () => {
    await supabase.auth.signOut();
    localStorage.removeItem("dhanpath_family_id");
    setSessionToken(null);
    setCurrentUserId(null);
    setCurrentUserEmail(null);
    setLocalFamilyId(null);
    setPendingInvites([]);
    setState({ summary: null, forecast: null, loading: false, error: null });
  };

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
        headers: {
          "Content-Type": "application/json",
          ...authHeaders(),
        },
        body: JSON.stringify({ question: q, familyId: state.summary?.familyId }),
      });
      const data = await res.json();
      setChatMsgs((p) => [...p, { role: "ai", text: data.answer ?? "Sorry, try again." }]);
    } catch {
      setChatMsgs((p) => [...p, { role: "ai", text: "Connection error. Please try again." }]);
    } finally {
      setChatLoading(false);
    }
  }, [chatInput, chatLoading, state.summary?.familyId, authHeaders]);

  useEffect(() => { chatEndRef.current?.scrollIntoView({ behavior: "smooth" }); }, [chatMsgs]);

  /* ── Derived values ─────────────────────────── */
  const maxMemberSpend = useMemo(() => {
    if (!state.summary || state.summary.memberBreakdown.length === 0) return 1;
    return Math.max(...state.summary.memberBreakdown.map((m) => m.monthlySpend), 1);
  }, [state.summary]);

  const budgetRemaining = useMemo(() => {
    if (!state.summary) return 0;
    return state.summary.monthlyBudget - state.summary.totalMonthlySpend;
  }, [state.summary]);

  /* ── Pre-boot Loading ───────────────────────── */
  if (!hasCheckedAuth || (sessionToken && localFamilyId && state.loading)) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-neutral-950">
        <div className="flex flex-col items-center gap-4">
          <div className="h-8 w-8 animate-spin rounded-full border-2 border-neutral-800 border-t-emerald-500" />
          <p className="text-sm text-neutral-500">Loading workspace…</p>
        </div>
      </div>
    );
  }

  /* ── Onboarding / Auth View ─────────────────── */
  if (!sessionToken) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-neutral-950 p-4">
        <Card className="w-full max-w-md bg-neutral-900 border-neutral-800">
          <CardHeader className="text-center pb-2">
            <div className="mx-auto flex h-12 w-12 items-center justify-center rounded-xl bg-neutral-800 text-white mb-4 border border-neutral-700 shadow-sm">
              <Mail className="h-6 w-6" />
            </div>
            <CardTitle>Sign in to DhanPath AI</CardTitle>
            <CardDescription className="text-neutral-400">
              Use your email to access real-time family workspace data.
            </CardDescription>
          </CardHeader>
          <CardContent className="pt-4">
            <div className="space-y-4">
              <div className="space-y-2">
                <label className="text-sm font-medium text-neutral-300">Email</label>
                <input
                  className="w-full rounded-lg border border-neutral-800 bg-neutral-950 px-4 py-2.5 text-sm text-white focus:border-emerald-600 focus:outline-none"
                  placeholder="you@example.com"
                  type="email"
                  value={loginEmail}
                  onChange={(e) => setLoginEmail(e.target.value)}
                  onKeyDown={(e) => e.key === "Enter" && handleEmailSignIn()}
                />
              </div>
              {authError && <p className="text-xs text-rose-500">{authError}</p>}
              {loginMessage && <p className="text-xs text-emerald-400">{loginMessage}</p>}
              <button
                onClick={handleEmailSignIn}
                disabled={!loginEmail.trim() || authLoading}
                className="w-full rounded-lg flex items-center justify-center gap-2 bg-emerald-600 text-white px-4 py-2.5 text-sm font-semibold hover:bg-emerald-700 transition-colors disabled:opacity-50"
              >
                {authLoading ? "Sending..." : "Send Magic Link"}
              </button>
            </div>
          </CardContent>
        </Card>
      </div>
    );
  }

  if (!localFamilyId) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-neutral-950 p-4">
        <Card className="w-full max-w-xl bg-neutral-900 border-neutral-800">
          <CardHeader className="text-center pb-2">
            <div className="mx-auto flex h-12 w-12 items-center justify-center rounded-xl bg-neutral-800 text-white mb-4 border border-neutral-700 shadow-sm">
              <LayoutDashboard className="h-6 w-6" />
            </div>
            <CardTitle>Family Workspace Setup</CardTitle>
            <CardDescription className="text-neutral-400">
              Signed in as {currentUserEmail}
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-6 pt-4">
            <div className="space-y-3 rounded-lg border border-neutral-800 p-4">
              <h3 className="text-sm font-semibold text-white">Create a Workspace</h3>
              <input
                className="w-full rounded-lg border border-neutral-800 bg-neutral-950 px-4 py-2.5 text-sm text-white focus:border-emerald-600 focus:outline-none"
                placeholder="e.g. Sharma Family Finance"
                value={workspaceName}
                onChange={(e) => setWorkspaceName(e.target.value)}
              />
              {authError && <p className="text-xs text-rose-500">{authError}</p>}
              <button
                onClick={handleCreateWorkspace}
                disabled={!workspaceName.trim() || authLoading}
                className="w-full rounded-lg bg-emerald-600 px-4 py-2.5 text-sm font-semibold text-white hover:bg-emerald-700 disabled:opacity-50"
              >
                {authLoading ? "Creating..." : "Create Workspace"}
              </button>
            </div>

            <div className="space-y-3 rounded-lg border border-neutral-800 p-4">
              <h3 className="text-sm font-semibold text-white">Pending Invitations</h3>
              {pendingInvites.length === 0 ? (
                <p className="text-xs text-neutral-500">No pending invitations for this email.</p>
              ) : (
                <div className="space-y-2">
                  {pendingInvites.map((inv) => (
                    <div key={inv.id} className="flex items-center justify-between rounded-md border border-neutral-800 px-3 py-2">
                      <div>
                        <p className="text-sm text-white">{inv.familyName}</p>
                        <p className="text-[11px] text-neutral-500">Expires: {new Date(inv.expiresAt).toLocaleString()}</p>
                      </div>
                      <button
                        onClick={() => acceptInvite(inv.token)}
                        className="rounded-md bg-blue-600 px-3 py-1.5 text-xs font-semibold text-white hover:bg-blue-700"
                      >
                        Accept
                      </button>
                    </div>
                  ))}
                </div>
              )}
            </div>

            <button onClick={handleLogout} className="w-full text-xs text-neutral-400 hover:text-white">
              <span className="inline-flex items-center gap-1"><LogOut className="h-3 w-3" /> Sign out</span>
            </button>
          </CardContent>
        </Card>
      </div>
    );
  }

  /* ── Error ──────────────────────────────────── */
  if (state.error || !state.summary || !state.forecast) {
    return (
      <div className="flex min-h-screen items-center justify-center p-4 bg-neutral-950">
        <Card className="max-w-md bg-neutral-900 border-neutral-800 text-white">
          <CardHeader>
            <CardTitle className="flex items-center gap-2"><AlertCircle className="h-5 w-5 text-rose-500" /> Workspace Error</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-sm text-neutral-400 mb-6">{state.error ?? "Failed to load dashboard."}</p>
            <button onClick={handleLogout} className="text-sm text-emerald-500 hover:text-emerald-400">Return to onboarding</button>
          </CardContent>
        </Card>
      </div>
    );
  }

  const { summary, forecast } = state;
  const currentMember = currentUserId
    ? summary.memberBreakdown.find((m) => m.userId === currentUserId)
    : null;
  const isCurrentUserAdmin = currentMember?.role === "admin";
  const now = new Date();
  const currentMonth = now.toLocaleString("en-US", { month: "long" });

  return (
    <div className="min-h-screen bg-[#09090b] dark:bg-[#09090b]">
      {/* ═══ Top Bar ═══ */}
      <header className="sticky top-0 z-50 border-b border-neutral-800 bg-[#09090b]/80 backdrop-blur-xl">
        <div className="mx-auto flex max-w-7xl items-center justify-between px-4 py-3 sm:px-6">
          <div className="flex items-center gap-3">
            <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-neutral-900 border border-neutral-700 font-bold text-white shadow-sm">
              <LayoutDashboard className="h-5 w-5" />
            </div>
            <div>
              <h1 className="text-sm font-semibold tracking-tight text-white">{summary.familyName}</h1>
              <p className="text-xs text-neutral-500 font-medium tracking-wide">Workspace • ID: {summary.inviteCode || "N/A"}</p>
            </div>
          </div>
          <div className="flex items-center gap-4">
            <Badge variant="outline" className="gap-1.5 border-emerald-900 bg-emerald-950/30 text-emerald-400">
              <span className="h-1.5 w-1.5 rounded-full bg-emerald-500 animate-pulse" />
              Live Sync
            </Badge>
            <button onClick={handleLogout} className="text-xs text-neutral-400 hover:text-white transition-colors">Sign out</button>
          </div>
        </div>
      </header>

      <main className="mx-auto max-w-7xl space-y-6 px-4 py-6 sm:px-6 dark">

        {/* ═══ Stats Row — shadcn Cards ═══ */}
        <section className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <Card className="bg-neutral-900 border-neutral-800/50">
            <CardHeader className="pb-2">
              <div className="flex items-center justify-between">
                <span className="text-xs font-semibold uppercase tracking-wider text-neutral-400">Total Spent</span>
                <div className="flex h-7 w-7 items-center justify-center rounded-md bg-neutral-800">
                  <Wallet className="h-3.5 w-3.5 text-neutral-400" />
                </div>
              </div>
            </CardHeader>
            <CardContent>
              <p className="text-2xl font-bold tracking-tight text-white">₹{summary.totalMonthlySpend.toLocaleString("en-IN")}</p>
              <p className="mt-1 text-xs text-neutral-500">of ₹{summary.monthlyBudget.toLocaleString("en-IN")} budget</p>
            </CardContent>
          </Card>

          <Card className="bg-neutral-900 border-neutral-800/50">
            <CardHeader className="pb-2">
              <div className="flex items-center justify-between">
                <span className="text-xs font-semibold uppercase tracking-wider text-neutral-400">Budget Left</span>
                <div className="flex h-7 w-7 items-center justify-center rounded-md bg-neutral-800">
                  <TrendingDown className="h-3.5 w-3.5 text-neutral-400" />
                </div>
              </div>
            </CardHeader>
            <CardContent>
              <p className={`text-2xl font-bold tracking-tight ${budgetRemaining >= 0 ? "text-emerald-400" : "text-rose-400"}`}>
                ₹{Math.abs(budgetRemaining).toLocaleString("en-IN")}
              </p>
              <p className="mt-1 text-xs text-neutral-500">{budgetRemaining >= 0 ? "remaining" : "over budget"}</p>
            </CardContent>
          </Card>

          <Card className="bg-neutral-900 border-neutral-800/50">
            <CardHeader className="pb-2">
              <div className="flex items-center justify-between">
                <span className="text-xs font-semibold uppercase tracking-wider text-neutral-400">Burn Rate</span>
                <div className="flex h-7 w-7 items-center justify-center rounded-md bg-neutral-800">
                  <TrendingDown className="h-3.5 w-3.5 text-neutral-400" />
                </div>
              </div>
            </CardHeader>
            <CardContent>
              <p className="text-2xl font-bold tracking-tight text-white">₹{Math.round(forecast.burnRatePerDay).toLocaleString("en-IN")}</p>
              <p className="mt-1 text-xs text-neutral-500">per day average</p>
            </CardContent>
          </Card>

          <Card className="bg-neutral-900 border-neutral-800/50">
            <CardHeader className="pb-2">
              <div className="flex items-center justify-between">
                <span className="text-xs font-semibold uppercase tracking-wider text-neutral-400">Members</span>
                <div className="flex h-7 w-7 items-center justify-center rounded-md bg-neutral-800">
                  <Users className="h-3.5 w-3.5 text-neutral-400" />
                </div>
              </div>
            </CardHeader>
            <CardContent>
              <p className="text-2xl font-bold tracking-tight text-white">{summary.memberBreakdown.length}</p>
              <p className="mt-1 text-xs text-neutral-500">{summary.memberBreakdown.filter((m) => m.role === "admin").length} admin</p>
            </CardContent>
          </Card>
        </section>

        {isCurrentUserAdmin && (
          <Card className="bg-neutral-900 border-neutral-800/50">
            <CardHeader>
              <CardTitle className="flex items-center gap-2 text-sm font-semibold text-white">
                <Mail className="h-4 w-4 text-emerald-400" /> Invite Family Member
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="flex flex-col gap-2 sm:flex-row">
                <input
                  className="flex-1 rounded-lg border border-neutral-800 bg-[#09090b] px-4 py-2.5 text-sm text-white outline-none placeholder:text-neutral-500 focus:border-neutral-600"
                  placeholder="member@email.com"
                  value={memberInviteEmail}
                  onChange={(e) => setMemberInviteEmail(e.target.value)}
                  onKeyDown={(e) => e.key === "Enter" && handleSendInvite()}
                />
                <button
                  onClick={handleSendInvite}
                  disabled={!memberInviteEmail.trim() || inviteLoading}
                  className="rounded-lg bg-emerald-600 px-4 py-2.5 text-sm font-semibold text-white hover:bg-emerald-700 disabled:opacity-50"
                >
                  {inviteLoading ? "Sending..." : "Send Invite"}
                </button>
              </div>
              {inviteFeedback && (
                <p className="mt-2 text-xs text-neutral-400">{inviteFeedback}</p>
              )}
            </CardContent>
          </Card>
        )}

        {/* ═══ Main Grid ═══ */}
        <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">

          {/* ── Watermelon UI BudgetCard ── */}
          <div>
            <BudgetCard
              month={currentMonth}
              totalBudget={summary.monthlyBudget}
              spentAmount={summary.totalMonthlySpend}
              breakdown={summary.topCategories.slice(0, 3).map((cat, i) => ({
                label: cat.category,
                amount: cat.amount,
                color: CAT_COLORS[i % CAT_COLORS.length],
              }))}
            />
          </div>

          {/* ── Member Spend — shadcn Card ── */}
          <Card className="bg-neutral-900 border-neutral-800/50">
            <CardHeader>
              <CardTitle className="flex items-center gap-2 text-sm font-semibold text-white">
                <Users className="h-4 w-4" /> Member Breakdown
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              {summary.memberBreakdown.map((m) => (
                <div key={m.userId} className="flex items-center gap-3 rounded-lg border border-neutral-800/50 p-3 transition-colors hover:bg-neutral-800/50">
                  <div
                    className="flex h-9 w-9 shrink-0 items-center justify-center rounded-md text-sm font-bold text-white shadow-sm"
                    style={{ background: m.avatarColor }}
                  >
                    {m.name.slice(0, 2).toUpperCase()}
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-2">
                      <span className="text-sm font-semibold text-white">{m.name}</span>
                      <Badge variant={m.role === "admin" ? "default" : "secondary"} className="text-[9px] uppercase font-bold flex items-center gap-1 bg-neutral-800 text-neutral-300">
                        {m.role === "admin" && <Crown className="h-3 w-3 text-emerald-500" />} {m.role}
                      </Badge>
                    </div>
                    <div className="mt-2 flex items-center gap-3">
                      <div className="h-1.5 flex-1 overflow-hidden rounded-full bg-neutral-800">
                        <div
                          className="h-full rounded-full transition-all duration-1000"
                          style={{
                            width: `${Math.max(8, (m.monthlySpend / maxMemberSpend) * 100)}%`,
                            background: m.avatarColor,
                          }}
                        />
                      </div>
                      <span className="text-xs font-semibold tabular-nums text-neutral-300">
                        ₹{m.monthlySpend.toLocaleString("en-IN")}
                      </span>
                    </div>
                  </div>
                </div>
              ))}
            </CardContent>
          </Card>
        </div>

        {/* ═══ Forecast Chart — full width ═══ */}
        <Card className="bg-neutral-900 border-neutral-800/50">
          <CardHeader>
            <div className="flex items-center justify-between">
              <CardTitle className="flex items-center gap-2 text-sm font-semibold text-white">
                <TrendingDown className="h-4 w-4 text-emerald-500" /> Budget Runway Forecast
              </CardTitle>
              {forecast.willExhaustInMonth && forecast.projectedBudgetExhaustionDay && (
                <Badge variant="destructive" className="text-xs flex items-center gap-1 bg-rose-500/10 text-rose-400 border-rose-500/20">
                  <AlertCircle className="h-3 w-3" /> Exhausts Day {forecast.projectedBudgetExhaustionDay}
                </Badge>
              )}
            </div>
          </CardHeader>
          <CardContent>
            <ForecastChart
              dailySpend={summary.dailySpend}
              monthlyBudget={summary.monthlyBudget}
              forecast={forecast}
            />
          </CardContent>
        </Card>

        {/* ═══ Bottom Row ═══ */}
        <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
          {/* ── Watermelon UI ActivitiesCard — Transactions ── */}
          <ActivitiesCard
            headerIcon={<Package className="h-4 w-4 text-neutral-500" />}
            title="Recent Transactions"
            subtitle={`${summary.recentTransactions.length} recent activities from group`}
            activities={summary.recentTransactions.map((tx) => ({
              icon: CAT_ICONS[tx.category] ?? <Package className="h-4 w-4" />,
              title: tx.merchant ?? tx.category,
              desc: `${tx.userName} · ${SOURCE_LABELS[tx.source] ?? tx.source}`,
              time: `−₹${tx.amount.toLocaleString("en-IN")}`,
            }))}
          />

          {/* ── AI Chat ── */}
          <Card className="flex flex-col bg-neutral-900 border-neutral-800/50" style={{ minHeight: 400 }}>
            <CardHeader>
              <CardTitle className="flex items-center gap-2 text-sm font-semibold text-white">
                <Bot className="h-4 w-4" /> AI Expense Assistant
                <Badge variant="outline" className="ml-auto gap-1 text-[9px] uppercase font-bold border-neutral-700 bg-neutral-800/50">
                  <Sparkles className="h-3 w-3 text-violet-400" /> Gemini
                </Badge>
              </CardTitle>
            </CardHeader>
            <CardContent className="flex flex-1 flex-col">
              <div className="flex-1 space-y-4 overflow-y-auto pr-1" style={{ maxHeight: 300 }}>
                {chatMsgs.map((msg, i) => (
                  <div key={i} className={`flex ${msg.role === "user" ? "justify-end" : "justify-start"}`}>
                    <div className={`max-w-[85%] rounded-lg px-4 py-3 text-sm ${
                      msg.role === "user"
                        ? "bg-neutral-800 text-white"
                        : "border border-neutral-800 bg-neutral-900/50 text-neutral-200"
                    }`}>
                      {msg.text}
                    </div>
                  </div>
                ))}
                {chatLoading && (
                  <div className="flex justify-start">
                    <div className="rounded-lg border border-neutral-800 bg-neutral-900/50 px-4 py-3 text-sm text-neutral-500">
                      Processing query…
                    </div>
                  </div>
                )}
                <div ref={chatEndRef} />
              </div>
              <div className="mt-4 flex gap-2">
                <input
                  className="flex-1 rounded-lg border border-neutral-800 bg-[#09090b] px-4 py-2.5 text-sm text-white outline-none placeholder:text-neutral-500 focus:border-neutral-600"
                  placeholder="Ask about workspace spending..."
                  value={chatInput}
                  onChange={(e) => setChatInput(e.target.value)}
                  onKeyDown={(e) => e.key === "Enter" && sendChat()}
                />
                <button
                  onClick={sendChat}
                  disabled={chatLoading || !chatInput.trim()}
                  className="flex h-10 w-10 items-center justify-center rounded-lg bg-white text-neutral-900 disabled:opacity-40 hover:bg-neutral-200 transition-colors"
                >
                  <Send className="h-4 w-4" />
                </button>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* ═══ Category Breakdown ═══ */}
        <Card className="bg-neutral-900 border-neutral-800/50">
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-sm font-semibold text-white"><Package className="h-4 w-4 text-violet-500" /> Category Breakdown</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="flex flex-col items-center gap-8 sm:flex-row">
              <DonutChart categories={summary.topCategories} total={summary.totalMonthlySpend} />
              <div className="grid flex-1 gap-2">
                {summary.topCategories.map((cat) => (
                  <div key={cat.category} className="flex items-center gap-3 rounded-lg border border-transparent p-2 transition-colors hover:bg-neutral-800/40 hover:border-neutral-800">
                    <span className="flex h-8 w-8 items-center justify-center rounded-md text-lg bg-neutral-800 text-neutral-400">
                      {CAT_ICONS[cat.category] ?? <Package className="h-4 w-4" />}
                    </span>
                    <span className="flex-1 text-sm text-neutral-300">{cat.category}</span>
                    <span className="text-sm font-semibold tabular-nums text-white">₹{cat.amount.toLocaleString("en-IN")}</span>
                  </div>
                ))}
              </div>
            </div>
          </CardContent>
        </Card>

        {/* ═══ Footer ═══ */}
        <footer className="py-8 text-center text-xs text-neutral-600">
          <p>DhanPath AI Enterprise — SaaS Workspace</p>
        </footer>
      </main>
    </div>
  );
}

/* ══════════════════════════════════════════════
   Sub-Components
   ══════════════════════════════════════════════ */

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
  const W = 800, H = 280;
  const plotW = W - pad.left - pad.right;
  const plotH = H - pad.top - pad.bottom;

  const maxY = Math.max(monthlyBudget * 1.15, (forecast.projectedMonthSpend || monthlyBudget) * 1.05);
  const xScale = (d: number) => pad.left + ((d - 1) / (daysInMonth - 1)) * plotW;
  const yScale = (v: number) => pad.top + plotH - (v / maxY) * plotH;

  const actualPoints = dailySpend.map((ds) => `${xScale(ds.dayOfMonth)},${yScale(ds.cumulativeSpend)}`);
  const actualLine = actualPoints.length > 0 ? `M${actualPoints.join(" L")}` : "";
  const areaPath = actualPoints.length > 0
    ? `M${xScale(dailySpend[0].dayOfMonth)},${yScale(0)} L${actualPoints.join(" L")} L${xScale(dailySpend[dailySpend.length - 1].dayOfMonth)},${yScale(0)} Z`
    : "";

  const lastDay = dailySpend.length > 0 ? dailySpend[dailySpend.length - 1] : null;
  const projectedLine = lastDay && forecast.burnRatePerDay > 0
    ? `M${xScale(lastDay.dayOfMonth)},${yScale(lastDay.cumulativeSpend)} L${xScale(daysInMonth)},${yScale(lastDay.cumulativeSpend + forecast.burnRatePerDay * (daysInMonth - lastDay.dayOfMonth))}`
    : "";

  const gridYCount = 4;
  const gridYValues = Array.from({ length: gridYCount + 1 }, (_, i) => (maxY / gridYCount) * i);
  const xLabels = Array.from({ length: Math.ceil(daysInMonth / 5) + 1 }, (_, i) => {
    const d = i * 5 || 1;
    return d <= daysInMonth ? d : daysInMonth;
  });

  const exhaustionDay = forecast.projectedBudgetExhaustionDay;

  return (
    <div style={{ width: "100%", aspectRatio: "2.8 / 1" }}>
      <svg viewBox={`0 0 ${W} ${H}`} preserveAspectRatio="xMidYMid meet" style={{ width: "100%", height: "100%" }}>
        {gridYValues.map((v, i) => (
          <g key={i}>
            <line stroke="currentColor" opacity={0.06} x1={pad.left} y1={yScale(v)} x2={W - pad.right} y2={yScale(v)} />
            <text fill="currentColor" opacity={0.35} x={pad.left - 8} y={yScale(v) + 3} textAnchor="end" fontSize={10} fontFamily="monospace">
              {v >= 1000 ? `${Math.round(v / 1000)}k` : Math.round(v)}
            </text>
          </g>
        ))}
        {xLabels.map((d) => (
          <text key={d} fill="currentColor" opacity={0.35} x={xScale(d)} y={H - 8} textAnchor="middle" fontSize={10} fontFamily="monospace">{d}</text>
        ))}
        <text fill="currentColor" opacity={0.3} x={W / 2} y={H} textAnchor="middle" fontSize={10}>Day of Month</text>

        <line stroke="#f43f5e" strokeWidth={1} strokeDasharray="4 4" opacity={0.5}
          x1={pad.left} y1={yScale(monthlyBudget)} x2={W - pad.right} y2={yScale(monthlyBudget)} />
        <text x={W - pad.right + 4} y={yScale(monthlyBudget) + 3} fill="#f43f5e" fontSize={9} fontFamily="monospace">Budget</text>

        {areaPath && <path d={areaPath} fill="url(#areaGrad2)" opacity={0.15} />}
        {actualLine && <path d={actualLine} fill="none" stroke="#10b981" strokeWidth={2.5} strokeLinecap="round" strokeLinejoin="round" />}
        {dailySpend.map((ds, i) => (
          <circle key={i} cx={xScale(ds.dayOfMonth)} cy={yScale(ds.cumulativeSpend)} r={3} fill="#10b981" />
        ))}
        {projectedLine && <path d={projectedLine} fill="none" stroke="#f59e0b" strokeWidth={2} strokeDasharray="8 6" opacity={0.6} />}

        {exhaustionDay && exhaustionDay <= daysInMonth && (
          <>
            <line stroke="#f43f5e" strokeWidth={1.5} opacity={0.5} strokeDasharray="4 4"
              x1={xScale(exhaustionDay)} y1={pad.top} x2={xScale(exhaustionDay)} y2={H - pad.bottom} />
            <text fill="#f43f5e" x={xScale(exhaustionDay)} y={pad.top - 5} textAnchor="middle" fontSize={10} fontWeight={700} fontFamily="monospace">
              Day {exhaustionDay}
            </text>
          </>
        )}

        <defs>
          <linearGradient id="areaGrad2" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="#10b981" stopOpacity="0.4" />
            <stop offset="100%" stopColor="#10b981" stopOpacity="0.02" />
          </linearGradient>
        </defs>
      </svg>
    </div>
  );
}

function DonutChart({ categories, total }: { categories: Array<{ category: string; amount: number }>; total: number }) {
  const size = 180, cx = size / 2, cy = size / 2, outerR = 78, innerR = 52;
  const arcs = categories.reduce<Array<{ d: string; color: string; cat: { category: string; amount: number } }>>(
    (acc, cat, i) => {
      const pct = total > 0 ? cat.amount / total : 0;
      const angle = pct * 360;
      const covered = categories
        .slice(0, i)
        .reduce((sum, item) => sum + (total > 0 ? (item.amount / total) * 360 : 0), 0);
      const startAngle = -90 + covered;
      const endAngle = startAngle + angle;

      const sr = (startAngle * Math.PI) / 180;
      const er = (endAngle * Math.PI) / 180;
      const la = angle > 180 ? 1 : 0;
      const d = [
        `M${cx + outerR * Math.cos(sr)},${cy + outerR * Math.sin(sr)}`,
        `A${outerR},${outerR} 0 ${la} 1 ${cx + outerR * Math.cos(er)},${cy + outerR * Math.sin(er)}`,
        `L${cx + innerR * Math.cos(er)},${cy + innerR * Math.sin(er)}`,
        `A${innerR},${innerR} 0 ${la} 0 ${cx + innerR * Math.cos(sr)},${cy + innerR * Math.sin(sr)}`,
        "Z",
      ].join(" ");
      acc.push({ d, color: CAT_COLORS[i % CAT_COLORS.length], cat });
      return acc;
    },
    [],
  );

  return (
    <svg viewBox={`0 0 ${size} ${size}`} className="h-44 w-44 shrink-0">
      {arcs.map((arc, i) => (
        <path key={i} d={arc.d} fill={arc.color} opacity={0.85}>
          <title>{arc.cat.category}: ₹{arc.cat.amount.toLocaleString("en-IN")}</title>
        </path>
      ))}
      <text x={cx} y={cy - 4} textAnchor="middle" className="fill-white" fontSize={16} fontWeight={800} fontFamily="monospace">
        ₹{total >= 1000 ? `${(total / 1000).toFixed(1)}k` : total}
      </text>
      <text x={cx} y={cy + 12} textAnchor="middle" className="fill-neutral-500" fontSize={10}>total</text>
    </svg>
  );
}
