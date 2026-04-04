# DhanPath Dashboard Frontend Architecture

## 1) Scope and Stack
- Framework: Next.js App Router (`src/app`) with TypeScript.
- Rendering model:
  - Public and auth routes use route-level pages directly.
  - Dashboard routes use shared shell layout (`Sidebar + TopBar + content`).
- Styling system:
  - Global styles: `src/app/globals.css`
  - Design tokens: `src/app/design-tokens.css`
  - Theme mode currently forced to light in root layout.
- Fonts: `Manrope` and `Sora` loaded in root layout.
- Primary frontend data source: internal API routes under `src/app/api/**`.

## 2) Route and Layout Map

### Root Layout
- File: `src/app/layout.tsx`
- Responsibilities:
  - Injects global CSS.
  - Sets metadata.
  - Applies font CSS variables.
  - Forces `data-theme="light"`.

### Dashboard Layout
- File: `src/app/dashboard/layout.tsx`
- Structure:
  - `Sidebar` (left navigation)
  - `TopBar` (page title + user summary + logout)
  - `main.app-content` (page content slot)

### App Routes
- `/` -> landing page (`src/app/page.tsx`)
- `/auth` -> login/signup page (`src/app/auth/page.tsx`)
- `/dashboard` -> overview (`src/app/dashboard/page.tsx`)
- `/dashboard/transactions` -> transaction explorer (`src/app/dashboard/transactions/page.tsx`)
- `/dashboard/analytics` -> category/member/year analytics (`src/app/dashboard/analytics/page.tsx`)
- `/dashboard/insights` -> generated insight cards (`src/app/dashboard/insights/page.tsx`)
- `/dashboard/budget` -> budget health and category pressure (`src/app/dashboard/budget/page.tsx`)
- `/dashboard/goals` -> derived savings goals (`src/app/dashboard/goals/page.tsx`)
- `/dashboard/members` -> member management and comparison (`src/app/dashboard/members/page.tsx`)
- `/dashboard/audit` -> audit log filters + export (`src/app/dashboard/audit/page.tsx`)
- `/dashboard/ca-pack` -> CA schedule and pack generation (`src/app/dashboard/ca-pack/page.tsx`)
- `/dashboard/billing` -> plan details and billing timeline (`src/app/dashboard/billing/page.tsx`)
- `/dashboard/settings` -> profile/family setup/manual transaction entry (`src/app/dashboard/settings/page.tsx`)
- `/family` -> legacy monolithic workspace page (`src/app/family/page.tsx`)
- `/ca-pack/[token]` -> public CA share page (`src/app/ca-pack/[token]/page.tsx`)

## 3) Shared Component Architecture

### Navigation Shell
- `src/components/Sidebar.tsx`
  - Grouped nav sections: Main, Finance, Family, Account.
  - Collapsible desktop sidebar.
  - Mobile drawer with overlay and escape-key close.
  - Active-route highlighting based on pathname.
- `src/components/TopBar.tsx`
  - Dynamic page title from pathname.
  - Fetches `/api/auth/me` client-side.
  - Shows user avatar/name/email.
  - Logout action posts to `/api/auth/logout`.

### Data Display Primitives
- `src/components/KPICard.tsx`
  - KPI card with variant styles (`default|success|danger|warning|info`).
  - Optional trend block and subtitle.
- `src/components/EmptyState.tsx`
  - Generic empty placeholder with optional CTA button.
- `src/components/Skeleton.tsx`
  - Loading placeholders.
  - `SkeletonCard()` used in KPI/grid loading states.

## 4) Page-by-Page Behavior

## 4.1 Public Pages

### Landing (`/`)
- File: `src/app/page.tsx`
- Behavior:
  - Checks auth cookie server-side.
  - Redirects authenticated users to `/dashboard`.
  - Otherwise shows hero + CTA to `/auth`.

