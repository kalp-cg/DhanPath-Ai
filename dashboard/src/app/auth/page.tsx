"use client";

import Link from "next/link";
import { FormEvent, useMemo, useState } from "react";

import { createSupabaseBrowserClient } from "@/lib/supabase-browser";

export default function AuthPage() {
  const [email, setEmail] = useState("");
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const supabase = useMemo(() => {
    try {
      return createSupabaseBrowserClient();
    } catch {
      return null;
    }
  }, []);

  async function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setLoading(true);
    setError(null);
    setMessage(null);

    if (!supabase) {
      setLoading(false);
      setError("Supabase env is missing. Set NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY.");
      return;
    }

    const { error: signInError } = await supabase.auth.signInWithOtp({
      email,
      options: {
        shouldCreateUser: true,
      },
    });

    if (signInError) {
      setError(signInError.message);
    } else {
      setMessage("Magic link sent. Open it, then return to /family.");
    }

    setLoading(false);
  }

  return (
    <div className="page-shell">
      <header className="hero">
        <p className="eyebrow">DhanPath Web Auth</p>
        <h1>Sign In to Family Dashboard</h1>
        <p>Use Supabase magic link login to access RLS-protected family data.</p>
      </header>

      <section className="card" style={{ maxWidth: 560 }}>
        <form onSubmit={onSubmit} className="form-stack">
          <label htmlFor="email">Email</label>
          <input
            id="email"
            type="email"
            required
            placeholder="you@example.com"
            value={email}
            onChange={(event) => setEmail(event.target.value)}
          />
          <button className="cta primary" type="submit" disabled={loading}>
            {loading ? "Sending..." : "Send Magic Link"}
          </button>
        </form>

        {message ? <p className="safe" style={{ marginTop: 12 }}>{message}</p> : null}
        {error ? <p className="warn" style={{ marginTop: 12 }}>{error}</p> : null}

        <div className="chips" style={{ marginTop: 14 }}>
          <Link className="cta secondary" href="/family">
            Go to Family Dashboard
          </Link>
        </div>
      </section>
    </div>
  );
}
