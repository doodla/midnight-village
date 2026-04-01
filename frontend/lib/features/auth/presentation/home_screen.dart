import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:midnight_village/design_system/components/core/primary_button.dart';
import 'package:midnight_village/design_system/components/core/mv_error.dart';
import 'package:midnight_village/design_system/components/core/mv_loading.dart';
import 'package:midnight_village/design_system/components/core/mv_scaffold.dart';
import 'package:midnight_village/design_system/components/core/mv_text_input.dart';
import 'package:midnight_village/design_system/tokens/app_tokens_provider.dart';

import '../../lobby/presentation/lobby_notifier.dart';
import '../domain/auth_state.dart';
import 'auth_notifier.dart';

/// MVP home screen demonstrating full auth flow.
///
/// Shows:
/// - Splash during initial load
/// - Welcome screen with display name input for unauthenticated users
/// - Hello message for authenticated users
/// - Error state with retry
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MvScaffold(
      title: 'Midnight Village',
      body: switch (authState) {
        AuthInitial() => const MvLoading(),
        AuthLoading() => const MvLoading(message: 'Creating account...'),
        AuthAuthenticated(:final user) => _AuthenticatedView(
          displayName: user.displayName,
        ),
        AuthUnauthenticated() => const _WelcomeView(),
        AuthError(:final message) => _ErrorView(message: message),
      },
    );
  }
}

class _WelcomeView extends ConsumerStatefulWidget {
  const _WelcomeView();

  @override
  ConsumerState<_WelcomeView> createState() => _WelcomeViewState();
}

class _WelcomeViewState extends ConsumerState<_WelcomeView> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onContinue() {
    final displayName = _controller.text.trim();
    ref
        .read(authProvider.notifier)
        .createGuest(displayName: displayName.isEmpty ? null : displayName);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(activeThemeProvider);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MvTextInput(
          controller: _controller,
          label: 'Display name',
          hint: 'Leave blank for random name',
        ),
        SizedBox(height: tokens.spacing.md),
        PrimaryButton(label: 'Continue', onPressed: _onContinue),
      ],
    );
  }
}

class _AuthenticatedView extends ConsumerStatefulWidget {
  const _AuthenticatedView({required this.displayName});

  final String displayName;

  @override
  ConsumerState<_AuthenticatedView> createState() => _AuthenticatedViewState();
}

class _AuthenticatedViewState extends ConsumerState<_AuthenticatedView> {
  final _joinController = TextEditingController();
  bool _isCreating = false;

  @override
  void dispose() {
    _joinController.dispose();
    super.dispose();
  }

  Future<void> _createLobby() async {
    setState(() => _isCreating = true);
    try {
      final service = ref.read(lobbyServiceProvider);
      final lobby = await service.createLobby();
      if (mounted) context.go('/lobby/${lobby.code}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to create lobby: $e')));
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  void _joinLobby() {
    final code = _joinController.text.trim().toUpperCase();
    if (code.isEmpty) return;
    context.go('/lobby/$code');
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(activeThemeProvider);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Hello, ${widget.displayName}!',
          style: tokens.typography.heading.copyWith(
            color: tokens.colors.onBackground,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: tokens.spacing.lg),
        PrimaryButton(
          label: _isCreating ? 'Creating...' : 'Create Game',
          onPressed: _isCreating ? null : _createLobby,
        ),
        SizedBox(height: tokens.spacing.lg),
        MvTextInput(
          controller: _joinController,
          label: 'Lobby code',
          hint: 'Enter code to join',
        ),
        SizedBox(height: tokens.spacing.sm),
        PrimaryButton.outlined(label: 'Join Game', onPressed: _joinLobby),
        SizedBox(height: tokens.spacing.xl),
        PrimaryButton.outlined(
          label: 'Logout',
          onPressed: () => ref.read(authProvider.notifier).logout(),
        ),
      ],
    );
  }
}

class _ErrorView extends ConsumerWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MvError(
      message: message,
      onRetry: () => ref.invalidate(authProvider),
    );
  }
}
