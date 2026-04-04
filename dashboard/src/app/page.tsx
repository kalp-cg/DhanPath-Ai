import { cookies } from "next/headers";
import Link from "next/link";
import { redirect } from "next/navigation";

import { AUTH_COOKIE } from "@/lib/auth";

export default async function HomePage() {
  const cookieStore = await cookies();
  const token = cookieStore.get(AUTH_COOKIE)?.value;

  if (token) {
    redirect("/dashboard");
  }

  return (
    <main className="landing-shell">
      <section className="hero">
        <h1>DhanPath Workspace</h1>
        <p>
          The family finance dashboard built for daily use. Track spending, manage budgets,
          and run planning with one focused workspace.
        </p>
        <Link className="primary-link" href="/auth">
          Get Started →
        </Link>
      </section>
    </main>
  );
}