### Auth (`/auth`)
- File: `src/app/auth/page.tsx`
- Behavior:
  - Toggle mode: `login` / `signup`.
  - POST endpoint selected by mode:
    - login -> `/api/auth/login`
    - signup -> `/api/auth/signup`
  - On success: route to `/dashboard` and refresh.

## 4.2 Dashboard Workspace Pages

### Overview (`/dashboard`)
- File: `src/app/dashboard/page.tsx`
- Data source:
  - `/api/family/summary` with `year=current`, `month=current`, `memberId` filter, `page=1`, `pageSize=5`.
  - Polls every 30s.
- Visual order:
  1. Family strip (name, invite code, plan chips, member selector).
  2. 4 KPI cards.
  3. Two-column panel: top categories and people-wise split.
  4. Recent transactions list (up to 5 shown).
  5. Monthly spending trend bars.
- Filters:
  - Member: `all` + each member from summary.

### Transactions (`/dashboard/transactions`)
- File: `src/app/dashboard/transactions/page.tsx`
- Data sources:
  - Members list from `/api/family/summary?year=2026&month=1&memberId=all&page=1&pageSize=1`.
  - Transaction data from `/api/transactions`.
- Default filter state:
  - `year=all`, `month=all`, `memberId=all`, `type=all`, `category=all`, `page=1`.
- Date-range logic:
  - Year/month produce `from/to`; `year=all` means no date window.
  - Local date formatting used to avoid timezone boundary drops.
- Visual order:
  1. Totals KPI row (debit/credit/net/count).
  2. Filter panel + actions (Clear, Export CSV, PDF View).
  3. People-wise clarity chart/list (if available).
  4. Full transaction list.
  5. Pager (`Previous`, `Next`, page summary).
- Pagination:
  - API receives `page` and fixed `pageSize=20`.
  - UI uses API booleans `hasPrev/hasNext`.

### Analytics (`/dashboard/analytics`)
- File: `src/app/dashboard/analytics/page.tsx`
- Data source: `/api/family/summary`.
- Filters:
  - Year from `availableYears`.
  - Month 1-12.
  - Member `all` + specific members.
- Visual order:
  1. Period filter panel.
  2. Category chart + people split (2-column).
  3. Month-wise trend chart (empty state when filtered trend total is 0).
  4. Member comparison chart.
  5. Year-wise totals chart (if available).
- Special behavior:
  - If selected year is not in `availableYears`, auto-fallback to first available year and month `1`.

### Insights (`/dashboard/insights`)
- File: `src/app/dashboard/insights/page.tsx`
- Data source: `/api/family/summary` for current month/year (`memberId=all`).
- Behavior:
  - Builds derived recommendation cards from top category, pace projection, member split, timeline activity.
  - Shows severity-colored cards and a generated "spending story" paragraph.

### Budget (`/dashboard/budget`)
- File: `src/app/dashboard/budget/page.tsx`
- Data source: `/api/family/summary`.
- Filters:
  - Year, month, member.
- Derived model:
  - Suggested budget = `currentSpend * 1.15` fallback `10000`.
  - Remaining buffer and utilization percentage.
- Visual order:
  1. Filter panel.
  2. KPI row (actual, suggested, remaining, usage%).
  3. Utilization bar chart.
  4. Category pressure list with percent-of-month spend.

### Goals (`/dashboard/goals`)
- File: `src/app/dashboard/goals/page.tsx`
- Data source: `/api/family/summary`.
- Filters:
  - Year, month, member.
- Derived goals:
  - Emergency buffer (3-month average spend with floor).
  - Category cut target (15% of top category).
  - Annual savings target.
- Visual order:
  1. Filter panel.
  2. KPI row (month spend, active monthly avg, annual target).
  3. Goal progress chart list with progress bars.

### Members (`/dashboard/members`)
- File: `src/app/dashboard/members/page.tsx`
- Data source: `/api/family/summary` with member filter.
- Features:
  - Invite code display + clipboard copy.
  - Member comparison chart (spend + txn volume bars).
  - Family member management list.
