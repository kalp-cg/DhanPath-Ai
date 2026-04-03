/// Base class for all failures in the application
/// Similar to Kotlin's sealed classes for error handling
abstract class Failure {
  final String message;
  final dynamic error;

  const Failure(this.message, [this.error]);

  @override
  String toString() => message;
}

/// Database operation failures
class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message, [super.error]);
}

/// Network operation failures
class NetworkFailure extends Failure {
  const NetworkFailure(super.message, [super.error]);
}

/// Validation failures
class ValidationFailure extends Failure {
  const ValidationFailure(super.message, [super.error]);
}

/// SMS parsing failures
class ParsingFailure extends Failure {
  const ParsingFailure(super.message, [super.error]);
}

/// Cache failures
class CacheFailure extends Failure {
  const CacheFailure(super.message, [super.error]);
}

/// Permission failures
class PermissionFailure extends Failure {
  const PermissionFailure(super.message, [super.error]);
}

/// Unknown/unexpected failures
class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message, [super.error]);
}
