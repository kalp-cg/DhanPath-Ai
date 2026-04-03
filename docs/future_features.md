# 🔮 Future Features (Post-Hackathon Roadmap)

These features are strictly **out-of-scope** for the 48-hour OceanLab hackathon. Do not attempt to build these this weekend. They are critical for the product's long-term maturity as an AI-first SaaS and should be mentioned if judges ask about the roadmap.

## 1. Advanced AI & ML
- **Custom Local ML Categorization Model:** Replace the hardcoded regex/if-else parser with a TinyML model that categorizes transactions locally on-device for maximum privacy without maintaining huge keyword maps.
- **Voice Assistant:** Allow users to talk to DhanPath AI natively (e.g., "DhanPath, log 500 rupees for petrol").

## 2. Advanced Multi-Player & Sync
- **Complex Authentication & Onboarding:** Real password-based auth, email verification, and proper family-invite links (OTP-based).
- **Gamified Family Savings Goals:** Allow the family to set a shared goal ("Go to Bali") and visually track contributions to it synchronously across devices.

## 3. Web Dashboard Pro Features
- **Forecasting Charts:** Provide AI predictions: "At this rate, your family will exhaust the budget by the 24th of this month."
- **Export & Compliance:** Export family spending data to CSV/PDF for chartered accountant (CA) reporting.

## 4. Deep Edge Cases
- **Handling Multi-Bank SMS Formats:** Support 50+ localized bank SMS formats robustly with parser fallback queues.
- **Offline Sync Conflicts:** Complex conflict resolution if multiple users are adding expenses offline simultaneously and then reconnecting to the network.
