# DhanPath AI

DhanPath AI is a full-stack personal and family finance platform built as a monorepo:

- A Flutter mobile app for SMS-first expense tracking and on-device finance workflows.
- A Next.js dashboard for family-level analytics, billing, audit logs, CA pack generation, and founder-grade command center operations.

The product vision is simple: convert raw transaction data into clear decisions, then into measurable action plans.

## Highlights

- Offline-first mobile expense tracking with SMS parsing and manual entries.
- Family workspace dashboard with role-based access and invite flow.
- Command Center with executive score, risk alerts, What-If Lab, and one-click plan application.
- Budget and Goals pages linked to applied action plans.
- Billing plans, subscription usage tracking, and invoice export.
- Audit log APIs and exports for accountability.
- CA Pack generation flow for shareable monthly reporting.

## Monorepo Structure

```text
DhanPathAi/
  lib/                    Flutter app source
  test/                   Flutter tests
  dashboard/              Next.js dashboard (frontend + APIs)
  docs/                   Planning and architecture docs
  android/ ios/ web/ ...  Flutter platform folders
```

## Tech Stack

### Mobile App

- Flutter / Dart
- Provider
- SQLite (`sqflite`)
- Telephony SMS parsing
- Local auth + secure storage
- Notifications and reporting/export utilities

### Dashboard

- Next.js App Router (TypeScript)
- React 19
- MongoDB + Mongoose
- JWT cookie auth
- ESLint + TypeScript strict checks

## Key Product Areas

### Flutter App

- SMS transaction ingestion and parser-based extraction.
- Daily budget ring and spending controls.
- Transaction management and insights screens.
- Monthly reports, tools, and security controls.

### Dashboard

- Auth (`/auth`) and family create/join.
- Overview, Analytics, Transactions, Members, Audit, Billing.
- Command Center (`/dashboard/command-center`) with:
  - Executive score and tier.
  - Risk radar.
  - Founder playbook.
  - What-If savings simulation.
  - `Apply Plan to Family` workflow.
- Budget and Goals consume the applied action plan automatically.

## Local Setup

## 1) Flutter App

Prerequisites:

- Flutter SDK
- Android SDK or emulator/device

Install and run:

```bash
cd /home/xkalp/Desktop/DhanPathAi
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=your_supabase_url \
  --dart-define=SUPABASE_ANON_KEY=your_supabase_anon_key
```

Run tests:

```bash
cd /home/xkalp/Desktop/DhanPathAi
flutter test
```

## 2) Dashboard

Prerequisites:

- Node.js 18+
- MongoDB instance

Install and run:

```bash
cd /home/xkalp/Desktop/DhanPathAi/dashboard
npm install
npm run dev
```

Open: `http://localhost:3000`

Quality checks:

```bash
cd /home/xkalp/Desktop/DhanPathAi/dashboard
npm run lint
npm run build
```

## Environment Variables

### Dashboard (`dashboard/.env`)

Minimum required values:

```env
MONGODB_URI=mongodb://127.0.0.1:27017
MONGODB_DB=dhanpath
JWT_SECRET=replace_with_long_random_secret
```

Optional billing/URLs:

```env
NEXT_PUBLIC_APP_URL=http://localhost:3000
RAZORPAY_KEY_ID=
RAZORPAY_KEY_SECRET=
CA_PACK_CRON_SECRET=
```

Security note: never commit real secrets or production credentials.

## Important Dashboard APIs

Auth:

- `POST /api/auth/signup`
- `POST /api/auth/login`
- `POST /api/auth/logout`
- `GET /api/auth/me`

Family:

- `POST /api/family/create`
- `POST /api/family/join`
- `GET /api/family/summary`
- `PATCH /api/family/members`
- `DELETE /api/family/members`

Transactions and reporting:

- `GET /api/transactions`
- `POST /api/transactions`
- `GET /api/family/transactions/report`

Audit and CA pack:

- `GET /api/family/audit`
- `GET /api/family/audit/export`
- `GET /api/family/ca-pack/settings`
- `POST /api/family/ca-pack/settings`
- `POST /api/family/ca-pack/generate`

Command Center and planning:

- `GET /api/dashboard/command-center`
- `GET /api/family/action-plan`
- `POST /api/family/action-plan`

## How the Action Plan Loop Works

1. Founder opens Command Center.
2. What-If Lab simulates savings based on spend/category cut percentage.
3. Founder clicks `Apply Plan to Family`.
4. API persists plan in `ActionPlan` collection.
5. Budget and Goals pages immediately reflect applied targets and ETA.

This creates a complete loop: insight -> decision -> execution -> tracking.

## Permissions and Security

- Family admin checks are enforced on sensitive endpoints.
- Membership is reconciled server-side to avoid stale role drift.
- JWT auth via HTTP-only cookie on dashboard.
- Mobile app remains offline-first with local storage controls.

## Troubleshooting

- `403 admin access required` on dashboard:
  verify you are owner/admin in current family and re-login.
- `Missing JWT_SECRET` or `Missing MONGODB_URI`:
  confirm `dashboard/.env` values.
- Billing page stuck/loading:
  ensure billing env keys are configured and API endpoint responds.
- Parser mismatch on mobile:
  run full SMS resync from app tools after parser updates.

## Documentation

- `dashboard/FRONTEND_ARCHITECTURE.md`
- `docs/HACKATHON_DELIVERY_PLAN.md`
- `docs/OCEANLAB_HACKATHON_EXECUTION.md`

## License

Private/proprietary project. All rights reserved.
