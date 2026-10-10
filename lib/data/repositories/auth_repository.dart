import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/app_exception.dart';

/// The authenticated user of the app.
class AuthUser {
  const AuthUser({required this.id, this.email, this.isAnonymous = false});

  final String id;
  final String? email;
  final bool isAnonymous;

  static const AuthUser guest = AuthUser(
    id: 'local',
    email: null,
    isAnonymous: true,
  );
}

/// Authentication contract. The local implementation represents the
/// guest/demo session; the Supabase implementation wraps Supabase Auth.
abstract interface class AuthRepository {
  AuthUser? get currentUser;
  Stream<AuthUser?> get userChanges;
  Future<void> signInWithEmail(String email, String password);
  Future<void> signUpWithEmail(String email, String password);
  Future<void> signOut();
}

/// Local (demo) auth: everyone is the local guest. Used when no Supabase
/// project is configured.
class LocalAuthRepository implements AuthRepository {
  final _controller = StreamController<AuthUser?>.broadcast();

  @override
  AuthUser? get currentUser => AuthUser.guest;

  @override
  Stream<AuthUser?> get userChanges async* {
    yield AuthUser.guest;
    yield* _controller.stream;
  }

  @override
  Future<void> signInWithEmail(String email, String password) async {
    _controller.add(AuthUser(id: 'local', email: email));
  }

  @override
  Future<void> signUpWithEmail(String email, String password) async {
    _controller.add(AuthUser(id: 'local', email: email));
  }

  @override
  Future<void> signOut() async => _controller.add(AuthUser.guest);

  void dispose() => _controller.close();
}

/// Supabase Auth (email + password sessions).
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository();

  SupabaseClient get _client => Supabase.instance.client;

  @override
  AuthUser? get currentUser {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return AuthUser(id: user.id, email: user.email);
  }

  @override
  Stream<AuthUser?> get userChanges {
    return _client.auth.onAuthStateChange.map((event) {
      final user = event.session?.user;
      if (user == null) return null;
      return AuthUser(id: user.id, email: user.email);
    });
  }

  @override
  Future<void> signInWithEmail(String email, String password) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (error) {
      throw AppException(ErrorKind.unauthorized, error.message);
    }
  }

  @override
  Future<void> signUpWithEmail(String email, String password) async {
    try {
      await _client.auth.signUp(email: email, password: password);
    } on AuthException catch (error) {
      throw AppException(ErrorKind.validation, error.message);
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();
}

/// Picks the right implementation for the current build configuration.
AuthRepository createAuthRepository() =>
    AppConfig.hasSupabase ? SupabaseAuthRepository() : LocalAuthRepository();
