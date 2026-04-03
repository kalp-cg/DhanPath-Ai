import '../../core/usecases/usecase.dart';
import '../../core/utils/result.dart';
import '../../models/transaction_model.dart';
import '../repositories/transaction_repository.dart';

/// Parameters for getting transactions between dates
class GetTransactionsBetweenDatesParams {
  final DateTime startDate;
  final DateTime endDate;

  GetTransactionsBetweenDatesParams({
    required this.startDate,
    required this.endDate,
  });
}

/// Use case for fetching transactions between dates
class GetTransactionsBetweenDatesUseCase
    implements UseCase<List<Transaction>, GetTransactionsBetweenDatesParams> {
  final TransactionRepository repository;

  GetTransactionsBetweenDatesUseCase(this.repository);

  @override
  Future<Result<List<Transaction>>> call(
    GetTransactionsBetweenDatesParams params,
  ) async {
    return await repository.getTransactionsBetweenDates(
      startDate: params.startDate,
      endDate: params.endDate,
    );
  }
}
