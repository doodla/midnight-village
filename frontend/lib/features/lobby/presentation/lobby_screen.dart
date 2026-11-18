import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/host/host_change.dart';
import '../../../core/router/routes.dart';
import '../../../design_system/components/core/mv_error.dart';
import '../../../design_system/components/core/mv_loading.dart';
import '../../../design_system/components/core/primary_button.dart';
import '../../../design_system/components/foundation/atmospheric_background.dart';
import '../../../design_system/components/foundation/player_avatar.dart';
import '../../../design_system/components/foundation/village_app_bar.dart';
import '../../../design_system/components/game/role_token_list.dart';
import '../../../design_system/models/avatar_size.dart';
import '../../../design_system/models/game_phase.dart';
import '../../../design_system/models/role.dart';
import '../../../design_system/tokens/app_tokens_provider.dart';
import '../../auth/domain/auth_state.dart';
import '../../game/presentation/away_notice.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../domain/lobby_state.dart';
import '../domain/role_config.dart';
import 'lobby_notifier.dart';

// ---------------------------------------------------------------------------
// Public screen widget
// ---------------------------------------------------------------------------

/// The main lobby screen.
///
/// Displays the lobby code, player list, role configuration (host only), and
/// action buttons. Navigates to the game screen when `game_started` is received.
class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key, required this.code});

  final String code;

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  @override
  Widget build(BuildContext context) {
    // A table runs several games in a row: open whichever one starts next.
    ref.listen(lobbyProvider(widget.code), (previous, next) {
      final started = next.value?.startedGameId;
      if (started != null && started != previous?.value?.startedGameId) {
        if (mounted) {
          GameRoute(gameId: started, lobby: widget.code).go(context);
        }
      }
    });

    final lobbyAsync = ref.watch(lobbyProvider(widget.code));
    final authState = ref.watch(authProvider);
    final currentUserId = authState is AuthAuthenticated
        ? authState.user.id
        : null;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const VillageAppBar.brand(),
      body: AtmosphericBackground(
        phase: GamePhase.lobby,
        child: SafeArea(
          child: lobbyAsync.when(
            loading: () => const MvLoading(),
            error: (e, _) => MvError(
              message: 'Failed to load lobby',
              onRetry: () => ref.invalidate(lobbyProvider(widget.code)),
            ),
            data: (lobby) {
              final isHost =
                  currentUserId != null && currentUserId == lobby.hostId;
              return _LobbyContent(
                lobby: lobby,
                code: widget.code,
                isHost: isHost,
                currentUserId: currentUserId,
              );
            },
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Main content
// ---------------------------------------------------------------------------

class _LobbyContent extends ConsumerWidget {
  const _LobbyContent({
    required this.lobby,
    required this.code,
    required this.isHost,
    required this.currentUserId,
  });

  final LobbyState lobby;
  final String code;
  final bool isHost;
  final int? currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(activeThemeProvider);
    final notifier = ref.read(lobbyProvider(code).notifier);

    final roleMap = _toRoleIdMap(lobby.roleConfig);
    final playerCount = lobby.players.length;
    final allReady =
        lobby.players.isNotEmpty && lobby.players.every((p) => p.isReady);
    final canStart =
        isHost &&
        allReady &&
        playerCount >= 3 &&
        playerCount <= 10 &&
        RoleConfig.isValid(roleMap, playerCount);

    // Find current user's ready state
    LobbyPlayer? currentPlayer;
    for (final p in lobby.players) {
      if (p.id == currentUserId) {
        currentPlayer = p;
        break;
      }
    }
    final isCurrentUserReady = currentPlayer?.isReady ?? false;

    return SingleChildScrollView(
      padding: EdgeInsets.all(tokens.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LobbyCodeSection(lobbyCode: lobby.code, tokens: tokens),
          // Who is hosting, while that is not the person who set the table up
          // (and for a moment after it changes back).
          HostNoticeLine(text: _hostLine(lobby, currentUserId)),
          SizedBox(height: tokens.spacing.xl),
          _PlayerListSection(players: lobby.players, tokens: tokens),
          SizedBox(height: tokens.spacing.xl),
          if (isHost)
            _RoleConfigSection(
              roles: lobby.roleConfig,
              playerCount: playerCount,
              onRolesChanged: (newRoles) =>
                  _hostAction(() => notifier.updateRoleConfig(newRoles)),
              tokens: tokens,
            )
          else
            _RoleTokenListSection(roleConfig: lobby.roleConfig),
          SizedBox(height: tokens.spacing.xl),
          if (isHost) ...[
            PrimaryButton(
              label: 'Start Game',
              onPressed: canStart
                  ? () => _hostAction(() => notifier.startGame())
                  : null,
            ),
            SizedBox(height: tokens.spacing.md),
          ] else ...[
            Center(
              child: Text(
                'Waiting for host to start...',
                style: tokens.typography.body.copyWith(
                  color: tokens.colors.disabled,
                ),
              ),
            ),
            SizedBox(height: tokens.spacing.md),
          ],
          PrimaryButton(
            label: isCurrentUserReady ? 'Not Ready' : 'Ready',
            onPressed: () => notifier.toggleReady(),
          ),
          SizedBox(height: tokens.spacing.md),
          PrimaryButton.outlined(
            label: 'Leave',
            onPressed: () async {
              await notifier.leave();
              if (context.mounted) context.go('/');
            },
          ),
          SizedBox(height: tokens.spacing.md),
        ],
      ),
    );
  }
}

/// Runs a host-only call. A refusal because the role just moved is already
/// said in the host line (the lobby has been read again), so it needs no
/// error of its own.
Future<void> _hostAction(Future<void> Function() call) async {
  try {
    await call();
  } on NoLongerHostException {
    // Nothing more to do: the line is in the lobby state.
  }
}

/// The host line: a refused host action, else "X is hosting while Y is away"
/// for as long as someone is acting as host, else "Y is hosting again" for a
/// few seconds after the role returned.
String? _hostLine(LobbyState lobby, int? viewerId) {
  if (lobby.hostActionNotice != null) return lobby.hostActionNotice;
  String? nameOf(int? id) {
    for (final p in lobby.players) {
      if (p.id == id) return p.displayName;
    }
    return null;
  }

  if (lobby.isActingHost) {
    return hostChangeLine(
      change: HostChange(
        hostId: lobby.hostId,
        hostName: lobby.hostName ?? nameOf(lobby.hostId) ?? 'Someone',
        originalHostId: lobby.originalHostId ?? lobby.hostId,
        reason: HostChangeReason.handover,
      ),
      viewerId: viewerId,
      originalHostName: nameOf(lobby.originalHostId),
    );
  }
  final returned = lobby.returnedNotice;
  if (returned != null) {
    return hostChangeLine(change: returned, viewerId: viewerId);
  }
  return null;
}

// ---------------------------------------------------------------------------
// Lobby code section
// ---------------------------------------------------------------------------

class _LobbyCodeSection extends StatelessWidget {
  const _LobbyCodeSection({required this.lobbyCode, required this.tokens});

  final String lobbyCode;
  final dynamic tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(tokens.spacing.lg),
      decoration: BoxDecoration(
        color: tokens.colors.surface.withValues(alpha: 0.8),
        borderRadius: tokens.radius.large,
        border: Border.all(color: tokens.colors.outline),
      ),
      child: Column(
        children: [
          Text(
            'Lobby Code',
            style: tokens.typography.caption.copyWith(
              color: tokens.colors.disabled,
            ),
          ),
          SizedBox(height: tokens.spacing.xs),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: lobbyCode));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Lobby code copied!')),
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  lobbyCode,
                  style: tokens.typography.lobbyCode.copyWith(
                    color: tokens.colors.onSurface,
                    // letterSpacing comes from the lobbyCode token (8.0)
                  ),
                ),
                SizedBox(width: tokens.spacing.sm),
                // Icon size 20 matches body text scale; no AppTokens icon-size token exists.
                Icon(Icons.copy, size: 20, color: tokens.colors.disabled),
              ],
            ),
          ),
          SizedBox(height: tokens.spacing.xs),
          Text(
            'Tap to copy and share with friends',
            style: tokens.typography.caption.copyWith(
              color: tokens.colors.disabled,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Player list section
// ---------------------------------------------------------------------------

class _PlayerListSection extends StatelessWidget {
  const _PlayerListSection({required this.players, required this.tokens});

  final List<LobbyPlayer> players;
  final dynamic tokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Players (${players.length})',
          style: tokens.typography.subheading.copyWith(
            color: tokens.colors.onBackground,
          ),
        ),
        SizedBox(height: tokens.spacing.sm),
        ...players.map((player) => _PlayerRow(player: player, tokens: tokens)),
      ],
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({required this.player, required this.tokens});

  final LobbyPlayer player;
  final dynamic tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.xs),
      child: Row(
        children: [
          PlayerAvatar(displayName: player.displayName, size: AvatarSize.small),
          SizedBox(width: tokens.spacing.sm),
          Expanded(
            child: Text(
              player.displayName,
              style: tokens.typography.body.copyWith(
                color: tokens.colors.onBackground,
              ),
            ),
          ),
          // Icon size 20 matches body text scale; no AppTokens icon-size token exists.
          if (player.isReady)
            Icon(Icons.check_circle, color: tokens.colors.villageTeam, size: 20)
          else
            Icon(
              Icons.radio_button_unchecked,
              color: tokens.colors.disabled,
              size: 20,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Role token list (non-host read-only view)
// ---------------------------------------------------------------------------

class _RoleTokenListSection extends ConsumerWidget {
  const _RoleTokenListSection({required this.roleConfig});

  final Map<String, int> roleConfig;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(activeThemeProvider);
    final roles = <RoleId>[];
    for (final entry in roleConfig.entries) {
      try {
        final roleId = RoleId.values.firstWhere(
          (r) => r.name == entry.key || r.displayName == entry.key,
        );
        for (var i = 0; i < entry.value; i++) {
          roles.add(roleId);
        }
      } catch (_) {
        // Skip unknown roles
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Roles in Game',
          style: tokens.typography.subheading.copyWith(
            color: tokens.colors.onBackground,
          ),
        ),
        SizedBox(height: tokens.spacing.sm),
        RoleTokenList(rolesInGame: roles),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Role configuration section (host only)
// ---------------------------------------------------------------------------

class _RoleConfigSection extends ConsumerStatefulWidget {
  const _RoleConfigSection({
    required this.roles,
    required this.playerCount,
    required this.onRolesChanged,
    required this.tokens,
  });

  final Map<String, int> roles;
  final int playerCount;
  final void Function(Map<String, int> roles) onRolesChanged;
  final dynamic tokens;

  @override
  ConsumerState<_RoleConfigSection> createState() => _RoleConfigSectionState();
}

class _RoleConfigSectionState extends ConsumerState<_RoleConfigSection> {
  late Map<String, int> _currentRoles;

  @override
  void initState() {
    super.initState();
    _currentRoles = Map.from(widget.roles);
  }

  @override
  void didUpdateWidget(_RoleConfigSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roles != widget.roles) {
      _currentRoles = Map.from(widget.roles);
    }
  }

  Map<RoleId, int> get _roleIdMap => _toRoleIdMap(_currentRoles);

  void _increment(RoleId role) {
    final key = role.displayName;
    final current = _currentRoles[key] ?? 0;
    final step = RoleConfig.stepSize(role);
    final max = RoleConfig.maxCount(role);
    if (current + step <= max) {
      setState(() => _currentRoles = {..._currentRoles, key: current + step});
      widget.onRolesChanged(_currentRoles);
    }
  }

  void _decrement(RoleId role) {
    final key = role.displayName;
    final current = _currentRoles[key] ?? 0;
    final step = RoleConfig.stepSize(role);
    if (current - step >= 0) {
      setState(() => _currentRoles = {..._currentRoles, key: current - step});
      widget.onRolesChanged(_currentRoles);
    }
  }

  void _applyPreset(Map<RoleId, int> preset) {
    final newRoles = _toStringMap(preset);
    setState(() => _currentRoles = newRoles);
    widget.onRolesChanged(newRoles);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final presets = RoleConfig.presetsForPlayerCount(widget.playerCount);
    final validationError = RoleConfig.validationError(
      _roleIdMap,
      widget.playerCount,
    );
    final total = RoleConfig.totalCards(_roleIdMap);
    final expected = widget.playerCount + 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Role Configuration',
          style: tokens.typography.subheading.copyWith(
            color: tokens.colors.onBackground,
          ),
        ),
        SizedBox(height: tokens.spacing.sm),

        // Preset selector
        if (presets.isNotEmpty) ...[
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: 'Preset',
              labelStyle: tokens.typography.caption.copyWith(
                color: tokens.colors.disabled,
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: tokens.colors.outline),
                borderRadius: tokens.radius.medium,
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: tokens.colors.primary),
                borderRadius: tokens.radius.medium,
              ),
            ),
            hint: Text(
              'Preset',
              style: tokens.typography.body.copyWith(
                color: tokens.colors.disabled,
              ),
            ),
            items: presets.entries.map((entry) {
              return DropdownMenuItem(
                value: entry.key,
                child: Text(
                  entry.key,
                  style: tokens.typography.body.copyWith(
                    color: tokens.colors.onSurface,
                  ),
                ),
              );
            }).toList(),
            onChanged: (name) {
              if (name != null) {
                _applyPreset(presets[name]!);
              }
            },
          ),
          SizedBox(height: tokens.spacing.md),
        ],

        // Card count summary
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.md,
            vertical: tokens.spacing.sm,
          ),
          decoration: BoxDecoration(
            color: validationError != null
                ? tokens.colors.error.withValues(alpha: 0.15)
                : tokens.colors.villageTeam.withValues(alpha: 0.15),
            borderRadius: tokens.radius.medium,
          ),
          child: Row(
            children: [
              // Icon size 16 matches caption text scale; no AppTokens icon-size token exists.
              Icon(
                validationError != null ? Icons.warning : Icons.check,
                size: 16,
                color: validationError != null
                    ? tokens.colors.error
                    : tokens.colors.villageTeam,
              ),
              SizedBox(width: tokens.spacing.xs),
              Expanded(
                child: Text(
                  validationError ??
                      '$total of $expected cards ($total/${widget.playerCount} players + 3 center)',
                  style: tokens.typography.caption.copyWith(
                    color: validationError != null
                        ? tokens.colors.error
                        : tokens.colors.onBackground,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: tokens.spacing.sm),

        // Per-role rows
        ...RoleId.values.map((role) {
          final count = _currentRoles[role.displayName] ?? 0;
          final max = RoleConfig.maxCount(role);
          final step = RoleConfig.stepSize(role);
          final canInc = count + step <= max;
          final canDec = count - step >= 0;

          return Padding(
            padding: EdgeInsets.symmetric(vertical: tokens.spacing.xs),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    role.displayName,
                    style: tokens.typography.body.copyWith(
                      color: tokens.colors.onBackground,
                    ),
                  ),
                ),
                // iconSize 20 matches body text scale; no AppTokens icon-size token exists.
                // BoxConstraints 36×36 is the accessibility minimum touch target;
                // no AppTokens touch-target token exists.
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: canDec ? () => _decrement(role) : null,
                  iconSize: 20,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  color: tokens.colors.onBackground,
                  disabledColor: tokens.colors.disabled,
                ),
                SizedBox(
                  width: 32,
                  child: Text(
                    '$count',
                    textAlign: TextAlign.center,
                    style: tokens.typography.body.copyWith(
                      color: tokens.colors.onBackground,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: canInc ? () => _increment(role) : null,
                  iconSize: 20,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  color: tokens.colors.onBackground,
                  disabledColor: tokens.colors.disabled,
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Conversion helpers
// ---------------------------------------------------------------------------

Map<RoleId, int> _toRoleIdMap(Map<String, int> roles) {
  final result = <RoleId, int>{};
  for (final entry in roles.entries) {
    try {
      final roleId = RoleId.values.firstWhere(
        (r) => r.name == entry.key || r.displayName == entry.key,
      );
      result[roleId] = entry.value;
    } catch (_) {
      // Ignore unknown role names
    }
  }
  return result;
}

Map<String, int> _toStringMap(Map<RoleId, int> roles) {
  return {
    for (final entry in roles.entries) entry.key.displayName: entry.value,
  };
}
