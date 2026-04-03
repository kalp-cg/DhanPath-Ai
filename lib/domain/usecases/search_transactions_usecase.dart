import '../../core/usecases/usecase.dart';
import '../../core/utils/result.dart';
import '../../models/transaction_model.dart';
import '../repositories/transaction_repository.dart';

/// Parameters for searching transactions
class SearchTransactionsParams {
  final String query;

  SearchTransactionsParams(this.query);
}

/// Use case for searching transactions
class SearchTransactionsUseCase
    implements UseCase<List<Transaction>, SearchTransactionsParams> {
  final TransactionRepository repository;

  SearchTransactionsUseCase(this.repository);

  @override
  Future<Result<List<Transaction>>> call(
    SearchTransactionsParams params,
  ) async {
    if (params.query.isEmpty) {
      // Return all transactions if query is empty
      return await repository.getAllTransactions();
    }

    return await repository.searchTransactions(params.query);
  }
}