- Filters:
  - View member selector: `all` + each member.
- Admin actions:
  - Role change: PATCH `/api/family/members`.
  - Remove member: DELETE `/api/family/members?targetUserId=...`.
- Permission rules in UI:
  - Owner cannot be removed.
  - Admin cannot remove self.
  - Role buttons hidden by guard checks.

### Audit (`/dashboard/audit`)
- File: `src/app/dashboard/audit/page.tsx`
- Data source:
  - `/api/family/summary` with audit query params:
    - `auditAction`, `auditActorId`, `auditFrom`, `auditTo`, `auditPage`, `auditPageSize=15`.
- Filters:
  - Action, actor, from, to.
- Actions:
  - Clear filters (reset state).
  - Export CSV via `/api/family/audit/export`.
- Pagination UI:
  - Previous/Next buttons based on `auditPagination.hasPrev/hasNext`.
- Important note:
  - Current `family/summary` implementation does not return `recentAudit` and `auditPagination`; page is implemented for them but backend contract currently looks incomplete.

### CA Pack (`/dashboard/ca-pack`)
- File: `src/app/dashboard/ca-pack/page.tsx`
- Data sources:
  - GET/POST `/api/family/ca-pack/settings`
  - POST `/api/family/ca-pack/generate`
- Inputs:
  - CA email, day-of-month (1..28), include-audit toggle, status active/paused.
- Actions:
  - Save schedule.
  - Generate current-month pack.
- Output panel after generation:
  - Share page URL, CSV URL, PDF URL, optional mailto link.

### Billing (`/dashboard/billing`)
- File: `src/app/dashboard/billing/page.tsx`
- Data source:
  - Billing section from `/api/family/summary`.
- Features:
  - Current plan KPIs, usage bar, trial badge.
  - Upgrade CTAs:
    - POST `/api/billing/subscribe` (`pro` or `family_pro`).
    - Redirects to checkout when `requiresPayment=true`.
  - Billing history list (timeline).
  - Export invoices CSV via `/api/billing/invoices/export`.

### Settings (`/dashboard/settings`)
- File: `src/app/dashboard/settings/page.tsx`
- Data source:
  - `/api/auth/me`.
- Behaviors:
  - If not authenticated, redirect to `/auth`.
  - Profile and logout panel.
  - If no family: show create/join forms.
  - If in family: show quick add transaction form.
- Actions:
  - Create: POST `/api/family/create`.
  - Join: POST `/api/family/join`.
  - Add transaction: POST `/api/transactions`.

## 4.3 Legacy Consolidated Page

### Family Mega Page (`/family`)
- File: `src/app/family/page.tsx`
- Role in system:
  - Legacy all-in-one dashboard combining overview, analytics, members, audit, transactions, billing, CA pack in one route.
- High-level behaviors:
  - Section navigator (`all`, `overview`, `members`, `analytics`, `transactions`, `audit`, `billing`, `ca-pack`).
  - Polling refresh every 5s (`summary`, `transactions`, `ca schedule`).
  - Contains duplicate logic that now exists in dedicated `/dashboard/*` pages.
- Pagination states:
  - `auditPage` for audit section.
  - `fullTxPage` for full transactions section.
- Filter sets:
  - Global summary filters: year/month/member.
  - Audit filters: action/actor/from/to.
  - Full transaction filters: year/month/type/member/category/manual from-to.
- Risk:
  - Contract assumptions in this page (summary includes audit fields) can drift from current `family/summary` response.

### Public CA Share Page (`/ca-pack/[token]`)
- File: `src/app/ca-pack/[token]/page.tsx`
- Server-rendered behavior:
  - Validates token and expiry via DB.
  - Builds CA pack data and renders plain report page.
  - Links to token-scoped CSV and PDF endpoints.
  - Shows up to 200 transactions in table.

## 5) API Contracts Used by Frontend

