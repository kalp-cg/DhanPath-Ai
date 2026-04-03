import '../../models/transaction_model.dart';
import '../../core/utils/result.dart';

/// Repository interface for transaction operations
/// Defines the contract that implementations must follow
abstract class TransactionRepository {
  /// Get all transactions
  Future<Result<List<Transaction>>> getAllTransactions();

  /// Get transaction by ID
  Future<Result<Transaction>> getTransactionById(int id);

  /// Get transactions between dates
  Future<Result<List<Transaction>>> getTransactionsBetweenDates({
    required DateTime startDate,
    required DateTime endDate,
  });

  /// Get transactions filtered by type
  Future<Result<List<Transaction>>> getTransactionsByType(TransactionType type);

  /// Get transactions filtered by category
  Future<Result<List<Transaction>>> getTransactionsByCategory(String category);

  /// Search transactions by query
  Future<Result<List<Transaction>>> searchTransactions(String query);

  /// Insert a new transaction
  Future<Result<int>> insertTransaction(Transaction transaction);

  /// Update an existing transaction
  Future<Result<void>> updateTransaction(Transaction transaction);

  /// Delete a transaction (soft delete)
  Future<Result<void>> deleteTransaction(int id);

  /// Permanently delete a transaction
  Future<Result<void>> permanentlyDeleteTransaction(int id);

  /// Restore a deleted transaction
  Future<Result<void>> restoreTransaction(int id);

  /// Get all categories
  Future<Result<List<String>>> getAllCategories();

  /// Get all merchants
  Future<Result<List<String>>> getAllMerchants();

  /// Get total amount by type and period
  Future<Result<double>> getTotalAmountByTypeAndPeriod({
    required TransactionType type,
    required DateTime startDate,
    required DateTime endDate,
  });

  /// Get monthly breakdown
  Future<Result<Map<String, dynamic>>> getMonthlyBreakdown({
    required int year,
    required int month,
  });

  /// Get current month breakdown
  Future<Result<Map<String, dynamic>>> getCurrentMonthBreakdown();

  /// Check if transaction exists by hash
  Future<Result<bool>> transactionExistsByHash(String hash);

  /// Get transaction by hash (for duplicate detection)
  Future<Result<Transaction?>> getTransactionByHash(String hash);

  /// Time-based duplicate check: find if a same-amount/type transaction
  /// already exists within [window] of [transactionDate].
  /// Used to deduplicate double SMS notifications from the same bank.
  Future<Result<bool>> existsSimilarTransaction({
    required double amount,
    required TransactionType type,
    required DateTime transactionDate,
    Duration window = const Duration(minutes: 2),
  });

  /// Batch insert transactions
  Future<Result<void>> batchInsertTransactions(List<Transaction> transactions);

  /// Add transaction (alias for insertTransaction with different return type handling)
  Future<Result<int>> addTransaction(Transaction transaction) =>
      insertTransaction(transaction);
}
