# 🪙 DhanPath AI

> **India's first SMS-native, AI-powered Family Finance OS**
> *Auto-detect bank transactions from SMS → AI categorizes + forecasts → every family member's phone feeds one unified dashboard. Zero manual entry. 100% private.*

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.6-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-Backend-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)
![Gemini AI](https://img.shields.io/badge/Gemini-AI-4285F4?style=for-the-badge&logo=google&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)

**OceanLab × CHARUSAT Hackathon | April 3–5, 2026 | DEPSTAR, Changa, Gujarat**

</div>

---

## 📋 Table of Contents

- [One-Line Pitch](#-one-line-pitch)
- [Problem Statement](#-problem-statement)
- [Solution Overview](#-solution-overview)
- [Tech Stack](#-tech-stack)
- [Phase 1 — Offline-First App](#-phase-1--offline-first-app-build-everything-locally)
- [Phase 2 — Online with Database & Web UI](#-phase-2--online-with-database--web-ui)
- [Phase 3 — Centralized APIs & Full Integration](#-phase-3--centralized-apis--full-integration)
- [Database Schema](#-database-schema)
- [System Architecture](#-system-architecture)
- [Feature Set](#-complete-feature-set)
- [48-Hour Execution Plan](#-48-hour-execution-plan)
- [Supported Banks & Wallets](#-supported-banks--wallets)
- [Android Permissions](#-android-permissions)
- [Getting Started](#-getting-started)
- [SaaS Pricing Model](#-saas-pricing-model)
- [Roadmap](#-roadmap)
- [Team](#-team)

---

## 💡 One-Line Pitch

**DhanPath AI answers the single most important daily financial question:**

> *"How much can our family spend today — and are we on track this month?"*

---

## 🔴 Problem Statement

Most Indian families receive **50–100+ bank SMS messages per month** across multiple phones and UPI numbers. Nobody looks at them collectively. The result:

| Problem | Impact |
|---|---|
| Parents have no real-time visibility into total household spending | Family overspends unknowingly |
| Children overspend because they cannot see family budget context | No accountability |
| Manual expense trackers abandoned within 2 weeks | Too much friction |
| Existing apps only track one person, not a family unit | Blind spots |
| No product predicts when a family will exhaust monthly budget | No early warning |

> **The gap:** an offline-first, AI-powered, family-centric finance OS built for India's UPI-first ecosystem.

---

## ✅ Solution Overview

DhanPath AI combines **four capabilities no competitor delivers together:**

| Capability | What it does |
|---|---|
| **SMS Auto-Parse** | 20+ Indian banks detected automatically. No manual entry ever. |
| **Family Mode** | Multiple phones → one shared workspace. Parent sees everyone's spend. |
| **3-Layer AI** | Generative chat + Vision receipt scan + Voice logging. All three live. |
| **Burn Forecast** | AI predicts exact day the family exhausts monthly budget. Visual chart. |

---

## 🛠 Tech Stack

| Layer | Technology | Role |
|---|---|---|
| Mobile App | Flutter 3.x / Dart | Cross-platform. Existing codebase. |
| State Management | Provider (ChangeNotifier) | Reactive UI, minimal boilerplate |
| Local DB | SQLite via `sqflite` | Offline-first. Fast on-device queries. |
| Cloud DB | **Supabase** ★ Sponsor | Postgres + Auth + Realtime + RLS |
| Web UI | **Watermelon UI** ★ Sponsor | Admin dashboard. Premium component library. |
| AI Chat | Gemini 1.5 Flash API | Finance assistant. Fast + multilingual. |
| Vision AI | Gemini Vision API | Receipt & bill scan. OCR. |
| Voice AI | Web Speech API + Gemini | Hinglish expense logging. |
| SMS Parse | `telephony` + Regex Engine | 20+ bank patterns. On-device. Privacy-first. |
| Charts | `fl_chart` | Daily ring, forecast chart, pie, trends. |
| Auth | Supabase Auth (JWT) | Family roles. RLS enforces data isolation. |
| Security | `flutter_secure_storage` + SHA-256 | PIN lock. Biometric. Encrypted keys. |
| Notifications | `flutter_local_notifications` | Budget alerts. Daily streak nudge. |
| Export | `csv` + `pdf` + `share_plus` | Monthly reports. CSV for accountants. |
| Deploy | Supabase Edge Functions | Serverless family aggregation API. |
| Rapid Proto | **Lovable Dev** ★ Sponsor | Web dashboard scaffolding & UI speed. |

---

---

# 🟢 Phase 1 — Offline-First App (Build Everything Locally)

> **Goal:** A fully functional personal finance app that works 100% offline with zero internet dependency. No Supabase. No AI. Pure local intelligence.

## Phase 1 Overview

```
SMS Arrives → On-Device Parse → SQLite Storage → Local UI Update
                                    ↓
                             Analytics Computed
                                    ↓
                          Budget Ring + Charts Shown
```

## Phase 1 Feature List

### 1.1 SMS Auto-Parser (Core Engine)
- Android SMS receiver via `telephony` package
- `BankParserFactory` — matches sender ID against 20+ regex patterns
- Extracts: **amount**, **type** (debit/credit), **merchant**, **balance**, **date**
- Deduplication via `sms_hash = SHA-256(sender + body + timestamp)`
- Supports: HDFC, ICICI, SBI, Axis, Kotak, PNB, BOI, Canara, IDFC, IndusInd, Yes Bank + 10 more
- UPI detection: PhonePe, Google Pay, Paytm, BHIM, Amazon Pay
- Fallback: `unrecognized_sms` queue for manual review

### 1.2 Local SQLite Schema (Phase 1)

```sql
-- Core transaction ledger (local only)
CREATE TABLE transactions (
  id          TEXT PRIMARY KEY,
  amount      REAL NOT NULL,
  type        TEXT CHECK(type IN ('debit','credit')),
  category    TEXT,
  merchant    TEXT,
  txn_time    INTEGER,
  source      TEXT CHECK(source IN ('sms','manual','vision','voice')),
  sms_hash    TEXT UNIQUE,
  note        TEXT,
  created_at  INTEGER DEFAULT (strftime('%s','now'))
);

-- Monthly budget per user
CREATE TABLE budgets (
  id              TEXT PRIMARY KEY,
  monthly_income  REAL,
  monthly_budget  REAL NOT NULL,
  month           INTEGER,
  year            INTEGER
);

-- Daily usage streaks
CREATE TABLE daily_streaks (
  id        TEXT PRIMARY KEY,
  date      TEXT UNIQUE,
  txn_count INTEGER DEFAULT 0
);

-- Unrecognized SMS for manual review
CREATE TABLE unrecognized_sms (
  id        TEXT PRIMARY KEY,
  sender    TEXT,
  message   TEXT,
  timestamp INTEGER
);
```

### 1.3 Auto-Categorization Engine
Transactions are auto-tagged on parse:

| Category | Keywords / Merchants |
|---|---|
| Food | Zomato, Swiggy, BigBazaar, DMart, restaurant |
| Transport | Ola, Uber, IRCTC, fuel, petrol |
| Shopping | Flipkart, Amazon, Myntra, mall |
| Bills | BESCOM, electricity, broadband, recharge |
| Entertainment | BookMyShow, Netflix, Hotstar |
| Health | pharmacy, hospital, Apollo, MedPlus |
| Salary | salary, credited by employer |

### 1.4 Daily Budget Ring
```
Daily Allowance = (Monthly Budget − Total Spent So Far) ÷ Days Remaining

Ring Color Logic:
  > 70% remaining  → 🟢 Green  (safe)
  30–70% remaining → 🟡 Yellow (caution)
  < 30% remaining  → 🔴 Red    (overspent)
```

### 1.5 Phase 1 Navigation (4-Tab App)

| Tab | Screen | Content |
|---|---|---|
| 🏠 Home | `HomeScreen` | Daily ring, streak counter, quick-add FAB |
| 📋 Activity | `TransactionsScreen` | Full list with filter, search, edit, delete |
| 📊 Analytics | `AnalyticsScreen` | Monthly overview, category pie, trends |
| 💰 Budget | `MonthlyBudgetScreen` | Set income, view budget, export |

### 1.6 Phase 1 Security
- PIN lock (SHA-256 hash, stored in `flutter_secure_storage`)
- Biometric auth (fingerprint / face unlock)
- **Privacy guarantee:** Raw SMS never leaves the device. Only parsed fields stored locally.

### 1.7 Phase 1 Build Checklist

- [ ] `BankParserFactory` with regex for 20+ banks
- [ ] `DatabaseHelper` singleton (SQLite)
- [ ] `TransactionProvider` (ChangeNotifier)
- [ ] `BudgetProvider` — daily ring computation
- [ ] `HomeScreen` — animated ring with color states
- [ ] `TransactionsScreen` — list, filter, edit, delete
- [ ] `AnalyticsScreen` — pie chart + monthly trend (fl_chart)
- [ ] `MonthlyBudgetScreen` — income/budget setup
- [ ] PIN lock screen + biometric toggle
- [ ] SMS receiver broadcast handler
- [ ] CSV export + PDF report
- [ ] `DailyStreakService` — streak tracking

### 1.7 Phase 1 Folder Structure

```
lib/
├── core/
│   ├── database/
│   │   └── database_helper.dart        # SQLite singleton
│   ├── parsers/
│   │   ├── bank_parser_factory.dart    # Parser dispatcher
│   │   ├── hdfc_parser.dart
│   │   ├── icici_parser.dart
│   │   ├── sbi_parser.dart
│   │   └── ... (one per bank)
│   ├── services/
│   │   ├── sms_service.dart            # SMS receiver + dedup
│   │   ├── notification_service.dart
│   │   └── streak_service.dart
│   └── utils/
│       ├── category_engine.dart        # Auto-categorization
│       └── crypto_utils.dart           # SHA-256 hash
├── models/
│   ├── transaction.dart
│   ├── budget.dart
│   └── daily_streak.dart
├── providers/
│   ├── transaction_provider.dart
│   ├── budget_provider.dart
│   └── analytics_provider.dart
└── screens/
    ├── home/
    │   └── home_screen.dart
    ├── transactions/
    │   └── transactions_screen.dart
    ├── analytics/
    │   └── analytics_screen.dart
    └── budget/
        └── monthly_budget_screen.dart
```

### Phase 1 Dependencies (`pubspec.yaml`)

```yaml
dependencies:
  flutter:
    sdk: flutter
  sqflite: ^2.3.2
  path: ^1.9.0
  telephony: ^0.2.0
  provider: ^6.1.2
  fl_chart: ^0.68.0
  flutter_secure_storage: ^9.0.0
  local_auth: ^2.2.0
  csv: ^6.0.0
  pdf: ^3.11.1
  share_plus: ^9.0.0
  intl: ^0.19.0
  uuid: ^4.4.2
  crypto: ^3.0.3
  flutter_local_notifications: ^17.2.2
```

---

---

# 🔵 Phase 2 — Online with Database & Web UI

> **Goal:** Connect the offline app to Supabase cloud. Enable Family Mode where multiple devices sync to one workspace. Launch the Watermelon UI web dashboard for the admin/parent view.

## Phase 2 Overview

```
Device A (Son)           Device B (Parent)         Web Dashboard
     ↓ SMS parse               ↓ SMS parse              ↓ Reads
  SQLite local             SQLite local           Watermelon UI
     ↓ sync                    ↓ sync              (Realtime sub)
         ↘                   ↙
           Supabase Postgres
           (Family workspace)
                ↓
         Edge Functions
         (Family totals)
```

## Phase 2 Feature List

### 2.1 Supabase Setup

#### Create Project
1. Go to [supabase.com](https://supabase.com) → New Project
2. Choose region: **Mumbai (ap-south-1)** for lowest latency
3. Copy your `SUPABASE_URL` and `SUPABASE_ANON_KEY`

#### Full Database Schema

```sql
-- ============================================
-- USERS
-- ============================================
CREATE TABLE users (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  phone       TEXT UNIQUE,
  email       TEXT UNIQUE,
  avatar_url  TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- FAMILIES (workspace)
-- ============================================
CREATE TABLE families (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  created_by  UUID REFERENCES users(id),
  invite_code TEXT UNIQUE DEFAULT substring(md5(random()::text), 1, 6),
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- FAMILY MEMBERS (role-based)
-- ============================================
CREATE TABLE family_members (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id   UUID REFERENCES families(id) ON DELETE CASCADE,
  user_id     UUID REFERENCES users(id) ON DELETE CASCADE,
  role        TEXT CHECK(role IN ('admin','member')) DEFAULT 'member',
  joined_at   TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(family_id, user_id)
);

-- ============================================
-- TRANSACTIONS (core ledger)
-- ============================================
CREATE TABLE transactions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID REFERENCES users(id) ON DELETE CASCADE,
  family_id   UUID REFERENCES families(id),
  amount      NUMERIC(12,2) NOT NULL,
  type        TEXT CHECK(type IN ('debit','credit')),
  category    TEXT,
  merchant    TEXT,
  txn_time    TIMESTAMPTZ,
  source      TEXT CHECK(source IN ('sms','manual','vision','voice')),
  sms_hash    TEXT UNIQUE,
  note        TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- BUDGETS
-- ============================================
CREATE TABLE budgets (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID REFERENCES users(id) ON DELETE CASCADE,
  family_id        UUID REFERENCES families(id),
  monthly_income   NUMERIC(12,2),
  monthly_budget   NUMERIC(12,2) NOT NULL,
  month            INTEGER CHECK(month BETWEEN 1 AND 12),
  year             INTEGER,
  UNIQUE(user_id, month, year)
);

-- ============================================
-- DAILY STREAKS
-- ============================================
CREATE TABLE daily_streaks (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID REFERENCES users(id) ON DELETE CASCADE,
  date        DATE NOT NULL,
  txn_count   INTEGER DEFAULT 0,
  UNIQUE(user_id, date)
);

-- ============================================
-- AI QUERY LOG (optional)
-- ============================================
CREATE TABLE ai_queries (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID REFERENCES users(id),
  family_id   UUID REFERENCES families(id),
  question    TEXT,
  answer      TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- UNRECOGNIZED SMS (fallback queue)
-- ============================================
CREATE TABLE unrecognized_sms (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID REFERENCES users(id),
  sender      TEXT,
  message     TEXT,
  timestamp   TIMESTAMPTZ
);
```

#### Row Level Security (RLS) Policies

```sql
-- Enable RLS on all tables
ALTER TABLE users            ENABLE ROW LEVEL SECURITY;
ALTER TABLE families         ENABLE ROW LEVEL SECURITY;
ALTER TABLE family_members   ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions     ENABLE ROW LEVEL SECURITY;
ALTER TABLE budgets          ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_streaks    ENABLE ROW LEVEL SECURITY;

-- USERS: can only read/update own row
CREATE POLICY "users_self" ON users
  FOR ALL USING (auth.uid() = id);

-- FAMILIES: members can see their family; admin can edit
CREATE POLICY "family_members_can_view" ON families
  FOR SELECT USING (
    id IN (SELECT family_id FROM family_members WHERE user_id = auth.uid())
  );

-- TRANSACTIONS: admin sees all in family; member sees own only
CREATE POLICY "transactions_read" ON transactions
  FOR SELECT USING (
    user_id = auth.uid()
    OR (
      family_id IN (
        SELECT family_id FROM family_members
        WHERE user_id = auth.uid() AND role = 'admin'
      )
    )
  );

CREATE POLICY "transactions_insert" ON transactions
  FOR INSERT WITH CHECK (user_id = auth.uid());

-- BUDGETS: own row or admin of family
CREATE POLICY "budgets_read" ON budgets
  FOR SELECT USING (
    user_id = auth.uid()
    OR family_id IN (
      SELECT family_id FROM family_members
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );
```

### 2.2 Flutter — Supabase Integration

#### Initialize Supabase (main.dart)

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );
  runApp(const DhanPathApp());
}

final supabase = Supabase.instance.client;
```

#### Sync Service (offline-first upsert)

```dart
class SyncService {
  // Upsert local SQLite transaction to Supabase
  static Future<void> syncTransaction(Transaction txn) async {
    try {
      await supabase.from('transactions').upsert({
        'id':        txn.id,
        'user_id':   supabase.auth.currentUser!.id,
        'family_id': txn.familyId,
        'amount':    txn.amount,
        'type':      txn.type,
        'category':  txn.category,
        'merchant':  txn.merchant,
        'txn_time':  txn.txnTime.toIso8601String(),
        'source':    txn.source,
        'sms_hash':  txn.smsHash,
      }, onConflict: 'sms_hash'); // dedup on sms_hash
    } catch (e) {
      // Network unavailable — stays in local SQLite, retry on next open
      debugPrint('Sync failed, will retry: $e');
    }
  }

  // Batch sync all unsynced local transactions on app open
  static Future<void> batchSync() async {
    final unsynced = await DatabaseHelper.instance.getUnsyncedTransactions();
    for (final txn in unsynced) {
      await syncTransaction(txn);
    }
  }
}
```

### 2.3 Family Mode

#### Family Provider

```dart
class FamilyProvider extends ChangeNotifier {
  Family? _family;
  List<FamilyMember> _members = [];

  Future<void> createFamily(String name) async {
    final res = await supabase.from('families').insert({'name': name}).select().single();
    _family = Family.fromJson(res);
    await joinFamily(_family!.inviteCode, role: 'admin');
    notifyListeners();
  }

  Future<void> joinByCode(String code) async {
    final res = await supabase
        .from('families')
        .select()
        .eq('invite_code', code.toUpperCase())
        .single();
    _family = Family.fromJson(res);
    await joinFamily(code);
    notifyListeners();
  }

  Future<void> loadMembers() async {
    final res = await supabase
        .from('family_members')
        .select('*, users(*)')
        .eq('family_id', _family!.id);
    _members = res.map((e) => FamilyMember.fromJson(e)).toList();
    notifyListeners();
  }
}
```

#### Realtime Subscription (live family updates)

```dart
// Subscribe to family transactions in real-time
supabase
  .from('transactions')
  .stream(primaryKey: ['id'])
  .eq('family_id', familyId)
  .order('txn_time', ascending: false)
  .listen((data) {
    // Update UI with new transaction from any family member
    context.read<TransactionProvider>().onRealtimeUpdate(data);
  });
```

### 2.4 Watermelon UI Web Dashboard

The web dashboard is built with **Watermelon UI** (sponsor tool) and connects to Supabase Realtime.

#### Dashboard Panels

| Panel | Description |
|---|---|
| **Family Overview** | Total household spend this month. Per-member spend bars. |
| **Budget Runway** | Forecast chart: solid line (actual) + dashed (projected) + red marker (day budget hits ₹0) |
| **Category Breakdown** | Pie chart split by Food, Transport, Shopping, Bills, etc. |
| **AI Chat Sidebar** | Gemini-powered assistant reading live Supabase data |
| **Member Cards** | Avatar + name + spend amount + last transaction for each member |

#### Forecast Formula

```
Projected Day = Monthly Budget ÷ (Total Spent ÷ Days Elapsed)

Example:
  Budget = ₹40,000
  Spent  = ₹18,000 in 12 days
  Daily burn rate = ₹18,000 ÷ 12 = ₹1,500/day
  Days until ₹0 = ₹40,000 ÷ ₹1,500 = Day 26.7 → "Budget runs out on Day 27"
```

### 2.5 Phase 2 Additional Flutter Dependencies

```yaml
dependencies:
  supabase_flutter: ^2.5.0
  connectivity_plus: ^6.0.3   # detect online/offline state
```

### 2.6 Phase 2 Build Checklist

- [ ] Supabase project created, all tables + RLS policies applied
- [ ] `SyncService` — upsert with `sms_hash` dedup
- [ ] Background sync on app open (`batchSync`)
- [ ] `FamilyProvider` — create workspace, join by code
- [ ] Family creation + invite UI in Budget tab
- [ ] `FamilyScreen` — member cards + per-member spend bars
- [ ] Supabase Realtime subscription — live transaction stream
- [ ] Watermelon UI dashboard — family overview panel
- [ ] Budget runway forecast chart (web + app)
- [ ] Per-category family pie (web dashboard)
- [ ] Admin vs member role enforcement in UI

---

---

# 🟣 Phase 3 — Centralized APIs & Full Integration

> **Goal:** Connect all AI services (Gemini Chat, Vision, Voice), build Supabase Edge Functions for server-side family aggregation, finalize all API connections, and make every feature production-ready.

## Phase 3 Overview

```
┌─────────────────────────────────────────────────┐
│                  DhanPath AI                    │
│                                                 │
│  Flutter App          Web Dashboard             │
│  ┌──────────┐         ┌─────────────────────┐   │
│  │ SMS Parse│         │  Watermelon UI      │   │
│  │ Local DB │──sync──▶│  Admin Dashboard    │   │
│  │ AI Chat  │         │  Realtime Updates   │   │
│  │ Vision   │         └─────────────────────┘   │
│  │ Voice    │                  │                │
│  └────┬─────┘                  │                │
│       │                        │                │
│       ▼                        ▼                │
│  ┌─────────────────────────────────────────┐    │
│  │           Supabase Backend              │    │
│  │  Postgres DB + Auth + Realtime + RLS    │    │
│  │  Edge Functions (family aggregation)    │    │
│  └────────────────┬────────────────────────┘    │
│                   │                             │
│       ┌───────────▼───────────┐                 │
│       │     Gemini AI APIs    │                 │
│       │  Flash · Vision · NLP │                 │
│       └───────────────────────┘                 │
└─────────────────────────────────────────────────┘
```

## Phase 3 Feature List

### 3.1 Gemini AI Chat — Finance Assistant

**System Prompt Design:**

```
You are DhanPath AI, a personal finance assistant for Indian families.
You have access to the user's transaction data from Supabase.
Always respond in simple, friendly language.
Support both English and Hinglish.
Format currency as ₹X,XXX. Never share raw SQL or internal data structures.
```

**Supported Intents (prompt-engineered):**

| User Query | AI Response Type |
|---|---|
| "How much did we spend this week?" | Aggregated weekly sum by category |
| "Which member spent most on food?" | Per-member category breakdown |
| "Are we on track to stay within ₹40,000?" | Forecast + recommendation |
| "How can we save 10% next month?" | Category-specific saving tips |
| "Show all transactions above ₹500 this week" | Filtered list |
| "Compare this month to last month" | Month-over-month diff |
| "Can we afford a ₹8,000 appliance?" | Budget runway check |
| "What is our biggest recurring expense?" | Merchant frequency analysis |
| "teen sau rupaye petrol mein gaya" | Hinglish → log ₹300 transport |
| "Add ₹500 for groceries at DMart" | Voice-to-transaction |

**Flutter Implementation:**

```dart
class GeminiService {
  static const _model = 'gemini-1.5-flash-latest';
  static const _apiBase = 'https://generativelanguage.googleapis.com/v1beta/models';

  static Future<String> askFinanceQuestion({
    required String question,
    required List<Transaction> recentTransactions,
    required Budget currentBudget,
  }) async {
    final context = _buildContext(recentTransactions, currentBudget);
    final prompt = '''
$context

User question: $question

Answer helpfully in 2-3 sentences. Use ₹ for amounts. Support Hinglish if needed.
''';

    final response = await http.post(
      Uri.parse('$_apiBase/$_model:generateContent?key=${Env.geminiKey}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [{'parts': [{'text': prompt}]}],
        'generationConfig': {'maxOutputTokens': 300, 'temperature': 0.3},
      }),
    );

    final data = jsonDecode(response.body);
    return data['candidates'][0]['content']['parts'][0]['text'];
  }

  static String _buildContext(List<Transaction> txns, Budget budget) {
    final total = txns.where((t) => t.type == 'debit').fold(0.0, (s, t) => s + t.amount);
    final byCategory = <String, double>{};
    for (final t in txns) {
      byCategory[t.category ?? 'Other'] = (byCategory[t.category] ?? 0) + t.amount;
    }
    return '''
Monthly budget: ₹${budget.monthlyBudget.toStringAsFixed(0)}
Total spent this month: ₹${total.toStringAsFixed(0)}
Remaining: ₹${(budget.monthlyBudget - total).toStringAsFixed(0)}
Category breakdown: ${byCategory.entries.map((e) => '${e.key}: ₹${e.value.toStringAsFixed(0)}').join(', ')}
Last 5 transactions: ${txns.take(5).map((t) => '${t.merchant} ₹${t.amount}').join(', ')}
''';
  }
}
```

### 3.2 Vision AI — Receipt & Bill Scanner

```dart
class VisionService {
  static Future<ParsedReceipt?> scanReceipt(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    final response = await http.post(
      Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${Env.geminiKey}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [{
          'parts': [
            {
              'inline_data': {
                'mime_type': 'image/jpeg',
                'data': base64Image,
              }
            },
            {
              'text': '''
Analyze this receipt or bill image and extract:
- amount (numeric only, in INR)
- merchant name
- date (ISO format if visible)
- category (Food/Transport/Shopping/Bills/Entertainment/Health/Other)

Respond ONLY as JSON: {"amount": 0, "merchant": "", "date": "", "category": ""}
If you cannot read clearly, return null for that field.
'''
            }
          ]
        }],
        'generationConfig': {'maxOutputTokens': 150, 'temperature': 0.1},
      }),
    );

    final text = jsonDecode(response.body)['candidates'][0]['content']['parts'][0]['text'];
    try {
      return ParsedReceipt.fromJson(jsonDecode(text));
    } catch (_) {
      return null; // fallback to manual entry
    }
  }
}
```

### 3.3 Voice AI — Hands-Free Logging

```dart
class VoiceService {
  static Future<ParsedExpense?> parseVoiceExpense(String spokenText) async {
    final response = await GeminiService.rawPrompt('''
Parse this spoken expense entry (may be in English or Hinglish):
"$spokenText"

Extract:
- amount (numeric INR)
- merchant or description
- category (Food/Transport/Shopping/Bills/Entertainment/Health)

Respond ONLY as JSON: {"amount": 0, "merchant": "", "category": ""}
Examples:
"spent 300 on petrol" → {"amount": 300, "merchant": "Petrol", "category": "Transport"}
"teen sau rupaye petrol mein gaya" → {"amount": 300, "merchant": "Petrol", "category": "Transport"}
"ordered food from Zomato for 450" → {"amount": 450, "merchant": "Zomato", "category": "Food"}
''');
    try {
      return ParsedExpense.fromJson(jsonDecode(response));
    } catch (_) {
      return null;
    }
  }
}
```

### 3.4 Supabase Edge Functions

#### Family Aggregate Function

```typescript
// supabase/functions/family-aggregate/index.ts
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  const { family_id, month, year } = await req.json();

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  // Total family spend this month
  const { data: transactions } = await supabase
    .from("transactions")
    .select("user_id, amount, category, txn_time")
    .eq("family_id", family_id)
    .eq("type", "debit")
    .gte("txn_time", `${year}-${String(month).padStart(2,"0")}-01`)
    .lt("txn_time", `${year}-${String(month + 1).padStart(2,"0")}-01`);

  const totalSpent = transactions?.reduce((sum, t) => sum + t.amount, 0) ?? 0;

  // Per-member breakdown
  const byMember: Record<string, number> = {};
  transactions?.forEach((t) => {
    byMember[t.user_id] = (byMember[t.user_id] ?? 0) + t.amount;
  });

  // Per-category breakdown
  const byCategory: Record<string, number> = {};
  transactions?.forEach((t) => {
    byCategory[t.category ?? "Other"] = (byCategory[t.category ?? "Other"] ?? 0) + t.amount;
  });

  return new Response(JSON.stringify({
    total_spent: totalSpent,
    by_member: byMember,
    by_category: byCategory,
    transaction_count: transactions?.length ?? 0,
  }), { headers: { "Content-Type": "application/json" } });
});
```

#### Budget Runway Function

```typescript
// supabase/functions/budget-runway/index.ts
serve(async (req) => {
  const { family_id, monthly_budget } = await req.json();

  const now = new Date();
  const daysElapsed = now.getDate();
  const daysInMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  const { data } = await supabase
    .from("transactions")
    .select("amount, txn_time")
    .eq("family_id", family_id)
    .eq("type", "debit")
    .gte("txn_time", `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2,"0")}-01`);

  const totalSpent = data?.reduce((s, t) => s + t.amount, 0) ?? 0;
  const dailyBurnRate = daysElapsed > 0 ? totalSpent / daysElapsed : 0;
  const projectedDayOfExhaustion = dailyBurnRate > 0
    ? Math.floor(monthly_budget / dailyBurnRate)
    : daysInMonth;

  return new Response(JSON.stringify({
    total_spent: totalSpent,
    daily_burn_rate: dailyBurnRate,
    projected_exhaustion_day: projectedDayOfExhaustion,
    days_elapsed: daysElapsed,
    days_in_month: daysInMonth,
    is_on_track: projectedDayOfExhaustion >= daysInMonth,
  }), { headers: { "Content-Type": "application/json" } });
});
```

### 3.5 Environment Configuration

```bash
# .env (never commit to Git — add to .gitignore)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
GEMINI_API_KEY=your-gemini-key

# Run with env injection
flutter run \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
  --dart-define=GEMINI_API_KEY=$GEMINI_API_KEY
```

```dart
// lib/core/config/env.dart
class Env {
  static const supabaseUrl    = String.fromEnvironment('SUPABASE_URL');
  static const supabaseKey    = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const geminiKey      = String.fromEnvironment('GEMINI_API_KEY');
}
```

### 3.6 Complete `pubspec.yaml`

```yaml
name: dhanpath_ai
description: India's first SMS-native, AI-powered family finance OS
version: 1.0.0+1

environment:
  sdk: ">=3.0.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter

  # Core
  sqflite: ^2.3.2
  path: ^1.9.0
  uuid: ^4.4.2
  intl: ^0.19.0
  crypto: ^3.0.3

  # State
  provider: ^6.1.2

  # SMS
  telephony: ^0.2.0

  # Cloud
  supabase_flutter: ^2.5.0
  connectivity_plus: ^6.0.3

  # AI
  http: ^1.2.1

  # Charts
  fl_chart: ^0.68.0

  # Security
  flutter_secure_storage: ^9.0.0
  local_auth: ^2.2.0

  # Notifications
  flutter_local_notifications: ^17.2.2

  # Export
  csv: ^6.0.0
  pdf: ^3.11.1
  share_plus: ^9.0.0

  # Camera (Vision AI)
  image_picker: ^1.1.2

  # Speech (Voice AI)
  speech_to_text: ^6.6.2

  # UI
  google_fonts: ^6.2.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
```

### 3.7 Phase 3 Build Checklist

- [ ] `GeminiService` — chat, with context injection from Supabase
- [ ] `VisionService` — receipt scan → auto-fill transaction form
- [ ] `VoiceService` — speech-to-text → Gemini parse → confirm dialog
- [ ] AI Chat UI in Budget tab with streaming response
- [ ] Camera FAB → receipt scan → confirm screen
- [ ] Mic FAB → voice logging → confirm screen
- [ ] Supabase Edge Function: `family-aggregate` deployed
- [ ] Supabase Edge Function: `budget-runway` deployed
- [ ] All env variables injected via `--dart-define`
- [ ] Gemini API cache (last 10 responses) for offline/demo fallback
- [ ] Mock API fallback for demo if Gemini is rate-limited
- [ ] Pre-loaded demo dataset: 3-person Patel family, 1 month, 30+ transactions
- [ ] All 3 AI modalities tested: Chat ✓ · Vision ✓ · Voice ✓
- [ ] Watermelon UI dashboard: all panels connected to live Supabase data
- [ ] 3-minute demo rehearsal done

---

> **Privacy Guarantee:** All SMS messages are parsed entirely on-device using local regex. Raw SMS content is **never uploaded**. Only extracted transaction data (amount, merchant, category) syncs to Supabase.

---

## 💰 SaaS Pricing Model

| Tier | Price | Features |
|---|---|---|
| **Free** | ₹0 / forever | Personal budget ring, SMS parsing, 1 user, 3 months history |
| **Family** | ₹199 / month | Up to 6 members, family dashboard, AI assistant, forecast chart, web access |
| **Business** | ₹999 / month | Teams, expense approvals, GST report, multi-branch, API access, accountant view |

**TAM Framing:**
- 300M+ Indian families. UPI hit 18B transactions/month in 2024.
- Family Plan at 0.1% penetration of 10M digitally-active families = **₹19.9 Cr ARR**
- Comparable: Walnut (acquired), CRED, Money View — **none have family mode**

---

## 👥 Team

Built with ❤️ for Indian Families at the **OceanLab × CHARUSAT Hackathon | April 3–5, 2026**

**Powered by:** Supabase · Watermelon UI · Lovable Dev · Gemini AI · Flutter

---

## 🙏 Acknowledgements

- **Flutter & Dart** — Google's UI toolkit
- **Supabase** — Open source Firebase alternative. Powers our family sync.
- **Watermelon UI** — Premium component library. Admin dashboard.
- **Lovable Dev** — AI-powered rapid web prototyping.
- **Google Gemini AI** — Vision + Chat + NLP. The AI brain of DhanPath.
- **fl_chart** — Beautiful Flutter charts
- **telephony** — SMS access for Android
- **OceanLab Technology + DEPSTAR CHARUSAT** — For creating this hackathon

---

<div align="center">

**DhanPath AI — Built with ❤️ for Indian Families**

*Know what your family can spend today. Every day.*

⭐ Star this repo if you found it useful!

</div>