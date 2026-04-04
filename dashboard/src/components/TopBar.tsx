"use client";

import { usePathname, useRouter } from "next/navigation";
import { useCallback, useEffect, useState } from "react";

type User = { id: string; email: string; name: string; familyId: string | null };

export default function TopBar() {
  const pathname = usePathname();
  const router = useRouter();
  const [user, setUser] = useState<User | null>(null);

  useEffect(() => {
    fetch("/api/auth/me", { cache: "no-store" })
      .then((r) => r.json())
      .then((d) => { if (d.user) setUser(d.user); })
      .catch(() => {});
  }, []);

  const pageTitle = useCallback(() => {
    const segments = pathname.split("/").filter(Boolean);
    const last = segments[segments.length - 1] || "dashboard";
    return last.charAt(0).toUpperCase() + last.slice(1).replace(/-/g, " ");
  }, [pathname]);

  async function logout() {
    await fetch("/api/auth/logout", { method: "POST" });
    router.replace("/auth");
  }

  return (
    <header className="topbar">
      <div className="topbar-left">
        <h1 className="topbar-title">{pageTitle()}</h1>
      </div>
      <div className="topbar-right">
        {user && (
          <div className="topbar-user">
            <div className="topbar-avatar">
              {user.name?.charAt(0).toUpperCase() || "U"}
            </div>
            <div className="topbar-user-info">
              <span className="topbar-user-name">{user.name}</span>
              <span className="topbar-user-email">{user.email}</span>
            </div>
            <button className="topbar-logout" onClick={logout} type="button" title="Logout">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9" />
              </svg>
            </button>
          </div>
        )}
      </div>
    </header>
  );
}
