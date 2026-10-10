/// Typed failures used across the app.
///
/// Every network/data failure is converted into an [AppException] so screens
/// can render a helpful message and offer a retry without exposing
/// internal error details or credentials.
library;

enum ErrorKind {
  /// Device is offline or the request timed out.
  network,

  /// Third-party API rate limit was hit (AniList returns HTTP 429).
  rateLimit,

  /// The user is not authenticated or the session expired.
  unauthorized,

  /// Signed in, but the user is not allowed to touch this record.
  forbidden,

  /// The requested resource does not exist.
  notFound,

  /// The third-party service returned an unexpected response.
  server,

  /// Storage (localStorage) read/write failed.
  storage,

  /// Validation of user input failed.
  validation,

  /// Anything else.
  unknown,
}

class AppException implements Exception {
  const AppException(this.kind, this.message, {this.cause});

  final ErrorKind kind;
  final String message;
  final Object? cause;

  /// Message that is safe to show to an end user.
  String get userMessage => switch (kind) {
        ErrorKind.network =>
          'No connection. Check your internet and try again.',
        ErrorKind.rateLimit =>
          'AniList is rate-limiting requests right now. Wait a moment and retry.',
        ErrorKind.unauthorized =>
          'Your session expired. Please sign in again.',
        ErrorKind.forbidden =>
          'You do not have permission to do that.',
        ErrorKind.notFound => 'That title could not be found.',
        ErrorKind.server =>
          'The service is having trouble right now. Try again later.',
        ErrorKind.storage => 'Could not save data on this device.',
        ErrorKind.validation => message,
        ErrorKind.unknown =>
          'Something went wrong. Please try again.',
      };

  @override
  String toString() => 'AppException($kind, $message)';
}
