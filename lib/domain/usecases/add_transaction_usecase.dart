import '../../core/usecases/usecase.dart';
import '../../core/utils/result.dart';
import '../../models/transaction_model.dart';
import '../repositories/transaction_repository.dart';

/// Use case for adding a new transaction
class AddTransactionUseCase implements UseCase<int, Transaction> {
  final TransactionRepository repository;

  AddTransactionUseCase(this.repository);

  @override
  Future<Result<int>> call(Transaction params) async {
    // Generate transaction hash if not present
    if (params.transactionHash == null || params.transactionHash!.isEmpty) {
      final hash = _generateTransactionHash(params);
      final transactionWithHash = Transaction(
        id: params.id,
        amount: params.amount,
        merchantName: params.merchantName,
        category: params.category,
        type: params.type,
        date: params.date,
        description: params.description,
        smsBody: params.smsBody,
        bankName: params.bankName,
        accountNumber: params.accountNumber,
        isRecurring: params.isRecurring,
        isDeleted: params.isDeleted,
        reference: params.reference,
        balance: params.balance,
        creditLimit: params.creditLimit,
        isFromCard: params.isFromCard,
        currency: params.currency,
        fromAccount: params.fromAccount,
        toAccount: params.toAccount,
        transactionHash: hash,
      );

      return await repository.insertTransaction(transactionWithHash);
    }

    return await repository.insertTransaction(params);
  }

  String _generateTransactionHash(Transaction transaction) {
    // Add microseconds AND a random salt to ensure uniqueness for manual transactions
    // This prevents duplicate hash issues when adding multiple transactions quickly
    final String hashString =
        '${transaction.amount}_'
        '${transaction.merchantName}_'
        '${transaction.date.microsecondsSinceEpoch}_' // Use microseconds instead of milliseconds
        '${transaction.accountNumber ?? ""}_'
        '${DateTime.now().microsecondsSinceEpoch}'; // Add current time as salt for uniqueness

    return hashString.hashCode.toString();
  }
}
