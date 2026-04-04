"use client";

import { FormEvent, useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import LogoMark from "@/components/LogoMark";

type AuthMode = "login" | "signup";

export default function AuthPage() {
  const router = useRouter();
  const [mode, setMode] = useState<AuthMode>("login");
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const endpoint = useMemo(() => (mode === "login" ? "/api/auth/login" : "/api/auth/signup"), [mode]);

  useEffect(() => {
    const requestedMode = new URLSearchParams(window.location.search).get("mode");
    if (requestedMode === "login" || requestedMode === "signup") {
      setMode(requestedMode);
    }
  }, []);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);

    const payload: Record<string, string> = { email, password };
    if (mode === "signup") payload.name = name;

    const res = await fetch(endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });

    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      setError(data.error ?? "authentication failed");
      setLoading(false);
      return;
    }

    router.push("/dashboard");
    router.refresh();
  }

  return (
    <main className="auth-shell">
      <section className="auth-panel">
        <div style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: "var(--space-2)", marginBottom: "var(--space-2)" }}>
          <LogoMark size={26} />
          <h1 style={{ margin: 0 }}>DhanPath</h1>
        </div>
        <p>The smart family finance workspace. Track, analyze, and optimize together.</p>

        <div className="auth-tabs">
          <button
            className={mode === "login" ? "active" : ""}
            onClick={() => setMode("login")}
            type="button"
          >
            Login
          </button>
          <button
            className={mode === "signup" ? "active" : ""}
            onClick={() => setMode("signup")}
            type="button"
          >
            Sign Up
          </button>
        </div>

        <form onSubmit={handleSubmit} className="form-grid">
          {mode === "signup" && (
            <label>
              Name
              <input value={name} onChange={(e) => setName(e.target.value)} placeholder="Your name" />
            </label>
          )}

          <label>
            Email
            <input
              required
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="you@example.com"
            />
          </label>

          <label>
            Password
            <input
              required
              type="password"
              minLength={6}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="At least 6 characters"
            />
          </label>

          {error && <p className="error">{error}</p>}

          <button disabled={loading} className="primary" type="submit">
            {loading ? "Please wait..." : mode === "login" ? "Login" : "Create account"}
          </button>
        </form>
      </section>
    </main>
  );
}
