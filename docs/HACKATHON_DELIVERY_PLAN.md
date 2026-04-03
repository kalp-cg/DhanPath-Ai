# DhanPath AI Hackathon Delivery Plan

Date: 2026-04-03
Goal: Ship a winning 3-minute demo with Family Mode + AI assistant + forecast storyline.

## Scope Lock

Must ship:
- Family workspace create/join flow (mobile)
- Family spend aggregation and forecast line logic
- AI assistant over real transaction context
- Demo-ready dashboard view

Can defer if blocked:
- Voice logging
- Advanced analytics polish

## Build Sequence

1. Foundation (Now - 3h)
- Add family workspace domain models and state provider
- Add forecast calculation service + unit tests
- Add integration interfaces for Supabase and Gemini

2. Family Sync (3h - 12h)
- Supabase schema migration for users/families/family_members/transactions
- RLS policy pass
- Create/join by invite code
- Sync parsed transactions with dedup key

3. AI Layer (12h - 20h)
- Gemini chat service with safe structured prompt
- Family-level questions from real data
- Add API failure fallback responses for demo reliability

4. Demo UX (20h - 32h)
- Family cards + per-member spend bars
- Forecast section with projected exhaustion day
- Admin/member role display

5. Demo Hardening (32h - 48h)
- Stable seed dataset
- Scripted happy-path walkthrough
- Backup offline scenario and fallback screenshots

## Immediate Start Status

Completed in this commit window:
- Family workspace models scaffolded
- Family workspace provider scaffolded
- Budget forecast service + unit tests added
- Plan documented for focused execution

Next implementation target:
- Wire Supabase-backed FamilySyncService and replace in-memory implementation.
