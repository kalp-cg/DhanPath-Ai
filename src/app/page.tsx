export default function Home() {
  return (
    <div className="dash-shell" style={{ minHeight: "100vh", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: "2rem" }}>
      <div style={{ textAlign: "center" }}>
        <div style={{
          width: 72, height: 72, borderRadius: 18,
          background: "linear-gradient(135deg, #10b981, #059669)",
          display: "flex", alignItems: "center", justifyContent: "center",
          fontSize: "2rem", color: "#fff", fontWeight: 800,
          margin: "0 auto 1.5rem",
          boxShadow: "0 0 40px rgba(16, 185, 129, 0.3)",
        }}>₹</div>
        <p style={{ fontSize: "0.75rem", color: "var(--accent-teal)", letterSpacing: "0.12em", textTransform: "uppercase", fontFamily: "var(--font-mono, monospace)", marginBottom: "0.5rem" }}>
          OceanLab × CHARUSAT 2026
        </p>
        <h1 style={{ fontSize: "clamp(1.8rem, 5vw, 3rem)", fontWeight: 800, margin: "0 0 0.75rem", background: "linear-gradient(90deg, #f1f5f9, #10b981)", WebkitBackgroundClip: "text", WebkitTextFillColor: "transparent" }}>
          DhanPath AI
        </h1>
        <p style={{ fontSize: "1.05rem", color: "var(--text-secondary)", maxWidth: 480, margin: "0 auto 2rem" }}>
          India&apos;s first SMS-native, AI-powered family budget OS.
          <br />Zero manual entry. 100% private.
        </p>
        <div style={{ display: "flex", gap: "0.75rem", justifyContent: "center", flexWrap: "wrap" }}>
          <a
            href="/family"
            style={{
              display: "inline-flex", alignItems: "center", gap: "0.5rem",
              padding: "0.75rem 1.5rem", borderRadius: 999,
              background: "linear-gradient(135deg, #10b981, #059669)",
              color: "#fff", fontWeight: 700, fontSize: "0.95rem",
              textDecoration: "none",
              boxShadow: "0 8px 24px rgba(16, 185, 129, 0.3)",
              transition: "transform 0.15s, box-shadow 0.15s",
            }}
          >
            Open Family Dashboard →
          </a>
          <a
            href="/api/family/summary"
            style={{
              display: "inline-flex", alignItems: "center", gap: "0.5rem",
              padding: "0.75rem 1.5rem", borderRadius: 999,
              background: "transparent",
              border: "1px solid rgba(16, 185, 129, 0.3)",
              color: "var(--accent-teal)", fontWeight: 600, fontSize: "0.95rem",
              textDecoration: "none",
              transition: "border-color 0.15s",
            }}
          >
            Test API
          </a>
        </div>
      </div>
      <div style={{ display: "flex", gap: "2rem", marginTop: "1rem", flexWrap: "wrap", justifyContent: "center" }}>
        {[
          { label: "SMS Auto-Parse", icon: "📱" },
          { label: "Family Mode", icon: "👨‍👩‍👦" },
          { label: "3 AI Modalities", icon: "🤖" },
          { label: "Budget Forecast", icon: "📈" },
        ].map((f) => (
          <div key={f.label} style={{
            padding: "0.85rem 1.25rem", borderRadius: "1rem",
            background: "rgba(255,255,255,0.04)",
            border: "1px solid rgba(255,255,255,0.08)",
            backdropFilter: "blur(12px)",
            textAlign: "center", minWidth: 120,
          }}>
            <div style={{ fontSize: "1.5rem", marginBottom: "0.35rem" }}>{f.icon}</div>
            <div style={{ fontSize: "0.78rem", color: "var(--text-secondary)" }}>{f.label}</div>
          </div>
        ))}
      </div>
    </div>
  );
}
