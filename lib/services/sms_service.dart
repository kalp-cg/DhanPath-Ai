import 'dart:async';
import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:telephony/telephony.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'database_helper.dart';
import 'emi_parser.dart';
import 'split_bill_parser.dart';
import 'bill_reminder_parser.dart';
import 'smart_notification_engine.dart';
import '../core/parsers/bank_parser_factory.dart';
import 'notification_service.dart';

// Top-level function for background handling (must be outside any class)
@pragma('vm:entry-point')
void backgroundMessageHandler(SmsMessage message) async {
  // MUST initialize when running in a background isolate!
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  // MUST initialize notifications for background isolates!
  await NotificationService().initialize();

  String? sender = message.address;
  String? body = message.body;
  int? date = message.date;

  if (sender != null && body != null && date != null) {
    final receivedDate = DateTime.fromMillisecondsSinceEpoch(date);

    // Process as regular transaction
    final parsedTxn = BankParserFactory.parseTransaction(body, sender, date);

    if (parsedTxn != null) {
      final transaction = parsedTxn.toTransaction();

      // Time-based dedup: check for an existing transaction with same
      // amount + type within ±2 minutes (catches BGGB-style dual SMS)
      final db = await DatabaseHelper.instance.database;
      final from = receivedDate
          .subtract(const Duration(minutes: 2))
          .toIso8601String();
      final to = receivedDate.add(const Duration(minutes: 2)).toIso8601String();
      final typeStr = transaction.type.name;
      final existing = await db.query(
        'transactions',
        where:
            'amount = ? AND type = ? AND date BETWEEN ? AND ? AND is_deleted = 0',
        whereArgs: [transaction.amount, typeStr, from, to],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        debugPrint(
          '⏭️ Skipped duplicate transaction: ${transaction.merchantName} Rs.${transaction.amount}',
        );
        return;
      }

      // Save transaction and capture the auto-generated ID
      final transactionId = await DatabaseHelper.instance.create(transaction);

      // ==================== AUTO-DETECT & UPDATE FEATURES ====================

      // db already obtained above for dedup check

      // 1. Check if it's an EMI payment SMS - auto-update EMI
      final emiPayment = EmiParser.detectEmiPayment(body, sender);
      if (emiPayment != null) {
        final matchingEmi = await EmiParser.findMatchingEmi(
          emiPayment.amount,
          emiPayment.lenderName,
          emiPayment.type,
          db,
        );

        if (matchingEmi != null) {
          final currentPaidMonths = matchingEmi['paid_months'] as int? ?? 0;
          final tenureMonths = matchingEmi['tenure_months'] as int;

          // Check if already completed
          if (currentPaidMonths >= tenureMonths) {
            debugPrint('EMI already completed: ${matchingEmi['lender_name']}');
          } else {
            final newPaidMonths = currentPaidMonths + 1;
            final isCompleted = newPaidMonths >= tenureMonths;

            // Calculate new outstanding - ensure it doesn't go negative
            final principalAmount = matchingEmi['principal_amount'] as double;
            final newOutstanding = isCompleted
                ? 0.0
                : principalAmount -
                      (principalAmount / tenureMonths) * newPaidMonths;

            await db.update(
              'emis',
              {
                'paid_months': newPaidMonths,
                'current_outstanding': newOutstanding,
                'is_active': isCompleted ? 0 : 1,
                'updated_at': DateTime.now().toIso8601String(),
              },
              where: 'id = ?',
              whereArgs: [matchingEmi['id']],
            );
            debugPrint(
              isCompleted
                  ? 'EMI COMPLETED: ${matchingEmi['lender_name']} - All ${tenureMonths} months paid!'
                  : 'EMI updated: ${matchingEmi['lender_name']} - Month ${newPaidMonths}/${tenureMonths}',
            );
          }
        }
      }

      // 2. Check if it's a Split Bill SMS - auto-create split bill entry
      final splitBill = SplitBillParser.detectSplitBill(body, sender);
      if (splitBill != null) {
        final now = DateTime.now().toIso8601String();

        // Create split bill
        final splitBillId = await db.insert('split_bills', {
          'bill_name': splitBill.billName,
          'total_amount': splitBill.amount,
          'transaction_id': transactionId,
          'bill_date': now,
          'is_paid_by_me': splitBill.isPaidByMe ? 1 : 0,
          'status': 'pending',
          'created_at': now,
          'updated_at': now,
        });

        // Add person to split
        await db.insert('split_persons', {
          'split_bill_id': splitBillId,
          'person_name': splitBill.personName,
          'share_amount': splitBill.amount,
          'is_paid': 0,
          'created_at': now,
        });

        debugPrint(
          'Split Bill created: ${splitBill.billName} with ${splitBill.personName}',
        );
      }

      // 3. Auto-tag transaction based on category
      final categoryTags = {
        'Food & Dining': 'Personal',
        'Entertainment': 'Personal',
        'Shopping': 'Personal',
        'Utilities': 'Personal',
        'Education': 'Tax Deductible',
        'Healthcare': 'Tax Deductible',
        'Fitness': 'Personal',
        'Business': 'Business',
      };

      final tagName = categoryTags[transaction.category] ?? 'Personal';
      final tags = await db.query(
        'expense_tags',
        where: 'name = ?',
        whereArgs: [tagName],
      );
      if (tags.isNotEmpty) {
        await db.insert('transaction_tags', {
          'transaction_id': transactionId,
          'tag_id': tags.first['id'],
          'created_at': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        debugPrint('Transaction auto-tagged: $tagName');
      }

      // 4. Check if it's a Bill SMS - auto-create bill reminder
      final billDetected = BillReminderParser.detectBill(body, sender);
      if (billDetected != null) {
        final now = DateTime.now();
        final nextDueDate = _calculateNextBillDue(now, billDetected.frequency);

        await db.insert('bill_reminders', {
          'bill_name': billDetected.billName,
          'category': billDetected.category,
          'amount': billDetected.amount,
          'frequency': billDetected.frequency.toString().split('.').last,
          'day_of_month': now.day,
          'next_due_date': nextDueDate.toIso8601String(),
          'status': 'paid',
          'is_active': 1,
          'auto_detected': 1,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        debugPrint('Bill Reminder auto-created: ${billDetected.billName}');
      }

      // 5. Update Net Worth if it's a major transaction (asset/liability change)
      if (transaction.amount > 10000 &&
          (transaction.category.contains('Investment') ||
              transaction.category.contains('Loan') ||
              transaction.category.contains('Deposit'))) {
        // Calculate actual totals from assets and liabilities tables
        final assetResult = await db.rawQuery(
          'SELECT COALESCE(SUM(current_value), 0) as total FROM assets',
        );
        final liabilityResult = await db.rawQuery(
          'SELECT COALESCE(SUM(current_balance), 0) as total FROM liabilities',
        );
        final totalAssets =
            (assetResult.first['total'] as num?)?.toDouble() ?? 0.0;
        final totalLiabilities =
            (liabilityResult.first['total'] as num?)?.toDouble() ?? 0.0;

        await db.insert('net_worth_snapshots', {
          'snapshot_date': DateTime.now().toIso8601String().split('T')[0],
          'total_assets': totalAssets,
          'total_liabilities': totalLiabilities,
          'net_worth': totalAssets - totalLiabilities,
          'created_at': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        debugPrint('Net Worth snapshot created');
      }

      debugPrint(
        'Auto-detection complete for transaction: ${transaction.merchantName}',
      );

      // ── Fire smart notification for this new transaction ──
      try {
        await SmartNotificationEngine().onNewTransaction(
          amount: transaction.amount,
          merchant: transaction.merchantName,
          type: transaction.type.name,
          category: transaction.category,
          bankName: transaction.bankName,
        );
      } catch (e) {
        debugPrint('Notification error: $e');
      }

      // Notify UI if we are in main isolate
      try {
        SmsService.notifyTransactionUpdated();
      } catch (e) {
        // Ignore
      }
    } else {
      // Save to Unrecognized SMS if BankParserFactory didn't recognize it
      await DatabaseHelper.instance.insertUnrecognizedSms({
        'sender': sender,
        'body': body,
        'reason': 'Unrecognized by BankParserFactory',
        'received_at': receivedDate.toIso8601String(),
      });
    }
  }
}

class SmsService {
  static bool _isListenerAttached = false;

  static final StreamController<void> _transactionUpdateController =
      StreamController<void>.broadcast();
  static Stream<void> get onTransactionUpdated =>
      _transactionUpdateController.stream;

  static void notifyTransactionUpdated() {
    if (!_transactionUpdateController.isClosed) {
      _transactionUpdateController.add(null);
    }
  }

  // ... existing code ...
  final Telephony telephony = Telephony.instance;

  Future<void> init() async {
    // Avoid plugin-internal permission request path (which can crash on old telephony).
    final smsStatus = await Permission.sms.status;
    if (!smsStatus.isGranted) {
      debugPrint('SMS listener init skipped: SMS permission not granted yet.');
      return;
    }

    // `listenIncomingSms` should only be registered once per process.
    if (_isListenerAttached) {
      return;
    }

    telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) {
        backgroundMessageHandler(message);
      },
      onBackgroundMessage: backgroundMessageHandler,
    );

    _isListenerAttached = true;
  }

  Future<bool> requestPermissions() async {
    // Request SMS permission
    final smsStatus = await Permission.sms.status;
    if (!smsStatus.isGranted) {
    final result = await Permission.sms.request();
      if (!result.isGranted) return false;
    }

    // Request notification permission (Android 13+)
    final notifStatus = await Permission.notification.status;
    if (!notifStatus.isGranted) {
      await Permission.notification.request();
    }

    return true;
  }

  /// Scan the SMS inbox for new transactions.
  /// Pass [resetScan] = true to ignore the last-scan timestamp and process
  /// all SMS from the beginning (used by Full Resync).
  Future<ScanResult> scanInbox({bool resetScan = false}) async {
    // Guard to ensure telephony plugin does not attempt its own permission reply path.
    final smsStatus = await Permission.sms.status;
    if (!smsStatus.isGranted) {
      return ScanResult(totalSmsRead: 0, transactionsFound: 0);
    }

    final prefs = await SharedPreferences.getInstance();
    if (resetScan) {
      await prefs.remove('last_sms_scan_timestamp');
    }
    final lastScanMs = prefs.getInt('last_sms_scan_timestamp') ?? 0;

    List<SmsMessage> messages = await telephony.getInboxSms(
      filter: lastScanMs > 0
          ? SmsFilter.where(SmsColumn.DATE).greaterThan(lastScanMs.toString())
          : null,
    );

    // If timestamp filter returned 0 messages but we had a saved timestamp,
    // retry without the filter (covers stale timestamp edge-case).
    if (messages.isEmpty && lastScanMs > 0) {
      messages = await telephony.getInboxSms();
    }

    int count = 0;
    final db = await DatabaseHelper.instance.database;
    int newestTimestamp = lastScanMs;

    // In-memory dedup: stores (amount, typeName, tsMs) of transactions
    // already committed this scan. Avoids BGGB-style dual-SMS duplicates
    // regardless of bucket boundaries or batch-commit timing.
    final List<({double amount, String type, int tsMs})> committedThisScan = [];
    const dedupWindowMs = 2 * 60 * 1000; // 2-minute window

    for (var message in messages) {
      if (message.address != null &&
          message.body != null &&
          message.date != null) {
        // Track newest SMS for next incremental scan
        if (message.date! > newestTimestamp) {
          newestTimestamp = message.date!;
        }

        // Process as regular transaction
        final parsedTxn = BankParserFactory.parseTransaction(
          message.body!,
          message.address!,
          message.date!,
        );

        if (parsedTxn != null) {
          final tsMs = message.date!;
          final amt = parsedTxn.amount;
          final typ = parsedTxn.type.name;

          // Step 1: In-memory check against already-committed SMS in this scan.
          // This catches same-batch duplicates even if timestamps straddle a
          // bucket boundary (unlike the old ~/ 120000 approach).
          final inMemoryDupe = committedThisScan.any(
            (s) =>
                s.amount == amt &&
                s.type == typ &&
                (tsMs - s.tsMs).abs() <= dedupWindowMs,
          );
          if (inMemoryDupe) continue;

          // Step 2: DB check for cross-batch / cross-scan duplicates.
          // This works because each insert is now committed immediately (no batch).
          final from = DateTime.fromMillisecondsSinceEpoch(
            tsMs,
          ).subtract(const Duration(minutes: 2)).toIso8601String();
          final to = DateTime.fromMillisecondsSinceEpoch(
            tsMs,
          ).add(const Duration(minutes: 2)).toIso8601String();
          final existing = await db.query(
            'transactions',
            where:
                'amount = ? AND type = ? AND date BETWEEN ? AND ? AND is_deleted = 0',
            whereArgs: [amt, typ, from, to],
            limit: 1,
          );
          if (existing.isNotEmpty) {
            committedThisScan.add((amount: amt, type: typ, tsMs: tsMs));
            continue;
          }

          // Step 3: Commit immediately so subsequent SMS in this loop see it.
          await db.insert(
            'transactions',
            parsedTxn.toTransaction().toMap(),
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          committedThisScan.add((amount: amt, type: typ, tsMs: tsMs));
          count++;
        } else {
          // Unrecognized by current parsers — save for review
          await db.insert('unrecognized_sms', {
            'sender': message.address,
            'body': message.body,
            'reason': 'Parser could not identify transaction',
            'received_at': DateTime.fromMillisecondsSinceEpoch(
              message.date!,
            ).toIso8601String(),
            'is_processed': 0,
            'created_at': DateTime.now().toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
    }

    // Save scan timestamp for incremental scanning next time
    if (newestTimestamp > lastScanMs) {
      await prefs.setInt('last_sms_scan_timestamp', newestTimestamp);
    }

    return ScanResult(totalSmsRead: messages.length, transactionsFound: count);
  }
}

/// Result of an SMS inbox scan
class ScanResult {
  final int totalSmsRead;
  final int transactionsFound;

  ScanResult({required this.totalSmsRead, required this.transactionsFound});
}

/// Helper function to calculate next bill due date
DateTime _calculateNextBillDue(DateTime now, dynamic frequency) {
  // frequency is a BillFrequency enum from bill_reminder_parser
  final freqStr = frequency.toString();

  if (freqStr.contains('monthly')) {
    return DateTime(now.year, now.month + 1, now.day);
  } else if (freqStr.contains('quarterly')) {
    return DateTime(now.year, now.month + 3, now.day);
  } else if (freqStr.contains('yearly')) {
    return DateTime(now.year + 1, now.month, now.day);
  } else if (freqStr.contains('weekly')) {
    return now.add(const Duration(days: 7));
  } else if (freqStr.contains('daily')) {
    return now.add(const Duration(days: 1));
  }

  return DateTime(now.year, now.month + 1, now.day); // Default to monthly
}
