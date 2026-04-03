import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../theme/app_theme.dart';
import 'add_rule_screen.dart';
import 'add_transaction_screen.dart';

class UnrecognizedSmsScreen extends StatefulWidget {
  const UnrecognizedSmsScreen({super.key});

  @override
  State<UnrecognizedSmsScreen> createState() => _UnrecognizedSmsScreenState();
}

class _UnrecognizedSmsScreenState extends State<UnrecognizedSmsScreen> {
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    final db = await DatabaseHelper.instance.database;
    final list = await db.query(
      'unrecognized_sms',
      where: 'is_processed = 0',
      orderBy: 'received_at DESC',
    );
    if (mounted) {
      setState(() {
        _messages = list;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Unrecognized SMS'),
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadMessages),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _messages.isEmpty
          ? const Center(child: Text('No unrecognized messages'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              msg['sender'] ?? 'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              msg['reason'] ?? '',
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(msg['body'] ?? ''),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              child: const Text(
                                'Ignore/Delete',
                                style: TextStyle(color: Colors.grey),
                              ),
                              onPressed: () => _deleteMessage(msg['id']),
                            ),
                            TextButton(
                              child: const Text(
                                'Add Rule',
                                style: TextStyle(color: AppTheme.primaryColor),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AddRuleScreen(),
                                  ),
                                );
                              },
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                              ),
                              child: const Text(
                                'Add Tx',
                                style: TextStyle(color: Colors.white),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AddTransactionScreen(
                                      prefilledDescription: msg['body'] ?? '',
                                    ),
                                  ),
                                ).then((_) {
                                  // Mark as processed after adding
                                  _deleteMessage(msg['id']);
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _deleteMessage(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('unrecognized_sms', where: 'id = ?', whereArgs: [id]);
    _loadMessages();
  }
}
