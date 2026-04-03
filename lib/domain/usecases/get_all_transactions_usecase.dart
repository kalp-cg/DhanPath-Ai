import '../../core/usecases/usecase.dart';
import '../../core/utils/result.dart';
import '../../models/transaction_model.dart';
import '../repositories/transaction_repository.dart';

/// Use case for fetching all transactions
class GetAllTransactionsUseCase implements NoParamsUseCase<List<Transaction>> {
  final TransactionRepository repository;

  GetAllTransactionsUseCase(this.repository);

  @override
  Future<Result<List<Transaction>>> call() async {
    return await repository.getAllTransactions();
  }
}