### `GET /api/family/summary`
- Current response includes:
  - Family identity, invite code, current user/admin flags.
  - Members list.
  - Time dimensions: `selectedYear`, `selectedMonth`, `availableYears`.
  - Spending dimensions: `totalMonthlySpend`, `memberBreakdown`, `memberTransactionStats`, `topCategories`, `monthlyTimeline`, `yearlyTotals`.
  - Billing block and recent transactions.
- Query params used by pages:
  - `year`, `month`, `memberId`, `page`, `pageSize`.
  - Some pages also send audit params (not currently returned in this route implementation).

### `GET /api/transactions`
- Query params:
  - `memberId`, `type`, `category`, `from`, `to`, `page`, `pageSize`.
- Response:
  - `transactions[]` enriched with member names.
  - `peopleWise.totals`, `peopleWise.members`, `peopleWise.trend`.
  - `pagination` with `hasPrev/hasNext`.

### Export Endpoints
- `GET /api/family/transactions/report`
  - Supports `format=csv|html` and transaction filters.
- `GET /api/family/audit/export`
  - CSV audit export with audit filters.
- `GET /api/billing/invoices/export`
  - Billing events CSV.

### CA Pack Endpoints
- `GET/POST /api/family/ca-pack/settings`
- `POST /api/family/ca-pack/generate`
- Token-based downloads:
  - `/api/family/ca-pack/[token]/csv`
  - `/api/family/ca-pack/[token]/pdf`

## 6) Filter Matrix (Current Dashboard)

| Page | Year | Month | Member | Type | Category | Date From/To | Clear Action |
|---|---|---|---|---|---|---|---|
| Overview | Fixed current | Fixed current | Yes | No | No | No | No explicit clear |
| Transactions | Yes (`all` default) | Yes (`all` default) | Yes (`all`) | Yes (`all`) | State exists (`all`) | Derived from year/month | Yes |
| Analytics | Yes | Yes | Yes | No | No | No | No explicit clear |
| Budget | Yes | Yes | Yes | No | No | No | No explicit clear |
| Goals | Yes | Yes | Yes | No | No | No | No explicit clear |
| Members | No | No | View filter only | No | No | No | Change selector |
| Audit | Implicit current in request | Implicit current in request | Actor filter | Action filter | No | Yes | Yes |
| Billing | No | No | No | No | No | No | N/A |
| CA Pack | No | No | No | No | No | No | N/A |
| Settings | No | No | No | No | Category input for add | No | Form-level |

## 7) Pagination Matrix

| Page | Dataset | Page State | API Fields Consumed | UI Controls |
|---|---|---|---|---|
| `/dashboard/transactions` | transactions list | `page` | `pagination.page,totalPages,totalTransactions,hasPrev,hasNext` | Prev / Next |
| `/dashboard/audit` | recent audit list | `page` | `auditPagination.page,totalPages,totalRecords,hasPrev,hasNext` | Prev / Next |
| `/family` transactions section | full filtered transactions | `fullTxPage` | `pagination.*` from `/api/transactions` | Prev / Next |
| `/family` audit section | audit list | `auditPage` | `summary.auditPagination.*` | Prev / Next |

## 8) Known Integration Gaps and Cleanup Targets
- `src/app/dashboard/audit/page.tsx` expects `recentAudit` and `auditPagination` from `GET /api/family/summary`, but current summary route does not return those fields.
- Legacy `/family` page duplicates most dashboard capabilities and increases maintenance surface.
- Some user-facing strings still include legacy "AI" wording in auth/branding copy.

## 9) Suggested Refactor Direction
- Keep `/dashboard/*` as canonical product UI and progressively deprecate `/family`.
- Split `family/summary` into explicit domain endpoints if payload grows further:
  - overview summary
  - audit feed
  - member stats
  - billing snapshot
- Introduce shared filter hooks/components to avoid repeated logic across Analytics/Budget/Goals/Transactions.
- Add contract tests for frontend-critical API fields (`pagination`, `availableYears`, `memberBreakdown`).
