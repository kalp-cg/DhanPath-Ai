import 'parsers/bank_parser_factory.dart';
import 'utils/result.dart';
import '../domain/repositories/transaction_repository.dart';
import '../models/transaction_model.dart';

/// Result of SMS processing
class ProcessingResult {
  final bool success;
  final int? transactionId;
  final String? errorMessage;
  final ProcessingStatus status;

  ProcessingResult.success(this.transactionId)
    : success = true,
      errorMessage = null,
      status = ProcessingStatus.success;

  ProcessingResult.duplicate()
    : success = false,
      transactionId = null,
      errorMessage = 'Duplicate transaction',
      status = ProcessingStatus.duplicate;

  ProcessingResult.notTransaction()
    : success = false,
      transactionId = null,
      errorMessage = 'Not a transaction SMS',
      status = ProcessingStatus.notTransaction;

  ProcessingResult.parseError(String message)
    : success = false,
      transactionId = null,
      errorMessage = message,
      status = ProcessingStatus.parseError;

  ProcessingResult.error(String message)
    : success = false,
      transactionId = null,
      errorMessage = message,
      status = ProcessingStatus.error;
}

enum ProcessingStatus { success, duplicate, notTransaction, parseError, error }

/// SMS Transaction Processor
/// Handles parsing, duplicate detection, and storing transactions
class SmsTransactionProcessor {
  final TransactionRepository _repository;

  SmsTransactionProcessor(this._repository);

  /// Process a single SMS message
  Future<ProcessingResult> processSms({
    required String sender,
    required String body,
    required int timestamp,
  }) async {
    try {
      // Step 1: Parse SMS using BankParserFactory
      final parsedTransaction = BankParserFactory.parseTransaction(
        body,
        sender,
        timestamp,
      );

      if (parsedTransaction == null) {
        return ProcessingResult.notTransaction();
      }

      // Step 2: Generate transaction hash for duplicate detection
      final transactionHash = parsedTransaction.generateHash();

      // Step 3a: Check for duplicate by hash
      final isDuplicate = await _checkDuplicate(transactionHash);
      if (isDuplicate) {
        return ProcessingResult.duplicate();
      }

      // Step 3b: Time-based duplicate guard.
      // Banks (e.g. BGGB) often send two different SMS for the same debit -
      // one with VPA details and one with balance. The hashes differ because
      // merchant/account fields vary, so we check for an existing transaction
      // with the same amount and type within a 2-minute window.
      final transactionDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final isSimilarDuplicate = await _checkTimeDuplicate(
        amount: parsedTransaction.amount,
        type: parsedTransaction.type,
        transactionDate: transactionDate,
      );
      if (isSimilarDuplicate) {
        return ProcessingResult.duplicate();
      }

      // Step 4: Convert to Transaction model
      final transaction = parsedTransaction.toTransaction();

      // Step 5: Apply smart categorization
      final categorizedTransaction = await _applyCategorization(transaction);

      // Step 6: Save to database
      final result = await _repository.addTransaction(categorizedTransaction);

      return result.fold(
        (failure) => ProcessingResult.error(failure.message),
        (transactionId) => ProcessingResult.success(transactionId),
      );
    } catch (e) {
      return ProcessingResult.error('Processing error: $e');
    }
  }

  /// Process multiple SMS messages with progress callback
  Future<BatchProcessingResult> processBatch({
    required List<SmsMessageData> messages,
    Function(int processed, int total)? onProgress,
  }) async {
    int successCount = 0;
    int duplicateCount = 0;
    int errorCount = 0;
    int notTransactionCount = 0;
    final List<int> transactionIds = [];

    for (int i = 0; i < messages.length; i++) {
      final sms = messages[i];
      final result = await processSms(
        sender: sms.sender,
        body: sms.body,
        timestamp: sms.timestamp,
      );

      switch (result.status) {
        case ProcessingStatus.success:
          successCount++;
          if (result.transactionId != null) {
            transactionIds.add(result.transactionId!);
          }
          break;
        case ProcessingStatus.duplicate:
          duplicateCount++;
          break;
        case ProcessingStatus.notTransaction:
          notTransactionCount++;
          break;
        case ProcessingStatus.parseError:
        case ProcessingStatus.error:
          errorCount++;
          break;
      }

      // Report progress
      onProgress?.call(i + 1, messages.length);
    }

    return BatchProcessingResult(
      total: messages.length,
      successCount: successCount,
      duplicateCount: duplicateCount,
      errorCount: errorCount,
      notTransactionCount: notTransactionCount,
      transactionIds: transactionIds,
    );
  }

  /// Check if transaction hash already exists (duplicate detection)
  Future<bool> _checkDuplicate(String transactionHash) async {
    final result = await _repository.getTransactionByHash(transactionHash);
    return result.fold(
      (_) => false, // If error checking, assume not duplicate
      (transaction) => transaction != null,
    );
  }

