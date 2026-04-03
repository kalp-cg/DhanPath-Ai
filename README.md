# DhanPath
Offline-first daily budget and expense tracker built with Flutter for Indian SMS transaction workflows.

DhanPath answers one practical question every day:
"How much can I spend today?"

## What DhanPath Is (Current Build)

DhanPath is a personal finance app (not a cloud family platform yet) that:
- reads bank and UPI SMS locally on device,
- extracts transaction details using parser rules,
- keeps all data in local SQLite,
- calculates daily budget in real time,
- shows spending insights and reports,
- provides app lock options (PIN/biometric where supported).

## Core Features Available Now

### 1) SMS Auto-Detection (On Device)
- Scans inbox and parses eligible financial SMS.
- Supports Indian banking/UPI style transaction messages.
- Full resync option is available to reprocess SMS with updated parsers.
- Unrecognized SMS can be reviewed in-app.

### 2) Daily Budget Ring
- Home screen shows daily spend status and budget left.
- Budget updates as transactions are added from SMS or manual entries.
- Helps daily spend decisions quickly.

### 3) Transactions and Activity
- Add/edit/delete transactions.
- View transaction history.
- Basic filters and details screen.

### 4) Insights and Reports
- Monthly breakdown views.
- Category-level spending views.
- Weekly digest, spending story, and calendar/heatmap screens.

### 5) Additional Tools
- Savings goals.
- Recurring bills.
- Budget suggestion/planner.
- Export and backup utilities (from app settings/tools).

### 6) Privacy and Security
- Offline-first architecture.
- Local SQLite storage.
- App lock flow with secure storage and biometric capability where available.

## Navigation (Current)

Bottom navigation tabs:
- Home
- Transactions
- Insights
- More

More section includes reports, tools, settings, and help screens.

## Tech Stack

- Flutter / Dart
- Provider (state management)
- SQLite (`sqflite`)
- Telephony/SMS parsing services
- Local notifications
- Secure storage + local auth

## Project Structure

```text
lib/
  main.dart
  models/
  providers/
  services/
  core/
    parsers/
  screens/
  widgets/
  theme/
```

## Getting Started

### Prerequisites
- Flutter SDK installed
- Android SDK / emulator or physical Android device

### Run locally

```bash
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=your_supabase_url \
  --dart-define=SUPABASE_ANON_KEY=your_supabase_anon_key
```

### Run tests

```bash
flutter test
```

## Android Permissions Used

- `READ_SMS` and `RECEIVE_SMS` for transaction detection
- `POST_NOTIFICATIONS` for reminders/alerts (Android 13+)
- `USE_BIOMETRIC` for biometric unlock
- Other optional permissions as needed by specific tools/screens

## Current Product Positioning

Use this positioning in demos and docs:
- "Offline-first personal finance tracker"
- "On-device SMS parsing + daily budget control"

Avoid claiming as shipped in current build:
- cloud family sync backend,
- parent-child shared finance workspace,
- server-powered conversational AI assistant.

## Hackathon Build Track

The active hackathon execution roadmap is maintained in:
- `docs/HACKATHON_DELIVERY_PLAN.md`

Web dashboard module:
- `dashboard/` (Next.js backend APIs + Supabase storage integration)

This plan tracks the transition from offline personal finance app to:
- Family workspace mode,
- Forecast and runway insights,
- AI assistant integration,
- Demo-ready dashboard narrative.

## Demo Flow (90 seconds)

1. Open app and show daily budget ring.
2. Trigger SMS sync and show found transactions.
3. Open transaction history and filters.
4. Show insights/report screen.
5. End on privacy message: "All data stays on device."

## License

Private/proprietary project. All rights reserved.
