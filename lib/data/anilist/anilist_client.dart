import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../core/utils/app_exception.dart';

/// Thin GraphQL client for the public AniList API.
///
/// AniList needs no credentials for public metadata (browse, search,
/// details, airing schedule) and exposes a single POST endpoint.
/// Rate limits: 90 requests/minute, degrading to 30 when abused — the app
/// surfaces HTTP 429 as a friendly [AppException] with a retry action.
class AniListClient {
  AniListClient({http.Client? httpClient, this.maxRetries = 2})
    : _http = httpClient ?? http.Client();

  final http.Client _http;
  final int maxRetries;
  final math.Random _random = math.Random();

  static const Duration timeout = Duration(seconds: 20);

  Duration? _retryAfterOf(http.Response response) {
    final raw = response.headers['retry-after'];
    if (raw == null || raw.isEmpty) return null;
    final seconds = int.tryParse(raw.trim());
    if (seconds == null) return null;
    if (seconds <= 0 || seconds > 60) return const Duration(seconds: 5);
    return Duration(seconds: seconds);
  }

  /// Executes [document] with [variables] and returns the `data` payload.
  ///
  /// Retries transient failures (network, 429, 5xx) with exponential
  /// backoff + jitter because AniList occasionally bursts 429s. Honors
  /// `Retry-After` when present so retries do not worsen a limit.
  ///
  /// Pass [token] for authenticated operations (e.g. the Viewer query).
  /// The token is sent as `Authorization: Bearer <token>` and never logged.
  Future<Map<String, dynamic>> query(
    String document,
    Map<String, dynamic> variables, {
    String? token,
  }) async {
    var attempt = 0;
    // Encode once per query (not per retry) to avoid re-encoding the
    // large GraphQL document on every backoff.
    final body = jsonEncode({'query': document, 'variables': variables});
    while (true) {
      attempt++;
      try {
        return await _attempt(body, token: token);
      } on _RetryAfter catch (retry) {
        if (attempt > maxRetries) {
          throw AppException(
            ErrorKind.rateLimit,
            'AniList rate limit exceeded',
          );
        }
        await Future<void>.delayed(retry.delay);
      } on AppException catch (error) {
        final retryable =
            error.kind == ErrorKind.network ||
            error.kind == ErrorKind.rateLimit ||
            error.kind == ErrorKind.server;
        if (!retryable || attempt > maxRetries) rethrow;
        // Exponential backoff with ±25% jitter to avoid retry storms.
        final base = 500 * math.pow(2, attempt - 1).toInt();
        final jitter = (base * 0.25 * (_random.nextDouble() * 2 - 1)).toInt();
        await Future<void>.delayed(Duration(milliseconds: base + jitter));
      }
    }
  }

  Future<Map<String, dynamic>> _attempt(String body, {String? token}) async {
    late final http.Response response;
    try {
      response = await _http
          .post(
            Uri.parse(AppConfig.aniListEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              if (token != null && token.isNotEmpty)
                'Authorization': 'Bearer $token',
            },
            body: body,
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const AppException(ErrorKind.network, 'AniList request timed out');
    } on Object catch (error) {
      throw AppException(ErrorKind.network, 'Network request failed: $error');
    }

    if (response.statusCode == 429) {
      final retryAfter = _retryAfterOf(response);
      if (retryAfter != null) throw _RetryAfter(retryAfter);
      throw const AppException(
        ErrorKind.rateLimit,
        'AniList rate limit exceeded',
      );
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const AppException(
        ErrorKind.unauthorized,
        'AniList token expired or invalid',
      );
    }
    if (response.statusCode >= 500) {
      throw AppException(
        ErrorKind.server,
        'AniList responded with ${response.statusCode}',
      );
    }
    if (response.statusCode == 400 || response.statusCode == 404) {
      // Bad variables / unknown id: not retryable, surfaced as notFound
      // so the UI shows an empty/friendly state instead of retry spam.
      throw AppException(
        ErrorKind.notFound,
        'AniList could not satisfy this request (${response.statusCode})',
      );
    }
    if (response.statusCode != 200) {
      throw AppException(
        ErrorKind.server,
        'Unexpected status ${response.statusCode} from AniList',
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const AppException(
        ErrorKind.server,
        'AniList returned malformed JSON',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const AppException(
        ErrorKind.server,
        'Unexpected AniList payload shape',
      );
    }

    final errors = decoded['errors'];
    if (errors is List && errors.isNotEmpty) {
      final first = errors.first;
      final message = first is Map && first['message'] is String
          ? first['message'] as String
          : 'AniList GraphQL error';
      final lower = message.toLowerCase();
      if (lower.contains('not found')) {
        throw AppException(ErrorKind.notFound, message);
      }
      if (lower.contains('invalid token') ||
          lower.contains('unauthorized') ||
          lower.contains('not authenticated') ||
          lower.contains('forbidden')) {
        throw AppException(ErrorKind.unauthorized, message);
      }
      throw AppException(ErrorKind.server, message);
    }

    final data = decoded['data'];
    if (data is Map<String, dynamic>) return data;
    throw const AppException(
      ErrorKind.server,
      'AniList response contained no data',
    );
  }

  void close() => _http.close();
}

/// Internal signal: the server asked us to wait [delay] before retrying.
class _RetryAfter {
  const _RetryAfter(this.delay);

  final Duration delay;
}
