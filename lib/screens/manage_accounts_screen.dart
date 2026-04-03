import 'package:flutter/material.dart';
import '../models/account_model.dart';
import '../services/database_helper.dart';
import '../services/user_preferences_service.dart';

class ManageAccountsScreen extends StatefulWidget {
  const ManageAccountsScreen({super.key});

  @override
  State<ManageAccountsScreen> createState() => _ManageAccountsScreenState();
}

class _ManageAccountsScreenState extends State<ManageAccountsScreen> {
  List<Account> _accounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() => _isLoading = true);
    final accountsData = await DatabaseHelper.instance.readAllAccounts();
    setState(() {
      _accounts = accountsData.map((a) => Account.fromMap(a)).toList();
      _isLoading = false;
    });
  }

  void _addAccount() {
    showDialog(
      context: context,
      builder: (context) => AddAccountDialog(onAccountAdded: _loadAccounts),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Accounts'), elevation: 0),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _accounts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.account_balance,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No accounts added yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _addAccount,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Account'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _accounts.length,
              itemBuilder: (context, index) {
                final account = _accounts[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.15),
                      child: Icon(
                        Icons.account_balance,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    title: Text(
                      account.bankName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${account.accountType} • XX${account.accountNumber}',
                    ),
                    trailing: account.currentBalance != null
                        ? Text(
                            '${CurrencyHelper.symbol}${account.currentBalance!.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          )
                        : null,
                    onTap: () {
                      // Navigate to account details
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addAccount,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AddAccountDialog extends StatefulWidget {
  final VoidCallback onAccountAdded;

  const AddAccountDialog({super.key, required this.onAccountAdded});

  @override
  State<AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState extends State<AddAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _balanceController = TextEditingController();
  String _accountType = 'Savings';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Account'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _bankNameController,
                decoration: const InputDecoration(
                  labelText: 'Bank Name',
                  hintText: 'e.g., HDFC Bank',
                ),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _accountNumberController,
                decoration: const InputDecoration(
                  labelText: 'Last 4 Digits',
                  hintText: 'e.g., 1234',
                ),
                keyboardType: TextInputType.number,
                maxLength: 4,
                validator: (v) => v?.length != 4 ? 'Enter 4 digits' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _accountType,
                decoration: const InputDecoration(labelText: 'Account Type'),
                items: ['Savings', 'Current', 'Credit Card'].map((type) {
                  return DropdownMenuItem(value: type, child: Text(type));
                }).toList(),
                onChanged: (value) => setState(() => _accountType = value!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _balanceController,
                decoration: InputDecoration(
                  labelText: 'Current Balance (Optional)',
                  prefixText: CurrencyHelper.symbol,
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final account = Account(
                bankName: _bankNameController.text,
                accountNumber: _accountNumberController.text,
                accountType: _accountType,
                currentBalance: _balanceController.text.isNotEmpty
                    ? double.tryParse(_balanceController.text)
                    : null,
              );
              await DatabaseHelper.instance.createAccount(account.toMap());
              widget.onAccountAdded();
              if (mounted) Navigator.pop(context);
            }
          },
          style: ElevatedButton.styleFrom(),
          child: const Text('Add'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _balanceController.dispose();
    super.dispose();
  }
}
