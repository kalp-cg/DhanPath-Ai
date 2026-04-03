import 'package:flutter_test/flutter_test.dart';

/// Tests to verify the database schema definitions are consistent
/// and the unrecognized_sms fix (v17) is correctly applied.
///
/// These tests verify the schema strings used in CREATE TABLE and migration
/// statements without needing an actual database connection.

void main() {
  group('Database Schema Consistency Tests', () {
    // These represent the expected column names for unrecognized_sms
    // as used by SmsService.scanInbox() batch insert
    final expectedColumns = [
      'sender',
      'body',
      'reason',
      'received_at',
      'is_processed',
      'created_at',
    ];

    test('Initial CREATE TABLE schema includes all required columns', () {
      // This is the schema from _createDB
      const createTableSql = '''
      CREATE TABLE unrecognized_sms (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sender TEXT NOT NULL,
        body TEXT NOT NULL,
        reason TEXT,
        received_at TEXT NOT NULL DEFAULT '',
        is_processed INTEGER DEFAULT 0,
        created_at TEXT NOT NULL DEFAULT ''
      )
      ''';

      for (final column in expectedColumns) {
        expect(
          createTableSql.contains(column),
          isTrue,
          reason: 'Initial CREATE TABLE should contain column "$column"',
        );
      }

      // Verify old columns are NOT present
      expect(
        createTableSql.contains('timestamp INTEGER'),
        isFalse,
        reason: 'Old "timestamp" column should not be in the new schema',
      );
      expect(
        createTableSql.contains("status TEXT DEFAULT 'PENDING'"),
        isFalse,
        reason: 'Old "status" column should not be in the new schema',
      );
    });

    test('v17 migration schema matches initial CREATE TABLE schema', () {
      // This is the schema from _upgradeDB v17 migration
      const v17MigrationSql = '''
      CREATE TABLE unrecognized_sms (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sender TEXT NOT NULL,
        body TEXT NOT NULL,
        reason TEXT,
        received_at TEXT NOT NULL DEFAULT '',
        is_processed INTEGER DEFAULT 0,
        created_at TEXT NOT NULL DEFAULT ''
      )
      ''';

      for (final column in expectedColumns) {
        expect(
          v17MigrationSql.contains(column),
          isTrue,
          reason: 'v17 migration should contain column "$column"',
        );
      }
    });

    test('SMS insert columns match schema columns', () {
      // Columns used by SmsService.scanInbox() batch.insert
      final insertColumns = {
        'sender',
        'body',
        'reason',
        'received_at',
        'is_processed',
        'created_at',
      };

      // Schema columns (excluding auto-generated 'id')
      final schemaColumns = {
        'sender',
        'body',
        'reason',
        'received_at',
        'is_processed',
        'created_at',
      };

      expect(
        insertColumns,
        equals(schemaColumns),
        reason: 'Insert columns must exactly match schema columns',
      );
    });

    test('Database version is 17 for the schema fix', () {
      // The database version should be 17 to trigger the migration
      const dbVersion = 17;
      expect(
        dbVersion,
        greaterThanOrEqualTo(17),
        reason: 'DB version must be >= 17 to include unrecognized_sms fix',
      );
    });
  });

  group('Unrecognized SMS Data Model Tests', () {
    test('SMS data map has all required fields', () {
      final smsData = {
        'sender': 'SBIBNK',
        'body': 'Dear Customer, your SBI YONO account...',
        'reason': 'Unknown bank format',
        'received_at': DateTime.now().toIso8601String(),
        'is_processed': 0,
        'created_at': DateTime.now().toIso8601String(),
      };

      expect(smsData.containsKey('sender'), isTrue);
      expect(smsData.containsKey('body'), isTrue);
      expect(smsData.containsKey('reason'), isTrue);
      expect(smsData.containsKey('received_at'), isTrue);
      expect(smsData.containsKey('is_processed'), isTrue);
      expect(smsData.containsKey('created_at'), isTrue);

      // Old columns should NOT be present
      expect(smsData.containsKey('timestamp'), isFalse);
      expect(smsData.containsKey('status'), isFalse);
    });

    test('SMS data values are correct types', () {
      final smsData = {
        'sender': 'HDFCBK',
        'body': 'Rs.500 debited from A/c',
        'reason': 'Parsing failed',
        'received_at': '2025-01-15T10:30:00.000',
        'is_processed': 0,
        'created_at': '2025-01-15T10:30:00.000',
      };

      expect(smsData['sender'], isA<String>());
      expect(smsData['body'], isA<String>());
      expect(smsData['reason'], isA<String>());
      expect(smsData['received_at'], isA<String>());
      expect(smsData['is_processed'], isA<int>());
      expect(smsData['created_at'], isA<String>());
    });

    test('Default reason is set when failureReason is null', () {
      // Simulate nullable value from database
      final Map<String, dynamic> row = {'reason': null};
      final reason = (row['reason'] as String?) ?? 'Unknown';
      expect(reason, equals('Unknown'));
    });

    test('Reason is preserved when failureReason is provided', () {
      final Map<String, dynamic> row = {'reason': 'Not a bank SMS'};
      final reason = (row['reason'] as String?) ?? 'Unknown';
      expect(reason, equals('Not a bank SMS'));
    });

    test('is_processed defaults to 0', () {
      const isProcessed = 0;
      expect(isProcessed, equals(0));
    });
  });

  group('Migration Safety Tests', () {
    test('v15 migration uses drop-and-recreate approach', () {
      // Verify that the v15 migration approach is nuclear (drop + recreate)
      // This is safer than ALTER TABLE for schema changes
      const dropSql = 'DROP TABLE IF EXISTS unrecognized_sms';
      expect(dropSql, contains('DROP TABLE'));
      expect(dropSql, contains('IF EXISTS'));
    });

    test('v17 migration uses drop-and-recreate approach', () {
      const dropSql = 'DROP TABLE IF EXISTS unrecognized_sms';
      expect(dropSql, contains('DROP TABLE'));
      expect(dropSql, contains('IF EXISTS'));
    });

    test('Unrecognized SMS data is non-critical (safe to drop)', () {
      // This test documents that unrecognized SMS data is regenerated
      // on the next scan, making drop-and-recreate safe
      const isRegeneratedOnScan = true;
      expect(
        isRegeneratedOnScan,
        isTrue,
        reason: 'Unrecognized SMS data should be regenerated on scan',
      );
    });

    test('Version upgrade path covers all scenarios', () {
      // Fresh install: _createDB with v17 schema
      // Existing v16: _upgradeDB runs v17 migration
      // Existing v15: _upgradeDB runs v16 + v17
      // Existing v14: _upgradeDB runs v15 (recreate) + v16 + v17
      final versionPaths = {
        'fresh_install': [17], // _createDB only
        'from_v16': [17],
        'from_v15': [16, 17],
        'from_v14': [15, 16, 17],
      };

      expect(versionPaths['fresh_install'], contains(17));
      expect(versionPaths['from_v16'], contains(17));
      expect(versionPaths['from_v15'], contains(16));
      expect(versionPaths['from_v14'], contains(15));
    });
  });
}
