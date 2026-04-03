import '../../core/usecases/usecase.dart';
import '../../core/utils/result.dart';
import '../repositories/transaction_repository.dart';

/// Parameters for deleting a transaction
class DeleteTransactionParams {
  final int transactionId;
  final bool permanent;

  DeleteTransactionParams({
    required this.transactionId,
    this.permanent = false,
  });
}

/// Use case for deleting a transaction
class DeleteTransactionUseCase
    implements UseCase<void, DeleteTransactionParams> {
  final TransactionRepository repository;

  DeleteTransactionUseCase(this.repository);

  @override
  Future<Result<void>> call(DeleteTransactionParams params) async {
    if (params.permanent) {
      return await repository.permanentlyDeleteTransaction(
        params.transactionId,
      );
    } else {
      return await repository.deleteTransaction(params.transactionId);
    }
  }
}
