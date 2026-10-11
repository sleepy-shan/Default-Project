import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/app_exception.dart';
import '../anilist/anilist_client.dart';
import '../anilist/anilist_queries.dart';

/// The signed-in AniList user.
class AuthUser {
  const AuthUser({required this.id, required this.name, this.avatarUrl});

  final int id;
  final String name;
  final String? avatarUrl;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'avatarUrl': avatarUrl,
  };

  static AuthUser? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    if (id is! int || name is! String) return null;
    return AuthUser(
      id: id,
      name: name,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}

/// Authentication contract. AniList is the only account backend:
/// OAuth implicit grant (`response_type=token`), token stored locally,
/// identity verified with the `Viewer` query.
abstract interface class AuthRepository {
  AuthUser? get currentUser;
  String? get accessToken;
  Stream<AuthUser?> get userChanges;

  /// Null when no `ANILIST_CLIENT_ID` was supplied at build time.
  Uri? get loginUri;

  /// Validates [token] against AniList, persists it + the profile, emits user.
  Future<AuthUser> signInWithToken(String token);

  Future<void> signOut();

  /// Loads the saved session (if any) and re-validates it with AniList.
  /// Invalid tokens are cleared so the app falls back to guest mode.
  Future<void> restore();
}

/// Extracts `access_token` from an OAuth implicit redirect fragment such as
/// `access_token=abc&token_type=Bearer&expires_in=3600`.
String? parseAccessTokenFromFragment(String fragment) {
  final clean = fragment.startsWith('#') ? fragment.substring(1) : fragment;
  if (clean.isEmpty) return null;
  for (final part in clean.split('&')) {
    final eq = part.indexOf('=');
    if (eq <= 0) continue;
    final key = Uri.decodeComponent(part.substring(0, eq));
    if (key == 'access_token') {
      final value = Uri.decodeComponent(part.substring(eq + 1));
      if (value.isEmpty) return null;
      return value;
    }
  }
  return null;
}

/// Convenience wrapper around [parseAccessTokenFromFragment] for [Uri.base].
String? parseAccessTokenFromUri(Uri uri) {
  final fromFragment = parseAccessTokenFromFragment(uri.fragment);
  if (fromFragment != null) return fromFragment;
  // Some hosts forward the token as a query parameter instead.
  return uri.queryParameters['access_token'];
}

class AniListAuthRepository implements AuthRepository {
  AniListAuthRepository(this._prefs, [AniListClient? client])
    : _client = client ?? AniListClient(),
      _ownsClient = client == null;

  static const String tokenKey = 'sandwich.anilist.token';
  static const String userKey = 'sandwich.anilist.user';

  final SharedPreferences _prefs;
  final AniListClient _client;
  final bool _ownsClient;

  AuthUser? _user;
  String? _token;
  final _controller = StreamController<AuthUser?>.broadcast();
  bool _restored = false;

  @override
  AuthUser? get currentUser => _user;

  @override
  String? get accessToken => _token;

  @override
  Stream<AuthUser?> get userChanges async* {
    yield _user;
    yield* _controller.stream;
  }

  @override
  Uri? get loginUri =>
      AppConfig.hasAnilistClient ? AppConfig.anilistLoginUri() : null;

  @override
  Future<AuthUser> signInWithToken(String token) async {
    final clean = token.trim();
    if (clean.isEmpty) {
      throw const AppException(
        ErrorKind.validation,
        'That token is empty — paste the access_token from AniList.',
      );
    }
    final viewer = await _fetchViewer(clean);
    _token = clean;
    _user = viewer;
    await _prefs.setString(tokenKey, clean);
    await _prefs.setString(
      userKey,
      jsonEncode(viewer.toJson()),
    );
    if (!_controller.isClosed) _controller.add(_user);
    return viewer;
  }

  @override
  Future<void> signOut() async {
    _token = null;
    _user = null;
    await _prefs.remove(tokenKey);
    await _prefs.remove(userKey);
    if (!_controller.isClosed) _controller.add(null);
  }

  @override
  Future<void> restore() async {
    if (_restored) return;
    _restored = true;
    _token = _prefs.getString(tokenKey);
    _user = _cachedUser();
    if (_token == null || _token!.isEmpty) {
      _token = null;
      _user = null;
      if (!_controller.isClosed) _controller.add(null);
      return;
    }
    try {
      final viewer = await _fetchViewer(_token!);
      _user = viewer;
      await _prefs.setString(userKey, jsonEncode(viewer.toJson()));
    } on AppException catch (error) {
      if (error.kind == ErrorKind.unauthorized) {
        // Expired/revoked token — drop it and stay in guest mode.
        await signOut();
        return;
      }
      // Network/rate-limit: keep the cached profile so the UI still shows
      // who is signed in; the next navigation will retry validation.
    }
    if (!_controller.isClosed) _controller.add(_user);
  }

  AuthUser? _cachedUser() {
    final raw = _prefs.getString(userKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return AuthUser.fromJson(decoded);
      if (decoded is Map) {
        return AuthUser.fromJson(Map<String, dynamic>.from(decoded));
      }
    } on Object {
      // Corrupt cache — ignore and re-fetch.
    }
    return null;
  }

  Future<AuthUser> _fetchViewer(String token) async {
    final data = await _client.query(kViewerQuery, const {}, token: token);
    final viewer = data['Viewer'];
    if (viewer is! Map) {
      throw const AppException(
        ErrorKind.server,
        'AniList did not return a profile for this token.',
      );
    }
    final map = viewer is Map<String, dynamic>
        ? viewer
        : Map<String, dynamic>.from(viewer);
    final id = (map['id'] as num?)?.toInt();
    final name = map['name'] as String?;
    if (id == null || name == null || name.isEmpty) {
      throw const AppException(
        ErrorKind.server,
        'AniList did not return a profile for this token.',
      );
    }
    final avatar = map['avatar'];
    String? avatarUrl;
    if (avatar is Map) {
      avatarUrl = avatar['large'] as String?;
    }
    return AuthUser(id: id, name: name, avatarUrl: avatarUrl);
  }

  void dispose() {
    _controller.close();
    if (_ownsClient) _client.close();
  }
}

/// Picks the AniList implementation for the current build configuration.
AuthRepository createAuthRepository(
  SharedPreferences prefs, [
  AniListClient? client,
]) => AniListAuthRepository(prefs, client);
