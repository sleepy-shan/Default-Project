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

  static const Duration timeout = Duration(seconds: 20);

  /// Executes [document] with [variables] and returns the `data` payload.
  ///
  /// Retries transient failures (network, 429, 5xx) with exponential
  /// backoff because AniList occasionally bursts 429s.
  Future<Map<String, dynamic>> query(
    String document,
    Map<String, dynamic> variables,
  ) async {
    var attempt = 0;
    while (true) {
      attempt++;
      try {
        return await _attempt(document, variables);
      } on AppException catch (error) {
        final retryable = error.kind == ErrorKind.network ||
            error.kind == ErrorKind.rateLimit ||
            error.kind == ErrorKind.server;
        if (!retryable || attempt > maxRetries) rethrow;
        final backoff = Duration(
          milliseconds: 500 * math.pow(2, attempt - 1).toInt(),
        );
        await Future<void>.delayed(backoff);
      }
    }
  }

  Future<Map<String, dynamic>> _attempt(
    String document,
    Map<String, dynamic> variables,
  ) async {
    late final http.Response response;
    try {
      response = await _http
          .post(
            Uri.parse(AppConfig.aniListEndpoint),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'query': document, 'variables': variables}),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const AppException(ErrorKind.network, 'AniList request timed out');
    } on Object catch (error) {
      throw AppException(ErrorKind.network, 'Network request failed: $error');
    }

    if (response.statusCode == 429) {
      throw const AppException(
        ErrorKind.rateLimit,
        'AniList rate limit exceeded',
      );
    }
    if (response.statusCode >= 500) {
      throw AppException(
        ErrorKind.server,
        'AniList responded with ${response.statusCode}',
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
      if (message.toLowerCase().contains('not found')) {
        throw AppException(ErrorKind.notFound, message);
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
