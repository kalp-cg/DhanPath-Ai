import 'package:flutter/material.dart';
import '../services/backup_service.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';

class BackupSettingsScreen extends StatefulWidget {
  const BackupSettingsScreen({Key? key}) : super(key: key);

  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen> {
  final _backupService = BackupService();
  bool _isLoading = false;

  void _showLoading(String message) {
    setState(() => _isLoading = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
    );
  }

  void _hideLoading() {
    setState(() => _isLoading = false);
  }

  Future<void> _exportCsv() async {
    _showLoading('Generating CSV export...');
    try {
      await _backupService.exportTransactionsToCsv();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export ready! Choose where to save it.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to export: $e')));
    } finally {
      _hideLoading();
    }
  }

  Future<void> _createBackup() async {
    _showLoading('Encrypting securely and backing up...');
    try {
      await _backupService.createDatabaseBackup();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup ready! Please save the .db file securely.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create backup: $e')));
    } finally {
      _hideLoading();
    }
  }

  Future<void> _restoreBackup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Backup?'),
        content: const Text('This will OVERWRITE your current data with the selected backup file. This cannot be undone. Make sure you select a valid DhanPath .db file.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Overwrite Data')
          ),
        ],
      ),
    );

    if (confirm != true) return;

    _showLoading('Restoring from backup...');
    try {
      final success = await _backupService.restoreDatabaseBackup();
      if (success) {
        // Refresh entire app state
        Provider.of<TransactionProvider>(context, listen: false).loadTransactions();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restore successful! App data updated.')));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restore cancelled or failed')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to restore: $e')));
    } finally {
      _hideLoading();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data & Offline Security'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Keep Your Data Safe',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'DhanPath is a strictly offline-first app for your security. Since we do not sync your highly sensitive transaction SMS to any cloud servers, you are responsible for keeping backups of your data when changing phones.',
                style: TextStyle(color: Colors.grey, height: 1.5),
              ),
              const SizedBox(height: 32),
              
              // Export Section
              const Text(
                '1. Analytics Export',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                tileColor: Theme.of(context).cardColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: const Icon(Icons.table_chart_rounded, color: Colors.green),
                title: const Text('Export to CSV'),
                subtitle: const Text('Download your transactions for Excel/Sheets'),
                trailing: const Icon(Icons.download_rounded),
                onTap: _exportCsv,
              ),

              const SizedBox(height: 32),

              // Full Backup Section
              const Text(
                '2. Full Offline Backup',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                tileColor: Theme.of(context).cardColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: const Icon(Icons.backup_rounded, color: Colors.blue),
                title: const Text('Create Local Backup'),
                subtitle: const Text('Generate a secure .db file of all your app data'),
                trailing: const Icon(Icons.save_alt_rounded),
                onTap: _createBackup,
              ),
              const SizedBox(height: 12),
              ListTile(
                tileColor: Theme.of(context).cardColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: const Icon(Icons.restore_rounded, color: Colors.orange),
                title: const Text('Restore from Data File'),
                subtitle: const Text('Recover app data from a previously saved .db file'),
                trailing: const Icon(Icons.upload_file_rounded),
                onTap: _restoreBackup,
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
