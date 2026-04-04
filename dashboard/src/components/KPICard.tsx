"use client";

type KPICardProps = {
  label: string;
  value: string;
  subtitle?: string;
  trend?: { value: number; label?: string };
  icon?: string;
  variant?: "default" | "success" | "danger" | "warning" | "info";
};

export default function KPICard({ label, value, subtitle, trend, icon, variant = "default" }: KPICardProps) {
  const trendDirection = trend ? (trend.value > 0 ? "up" : trend.value < 0 ? "down" : "flat") : null;
  const hasFooter = Boolean(subtitle || trend);

  return (
    <article className={`kpi-card kpi-card--${variant} kpi-card--interactive`}>
      <div className="kpi-card-header">
        {icon && (
          <span className="kpi-card-icon" aria-hidden="true">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
              <path d="M4 19h16" />
              <path d="M7 14v-3" />
              <path d="M12 14V8" />
              <path d="M17 14V5" />
            </svg>
          </span>
        )}
        <span className="kpi-card-label">{label}</span>
      </div>
      <p className="kpi-card-value" title={value}>{value}</p>
      {hasFooter && (
        <div className="kpi-card-footer">
          {subtitle && <span className="kpi-card-subtitle">{subtitle}</span>}
          {trend && (
            <span className={`kpi-card-trend kpi-card-trend--${trendDirection}`}>
              {trendDirection === "up" && (
                <svg width="12" height="12" viewBox="0 0 12 12" fill="none"><path d="M6 2v8M3 5l3-3 3 3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/></svg>
              )}
              {trendDirection === "down" && (
                <svg width="12" height="12" viewBox="0 0 12 12" fill="none"><path d="M6 10V2M3 7l3 3 3-3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/></svg>
              )}
              {trend.value > 0 ? "+" : ""}{trend.value.toFixed(1)}%
              {trend.label && <span>{trend.label}</span>}
            </span>
          )}
        </div>
      )}
    </article>
  );
}
