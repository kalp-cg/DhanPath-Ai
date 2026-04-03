import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'sms_service.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) async {
  debugPrint('Notification action triggered: ${notificationResponse.actionId} with payload: ${notificationResponse.payload}');
  if (notificationResponse.actionId == 'action_mark_paid' && notificationResponse.payload != null) {
    try {
      final parts = notificationResponse.payload!.split('_');
      if (parts.length >= 2) {
        final type = parts[0];
        final idStr = parts[1];
        final id = int.tryParse(idStr);
        if (id != null) {
          final db = await DatabaseHelper.instance.database;
          if (type == 'emi') {
             final emiData = await db.query('emis', where: 'id = ?', whereArgs: [id]);
             if (emiData.isNotEmpty) {
                 final emi = emiData.first;
                 int paid = (emi['paid_months'] as num?)?.toInt() ?? 0;
                 int tenure = (emi['tenure_months'] as num?)?.toInt() ?? 0;
                 if (paid < tenure) {
                    await db.update('emis', {
                      'paid_months': paid + 1,
                      'updated_at': DateTime.now().toIso8601String()
                    }, where: 'id = ?', whereArgs: [id]);
                    debugPrint('Marked EMI $id as paid via notification action.');
                    try {
                       SmsService.notifyTransactionUpdated();
                    } catch(_) {}
                 }
             }
          } else if (type == 'bill') {
             await db.update('bill_reminders', {
                 'status': 'paid',
                 'last_paid_date': DateTime.now().toIso8601String(),
                 'updated_at': DateTime.now().toIso8601String()
             }, where: 'id = ?', whereArgs: [id]);
             debugPrint('Marked Bill $id as paid via notification action.');
             try {
                SmsService.notifyTransactionUpdated();
             } catch(_) {}
          }
        }
      }
    } catch(e) {
      debugPrint("Action Error: $e");
    }
  }
}
