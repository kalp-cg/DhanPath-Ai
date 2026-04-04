    # DhanPath AI - Product Page Breakdown

    This file explains every main dashboard page in easy English for evolution/demo rounds.

    Format used:
    - Page :- name
    - Motive of that page :- why this page exists
    - Section by section (Logic + Use case) :- what each section does and why user needs it

    ## 1) Landing

    Page :- `/`

    Motive of that page :-
    - Entry point for new users.
    - Redirect logged-in users directly to dashboard.

    Section by section (Logic + Use case) :-
    1. Hero section
    - Logic: checks auth cookie; if token exists, redirects to `/dashboard`.
    - Use case: signed-in users save time, new users see product intro.
    2. Get Started button
    - Logic: navigates to `/auth`.
    - Use case: starts login/signup quickly.

    ## 2) Auth

    Page :- `/auth`

    Motive of that page :-
    - Login and signup in one clean page.

    Section by section (Logic + Use case) :-
    1. Mode tabs (Login / Sign Up)
    - Logic: toggles form mode and API endpoint (`/api/auth/login` or `/api/auth/signup`).
    - Use case: one page for both account flows.
    2. Auth form
    - Logic: validates inputs, sends API request, handles loading/errors.
    - Use case: user account access.
    3. Success redirect
    - Logic: after success, pushes to `/dashboard` and refreshes state.
    - Use case: immediate onboarding to main workspace.

    ## 3) Family Workspace (Legacy Unified Page)

    Page :- `/family`

    Motive of that page :-
    - All-in-one family workspace (legacy combined screen).

    Section by section (Logic + Use case) :-
    1. Family summary and analytics state
    - Logic: fetches summary, transactions, audit, billing-like data into one state tree.
    - Use case: power users/admin can manage many flows from one page.
    2. Section switching
    - Logic: local `activeSection` state controls which block is visible.
    - Use case: quick switching without route change.
    3. Admin actions
    - Logic: includes family, audit, CA pack, transaction tools.
    - Use case: operational control in one place.

    ## 4) Dashboard Shell

    Page :- `/dashboard/layout` (applies to all dashboard pages)

    Motive of that page :-
    - Common app frame for all dashboard screens.

    Section by section (Logic + Use case) :-
    1. Sidebar
    - Logic: grouped navigation, active route highlighting, mobile open/close.
    - Use case: clear movement across product modules.
    2. TopBar
    - Logic: reads current route for title, fetches user profile, logout action.
    - Use case: context + account control.
    3. Content area
    - Logic: renders page content inside shared spacing/animation.
    - Use case: visual consistency.

    ## 5) Overview

    Page :- `/dashboard`

    Motive of that page :-
    - Main daily finance snapshot.

    Section by section (Logic + Use case) :-
    1. Quick info strip
    - Logic: shows family name, invite code, plan usage, member filter.
    - Use case: immediate workspace context.
    2. KPI cards
    - Logic: monthly spend, projected month end, average month, top spender.
    - Use case: fast decision support.
    3. Top categories + member split
    - Logic: bar visuals from summary aggregates.
    - Use case: know where money goes and who spends.
    4. Recent transactions
    - Logic: latest items with type/source badges.
    - Use case: quick verification.
    5. Monthly trend chart
    - Logic: month-wise bars for selected year.
    - Use case: trend understanding.

    ## 6) Command Center

    Page :- `/dashboard/command-center`

    Motive of that page :-
    - Founder/admin control tower for strategy and decisions.

    Section by section (Logic + Use case) :-
    1. Founder hero + executive score
    - Logic: fetches `/api/dashboard/command-center`; shows score/tier/headline.
    - Use case: one-number business health view.
    2. Copy Snapshot
    - Logic: copies executive summary text to clipboard.
    - Use case: quick sharing to team/investor/mentor.
    3. Founder playbook
    - Logic: API returns top priority actions from detected risks.
    - Use case: clear next steps.
    4. What-If Lab
    - Logic: simulate savings by category + cut%; computes monthly/yearly savings and goal ETA.
    - Use case: planning before execution.
    5. Apply Plan to Family
    - Logic: POST to `/api/family/action-plan`; saves simulation as active plan.
    - Use case: convert insight into real execution.
    6. Risk radar + operational health
    - Logic: alert cards + health KPIs (freshness, anomalies, cashflow).
    - Use case: risk monitoring.
    7. Weekly velocity, source funnel, top categories, member board
    - Logic: chart/list blocks from backend analytics.
    - Use case: performance deep dive.

    ## 7) Transactions

    Page :- `/dashboard/transactions`

    Motive of that page :-
    - Full ledger view with filters and exports.

    Section by section (Logic + Use case) :-
    1. KPI totals
    - Logic: debit, credit, net, transaction count from API response.
    - Use case: period-level financial position.
    2. Filters panel
    - Logic: year/month/member/type/category + pagination reset.
    - Use case: precise data slicing.
    3. People-wise clarity panel
    - Logic: debit/credit bars per member + share metrics.
    - Use case: member accountability.
    4. Transaction list + pagination
    - Logic: paginated API-driven rows with badges and amount coloring.
    - Use case: operational transaction review.
    5. Export actions
    - Logic: CSV download or printable/PDF view endpoint.
    - Use case: reporting/compliance.

    ## 8) Analytics

    Page :- `/dashboard/analytics`

    Motive of that page :-
    - Multi-angle analytics by period and member.

    Section by section (Logic + Use case) :-
    1. Period filter
    - Logic: year/month/member controls summary query.
    - Use case: focused analysis.
    2. Spending by category
    - Logic: category bars with percentage share.
    - Use case: category optimization.
    3. People-wise split
    - Logic: member spend bars.
    - Use case: behavior comparison.
    4. Month-wise trend
    - Logic: 12-month bars for selected year.
    - Use case: seasonality and trend tracking.
    5. Year-wise comparison
    - Logic: yearly totals bar comparison.
    - Use case: growth/decline understanding.

    ## 9) Insights

    Page :- `/dashboard/insights`

    Motive of that page :-
    - Human-readable smart recommendations.

    Section by section (Logic + Use case) :-
    1. Smart insights cards
    - Logic: builds tips from top category, spend pace, member trends, average month.
    - Use case: actionable advice without manual analysis.
    2. Spending story
    - Logic: narrative text generated from summary numbers.
    - Use case: simple monthly summary for non-technical users.

    ## 10) Budget

    Page :- `/dashboard/budget`

    Motive of that page :-
    - Turn spending data into budget control.

    Section by section (Logic + Use case) :-
    1. Filters
    - Logic: year/month/member selectors.
    - Use case: budget view per period/person.
    2. Budget KPIs
    - Logic: actual spend, suggested budget, remaining buffer, usage percent.
    - Use case: monitor overspending quickly.
    3. Active Applied Plan banner
    - Logic: loads `/api/family/action-plan` and shows linked plan values.
    - Use case: confirms strategy is active.
    4. Utilization chart
    - Logic: progress bar of spend vs budget.
    - Use case: visual control.
    5. Category pressure points
    - Logic: top category contribution and bars.
    - Use case: identify budget stress areas.

    ## 11) Goals

    Page :- `/dashboard/goals`

    Motive of that page :-
    - Show savings targets and progress.

    Section by section (Logic + Use case) :-
    1. Filters
    - Logic: same year/month/member filtering.
    - Use case: goal tracking by context.
    2. Command Center plan linked banner
    - Logic: reads action plan and displays target/contribution/ETA.
    - Use case: bridge between planning and outcomes.
    3. KPI cards
    - Logic: current spend, monthly average, annual saving target.
    - Use case: high-level goal health.
    4. Goal progress chart
    - Logic: emergency buffer, category cut, annual target with percentage bars.
    - Use case: motivation + tracking.

    ## 12) Members

    Page :- `/dashboard/members`

    Motive of that page :-
    - Family member management and member-level finance visibility.

    Section by section (Logic + Use case) :-
    1. Invite code card
    - Logic: displays and copies family invite code.
    - Use case: easy member onboarding.
    2. Member selector
    - Logic: view all or one member details.
    - Use case: focused review.
    3. Member-wise spend chart
    - Logic: compares spend and transaction volume.
    - Use case: fairness and monitoring.
    4. Members list with admin controls
    - Logic: role toggle and member removal via `/api/family/members`.
    - Use case: access governance.

    ## 13) Audit Log

    Page :- `/dashboard/audit`

    Motive of that page :-
    - Track who changed what and when.

    Section by section (Logic + Use case) :-
    1. Filter bar
    - Logic: action, actor, date range filters.
    - Use case: forensic search.
    2. Export CSV
    - Logic: calls `/api/family/audit/export`.
    - Use case: external review/compliance.
    3. Activity list + pagination
    - Logic: paginated audit feed with actor/target details.
    - Use case: accountability timeline.

    ## 14) Billing

    Page :- `/dashboard/billing`

    Motive of that page :-
    - Plan, usage, and subscription operations.

    Section by section (Logic + Use case) :-
    1. Current plan block
    - Logic: fetches `/api/billing/subscription` with timeout + error handling.
    - Use case: avoid billing blind spots.
    2. Upgrade cards
    - Logic: triggers `/api/billing/subscribe`; redirects if payment required.
    - Use case: self-serve upgrades.
    3. Billing history
    - Logic: timeline of billing events + CSV export.
    - Use case: invoice and payment traceability.

    ## 15) CA Pack

    Page :- `/dashboard/ca-pack`

    Motive of that page :-
    - Monthly CA-ready report generation and sharing.

    Section by section (Logic + Use case) :-
    1. Schedule form
    - Logic: save CA email, run day, include audit, active/paused status.
    - Use case: automate finance reporting.
    2. Generate this month
    - Logic: creates signed share token and report links.
    - Use case: instant pack creation.
    3. Generated pack actions
    - Logic: open share page, CSV, PDF, email link.
    - Use case: quick CA handoff.

    ## 16) Settings

    Page :- `/dashboard/settings`

    Motive of that page :-
    - User profile, family setup entry, quick transaction action.

    Section by section (Logic + Use case) :-
    1. Profile block
    - Logic: fetch `/api/auth/me`, display user and family connection state.
    - Use case: identity and status confirmation.
    2. Family create/join blocks
    - Logic: calls `/api/family/create` and `/api/family/join`.
    - Use case: onboarding for users without family.
    3. Quick add transaction
    - Logic: creates manual transaction through `/api/transactions`.
    - Use case: fast data entry.
    4. Logout
    - Logic: calls `/api/auth/logout`.
    - Use case: secure sign-out.

    ## 17) CA Share Page

    Page :- `/ca-pack/[token]`

    Motive of that page :-
    - Public/share-safe view for CA pack by token.

    Section by section (Logic + Use case) :-
    1. Token validation
    - Logic: checks token existence and expiry in DB.
    - Use case: secure temporary access.
    2. Pack summary
    - Logic: shows period, rows, debit/credit/net totals.
    - Use case: quick report overview.
    3. Download links
    - Logic: CSV and PDF links tied to token.
    - Use case: easy data extraction.
    4. Transaction table
    - Logic: renders recent rows for quick verification.
    - Use case: manual audit/review.

    ---

    ## Product Logic Flow (Simple)

    1. User logs in -> joins/creates family.
    2. Transactions are captured/imported.
    3. Dashboard pages transform raw data into analytics.
    4. Command Center gives strategy and What-If simulation.
    5. `Apply Plan to Family` stores action plan.
    6. Budget and Goals automatically use that plan.
    7. Audit + CA Pack + Billing complete operations and governance.
