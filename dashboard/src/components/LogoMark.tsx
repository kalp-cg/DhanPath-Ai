type LogoMarkProps = {
  size?: number;
  className?: string;
};

export default function LogoMark({ size = 28, className }: LogoMarkProps) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 28 28"
      fill="none"
      className={className}
      aria-hidden="true"
    >
      <rect x="0.5" y="0.5" width="27" height="27" rx="4.8" fill="#0D1538" />

      <rect x="6" y="17" width="5" height="7" fill="#2E84BF" />
      <rect x="12" y="13" width="5" height="11" fill="#37C670" />
      <rect x="18" y="9" width="5" height="15" fill="#F2CB0C" />

      <path
        d="M6.2 16.5h3.1l3.1-4.2h2.9l3-4.2 3.5-3.5"
        stroke="#F3F4F6"
        strokeWidth="1.4"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <circle cx="21.9" cy="4.7" r="1.6" fill="#F2CB0C" stroke="#C5A203" strokeWidth="0.5" />
    </svg>
  );
}
