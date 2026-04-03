import '../error/failures.dart' as failures;

/// Result type for handling success/failure cases
/// Similar to Kotlin's Result or Either monad
sealed class Result<T> {
  const Result();
}

/// Success case containing the value
class Success<T> extends Result<T> {
  final T value;

  const Success(this.value);

  @override
  String toString() => 'Success($value)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<T> &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// Failure case containing the error
class ResultFailure<T> extends Result<T> {
  final failures.Failure failure;

  const ResultFailure(this.failure);

  @override
  String toString() => 'Failure($failure)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResultFailure<T> &&
          runtimeType == other.runtimeType &&
          failure == other.failure;

  @override
  int get hashCode => failure.hashCode;
}

/// Extension methods for Result
extension ResultExtensions<T> on Result<T> {
  /// Returns true if this is a Success
  bool get isSuccess => this is Success<T>;

  /// Returns true if this is a Failure
  bool get isFailure => this is ResultFailure<T>;

  /// Gets the value if Success, throws if Failure
  T get value {
    if (this is Success<T>) {
      return (this as Success<T>).value;
    }
    throw Exception('Called value on a Failure');
  }

  /// Gets the value if Success, returns null if Failure
  T? get valueOrNull {
    if (this is Success<T>) {
      return (this as Success<T>).value;
    }
    return null;
  }

  /// Gets the failure if Failure, returns null if Success
  failures.Failure? get failureOrNull {
    if (this is ResultFailure<T>) {
      return (this as ResultFailure<T>).failure;
    }
    return null;
  }

  /// Transforms the value if Success
  Result<R> map<R>(R Function(T) transform) {
    if (this is Success<T>) {
      try {
        return Success(transform((this as Success<T>).value));
      } catch (e) {
        return ResultFailure(
          failures.UnexpectedFailure('Error during transformation: $e', e),
        );
      }
    }
    return ResultFailure((this as ResultFailure<T>).failure);
  }

  /// Flat maps the value if Success
  Result<R> flatMap<R>(Result<R> Function(T) transform) {
    if (this is Success<T>) {
      try {
        return transform((this as Success<T>).value);
      } catch (e) {
        return ResultFailure(
          failures.UnexpectedFailure('Error during flat transformation: $e', e),
        );
      }
    }
    return ResultFailure((this as ResultFailure<T>).failure);
  }

  /// Executes one of the functions based on the result
  R fold<R>(R Function(failures.Failure) onFailure, R Function(T) onSuccess) {
    if (this is Success<T>) {
      return onSuccess((this as Success<T>).value);
    }
    return onFailure((this as ResultFailure<T>).failure);
  }
}
