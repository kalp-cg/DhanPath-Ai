import 'package:flutter_test/flutter_test.dart';
import 'package:dhanpath/core/error/failures.dart';
import 'package:dhanpath/core/utils/result.dart';
import 'package:dhanpath/models/transaction_model.dart';
import 'package:dhanpath/domain/repositories/transaction_repository.dart';
import 'package:dhanpath/domain/usecases/get_all_transactions_usecase.dart';

// Mock repository for testing
class MockTransactionRepository implements TransactionRepository {
  List<Transaction> mockTransactions = [];
  bool shouldFail = false;

  @override
  Future<Result<List<Transaction>>> getAllTransactions() async {
    if (shouldFail) {
      return const ResultFailure(DatabaseFailure('Database error'));
    }
    return Success(mockTransactions);
  }

  @override
  Future<Result<Transaction>> getTransactionById(int id) async {
    if (shouldFail) {
      return const ResultFailure(DatabaseFailure('Database error'));
    }
    final transaction = mockTransactions.where((t) => t.id == id).firstOrNull;
    if (transaction == null) {
      return const ResultFailure(DatabaseFailure('Transaction not found'));
    }
    return Success(transaction);
  }

  @override
  Future<Result<int>> insertTransaction(Transaction transaction) async {
    if (shouldFail) {
      return const ResultFailure(DatabaseFailure('Insert failed'));
    }
    mockTransactions.add(transaction);
    return const Success(1);
  }

  @override
  Future<Result<void>> deleteTransaction(int id) async {
    if (shouldFail) {
      return const ResultFailure(DatabaseFailure('Delete failed'));
    }
    mockTransactions.removeWhere((t) => t.id == id);
    return const Success(null);
  }

  // Implement other methods with minimal implementation
  @override
  Future<Result<List<Transaction>>> getTransactionsBetweenDates({
    required DateTime startDate,
    required DateTime endDate,
  }) async => Success(mockTransactions);

  @override
  Future<Result<List<Transaction>>> getTransactionsByType(
    TransactionType type,
  ) async => Success(mockTransactions.where((t) => t.type == type).toList());

  @override
  Future<Result<List<Transaction>>> getTransactionsByCategory(
    String category,
  ) async =>
      Success(mockTransactions.where((t) => t.category == category).toList());

  @override
  Future<Result<List<Transaction>>> searchTransactions(String query) async =>
      Success(
        mockTransactions.where((t) => t.merchantName.contains(query)).toList(),
      );

  @override
  Future<Result<void>> updateTransaction(Transaction transaction) async =>
      const Success(null);

  @override
  Future<Result<void>> permanentlyDeleteTransaction(int id) async =>
      const Success(null);

  @override
  Future<Result<void>> restoreTransaction(int id) async => const Success(null);

  @override
  Future<Result<List<String>>> getAllCategories() async =>
      Success(mockTransactions.map((t) => t.category).toSet().toList());

  @override
  Future<Result<List<String>>> getAllMerchants() async =>
      Success(mockTransactions.map((t) => t.merchantName).toSet().toList());

  @override
  Future<Result<double>> getTotalAmountByTypeAndPeriod({
    required TransactionType type,
    required DateTime startDate,
    required DateTime endDate,
  }) async => const Success(0.0);

  @override
  Future<Result<Map<String, dynamic>>> getMonthlyBreakdown({
    required int year,
    required int month,
  }) async => Success({});

  @override
  Future<Result<Map<String, dynamic>>> getCurrentMonthBreakdown() async =>
      Success({});

  @override
  Future<Result<bool>> transactionExistsByHash(String hash) async =>
      const Success(false);

  @override
  Future<Result<void>> batchInsertTransactions(
    List<Transaction> transactions,
  ) async => const Success(null);

  @override
  Future<Result<Transaction?>> getTransactionByHash(String hash) async =>
      const Success(null);

  @override
  Future<Result<int>> addTransaction(Transaction transaction) async =>
      insertTransaction(transaction);
}

void main() {
  group('GetAllTransactionsUseCase', () {
    late MockTransactionRepository mockRepository;
    late GetAllTransactionsUseCase useCase;

    setUp(() {
      mockRepository = MockTransactionRepository();
      useCase = GetAllTransactionsUseCase(mockRepository);
    });

    test('should return empty list when no transactions', () async {
      // Arrange
      mockRepository.mockTransactions = [];

      // Act
      final result = await useCase.call();

      // Assert
      expect(result.isSuccess, true);
      expect(result.value, isEmpty);
    });

    test('should return list of transactions when available', () async {
      // Arrange
      final mockTransactions = [
        Transaction(
          id: 1,
          amount: 100.0,
          merchantName: 'Test Merchant',
          category: 'Food',
          type: TransactionType.expense,
          date: DateTime.now(),
          isRecurring: false,
          isDeleted: false,
        ),
        Transaction(
          id: 2,
          amount: 200.0,
          merchantName: 'Another Merchant',
          category: 'Shopping',
          type: TransactionType.expense,
          date: DateTime.now(),
          isRecurring: false,
          isDeleted: false,
        ),
      ];
      mockRepository.mockTransactions = mockTransactions;

      // Act
      final result = await useCase.call();

      // Assert
      expect(result.isSuccess, true);
      expect(result.value.length, 2);
      expect(result.value[0].merchantName, 'Test Merchant');
      expect(result.value[1].merchantName, 'Another Merchant');
    });

    test('should return failure when repository fails', () async {
      // Arrange
      mockRepository.shouldFail = true;

      // Act
      final result = await useCase.call();

      // Assert
      expect(result.isFailure, true);
      expect(result.failureOrNull, isA<DatabaseFailure>());
    });
  });

  group('Result Extensions', () {
    test('should map success value correctly', () {
      // Arrange
      const result = Success(10);

      // Act
      final mapped = result.map((value) => value * 2);

      // Assert
      expect(mapped.isSuccess, true);
      expect(mapped.value, 20);
    });

    test('should not map failure', () {
      // Arrange
      const result = ResultFailure<int>(DatabaseFailure('Error'));

      // Act
      final mapped = result.map((value) => value * 2);

      // Assert
      expect(mapped.isFailure, true);
    });

    test('should fold correctly for success', () {
      // Arrange
      const result = Success(10);

      // Act
      final value = result.fold(
        (failure) => 'Failed',
        (value) => 'Success: $value',
      );

      // Assert
      expect(value, 'Success: 10');
    });

    test('should fold correctly for failure', () {
      // Arrange
      const result = ResultFailure<int>(DatabaseFailure('Database error'));

      // Act
      final value = result.fold(
        (failure) => 'Failed: ${failure.message}',
        (value) => 'Success: $value',
      );

      // Assert
      expect(value, 'Failed: Database error');
    });
  });
}
