"use client";

import { usePathname } from "next/navigation";
import Link from "next/link";
import { useState, useEffect } from "react";

type NavItem = {
  label: string;
  href: string;
  icon: "overview" | "command" | "transactions" | "analytics" | "insights" | "advisor" | "budget" | "goals" | "members" | "audit" | "pack" | "billing" | "settings";
  badge?: string;
};

type NavGroup = {
  title: string;
  items: NavItem[];
};

const navGroups: NavGroup[] = [
  {
    title: "Main",
    items: [
      { label: "Overview", href: "/dashboard", icon: "overview" },
      { label: "Command Center", href: "/dashboard/command-center", icon: "command" },
      { label: "Transactions", href: "/dashboard/transactions", icon: "transactions" },
      { label: "Analytics", href: "/dashboard/analytics", icon: "analytics" },
      { label: "Insights", href: "/dashboard/insights", icon: "insights" },
      { label: "AI Advisor", href: "/dashboard/ai-advisor", icon: "advisor" },
    ],
  },
  {
    title: "Finance",
    items: [
      { label: "Budget", href: "/dashboard/budget", icon: "budget" },
      { label: "Goals", href: "/dashboard/goals", icon: "goals" },
    ],
  },
  {
    title: "Family",
    items: [
      { label: "Members", href: "/dashboard/members", icon: "members" },
      { label: "Audit Log", href: "/dashboard/audit", icon: "audit" },
      { label: "CA Pack", href: "/dashboard/ca-pack", icon: "pack" },
    ],
  },
  {
    title: "Account",
    items: [
      { label: "Billing", href: "/dashboard/billing", icon: "billing" },
      { label: "Settings", href: "/dashboard/settings", icon: "settings" },
    ],
  },
];

function navIcon(icon: NavItem["icon"]) {
  const common = {
    width: "18",
    height: "18",
    viewBox: "0 0 24 24",
    fill: "none",
    stroke: "currentColor",
    strokeWidth: "1.8",
    strokeLinecap: "round" as const,
    strokeLinejoin: "round" as const,
  };

  switch (icon) {
    case "overview":
      return <svg {...common}><path d="M4 4h7v7H4zM13 4h7v4h-7zM13 10h7v10h-7zM4 13h7v7H4z"/></svg>;
    case "command":
      return <svg {...common}><path d="M4 12h16"/><path d="M12 4v16"/><circle cx="12" cy="12" r="3"/></svg>;
    case "transactions":
      return <svg {...common}><rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3 10h18"/><path d="M7 15h3"/></svg>;
    case "analytics":
      return <svg {...common}><path d="M4 20h16"/><path d="M7 16v-4"/><path d="M12 16V8"/><path d="M17 16V5"/></svg>;
    case "insights":
      return <svg {...common}><path d="M9 18h6"/><path d="M10 22h4"/><path d="M8 14a6 6 0 1 1 8 0c-1.1.9-1.7 1.7-2 4h-4c-.3-2.3-.9-3.1-2-4Z"/></svg>;
    case "advisor":
      return <svg {...common}><path d="M12 3 4 7v5c0 5 3.3 8.8 8 10 4.7-1.2 8-5 8-10V7z"/><path d="M9 12h6"/><path d="M12 9v6"/></svg>;
    case "budget":
      return <svg {...common}><circle cx="12" cy="12" r="8"/><path d="M12 8v4l3 3"/></svg>;
    case "goals":
      return <svg {...common}><path d="M12 3 4 7v5c0 5 3.4 8.9 8 10 4.6-1.1 8-5 8-10V7z"/></svg>;
    case "members":
      return <svg {...common}><circle cx="9" cy="8" r="3"/><path d="M3.5 18a5.5 5.5 0 0 1 11 0"/><circle cx="17" cy="9" r="2"/><path d="M14.5 18a4 4 0 0 1 5.5-3.7"/></svg>;
    case "audit":
      return <svg {...common}><rect x="5" y="3" width="14" height="18" rx="2"/><path d="M8 8h8M8 12h8M8 16h5"/></svg>;
    case "pack":
      return <svg {...common}><path d="M3 7h18v12H3z"/><path d="M3 7 12 3l9 4"/><path d="M12 3v4"/></svg>;
    case "billing":
      return <svg {...common}><path d="M12 3v18"/><path d="M17 7.5a5 5 0 0 0-5-2.5 4 4 0 0 0 0 8 4 4 0 0 1 0 8 5 5 0 0 1-5-2.5"/></svg>;
    case "settings":
      return <svg {...common}><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.9l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.9-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.2a1.7 1.7 0 0 0-1-1.5 1.7 1.7 0 0 0-1.9.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1A1.7 1.7 0 0 0 4.6 15a1.7 1.7 0 0 0-1.6-1H3a2 2 0 1 1 0-4h.2a1.7 1.7 0 0 0 1.5-1 1.7 1.7 0 0 0-.3-1.9l-.1-.1a2 2 0 0 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.9.3h.1a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.2a1.7 1.7 0 0 0 1 1.5h.1a1.7 1.7 0 0 0 1.9-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.9v.1a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.2a1.7 1.7 0 0 0-1.5 1Z"/></svg>;
  }
}

