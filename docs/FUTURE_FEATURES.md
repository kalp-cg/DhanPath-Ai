# Future Features Roadmap: DhanPath

This document outlines high-impact features planned for future releases. The goal is to build these out methodically rather than rushing, ensuring stability and a premium user experience.

## 1. Trip / Event Mode (High Priority)
**Problem:** Users travel or host events and want to see isolated spending without it ruining their monthly budget analytics.
**Solution:** A temporary mode that links transactions to a specific event.
* **Core Logic:** 
  * User creates a "Trip" with a start date and an estimated end date.
  * `sms_service.dart` checks: *Is there an active trip happening right now?*
  * If yes, the newly parsed transaction is automatically tagged (e.g., `trip_id = 12`).
* **UI Required:**
  * Trip creation modal.
  * Dedicated "Trip Dashboard" showing total trip cost vs. trip budget.
* **Database Updates Required:**
  * Create `trips` table `(id, name, start_date, end_date, budget)`.
  * Add `trip_id` (nullable foreign key) to the `transactions` table.

## 2. Smart "Split Bill" Engine (Splitwise Alternative)
**Problem:** Users currently have to double-enter data if they pay a group bill (once for DhanPath, once in Splitwise).
**Solution:** Expand the existing `SplitBillParser`.
* **Core Logic:**
  * When a large restaurant/food transaction is detected, trigger an actionable notification: *"Split this bill?"*
  * User taps notification, selects contacts.
  * DhanPath records that user paid ₹2000, but ₹1500 is "owed" to them, meaning their *actual personal expense* is only ₹500.
* **UI Required:**
  * "Who Owes Me" dashboard.
  * WhatsApp integration: 1-click button to generate a UPI payment link and send it via WhatsApp to the friend.

## 3. Subscription & Trial Tracker
**Problem:** Banks don't clearly show recurring card mandates or upcoming hidden fees until it's too late.
**Solution:** Analyze existing historical data to find patterns.
* **Core Logic:**
  * Run a background analyzer over the SQLite database comparing merchant names and exact amounts spaced ~30 days apart (e.g., Netflix ₹199).
  * Automatically categorize them as "Subscriptions".
  * Predict the next charge date and send a "Pre-charge Warning" notification 2 days before.
* **UI Required:**
  * "Active Subscriptions" screen showing total monthly burn rate on subscriptions.

## 4. Refund & Reversal Linker
**Problem:** An expense of ₹1000 happens. Two days later, an Amazon refund of ₹1000 arrives. Currently, these show as two separate items (an expense and an income), inflating the charts.
**Solution:** Smart pairing.
* **Core Logic:**
  * When an income transaction has keywords like "Refund", "Reversal", or "Credited back", scan the last 14 days for an exact matching expense amount from the same merchant.
  * Link them together so the net impact on the budget becomes zero.

---
*Note: Development will proceed sequentially, starting with the Trip Mode. Database migrations should be handled carefully via `database_helper.dart` `onUpgrade` to preserve user data.*