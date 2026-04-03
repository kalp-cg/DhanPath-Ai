# DhanPath AI Dashboard (Next.js)

This folder contains the web admin dashboard for Family Mode.

## Why Next.js Here

- App Router pages for a real web app structure
- API routes for server-side logic and business rules
- Node backend service layer owns all read/write operations
- Supabase is used as storage only (database persistence)
- Easy deployment on Vercel

## Quick Start

```bash
cd dashboard
npm install
cp .env.example .env.local
npm run dev
```

Open `http://localhost:3000`.

## Environment Variables

Set these in `.env.local`:

```bash
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=
NEXT_PUBLIC_APP_URL=http://localhost:3000
GEMINI_API_KEY=
```

No static/mock fallback is used by API routes. Supabase config is required.

## Routes

- `/` landing page with build status and links
- `/family` family dashboard (member bars + runway section)
- `/api/family/summary` family summary JSON
- `/api/family/workspace` create workspace (POST)
- `/api/family/invite` invite member by email (POST)
- `/api/family/invitations/pending` fetch pending invites for logged-in email (GET)
- `/api/family/invitations/accept` accept invite token (POST)
- `/api/transactions` create transaction (POST)
- `/api/forecast` budget forecast JSON

## Architecture Note

- Frontend never talks directly to Supabase.
- Next.js API routes act as backend endpoints.
- Backend service layer in `src/server/` handles Supabase queries and aggregation logic.

## Verify Build

```bash
npm run lint
npm run build
```
