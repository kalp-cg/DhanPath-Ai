import Link from "next/link";

export default function Home() {
  return (
    <div className="page-shell">
      <header className="hero">
        <p className="eyebrow">OceanLab x CHARUSAT 2026</p>
        <h1>DhanPath AI Web Dashboard</h1>
        <p>
          Next.js control panel for family spend visibility, budget runway, and
          Supabase-backed sync.
        </p>
      </header>

      <section className="grid two">
        <article className="card">
          <h2>What Is Ready</h2>
          <p>- Family summary endpoint (`/api/family/summary`)</p>
          <p>- Forecast endpoint (`/api/forecast`)</p>
          <p>- Demo dashboard page with spend bars and runway signal</p>
          <p>- Supabase fallback-safe response mode for hackathon demos</p>
        </article>

        <article className="card">
          <h2>Next Immediate Step</h2>
          <p>
            Connect real Supabase project credentials in `.env.local`, then wire
            authenticated admin/member views.
          </p>
          <div className="chips" style={{ marginTop: "0.9rem" }}>
            <Link className="cta primary" href="/family">
              Open Family Dashboard
            </Link>
            <Link className="cta secondary" href="/api/family/summary">
              Test Summary API
            </Link>
          </div>
        </article>
      </section>
    </div>
  );
}
