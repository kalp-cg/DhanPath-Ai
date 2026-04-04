import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'database_helper.dart';
import 'export_service.dart';

class BackupService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final ExportService _exportService = ExportService();

  Future<void> createBackup() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'dhanpath.db');
    final file = File(path);

    if (!await file.exists()) {
      throw Exception('Database file not found');
    }

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final backupPath = join(tempDir.path, 'dhanpath_backup_$timestamp.db');

    // Copy the database file to temporary location
    await file.copy(backupPath);

    // Share the backup file
    await Share.shareXFiles([
      XFile(backupPath),
    ], text: 'DhanPath Database Backup');
  }

  // Backward-compatible aliases used by newer settings screens.
  Future<void> createDatabaseBackup() => createBackup();

  Future<bool> restoreBackup() async {
    // Pick the backup file
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null && result.files.single.path != null) {
      final File backupFile = File(result.files.single.path!);

      // Basic validation (check extension or magic header could be better, but simple extension for now)
      // Note: User might select a file without .db extension if renamed, so maybe just trust it or try opening it.

      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'dhanpath.db');

      // Close the existing database connection
      await _dbHelper.close();

      // Overwrite the database file
      // Delete existing first to be safe (copy usually overwrites but...)
      final currentDbFile = File(path);
      if (await currentDbFile.exists()) {
        await currentDbFile.delete();
      }

      await backupFile.copy(path);

      // Force re-initialization on next access
      await _dbHelper.database;

      return true;
    }
    return false;
  }

  // Backward-compatible aliases used by newer settings screens.
  Future<bool> restoreDatabaseBackup() => restoreBackup();

  Future<void> exportTransactionsToCsv() async {
    // Export all available history in CSV format.
    await _exportService.exportTransactions(
      startDate: DateTime(1970, 1, 1),
      endDate: DateTime.now(),
      isPdf: false,
    );
  }
}
