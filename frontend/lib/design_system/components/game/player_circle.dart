import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:midnight_village/design_system/models/player_display.dart';
import 'package:midnight_village/design_system/tokens/app_tokens.dart';
import 'package:midnight_village/design_system/tokens/app_tokens_provider.dart';

/// Fixed avatar diameter in dp — a layout constant, not a visual token.
const double _kAvatarSize = 40.0;

/// Border width when a player is selected or is the current player.
const double _kBorderSelected = 2.5;

/// Default border width for unselected players.
const double _kBorderDefault = 1.5;

/// Opacity applied to dimmed (non-selectable / locked-out) players.
const double _kDimOpacity = 0.45;

/// Side padding buffer added to each player slot's width.
const double _kSlotPadding = 8.0;

/// A grid of player avatars arranged to adapt to the number of players.
///
/// Layouts by player count:
/// - 3–4 players: single row
/// - 5–6 players: 2 rows of 3
/// - 7–8 players: 2 rows of 4
/// - 9–10 players: 2 rows of 5
///
/// Handles selection state, current-player exclusion, max-selections cap,
/// and optional eliminated/disconnected status indicators.
class PlayerCircle extends ConsumerWidget {
  final List<PlayerDisplay> players;

  /// Callback fired with the tapped player's ID. Null means non-interactive.
  final ValueChanged<String>? onPlayerSelected;

  /// Maximum simultaneous selections. 1 = vote/peek, 2 = troublemaker/seer.
  /// Null means unlimited.
  final int? maxSelections;

  /// When true, show visual indicators for eliminated and disconnected players.
  final bool showStatus;

  const PlayerCircle({
    super.key,
    required this.players,
    this.onPlayerSelected,
    this.maxSelections,
    this.showStatus = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(activeThemeProvider);

    final int selectedCount =
        players.where((p) => p.isSelected).length;
    final bool maxReached =
        maxSelections != null && selectedCount >= maxSelections!;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: tokens.spacing.m,
      runSpacing: tokens.spacing.m,
      children: players.map((player) {
        // A player is effectively tappable when:
        // - there is a tap callback
        // - the player is not the current user
        // - the player is marked selectable
        // - max selections has not been reached (unless already selected)
        final bool canTap = onPlayerSelected != null &&
            !player.isCurrentPlayer &&
            player.isSelectable &&
            (!maxReached || player.isSelected);

        return _PlayerSlot(
          player: player,
          tokens: tokens,
          canTap: canTap,
          showStatus: showStatus,
          onTap: canTap
              ? () => onPlayerSelected?.call(player.id)
              : null,
        );
      }).toList(),
    );
  }
}

/// A single player slot: circular avatar + name label beneath.
class _PlayerSlot extends StatelessWidget {
  final PlayerDisplay player;
  final AppTokens tokens;
  final bool canTap;
  final bool showStatus;
  final VoidCallback? onTap;

