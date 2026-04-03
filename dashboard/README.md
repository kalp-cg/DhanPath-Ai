# DhanPath AI Dashboard (Next.js)

This folder contains the web admin dashboard for Family Mode.

## Why Next.js Here

- App Router pages for a real web app structure
- API routes for server-side logic (`/api/family/summary`, `/api/forecast`)
- Smooth Supabase integration for family-level data
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
NEXT_PUBLIC_FAMILY_ID=
```

If Supabase is not configured, APIs return mock demo data so the dashboard still works for rehearsals.

## Routes

- `/` landing page with build status and links
- `/auth` Supabase magic-link sign-in page
- `/family` family dashboard (member bars + runway section)
- `/api/family/summary` family summary JSON
- `/api/forecast` budget forecast JSON

## Auth + RLS Behavior

- When Supabase env is configured, `/api/family/summary` requires `Authorization: Bearer <access_token>`.
- The `/family` page reads current session token from Supabase Auth and sends it to the API.
- If no session is available, user is prompted to sign in via `/auth`.

## Verify Build

```bash
npm run lint
npm run build
```
