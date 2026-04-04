import { cookies } from "next/headers";
import Link from "next/link";
import { redirect } from "next/navigation";

import { AUTH_COOKIE } from "@/lib/auth";
import LogoMark from "@/components/LogoMark";

export default async function HomePage() {
  const cookieStore = await cookies();
  const token = cookieStore.get(AUTH_COOKIE)?.value;

  if (token) {
    redirect("/dashboard");
  }

  return (
    <main className="landing-shell">
      <div className="landing-grid-overlay" aria-hidden="true" />
      <div className="landing-aurora landing-aurora--left" aria-hidden="true" />
      <div className="landing-aurora landing-aurora--right" aria-hidden="true" />

      <section className="landing-nav">
        <div className="landing-brand">
          <LogoMark size={30} />
          <div>
            <strong>DhanPath</strong>
            <span>Finance Workspace</span>
          </div>
        </div>
        <div className="landing-nav-actions">
          <Link className="landing-btn landing-btn--ghost" href="/auth?mode=login">
            Sign In
          </Link>
          <Link className="landing-btn landing-btn--solid" href="/auth?mode=signup">
            Sign Up Free
          </Link>
        </div>
      </section>

      <section className="landing-hero">
        <div className="landing-copy">
          <span className="landing-kicker">Built for serious financial clarity</span>
          <h1>Premium family finance command center for modern households.</h1>
          <p>
            See every account, budget, and plan in one elegant workspace. DhanPath helps your
            family save smarter, spend intentionally, and move toward long-term goals together.
          </p>

          <div className="landing-cta-row">
            <Link className="landing-btn landing-btn--solid" href="/auth?mode=signup">
              Create Account
            </Link>
            <Link className="landing-btn landing-btn--ghost" href="/auth?mode=login">
              Login to Workspace
            </Link>
          </div>

          <ul className="landing-proof-list" aria-label="Platform highlights">
            <li>
              <strong>99.9%</strong>
              <span>uptime infrastructure</span>
            </li>
            <li>
              <strong>256-bit</strong>
              <span>bank-level encryption</span>
            </li>
          </ul>
        </div>

        <aside className="landing-preview" aria-label="DhanPath product snapshot">
          <div className="preview-head">
            <span className="preview-pill">Live Overview</span>
            <span className="preview-caption">Updated 2m ago</span>
          </div>

          <div className="preview-balance-card">
            <p>Total family balance</p>
            <h2>INR 14,82,300</h2>
            <span>+8.6% vs last month</span>
          </div>

          <div className="preview-tiles">
            <article>
              <p>Savings Goal</p>
              <strong>78%</strong>
            </article>
            <article>
              <p>Spend Health</p>
              <strong>Excellent</strong>
            </article>
          </div>

          <div className="preview-bars" aria-hidden="true">
            <span style={{ height: "46%" }} />
            <span style={{ height: "72%" }} />
            <span style={{ height: "58%" }} />
            <span style={{ height: "86%" }} />
            <span style={{ height: "65%" }} />
            <span style={{ height: "94%" }} />
          </div>
        </aside>
      </section>

      <section className="landing-marquee" aria-label="Trusted product capabilities">
        <p>Automated insights</p>
        <p>Family permissions</p>
        <p>Tax-ready reports</p>
        <p>Smart alerts</p>
        <p>Goal simulations</p>
      </section>
    </main>
  );
}