  const _PlayerSlot({
    required this.player,
    required this.tokens,
    required this.canTap,
    required this.showStatus,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Determine dimming: not-selectable players, or locked out by max selections.
    // Current player is NOT dimmed — they get a primary ring instead.
    final bool isDimmed =
        (!player.isCurrentPlayer && !player.isSelectable) ||
        (!canTap && !player.isSelected);

    return Semantics(
      label: '${player.displayName}${player.isCurrentPlayer ? ', you' : ''}${player.isSelected ? ', selected' : ''}',
      button: canTap,
      onTapHint: canTap ? 'select player' : null,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: _kAvatarSize + _kSlotPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PlayerAvatar(
                player: player,
                tokens: tokens,
                isDimmed: isDimmed,
                showStatus: showStatus,
              ),
              SizedBox(height: tokens.spacing.xs),
              _PlayerName(
                player: player,
                tokens: tokens,
                isDimmed: isDimmed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circular avatar with selection ring, current-player ring, status overlay.
class _PlayerAvatar extends StatelessWidget {
  final PlayerDisplay player;
  final AppTokens tokens;
  final bool isDimmed;
  final bool showStatus;

  const _PlayerAvatar({
    required this.player,
    required this.tokens,
    required this.isDimmed,
    required this.showStatus,
  });

  /// Up to two initials from the display name.
  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].isEmpty ? '?' : parts[0][0].toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  /// Badge for the current player — small person icon, bottom-right.
  Widget _buildCurrentPlayerBadge(AppTokens tokens) {
    return Positioned(
      bottom: 0,
      right: 0,
      child: Container(
        width: _kAvatarSize * 0.38,
        height: _kAvatarSize * 0.38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: tokens.colors.primary,
        ),
        child: Icon(
          Icons.person,
          size: _kAvatarSize * 0.24,
          color: tokens.colors.onPrimary,
        ),
      ),
    );
  }

  /// Badge for a selected player — checkmark icon, top-right.
  Widget _buildSelectedBadge(AppTokens tokens) {
    return Positioned(
      top: 0,
      right: 0,
      child: Container(
        width: _kAvatarSize * 0.38,
        height: _kAvatarSize * 0.38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: tokens.colors.primary,
        ),
        child: Icon(
          Icons.check,
          size: _kAvatarSize * 0.24,
          color: tokens.colors.onPrimary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isEliminated =
        showStatus && player.status == PlayerStatus.eliminated;
    final bool isDisconnected =
        showStatus && player.status == PlayerStatus.disconnected;

    // Border colour & width based on state priority:
    // current player > selected > outline (default)
    final Color borderColor;
    final double borderWidth;
    if (player.isCurrentPlayer) {
      borderColor = tokens.colors.primary;
      borderWidth = _kBorderSelected;
    } else if (player.isSelected) {
      borderColor = tokens.colors.primary;
      borderWidth = _kBorderSelected;
    } else {
      borderColor = tokens.colors.outline;
      borderWidth = _kBorderDefault;
    }

    final Color avatarBackground = isDisconnected
        ? tokens.colors.disabled
        : tokens.colors.surface;

    // When isDimmed, the Opacity wrapper handles all dimming uniformly —
    // do not additionally set onDisabled on the initials text.
    final Color initialsColor = isDisconnected
        ? tokens.colors.onDisabled
        : tokens.colors.onSurface;

    Widget avatar = Container(
      width: _kAvatarSize,
      height: _kAvatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: avatarBackground,
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: Center(
        child: Text(
          _initials(player.displayName),
          style: tokens.typography.label.copyWith(color: initialsColor),
        ),
      ),
    );

    // Apply opacity dimming.
    if (isDimmed) {
      avatar = Opacity(opacity: _kDimOpacity, child: avatar);
    }

    // Stack status indicators on top of the avatar.
    if (showStatus) {
      final List<Widget> overlays = [];

      if (isEliminated) {
        // Red semi-transparent overlay + X icon.
        overlays.add(
          Container(
            width: _kAvatarSize,
            height: _kAvatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tokens.colors.error.withValues(alpha: 0.35),
            ),
            child: Icon(
              Icons.close,
              size: _kAvatarSize * 0.5,
              color: tokens.colors.error,
            ),
          ),
        );
      }

      if (isDisconnected) {
        // Small badge in bottom-right corner.
        overlays.add(
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: _kAvatarSize * 0.4,
              height: _kAvatarSize * 0.4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tokens.colors.background,
              ),
              child: Icon(
                Icons.wifi_off,
                size: _kAvatarSize * 0.28,
                color: tokens.colors.disabled,
              ),
            ),
          ),
        );
      }

      if (player.isCurrentPlayer) {
        overlays.add(_buildCurrentPlayerBadge(tokens));
      }

      if (player.isSelected) {
        overlays.add(_buildSelectedBadge(tokens));
      }

      if (overlays.isNotEmpty) {
        return SizedBox(
          width: _kAvatarSize,
          height: _kAvatarSize,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              avatar,
              ...overlays,
            ],
          ),
        );
      }
    } else {
      // showStatus is false — still show current-player and selected badges.
      final List<Widget> badges = [];

      if (player.isCurrentPlayer) {
        badges.add(_buildCurrentPlayerBadge(tokens));
      }

      if (player.isSelected) {
        badges.add(_buildSelectedBadge(tokens));
      }

      if (badges.isNotEmpty) {
        return SizedBox(
          width: _kAvatarSize,
          height: _kAvatarSize,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              avatar,
              ...badges,
            ],
          ),
        );
      }
    }

    return avatar;
  }
}

/// Name label below the avatar — truncated with ellipsis to fit the slot width.
class _PlayerName extends StatelessWidget {
  final PlayerDisplay player;
  final AppTokens tokens;
  final bool isDimmed;

  const _PlayerName({
    required this.player,
    required this.tokens,
    required this.isDimmed,
  });

  @override
  Widget build(BuildContext context) {
    final Color nameColor = isDimmed
        ? tokens.colors.onDisabled
        : tokens.colors.onBackground;

    // "(You)" suffix for current player.
    final String label = player.isCurrentPlayer
        ? '${player.displayName} (You)'
        : player.displayName;

    return Text(
      label,
      style: tokens.typography.caption.copyWith(color: nameColor),
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
