import 'dart:convert';
import 'package:http/http.dart' as http;
import 'database_helper.dart';

/// Syncs local SQLite transactions to the DhanPath cloud dashboard.
///
/// Usage:
///   final syncer = CloudSyncService(
///     dashboardUrl: 'https://your-dashboard.vercel.app',  // or http://192.168.x.x:3000
///     familyId: 'your-family-uuid',
///     accessToken: '`supabase-access-token`',
///   );
///   await syncer.syncAll();
class CloudSyncService {
  final String dashboardUrl;
  final String familyId;
  final String accessToken;

  CloudSyncService({
    required this.dashboardUrl,
    required this.familyId,
    required this.accessToken,
  });

  /// Push all local transactions to the cloud dashboard.
  /// Returns the count of transactions synced.
  Future<int> syncAll() async {
    final db = await DatabaseHelper.instance.database;
    final txRows = await db.query(
      'transactions',
      where: 'is_deleted = 0',
      orderBy: 'date ASC',
    );

    if (txRows.isEmpty) return 0;

    // Map local DB rows -> cloud API format
    final mapped = txRows.map((tx) {
      return <String, dynamic>{
        'amount': (tx['amount'] as num?)?.toDouble() ?? 0,
        'merchantName': tx['merchant_name'] as String? ?? 'Unknown',
        'category': tx['category'] as String? ?? 'Uncategorized',
        'type': tx['type'] as String? ?? 'expense',
        'date': tx['date'] as String? ?? DateTime.now().toIso8601String(),
        'bankName': tx['bank_name'] as String?,
        'accountNumber': tx['account_number'] as String?,
        'transactionHash': tx['transaction_hash'] as String?,
      };
    }).toList();

    // Send in batches of 100
    int totalSynced = 0;
    for (var i = 0; i < mapped.length; i += 100) {
      final batch = mapped.sublist(
        i,
        i + 100 > mapped.length ? mapped.length : i + 100,
      );

      final response = await http.post(
        Uri.parse('$dashboardUrl/api/sync'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'familyId': familyId,
          'transactions': batch.map((tx) {
            final date = tx['date'] as String? ?? '';
            final amount = tx['amount']?.toString() ?? '0';
            final merchant = tx['merchantName']?.toString() ?? '';
            return {...tx, 'clientTxnId': '$date|$amount|$merchant'};
          }).toList(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        totalSynced += (data['synced'] as int?) ?? 0;
      } else {
        throw Exception(
          'Sync failed (batch ${i ~/ 100 + 1}): ${response.body}',
        );
      }
    }

    return totalSynced;
  }
}
