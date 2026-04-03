# DhanPath Family SaaS Plan

Date: 2026-04-03
Goal: Convert DhanPath from app project to revenue-ready Family Finance SaaS.

## Product Thesis

- Primary user: Family admin (father/mother) who wants total household visibility.
- Daily user: Family members logging and auto-importing transactions.
- Core promise: "Every family member's transactions, one live family dashboard."

## Final Workflow (Simple)

1. Mobile app opens.
2. User signs in with email + password.
3. User email is stored locally and synced to Supabase user profile.
4. Family admin creates workspace on web and invites members by email.
5. Member accepts invite once.
6. Mobile auto-sync pushes transactions to backend API.
7. Web dashboard reads latest family summary and forecast in real time.

## Architecture (Production)

- Mobile: Flutter app (capture + local processing + sync trigger)
- Backend: Next.js API routes (business logic, auth checks, aggregation)
- Storage: Supabase Postgres only (no frontend direct DB writes)

Rules:
- Frontend must not own business logic.
- All family authorization checks happen in backend APIs.
- Supabase used as data layer and identity provider.

## MVP Scope to Ship

- Email/password login in mobile
- Family invite + accept by email
- Transaction sync endpoint with idempotency
- Family summary endpoint with member-wise totals
- Budget runway calculation and trend graph

## Revenue Packaging

- Free: 1 user, local-only, basic analytics
- Family (Rs 199/month): up to 6 members, cloud sync, family dashboard, runway forecast
- Pro Family (Rs 399/month): AI insights, anomaly alerts, monthly PDF report, priority support

## CEO Demo Story (3 minutes)

1. Sign in from two family accounts.
2. Add one transaction on member phone.
3. Show instant dashboard update on web admin view.
4. Ask AI: "Can we stay within Rs 40,000 this month?"
5. Show runway day and action suggestion.

## Weekly Execution Plan

Week 1:
- Stabilize auth/sync/invite flow
- Remove dead screens and duplicate service paths
- Add telemetry logs for sync failures

Week 2:
- Add subscription checks in backend middleware
- Add billing-ready account model
- Add dashboard KPI cards and CSV monthly export

Week 3:
- AI recommendation endpoint (cost-safe prompt)
- Alerting workflow (overspend warnings)
- Onboarding funnel optimization

## Quality Gates

- Build passes for Flutter + Next.js on each merge
- API contract tests for sync, invite, summary
- No silent sync failures (all failures logged)
- Dashboard latency target: summary endpoint < 500ms for normal family size
