/// Failures every backend implementation must report with these types so
/// that UI code can react the same way regardless of the server in use.
sealed class MatchingException implements Exception {
  const MatchingException(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Input was rejected (empty message, unknown field, too long, ...).
final class ValidationFailure extends MatchingException {
  const ValidationFailure(super.message);
}

/// The caller is not allowed to see or act on the resource.
final class ForbiddenFailure extends MatchingException {
  const ForbiddenFailure(super.message);
}

/// The client used an outdated service configuration version.
/// The UI should keep the user's input and reload the configuration.
final class StaleConfigFailure extends MatchingException {
  const StaleConfigFailure(super.message, {required this.currentVersion});
  final int currentVersion;
}

/// The request conflicts with existing state, e.g. the same idempotency key
/// was reused with a different payload.
final class ConflictFailure extends MatchingException {
  const ConflictFailure(super.message);
}

/// Transient failure. [mayHaveCommitted] is true when the request might have
/// been applied (response lost); retry with the same idempotency key.
final class TemporarilyUnavailableFailure extends MatchingException {
  const TemporarilyUnavailableFailure(super.message,
      {this.mayHaveCommitted = false});
  final bool mayHaveCommitted;
}
