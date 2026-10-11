/// Runtime configuration for the app.
///
/// Values are supplied at build/run time with `--dart-define` so that no
/// credentials are ever hardcoded in the client bundle:
///
/// ```
/// flutter run -d chrome \
///   --dart-define=ANILIST_CLIENT_ID=12345
/// ```
///
/// AniList is the only account backend. Public metadata (browse, search,
/// details, airing schedule) needs no credentials. Logging in with AniList
/// (OAuth implicit grant) unlocks the personal account identity; the user's
/// tracking list itself is stored locally in this browser.
abstract final class AppConfig {
  /// Base URL of the AniList GraphQL API (public metadata source).
  static const String aniListEndpoint = 'https://graphql.anilist.co';

  /// AniList OAuth authorize endpoint (implicit grant, response_type=token).
  static const String aniListAuthorizeEndpoint =
      'https://anilist.co/api/v2/oauth/authorize';

  /// AniList OAuth client ID.
  ///
  /// Create one at https://anilist.co/settings/developer and set the
  /// Redirect URL to where the app is served (e.g. `http://localhost:8080/`
  /// for local dev, or your production origin). Then pass it at build time
  /// with `--dart-define=ANILIST_CLIENT_ID=...`.
  static const String anilistClientId = String.fromEnvironment(
    'ANILIST_CLIENT_ID',
    defaultValue: '',
  );

  /// True when an AniList client ID was supplied at build time.
  static bool get hasAnilistClient => anilistClientId.isNotEmpty;

  /// OAuth authorize URL for the implicit grant flow.
  ///
  /// AniList redirects back to the registered Redirect URL with
  /// `#access_token=...&token_type=Bearer&expires_in=...`.
  static Uri anilistLoginUri() {
    return Uri.parse(
      '$aniListAuthorizeEndpoint?client_id=$anilistClientId&response_type=token',
    );
  }
}
