import 'package:sqflite/sqflite.dart' hide Transaction;
import '../../domain/repositories/transaction_repository.dart';
import '../../models/transaction_model.dart';
import '../../services/database_helper.dart';
import '../../core/utils/result.dart';
import '../../core/error/failures.dart';

/// Implementation of TransactionRepository using SQLite
class TransactionRepositoryImpl implements TransactionRepository {
  final DatabaseHelper _databaseHelper;

  TransactionRepositoryImpl(this._databaseHelper);

  @override
  Future<Result<List<Transaction>>> getAllTransactions() async {
    try {
      final db = await _databaseHelper.database;
      final results = await db.query(
        'transactions',
        where: 'is_deleted = 0',
        orderBy: 'date DESC',
      );

      final transactions = results
          .map((map) => Transaction.fromMap(map))
          .toList();

      return Success(transactions);
    } catch (e) {
      return ResultFailure(
        DatabaseFailure('Failed to fetch transactions: $e', e),
      );
    }
  }

  @override
  Future<Result<Transaction>> getTransactionById(int id) async {
    try {
      final db = await _databaseHelper.database;
      final results = await db.query(
        'transactions',
        where: 'id = ? AND is_deleted = 0',
        whereArgs: [id],
        limit: 1,
      );

      if (results.isEmpty) {
        return ResultFailure(DatabaseFailure('Transaction not found'));
      }

      return Success(Transaction.fromMap(results.first));
    } catch (e) {
      return ResultFailure(
        DatabaseFailure('Failed to fetch transaction: $e', e),
      );
    }
  }

  @override
  Future<Result<List<Transaction>>> getTransactionsBetweenDates({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final db = await _databaseHelper.database;
      final results = await db.query(
        'transactions',
        where: 'date BETWEEN ? AND ? AND is_deleted = 0',
        whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
        orderBy: 'date DESC',
      );

      final transactions = results
          .map((map) => Transaction.fromMap(map))
          .toList();

      return Success(transactions);
    } catch (e) {
      return ResultFailure(
        DatabaseFailure('Failed to fetch transactions by date: $e', e),
      );
    }
  }

  @override
  Future<Result<List<Transaction>>> getTransactionsByType(
    TransactionType type,
  ) async {
    try {
      final db = await _databaseHelper.database;
      final results = await db.query(
        'transactions',
        where: 'type = ? AND is_deleted = 0',
        whereArgs: [type.toString().split('.').last],
        orderBy: 'date DESC',
      );

      final transactions = results
          .map((map) => Transaction.fromMap(map))
          .toList();

      return Success(transactions);
    } catch (e) {
      return ResultFailure(
        DatabaseFailure('Failed to fetch transactions by type: $e', e),
      );
    }
  }

  @override
  Future<Result<List<Transaction>>> getTransactionsByCategory(
    String category,
  ) async {
    try {
      final db = await _databaseHelper.database;
      final results = await db.query(
        'transactions',
        where: 'category = ? AND is_deleted = 0',
        whereArgs: [category],
        orderBy: 'date DESC',
      );

      final transactions = results
          .map((map) => Transaction.fromMap(map))
          .toList();

      return Success(transactions);
    } catch (e) {
      return ResultFailure(
        DatabaseFailure('Failed to fetch transactions by category: $e', e),
      );
    }
  }

  @override
  Future<Result<List<Transaction>>> searchTransactions(String query) async {
    try {
      final db = await _databaseHelper.database;
      final searchPattern = '%$query%';
      final results = await db.query(
        'transactions',
        where: '''
          (merchant_name LIKE ? OR 
           category LIKE ? OR 
           description LIKE ?) 
          AND is_deleted = 0
        ''',
        whereArgs: [searchPattern, searchPattern, searchPattern],
        orderBy: 'date DESC',
      );

      final transactions = results
          .map((map) => Transaction.fromMap(map))
          .toList();

      return Success(transactions);
    } catch (e) {
      return ResultFailure(
        DatabaseFailure('Failed to search transactions: $e', e),
      );
    }
  }

