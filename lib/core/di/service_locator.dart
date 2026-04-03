import '../../services/database_helper.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../data/repositories/transaction_repository_impl.dart';
import '../../domain/usecases/get_all_transactions_usecase.dart';
import '../../domain/usecases/get_transactions_between_dates_usecase.dart';
import '../../domain/usecases/add_transaction_usecase.dart';
import '../../domain/usecases/get_current_month_breakdown_usecase.dart';
import '../../domain/usecases/search_transactions_usecase.dart';
import '../../domain/usecases/delete_transaction_usecase.dart';
import '../sms_transaction_processor.dart';

/// Service Locator for Dependency Injection
/// Similar to Hilt in Kotlin - provides singleton instances
class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();

  factory ServiceLocator() => _instance;

  ServiceLocator._internal();

  // Cache for singleton instances
  final Map<Type, dynamic> _singletons = {};

  // ========== Data Layer ==========

  /// Get DatabaseHelper singleton
  DatabaseHelper get databaseHelper {
    return _singletons.putIfAbsent(
      DatabaseHelper,
      () => DatabaseHelper.instance,
    );
  }

  // ========== Repositories ==========

  /// Get TransactionRepository singleton
  TransactionRepository get transactionRepository {
    return _singletons.putIfAbsent(
      TransactionRepository,
      () => TransactionRepositoryImpl(databaseHelper),
    );
  }

  // ========== Use Cases ==========

  /// Get GetAllTransactionsUseCase
  GetAllTransactionsUseCase get getAllTransactionsUseCase {
    return _singletons.putIfAbsent(
      GetAllTransactionsUseCase,
      () => GetAllTransactionsUseCase(transactionRepository),
    );
  }

  /// Get GetTransactionsBetweenDatesUseCase
  GetTransactionsBetweenDatesUseCase get getTransactionsBetweenDatesUseCase {
    return _singletons.putIfAbsent(
      GetTransactionsBetweenDatesUseCase,
      () => GetTransactionsBetweenDatesUseCase(transactionRepository),
    );
  }

  /// Get AddTransactionUseCase
  AddTransactionUseCase get addTransactionUseCase {
    return _singletons.putIfAbsent(
      AddTransactionUseCase,
      () => AddTransactionUseCase(transactionRepository),
    );
  }

  /// Get GetCurrentMonthBreakdownUseCase
  GetCurrentMonthBreakdownUseCase get getCurrentMonthBreakdownUseCase {
    return _singletons.putIfAbsent(
      GetCurrentMonthBreakdownUseCase,
      () => GetCurrentMonthBreakdownUseCase(transactionRepository),
    );
  }

  /// Get SearchTransactionsUseCase
  SearchTransactionsUseCase get searchTransactionsUseCase {
    return _singletons.putIfAbsent(
      SearchTransactionsUseCase,
      () => SearchTransactionsUseCase(transactionRepository),
    );
  }

  /// Get DeleteTransactionUseCase
  DeleteTransactionUseCase get deleteTransactionUseCase {
    return _singletons.putIfAbsent(
      DeleteTransactionUseCase,
      () => DeleteTransactionUseCase(transactionRepository),
    );
  }

  // ========== SMS Processing ==========

  /// Get SmsTransactionProcessor singleton
  SmsTransactionProcessor get smsTransactionProcessor {
    return _singletons.putIfAbsent(
      SmsTransactionProcessor,
      () => SmsTransactionProcessor(transactionRepository),
    );
  }

  /// Reset all dependencies (useful for testing)
  void reset() {
    _singletons.clear();
  }

  /// Register a custom instance (useful for testing with mocks)
  void registerSingleton<T>(T instance) {
    _singletons[T] = instance;
  }
}

/// Global instance for easy access
final serviceLocator = ServiceLocator();
