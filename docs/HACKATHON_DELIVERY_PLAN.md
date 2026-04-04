# DhanPath AI Hackathon Delivery Plan

Date: 2026-04-04
Goal: Ship a strong demo with stable mobile + dashboard flow, MongoDB-backed family data, and one-way sync from app to dashboard.

## Scope Lock (Current)

Must show in demo:
- Mobile offline-first expense tracking (SQLite + SMS parsing)
- Dashboard auth + family create/join flow
- Family-level spend summary and transaction views
- One-way transaction sync from mobile to dashboard
- Stable audit/billing/export story already present in dashboard

Defer for now:
- Two-way sync and conflict resolution
- Supabase data backend migration
- Voice/PDF as mandatory demo path

## Architecture Decisions (Locked for Hackathon)

- Dashboard backend and family data source is MongoDB.
- Supabase can remain optional only for mobile auth/bootstrap use.
- Sync direction is one-way only: mobile SQLite -> dashboard API -> MongoDB.
- For demo reliability, keep generous limits and avoid strict blockers where possible.

## Delivery Sequence

1. Demo Stability
- Validate auth, family create/join, and transaction listing flows on dashboard.
- Validate mobile local transaction flow and sync trigger.

2. Data Confidence
- Confirm transaction dedup path works for repeated sync.
- Confirm family summary reflects synced transactions.

3. Demo Narrative Polish
- Prepare one happy-path walkthrough with realistic data.
- Prepare one fallback path if network/dashboard is unavailable.

4. Final Hardening
- Smoke test both mobile and dashboard paths.
- Freeze scope and avoid risky refactors before presentation.

## Current Status Notes

- Family workspace provider in mobile currently uses in-memory service.
- Cloud transaction sync service exists and calls dashboard APIs.
- Dashboard APIs are MongoDB-backed with JWT auth.
- Keep this state for hackathon demo; no architecture switch during final window.