  @override
  Future<Result<int>> insertTransaction(Transaction transaction) async {
    try {
      await _databaseHelper.upsertAccountFromTransaction(transaction);

      final db = await _databaseHelper.database;
      final id = await db.insert(
        'transactions',
        transaction.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      return Success(id);
    } catch (e) {
      return ResultFailure(
        DatabaseFailure('Failed to insert transaction: $e', e),
      );
    }
  }

  @override
  Future<Result<void>> updateTransaction(Transaction transaction) async {
    try {
      final db = await _databaseHelper.database;
      await db.update(
        'transactions',
        transaction.toMap(),
        where: 'id = ?',
        whereArgs: [transaction.id],
      );

      return const Success(null);
    } catch (e) {
      return ResultFailure(
        DatabaseFailure('Failed to update transaction: $e', e),
      );
    }
  }

  @override
  Future<Result<void>> deleteTransaction(int id) async {
    try {
      final db = await _databaseHelper.database;
      await db.update(
        'transactions',
        {'is_deleted': 1},
        where: 'id = ?',
        whereArgs: [id],
      );

      return const Success(null);
    } catch (e) {
      return ResultFailure(
        DatabaseFailure('Failed to delete transaction: $e', e),
      );
    }
  }

  @override
  Future<Result<void>> permanentlyDeleteTransaction(int id) async {
    try {
      final db = await _databaseHelper.database;
      await db.delete('transactions', where: 'id = ?', whereArgs: [id]);

      return const Success(null);
    } catch (e) {
      return ResultFailure(
        DatabaseFailure('Failed to permanently delete transaction: $e', e),
      );
    }
  }

  @override
  Future<Result<void>> restoreTransaction(int id) async {
    try {
      final db = await _databaseHelper.database;
      await db.update(
        'transactions',
        {'is_deleted': 0},
        where: 'id = ?',
        whereArgs: [id],
      );

      return const Success(null);
    } catch (e) {
      return ResultFailure(
        DatabaseFailure('Failed to restore transaction: $e', e),
      );
    }
  }

  @override
  Future<Result<List<String>>> getAllCategories() async {
    try {
      final db = await _databaseHelper.database;
      final results = await db.query(
        'transactions',
        columns: ['DISTINCT category'],
        where: 'is_deleted = 0',
        orderBy: 'category',
      );

      final categories = results
          .map((map) => map['category'] as String)
          .toList();

      return Success(categories);
    } catch (e) {
      return ResultFailure(
        DatabaseFailure('Failed to fetch categories: $e', e),
      );
    }
  }

  @override
  Future<Result<List<String>>> getAllMerchants() async {
    try {
      final db = await _databaseHelper.database;
      final results = await db.query(
        'transactions',
        columns: ['DISTINCT merchant_name'],
        where: 'is_deleted = 0',
        orderBy: 'merchant_name',
      );

      final merchants = results
          .map((map) => map['merchant_name'] as String)
          .toList();

      return Success(merchants);
    } catch (e) {
      return ResultFailure(DatabaseFailure('Failed to fetch merchants: $e', e));
    }
  }

  @override
  Future<Result<double>> getTotalAmountByTypeAndPeriod({
    required TransactionType type,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final db = await _databaseHelper.database;
      final result = await db.rawQuery(
        '''
        SELECT SUM(amount) as total
        FROM transactions
        WHERE type = ?
          AND date BETWEEN ? AND ?
          AND is_deleted = 0
      ''',
        [
          type.toString().split('.').last,
          startDate.toIso8601String(),
          endDate.toIso8601String(),
        ],
      );

      final total = result.first['total'] as double? ?? 0.0;
      return Success(total);
    } catch (e) {
      return ResultFailure(
        DatabaseFailure('Failed to calculate total amount: $e', e),
      );
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> getMonthlyBreakdown({
    required int year,
    required int month,
  }) async {
    try {
      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 0, 23, 59, 59);

      final db = await _databaseHelper.database;
      final results = await db.query(
        'transactions',
        where: 'date BETWEEN ? AND ? AND is_deleted = 0',
        whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
      );

      final transactions = results
          .map((map) => Transaction.fromMap(map))
          .toList();

      double totalIncome = 0;
      double totalExpense = 0;
      double totalCredit = 0;

      for (var transaction in transactions) {
        switch (transaction.type) {
          case TransactionType.income:
            totalIncome += transaction.amount;
            break;
          case TransactionType.expense:
            totalExpense += transaction.amount;
            break;
          case TransactionType.credit:
            totalCredit += transaction.amount;
            break;
          default:
            break;
        }
      }

      return Success({
        'totalIncome': totalIncome,
        'totalExpense': totalExpense,
        'totalCredit': totalCredit,
        'balance': totalIncome - totalExpense,
        'transactionCount': transactions.length,
      });
    } catch (e) {
      return ResultFailure(
        DatabaseFailure('Failed to get monthly breakdown: $e', e),
      );
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> getCurrentMonthBreakdown() async {
    final now = DateTime.now();
    return getMonthlyBreakdown(year: now.year, month: now.month);
  }

  @override
  Future<Result<bool>> transactionExistsByHash(String hash) async {
    try {
      final db = await _databaseHelper.database;
      final results = await db.query(
        'transactions',
        where: 'transaction_hash = ?',
        whereArgs: [hash],
        limit: 1,
      );

      return Success(results.isNotEmpty);
    } catch (e) {
      return ResultFailure(
        DatabaseFailure('Failed to check transaction existence: $e', e),
      );
    }
  }

  @override
  Future<Result<Transaction?>> getTransactionByHash(String hash) async {
    try {
      final db = await _databaseHelper.database;
      final results = await db.query(
        'transactions',
        where: 'transaction_hash = ?',
        whereArgs: [hash],
        limit: 1,
      );

      if (results.isEmpty) {
        return const Success(null);
      }

      return Success(Transaction.fromMap(results.first));
    } catch (e) {
      return ResultFailure(
        DatabaseFailure('Failed to get transaction by hash: $e', e),
      );
    }
  }

  @override
  Future<Result<bool>> existsSimilarTransaction({
    required double amount,
    required TransactionType type,
    required DateTime transactionDate,
    Duration window = const Duration(minutes: 2),
  }) async {
    try {
      final db = await _databaseHelper.database;
      final from = transactionDate.subtract(window).toIso8601String();
      final to = transactionDate.add(window).toIso8601String();
      final typeStr = type.toString().split('.').last;

      final results = await db.query(
        'transactions',
        where:
            'amount = ? AND type = ? AND date BETWEEN ? AND ? AND is_deleted = 0',
        whereArgs: [amount, typeStr, from, to],
        limit: 1,
      );

      return Success(results.isNotEmpty);
    } catch (e) {
      return ResultFailure(
        DatabaseFailure('Failed to check similar transaction: $e', e),
      );
    }
  }

  @override
  Future<Result<void>> batchInsertTransactions(
    List<Transaction> transactions,
  ) async {
    try {
      final db = await _databaseHelper.database;
      final batch = db.batch();

      for (var transaction in transactions) {
        await _databaseHelper.upsertAccountFromTransaction(transaction);
        batch.insert(
          'transactions',
          transaction.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      await batch.commit(noResult: true);
      return const Success(null);
    } catch (e) {
      return ResultFailure(
        DatabaseFailure('Failed to batch insert transactions: $e', e),
      );
    }
  }

  @override
  Future<Result<int>> addTransaction(Transaction transaction) {
    return insertTransaction(transaction);
  }
}
