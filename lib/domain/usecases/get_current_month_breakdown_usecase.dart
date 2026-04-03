import '../../core/usecases/usecase.dart';
import '../../core/utils/result.dart';
import '../repositories/transaction_repository.dart';

/// Use case for getting current month breakdown
class GetCurrentMonthBreakdownUseCase
    implements NoParamsUseCase<Map<String, dynamic>> {
  final TransactionRepository repository;

  GetCurrentMonthBreakdownUseCase(this.repository);

  @override
  Future<Result<Map<String, dynamic>>> call() async {
    return await repository.getCurrentMonthBreakdown();
  }
}
