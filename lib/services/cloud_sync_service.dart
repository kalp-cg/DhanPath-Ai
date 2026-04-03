import 'dart:convert';
import 'package:http/http.dart' as http;
import 'database_helper.dart';
import 'secure_storage_service.dart';
import 'user_preferences_service.dart';

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
  final String accessToken;

  CloudSyncService({
    required this.dashboardUrl,
    required this.accessToken,
  });

  static Future<String> loginAndGetToken({
    required String dashboardUrl,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$dashboardUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.trim().toLowerCase(),
        'password': password,
      }),
    );

    Map<String, dynamic> payload = <String, dynamic>{};
    final rawBody = response.body.trim();
    if (rawBody.isNotEmpty) {
      try {
        payload = jsonDecode(rawBody) as Map<String, dynamic>;
      } catch (_) {
        payload = <String, dynamic>{};
      }
    }

    if (response.statusCode != 200) {
      final serverError = payload['error'] as String?;
      if (serverError != null && serverError.trim().isNotEmpty) {
        throw Exception(serverError);
      }

      if (response.statusCode == 401) {
        throw Exception('Invalid website email or password.');
      }
      if (response.statusCode == 404) {
        throw Exception('Dashboard URL is incorrect (auth endpoint not found).');
      }
      throw Exception('Dashboard login failed (${response.statusCode}).');
    }

    final token = (payload['token'] as String?)?.trim();
    if (token == null || token.isEmpty) {
      throw Exception('Dashboard login response did not include an auth token.');
    }

    return token;
  }

  Future<Map<String, dynamic>> verifyMembership() async {
    final response = await http.get(
      Uri.parse('$dashboardUrl/api/family/summary'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Email is not an accepted family member yet (${response.statusCode}): ${response.body}',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

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

    // Map local DB rows -> cloud API format for bulk endpoint.
    final mapped = txRows.map((tx) {
      final type = (tx['type'] as String? ?? 'expense').toLowerCase();
      final normalizedType = (type == 'income' || type == 'credit')
          ? 'credit'
          : 'debit';
      final date = tx['date'] as String? ?? DateTime.now().toIso8601String();
      final amount = (tx['amount'] as num?)?.toDouble() ?? 0;
      final merchant = tx['merchant_name'] as String? ?? 'Unknown';
      final transactionHash = tx['transaction_hash'] as String?;

      return <String, dynamic>{
        'amount': amount,
        'merchant': merchant,
        'category': tx['category'] as String? ?? 'Uncategorized',
        'type': normalizedType,
        'txnTime': date,
        'source': 'sms',
        'clientTxnId': transactionHash ?? '$date|$amount|$merchant',
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
        Uri.parse('$dashboardUrl/api/transactions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'transactions': batch,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        totalSynced += (data['synced'] as int?) ?? 0;
      } else if (response.statusCode == 401) {
        throw Exception('Dashboard auth expired. Please sync again.');
      } else {
        throw Exception(
          'Sync failed (batch ${i ~/ 100 + 1}): ${response.body}',
        );
      }
    }

    return totalSynced;
  }

  /// Attempts best-effort sync using stored dashboard credentials.
  static Future<int> autoSyncCurrentUser() async {
    final prefs = UserPreferencesService();
    final secure = SecureStorageService();

    final dashboardUrl = await prefs.getEffectiveCloudDashboardUrl();
    final email = (await secure.getCloudSyncEmail())?.trim() ?? '';
    final password = (await secure.getCloudSyncPassword()) ?? '';
    if (email.isEmpty || password.isEmpty) return 0;

    var token = (await secure.getCloudSyncToken())?.trim() ?? '';
    if (token.isEmpty) {
      token = await loginAndGetToken(
        dashboardUrl: dashboardUrl,
        email: email,
        password: password,
      );
      await secure.setCloudSyncToken(token);
    }

    try {
      final syncer = CloudSyncService(
        dashboardUrl: dashboardUrl,
        accessToken: token,
      );
      final summary = await syncer.verifyMembership();
      final resolvedFamilyId = (summary['familyId'] as String?)?.trim() ?? '';
      if (resolvedFamilyId.isNotEmpty) {
        await prefs.setCloudFamilyId(resolvedFamilyId);
      }
      await prefs.setCloudEmail(email);
      return syncer.syncAll();
    } catch (_) {
      // One retry with a fresh token in case old token is expired.
      final refreshed = await loginAndGetToken(
        dashboardUrl: dashboardUrl,
        email: email,
        password: password,
      );
      await secure.setCloudSyncToken(refreshed);

      final syncer = CloudSyncService(
        dashboardUrl: dashboardUrl,
        accessToken: refreshed,
      );
      final summary = await syncer.verifyMembership();
      final resolvedFamilyId = (summary['familyId'] as String?)?.trim() ?? '';
      if (resolvedFamilyId.isNotEmpty) {
        await prefs.setCloudFamilyId(resolvedFamilyId);
      }
      await prefs.setCloudEmail(email);
      return syncer.syncAll();
    }
  }
}
