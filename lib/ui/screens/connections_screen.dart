import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/repositories/auth_repository.dart';
import '../../state/my_lists_controller.dart';
import '../../state/providers.dart';
import '../router/app_router.dart';

/// Account connections page: AniList login status and service overview.
///
/// AniList is the only account backend (OAuth implicit grant). Public
/// browsing works as a guest; signing in identifies the user for future
/// personal features while lists stay in this browser's localStorage.
class ConnectionsScreen extends ConsumerStatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  ConsumerState<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends ConsumerState<ConnectionsScreen> {
  final _tokenController = TextEditingController();
  bool _savingToken = false;
  String? _tokenError;

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _loginWithAniList(Uri loginUri) async {
    // Must stay in the same tab so AniList can redirect back with
    // `#access_token=...` to this app.
    final ok = await launchUrl(loginUri, webOnlyWindowName: '_self');
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open AniList login')),
      );
    }
  }

  Future<void> _savePastedToken() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      setState(() => _tokenError = 'Paste the access_token from AniList.');
      return;
    }
    setState(() {
      _savingToken = true;
      _tokenError = null;
    });
    try {
      // Accept either a raw token or a full redirect URL/fragment.
      final extracted =
          parseAccessTokenFromFragment(token) ??
          parseAccessTokenFromUri(Uri.tryParse(token) ?? Uri()) ??
          token;
      await ref.read(authRepositoryProvider).signInWithToken(extracted);
      _tokenController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signed in with AniList')),
        );
      }
    } on Object catch (error) {
      setState(() => _tokenError = '$error');
    } finally {
      if (mounted) setState(() => _savingToken = false);
    }
  }

  Future<void> _signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Signed out')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = ref.watch(myListsControllerProvider).entries;
    final auth = ref.watch(authStateProvider);
    final signedIn = switch (auth) {
      AsyncData(:final value) => value != null,
      _ => false,
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Tokens.space16,
        Tokens.space20,
        Tokens.space16,
        Tokens.space48,
      ),
      children: [
        Text('Account & connections', style: theme.textTheme.headlineMedium),
        const SizedBox(height: Tokens.space4),
        Text(
          'Sign in with AniList to identify your account. Your lists stay in this browser.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Tokens.space24),
        _SectionCard(
          title: 'AniList account',
          children: [_buildAccountBody(theme, auth)],
        ),
        const SizedBox(height: Tokens.space16),
        _SectionCard(
          title: 'Tracking services',
          children: [
            _StatusRow(
              icon: Icons.hub_outlined,
              label: 'AniList (metadata + account)',
              connected: true,
              trailing: signedIn ? 'Signed in' : 'Public API',
            ),
            const Divider(height: Tokens.space24),
            _StatusRow(
              icon: Icons.playlist_add_check_outlined,
              label: 'MyAnimeList',
              connected: false,
              trailing: 'Not connected',
            ),
            const Divider(height: Tokens.space24),
            _StatusRow(
              icon: Icons.tv_outlined,
              label: 'Simkl',
              connected: false,
              trailing: 'Not connected',
            ),
            const SizedBox(height: Tokens.space8),
            Text(
              'Additional services are added one at a time behind the same '
              'internal tracking interface, so the app keeps working if a '
              'service is unavailable.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: Tokens.space16),
        _SectionCard(
          title: 'What your list can do right now',
          children: [
            _CapabilityRow('Titles tracked', '${entries.length}'),
            _CapabilityRow(
              'Statuses',
              'Planning / Watching / Completed / Paused / Dropped',
            ),
            _CapabilityRow(
              'Progress',
              'Episode & chapter counters saved per title',
            ),
            _CapabilityRow('Scores', 'Personal 0–10 score per title'),
            _CapabilityRow('Storage', 'This browser only'),
          ],
        ),
        const SizedBox(height: Tokens.space16),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.go(Routes.settings),
            icon: const Icon(Icons.settings_outlined, size: 18),
            label: const Text('Open settings'),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountBody(ThemeData theme, AsyncValue<AuthUser?> auth) {
    final user = switch (auth) {
      AsyncData(:final value) => value,
      _ => null,
    };
    if (auth.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Checking AniList session…'),
          ],
        ),
      );
    }
    if (user != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundImage: user.avatarUrl != null
                    ? NetworkImage(user.avatarUrl!)
                    : null,
                child: user.avatarUrl == null
                    ? Text(
                        user.name.isEmpty
                            ? '?'
                            : user.name[0].toUpperCase(),
                      )
                    : null,
              ),
              const SizedBox(width: Tokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'AniList ID: ${user.id}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Tokens.space8,
                  vertical: Tokens.space2,
                ),
                decoration: BoxDecoration(
                  color: Tokens.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(Tokens.radiusPill),
                ),
                child: const Text(
                  'Connected',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Tokens.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Tokens.space12),
          OutlinedButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Sign out'),
          ),
          if (auth.hasError) ...[
            const SizedBox(height: Tokens.space8),
            Text(
              '${auth.error}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      );
    }

    // Guest mode.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StatusRow(
          icon: Icons.person_outline,
          label: 'Guest session',
          connected: false,
          trailing: 'Local only',
        ),
        const SizedBox(height: Tokens.space12),
        if (!AppConfig.hasAnilistClient) ...[
          Text(
            'To enable AniList login, create a client at '
            'anilist.co/settings/developer and rebuild with:\n'
            'flutter run -d chrome '
            '--dart-define=ANILIST_CLIENT_ID=...',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: Tokens.space12),
        ] else ...[
          FilledButton.icon(
            onPressed: () => _loginWithAniList(AppConfig.anilistLoginUri()),
            icon: const Icon(Icons.login, size: 18),
            label: const Text('Login with AniList'),
          ),
          const SizedBox(height: Tokens.space8),
          Text(
            'You will be sent to anilist.co to approve, then returned here automatically.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Tokens.space12),
        ],
        Text(
          'Or paste an access token manually:',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Tokens.space8),
        TextField(
          controller: _tokenController,
          decoration: InputDecoration(
            hintText: 'access_token or full redirect URL',
            errorText: _tokenError,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          minLines: 1,
          maxLines: 2,
        ),
        const SizedBox(height: Tokens.space8),
        OutlinedButton.icon(
          onPressed: _savingToken ? null : _savePastedToken,
          icon: _savingToken
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.key_outlined, size: 18),
          label: Text(_savingToken ? 'Verifying…' : 'Save token'),
        ),
        if (auth.hasError) ...[
          const SizedBox(height: Tokens.space8),
          Text(
            '${auth.error}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: Tokens.space12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.label,
    required this.connected,
    required this.trailing,
  });

  final IconData icon;
  final String label;
  final bool connected;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = connected
        ? Tokens.success
        : theme.colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: Tokens.space12),
        Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.space8,
            vertical: Tokens.space2,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(Tokens.radiusPill),
          ),
          child: Text(
            connected ? 'Connected' : trailing,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _CapabilityRow extends StatelessWidget {
  const _CapabilityRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Tokens.space8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}
