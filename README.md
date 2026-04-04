# DhanPath AI

<p align="center">
  <img src="assets/icon/app_icon.png" alt="DhanPath AI Logo" width="132" />
</p>

<p align="center">
  <a href="PASTE_YOUR_YOUTUBE_DEMO_LINK_HERE">
    <img src="https://img.shields.io/badge/YouTube-Demo%20Video-FF0000?style=for-the-badge&logo=youtube&logoColor=white" alt="Demo Video" />
  </a>
</p>

<p align="center">
  <strong>Watch the complete product walkthrough:</strong><br/>
  <a href="PASTE_YOUR_YOUTUBE_DEMO_LINK_HERE">Demo Video of Whole Product</a>
</p>

Premium AI-powered family finance product for hackathons and real-world operations.

- Mobile app: offline-first capture, SMS parsing, SQLite reliability.
- Dashboard: command center, analytics, billing, governance, and CA-ready exports.
- Sync bridge: one-way mobile to cloud flow for stable demo delivery.

## Hackathon Priority Highlights

### 1. Payment Gateway + Subscription Flow
- Dual payment readiness with Stripe and Razorpay wiring.
- Plan-based subscription model with provider metadata and usage tracking.
- Billing history export for operational and investor review.

### 2. SMS Parsing Engine (Core Innovation)
- Bank SMS parser pipeline with transaction extraction and categorization.
- Duplicate detection for repeated bank notifications.
- Offline-first persistence so data survives weak/no network.

### 3. Verified Webhooks for Billing Automation
- Dedicated webhook endpoint for payment event ingestion.
- Signature validation before state mutation.
- Automated subscription updates after successful payment events.

### 4. Demo-Stable Architecture
- MongoDB-backed dashboard APIs with JWT auth cookies.
- One-way sync from mobile local data to dashboard family ledger.
- Scope locked for reliability-first hackathon demonstration.

## Product Feature Catalog

### Authentication and Access
- Unified login and signup flow.
- JWT session auth with HTTP-only cookie strategy.
- Family create/join workflow with invite-code onboarding.

### Family Workspace and Roles
- Family-level data visibility with role-sensitive actions.
- Member management (role change, remove member).
- Invite sharing and household onboarding support.

### Financial Operations
- Manual + imported transaction ledger support.
- Category and member-level drill-down.
- Monthly report endpoints and export pathways.

### Command Center (Founder/Admin Mode)
- Executive score and performance tier.
- Risk radar and operational health surfaces.
- What-If Lab to simulate savings strategies.
- One-click Apply Plan to Family action.

### Budget and Goals Intelligence
- Budget utilization with pressure-point visibility.
- Goal progress board with ETA logic.
- Automatic linkage to active action plans.

### Billing, Invoices, and Governance
- Subscription read model with provider and timeline state.
- Billing event history and CSV export.
- Audit trail for critical family and admin operations.

### CA Pack and Compliance Workflows
- CA schedule setup with include-audit option.
- Monthly pack generation and tokenized sharing.
- CSV/PDF retrieval for accountant-ready handoff.

## Product Areas by Surface

### Mobile App (Flutter)
- Offline transaction store (SQLite).
- SMS ingestion and parser-based extraction.
- Financial views and quick insights for daily use.
- Cloud sync trigger for dashboard visibility.

### Web Dashboard (Next.js)
- Landing and auth experience.
- Overview, transactions, analytics, insights, members, audit.
- Billing and CA pack operations.
- Command center for strategy-to-execution loops.

## Monorepo Structure

```text
DhanPath-Ai/
  lib/                    Flutter mobile app source
  test/                   Flutter test suite
  dashboard/              Next.js dashboard + API routes
  docs/                   Hackathon and product docs
  assets/                 Icons and static media
  android/ ios/ web/ ...  Platform targets
```

## Tech Stack

### Mobile
- Flutter / Dart
- SQLite (sqflite)
- Telephony-based SMS intake
- Provider state management
- Secure storage and local auth support

### Dashboard
- Next.js App Router (TypeScript)
- React 19
- MongoDB + Mongoose
- JWT authentication
- Stripe + Razorpay integration points

## Important API Endpoints

### Auth
- POST /api/auth/signup
- POST /api/auth/login
- POST /api/auth/logout
- GET /api/auth/me

### Family
- POST /api/family/create
- POST /api/family/join
- GET /api/family/summary
- PATCH /api/family/members
- DELETE /api/family/members

### Transactions and Reporting
- GET /api/transactions
- POST /api/transactions
- GET /api/family/transactions/report

### Billing and Payments
- GET /api/billing/plans
- GET /api/billing/subscription
- POST /api/billing/subscribe
- POST /api/billing/confirm
- POST /api/billing/webhook
- GET /api/billing/invoices/export

### Audit and CA Pack
- GET /api/family/audit
- GET /api/family/audit/export
- GET /api/family/ca-pack/settings
- POST /api/family/ca-pack/settings
- POST /api/family/ca-pack/generate
- POST /api/family/ca-pack/run-due

### Command Center Planning
- GET /api/dashboard/command-center
- GET /api/family/action-plan
- POST /api/family/action-plan

## Quick Start

### 1) Mobile App

Prerequisites:
- Flutter SDK
- Android SDK or physical device

```bash
flutter pub get
flutter run
```

Run tests:

```bash
flutter test
```

### 2) Dashboard App

Prerequisites:
- Node.js 18+
- MongoDB running locally or remotely

```bash
cd dashboard
npm install
npm run dev
```

Quality checks:

```bash
cd dashboard
npm run lint
npm run build
```

## Environment Variables (Dashboard)

Create and update dashboard/.env:

```env
MONGODB_URI=mongodb://127.0.0.1:27017
MONGODB_DB=dhanpath
JWT_SECRET=replace_with_long_random_secret
NEXT_PUBLIC_APP_URL=http://localhost:3000

# Razorpay
RAZORPAY_KEY_ID=
RAZORPAY_KEY_SECRET=
RAZORPAY_WEBHOOK_SECRET=

# Stripe
STRIPE_SECRET_KEY=
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=

# Optional
CA_PACK_CRON_SECRET=
```

## Demo Flow (3 Minutes)

1. Show mobile expense capture and offline reliability.
2. Show dashboard login and family workspace.
3. Trigger sync and refresh dashboard transactions.
4. Show command center insights and apply an action plan.
5. Highlight billing, webhook automation, and audit/compliance exports.

## Documentation

- dashboard/FRONTEND_ARCHITECTURE.md
- docs/HACKATHON_DELIVERY_PLAN.md
- docs/OCEANLAB_HACKATHON_EXECUTION.md
- product.md

## License

Private/proprietary project. All rights reserved.
