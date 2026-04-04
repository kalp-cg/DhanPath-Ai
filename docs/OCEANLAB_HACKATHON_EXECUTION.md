# OceanLab X Charusat 2026: Practical Execution Plan

Track: AI Expense Buddy
Goal: Deliver a clean, believable, end-to-end demo using what is already implemented and stable.

## 1) Product Story for Judges

- Mobile app captures and tracks personal expenses offline.
- Dashboard enables family-level view with role-based access and summaries.
- Cloud bridge syncs transactions from mobile to dashboard.
- Result: practical family finance visibility with real data in MongoDB.

## 2) Technical Truth (Locked for Demo)

- Dashboard stack: Next.js + MongoDB + JWT auth.
- Mobile app core data: local SQLite.
- Cloud sync: one-way only (mobile to dashboard).
- Supabase is not the primary data backend in current demo architecture.

## 3) Demo Scope to Execute

1. Mobile
- Show transaction capture and local history.
- Show that app works even without cloud dependency.

2. Dashboard
- Sign up/login, create or join family.
- Show member list, recent transactions, spend breakdown.

3. Sync
- Trigger sync from mobile setup flow.
- Refresh dashboard and show imported transactions.

4. Reliability
- Keep simple happy path first.
- Keep fallback script if sync is slow or network is unstable.

## 4) Team Split (Low-Risk)

Developer 1 (Mobile)
- Ensure local transaction flow is stable.
- Ensure cloud sync trigger works and gives clear result messages.
- Prepare demo seed data in device for sync.

Developer 2 (Dashboard)
- Ensure auth/family routes are stable.
- Ensure summary and transactions pages update correctly after sync.
- Ensure MongoDB deployment/demo environment is healthy.

## 5) 3-Minute Demo Script (Realistic)

1. 0:00-0:40
- Problem and solution statement.
- Show offline-first mobile expense tracking.

2. 0:40-1:30
- Show family dashboard login and workspace view.
- Explain role-based family visibility.

3. 1:30-2:20
- Trigger one-way sync from mobile.
- Refresh dashboard and verify new transactions in family reports.

4. 2:20-3:00
- Highlight architecture practicality: mobile reliability + cloud aggregation.
- Close with immediate roadmap: optional two-way sync and richer AI later.

## 6) Out of Scope for Final Hackathon Window

- Forced migration to Supabase backend.
- Two-way sync/conflict resolution.
- Any deep refactor that risks breaking demo stability.
