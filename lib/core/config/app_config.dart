/// Runtime configuration for the app.
///
/// Values are supplied at build/run time with `--dart-define` so that no
/// credentials are ever hardcoded in the client bundle:
///
/// ```
/// flutter run -d chrome \
///   --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJ...
/// ```
///
/// When no Supabase project is configured the app runs in **local demo
/// mode**: everything works, but tracking data is stored only in this
/// browser (localStorage) instead of a cloud account.
abstract final class AppConfig {
  /// Base URL of the AniList GraphQL API (public metadata source).
  static const String aniListEndpoint = 'https://graphql.anilist.co';

  /// Optional Supabase project URL (empty string when not configured).
  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');

  /// Optional Supabase anon/public key. The **service-role** key must
  /// never be passed here; it is only safe on a server.
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  /// True when a Supabase project has been supplied at build time.
  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// True when the app is running against a real backend.
  static bool get isCloudMode => hasSupabase;
}
