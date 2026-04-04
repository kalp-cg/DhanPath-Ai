type BadgeVariant =
  | "debit"
  | "credit"
  | "info"
  | "warning"
  | "neutral"
  | "brand"
  | "admin";

type BadgeProps = {
  label: string;
  variant?: BadgeVariant;
  className?: string;
};

export default function Badge({ label, variant = "neutral", className = "" }: BadgeProps) {
  const classes = ["wm-badge", `wm-badge--${variant}`, className].filter(Boolean).join(" ");
  return <span className={classes}>{label}</span>;
}