export default function Sidebar() {
  const pathname = usePathname();
  const [collapsed, setCollapsed] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);

  // Close mobile sidebar on route change
  useEffect(() => {
    setMobileOpen(false);
  }, [pathname]);

  // Close on escape
  useEffect(() => {
    const handleKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") setMobileOpen(false);
    };
    window.addEventListener("keydown", handleKey);
    return () => window.removeEventListener("keydown", handleKey);
  }, []);

  return (
    <>
      {/* Mobile hamburger */}
      <button
        className="sidebar-mobile-trigger"
        onClick={() => setMobileOpen(true)}
        type="button"
        aria-label="Open navigation"
      >
        <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
          <path d="M3 5h14M3 10h14M3 15h14" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
        </svg>
      </button>

      {/* Overlay */}
      {mobileOpen && (
        <div
          className="sidebar-overlay"
          onClick={() => setMobileOpen(false)}
          role="presentation"
        />
      )}

      {/* Sidebar */}
      <aside
        className={`sidebar ${collapsed ? "sidebar--collapsed" : ""} ${mobileOpen ? "sidebar--mobile-open" : ""}`}
      >
        {/* Brand */}
        <div className="sidebar-brand">
          <div className="sidebar-logo">
            <svg width="28" height="28" viewBox="0 0 28 28" fill="none">
              <rect width="28" height="28" rx="8" fill="var(--brand-primary)" />
              <path d="M8 14l4 4 8-8" stroke="white" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
          </div>
          {!collapsed && (
            <div className="sidebar-brand-text">
              <span className="sidebar-brand-name">DhanPath</span>
              <span className="sidebar-brand-badge">PRO</span>
            </div>
          )}
          <button
            className="sidebar-collapse-btn"
            onClick={() => setCollapsed(!collapsed)}
            type="button"
            aria-label={collapsed ? "Expand sidebar" : "Collapse sidebar"}
          >
            <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
              <path
                d={collapsed ? "M6 4l4 4-4 4" : "M10 4l-4 4 4 4"}
                stroke="currentColor"
                strokeWidth="1.5"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
          </button>
        </div>

        {/* Navigation */}
        <nav className="sidebar-nav">
          {navGroups.map((group) => (
            <div key={group.title} className="sidebar-group">
              {!collapsed && <span className="sidebar-group-title">{group.title}</span>}
              <ul className="sidebar-group-list">
                {group.items.map((item) => {
                  const isActive =
                    pathname === item.href ||
                    (item.href !== "/dashboard" && pathname.startsWith(item.href));
                  return (
                    <li key={item.href}>
                      <Link
                        href={item.href}
                        className={`sidebar-link ${isActive ? "sidebar-link--active" : ""}`}
                        title={collapsed ? item.label : undefined}
                      >
                        <span className="sidebar-link-icon">{navIcon(item.icon)}</span>
                        {!collapsed && (
                          <>
                            <span className="sidebar-link-label">{item.label}</span>
                            {item.badge && <span className="sidebar-link-badge">{item.badge}</span>}
                          </>
                        )}
                      </Link>
                    </li>
                  );
                })}
              </ul>
            </div>
          ))}
        </nav>

        {/* Footer */}
        <div className="sidebar-footer">
          {!collapsed && (
            <div className="sidebar-footer-content">
              <div className="sidebar-plan-badge">Free Plan</div>
              <span className="sidebar-footer-hint">Upgrade for full features</span>
            </div>
          )}
        </div>
      </aside>
    </>
  );
}
