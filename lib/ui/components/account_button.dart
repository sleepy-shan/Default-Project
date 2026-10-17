import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/design_tokens.dart';
import '../../data/repositories/auth_repository.dart';
import '../../state/providers.dart';
import '../router/app_router.dart';
import 'sign_in_dialog.dart';

/// Top-bar account control.
///
/// - Guests see a **Sign in** button (labelled, or an icon on narrow bars)
///   that starts the AniList OAuth flow.
/// - Signed-in users see their AniList avatar; tapping it opens a menu with
///   **Profile** and **Sign out**.
///
/// Keeping it here (rather than on the profile page) means sign in / sign out
/// is reachable from every screen and there is a single source of truth.
class AccountButton extends ConsumerWidget {
  const AccountButton({this.iconOnly = false, super.key});

  /// When true the guest button collapses to an icon to save bar space.
  final bool iconOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final AuthUser? user = switch (auth) {
      AsyncData(:final value) => value,
      _ => null,
    };

    if (user == null) {
      // While the saved session is being validated, hold the slot so the bar
      // does not flash between "Sign in" and the avatar.
      if (auth.isLoading && !auth.hasValue) {
        return const SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      }
      if (iconOnly) {
        return IconButton(
          tooltip: 'Sign in with AniList',
          icon: const Icon(Icons.login_rounded),
          onPressed: () => showSignInDialog(context),
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
        child: FilledButton.icon(
          onPressed: () => showSignInDialog(context),
          icon: const Icon(Icons.login_rounded, size: 18),
          label: const Text('Sign in'),
        ),
      );
    }

    return _UserMenu(user: user);
  }
}

class _UserMenu extends ConsumerWidget {
  const _UserMenu({required this.user});

  final AuthUser user;

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await ref.read(authRepositoryProvider).signOut();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Signed out')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return PopupMenuButton<String>(
      tooltip: user.name,
      offset: const Offset(0, 46),
      onSelected: (value) {
        switch (value) {
          case 'profile':
            context.go(Routes.profile);
          case 'signout':
            _signOut(context, ref);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          height: 64,
          child: Row(
            children: [
              _Avatar(user: user, size: 30),
              const SizedBox(width: Tokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    Text(
                      'Signed in with AniList',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'profile',
          child: Row(
            children: [
              Icon(Icons.person_outline, size: 18),
              SizedBox(width: Tokens.space12),
              Text('Profile'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'signout',
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 18),
              SizedBox(width: Tokens.space12),
              Text('Sign out'),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
        child: _Avatar(user: user, size: 32),
      ),
    );
  }
}

/// Round AniList avatar with an initial-letter fallback.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.user, required this.size});

  final AuthUser user;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = user.avatarUrl;
    final initial = user.name.isEmpty
        ? '?'
        : user.name.substring(0, 1).toUpperCase();
    final fallback = ColoredBox(
      color: scheme.primaryContainer,
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: scheme.onPrimaryContainer,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.42,
          ),
        ),
      ),
    );
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.surfaceContainerHighest,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: url == null || url.isEmpty
          ? fallback
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => fallback,
            ),
    );
  }
}