  /// Time-based duplicate guard: returns true if a transaction with the same
  /// amount and type already exists within a 2-minute window around [transactionDate].
  /// This catches cases where a bank sends two different SMS for the same event
  /// (e.g., one with VPA details and another with balance info) whose hashes differ.
  Future<bool> _checkTimeDuplicate({
    required double amount,
    required TransactionType type,
    required DateTime transactionDate,
  }) async {
    final result = await _repository.existsSimilarTransaction(
      amount: amount,
      type: type,
      transactionDate: transactionDate,
    );
    return result.fold(
      (_) => false, // On error, assume not duplicate
      (exists) => exists,
    );
  }

  /// Apply smart categorization based on merchant and patterns
  Future<Transaction> _applyCategorization(Transaction transaction) async {
    // If already has a specific category, keep it
    if (transaction.category != 'Expense' &&
        transaction.category != 'Income' &&
        transaction.category != 'Credit Card') {
      return transaction;
    }

    // Apply category rules based on merchant
    final merchantLower = transaction.merchantName.toLowerCase();
    final bodyLower = (transaction.smsBody ?? '').toLowerCase();

    // Category mapping
    final categoryMap = {
      'Food & Dining': [
        'swiggy',
        'zomato',
        'restaurant',
        'cafe',
        'food',
        'dominos',
        'pizza',
        'mcdonald',
        'kfc',
      ],
      'Transportation': [
        'uber',
        'ola',
        'rapido',
        'metro',
        'petrol',
        'fuel',
        'parking',
        'fastag',
      ],
      'Shopping': ['amazon', 'flipkart', 'myntra', 'ajio', 'mall', 'store'],
      'Entertainment': [
        'netflix',
        'prime',
        'hotstar',
        'spotify',
        'movie',
        'cinema',
      ],
      'Utilities': [
        'electricity',
        'water',
        'gas',
        'internet',
        'broadband',
        'mobile',
        'recharge',
      ],
      'Healthcare': ['hospital', 'pharmacy', 'medical', 'doctor', 'apollo'],
      'Banking': ['atm', 'transfer', 'upi', 'imps', 'neft'],
    };

    for (final entry in categoryMap.entries) {
      for (final keyword in entry.value) {
        if (merchantLower.contains(keyword) || bodyLower.contains(keyword)) {
          return Transaction(
            id: transaction.id,
            amount: transaction.amount,
            merchantName: transaction.merchantName,
            category: entry.key,
            type: transaction.type,
            date: transaction.date,
            description: transaction.description,
            smsBody: transaction.smsBody,
            bankName: transaction.bankName,
            accountNumber: transaction.accountNumber,
            isRecurring: transaction.isRecurring,
            isDeleted: transaction.isDeleted,
            reference: transaction.reference,
            balance: transaction.balance,
            creditLimit: transaction.creditLimit,
            isFromCard: transaction.isFromCard,
            currency: transaction.currency,
            fromAccount: transaction.fromAccount,
            toAccount: transaction.toAccount,
            transactionHash: transaction.transactionHash,
          );
        }
      }
    }

    return transaction;
  }

  /// Get statistics about processed transactions
  Future<ProcessingStats> getStats() async {
    final allTransactionsResult = await _repository.getAllTransactions();

    return allTransactionsResult.fold(
      (_) => ProcessingStats(
        totalTransactions: 0,
        uniqueBanks: 0,
        duplicatesDetected: 0,
      ),
      (transactions) {
        final uniqueBanks = transactions.map((t) => t.bankName).toSet().length;
        return ProcessingStats(
          totalTransactions: transactions.length,
          uniqueBanks: uniqueBanks,
          duplicatesDetected: 0, // Would need separate tracking
        );
      },
    );
  }
}

/// SMS message model
class SmsMessageData {
  final String sender;
  final String body;
  final int timestamp;

  SmsMessageData({
    required this.sender,
    required this.body,
    required this.timestamp,
  });

  factory SmsMessageData.fromMap(Map<String, dynamic> map) {
    return SmsMessageData(
      sender: map['sender'] as String,
      body: map['body'] as String,
      timestamp: map['timestamp'] as int,
    );
  }
}

/// Result of batch processing
class BatchProcessingResult {
  final int total;
  final int successCount;
  final int duplicateCount;
  final int errorCount;
  final int notTransactionCount;
  final List<int> transactionIds;

  BatchProcessingResult({
    required this.total,
    required this.successCount,
    required this.duplicateCount,
    required this.errorCount,
    required this.notTransactionCount,
    required this.transactionIds,
  });

  int get processedCount =>
      successCount + duplicateCount + errorCount + notTransactionCount;

  double get successRate => total > 0 ? (successCount / total) * 100 : 0;

  @override
  String toString() {
    return 'BatchProcessingResult(total: $total, success: $successCount, '
        'duplicates: $duplicateCount, errors: $errorCount, '
        'non-transactions: $notTransactionCount)';
  }
}

/// Processing statistics
class ProcessingStats {
  final int totalTransactions;
  final int uniqueBanks;
  final int duplicatesDetected;

  ProcessingStats({
    required this.totalTransactions,
    required this.uniqueBanks,
    required this.duplicatesDetected,
  });
}
