import { cookies } from "next/headers";
import Link from "next/link";
import { redirect } from "next/navigation";

import { AUTH_COOKIE } from "@/lib/auth";

export default async function HomePage() {
  const cookieStore = await cookies();
  const token = cookieStore.get(AUTH_COOKIE)?.value;

  if (token) {
    redirect("/family");
  }

  return (
    <main className="shell landing-shell">
      <section className="panel hero">
        <h1>DhanPath AI Dashboard</h1>
        <p>Fresh MongoDB + Next.js workflow for email/password auth, family matching, and transactions.</p>
        <Link className="primary-link" href="/auth">
          Start Now
        </Link>
      </section>
    </main>
  );
}
