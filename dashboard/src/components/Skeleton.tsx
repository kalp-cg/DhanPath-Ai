type SkeletonProps = {
  width?: string;
  height?: string;
  radius?: string;
  count?: number;
};

export default function Skeleton({ width = "100%", height = "16px", radius = "var(--radius-sm)", count = 1 }: SkeletonProps) {
  return (
    <>
      {Array.from({ length: count }, (_, i) => (
        <div
          key={i}
          className="skeleton"
          style={{ width, height, borderRadius: radius }}
        />
      ))}
    </>
  );
}

export function SkeletonCard() {
  return (
    <div className="skeleton-card">
      <Skeleton width="40%" height="12px" />
      <Skeleton width="60%" height="28px" />
      <Skeleton width="80%" height="12px" />
    </div>
  );
}
