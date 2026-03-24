# Component API Contracts

**Feature**: 001-frontend-design-system-and-architecture
**Date**: 2026-03-24

## Core Components

### MvButton

```dart
MvButton({
  required String label,
  required VoidCallback? onPressed,  // null = disabled
  MvButtonVariant variant = MvButtonVariant.primary,  // primary, secondary, destructive
  bool isLoading = false,
})
```

### MvCard

```dart
MvCard({
  required Widget child,
  Widget? header,
  Widget? footer,
  double? elevation,  // overrides theme default (raised)
  EdgeInsets? padding,  // overrides theme default (spacing.m)
})
```

### MvTextInput

```dart
MvTextInput({
  required String label,
  String? hint,
  String? errorText,
  TextEditingController? controller,
  ValueChanged<String>? onChanged,
  bool obscureText = false,
  bool enabled = true,
})
```

### MvDialog

```dart
MvDialog.confirmation({
  required String title,
  required String body,
  required String confirmLabel,
  required VoidCallback onConfirm,
  String cancelLabel = 'Cancel',
  VoidCallback? onCancel,
})

MvDialog.info({
  required String title,
  required String body,
  String dismissLabel = 'OK',
})

MvDialog.error({
  required String title,
  required String body,
  String retryLabel = 'Retry',
  VoidCallback? onRetry,
})
```

### MvScaffold

```dart
MvScaffold({
  required Widget body,
  String? title,
  List<Widget>? actions,  // app bar trailing actions
  Widget? bottomBar,
  bool showBackButton = false,
})
```

### MvLoading

```dart
MvLoading({
  String? message,
})
```

### MvError

```dart
MvError({
  required String message,
  VoidCallback? onRetry,
})
```

## Game Components

### RoleCard

```dart
RoleCard({
  required RoleId role,
  bool isFaceUp = true,
  double? width,  // defaults to responsive sizing
})
```

Renders: team-color border/background, role name, placeholder icon (later: SVG illustration). Face-down state shows card-back design.

### RoleTokenList

```dart
RoleTokenList({
  required List<RoleId> rolesInGame,
})
```

Renders: horizontal or wrapped list of role badges showing which roles are in the current game. Public information visible to all players.

### CenterCards

```dart
CenterCards({
  required int count,  // always 3 for v1
  List<RoleId>? revealedRoles,  // null = all face-down, partial = some revealed
})
```

### PlayerCircle

```dart
PlayerCircle({
  required List<PlayerDisplay> players,
  ValueChanged<String>? onPlayerSelected,  // callback with player ID
  int? maxSelections,  // 1 for vote/peek, 2 for troublemaker/seer-center
  bool showStatus = false,  // show eliminated/disconnected indicators
})
```

### PhaseIndicator

```dart
PhaseIndicator({
  required GamePhase currentPhase,
})
```

### GameTimer

```dart
GameTimer({
  required Duration remaining,
  required Duration total,
  bool showUrgency = true,  // color shift when time is low
})
```

The component is a pure display widget. The actual countdown logic lives in the data layer (driven by server time sync). The component receives `remaining` and renders it.

### NightActionPrompt

```dart
NightActionPrompt({
  required NightActionType actionType,
  required RoleId playerRole,
  required List<PlayerDisplay> players,  // for player targeting
  required int centerCardCount,          // for center targeting
  required Duration timeRemaining,
  required ValueChanged<NightActionSelection> onActionSubmitted,
  VoidCallback? onSkip,  // for optional actions
})
```

`NightActionSelection` is a sealed class covering the different selection shapes:
- `PlayerTarget(String playerId)` — peek_player, swap_with_player
- `CenterTargets(List<int> indices)` — peek_center, swap_with_center
- `TwoPlayerTargets(String player1Id, String player2Id)` — swap_others
- `NoAction()` — see_team acknowledged, skip

### VoteSubmission

```dart
VoteSubmission({
  required List<PlayerDisplay> players,
  required Duration timeRemaining,
  required ValueChanged<String> onVoteSubmitted,  // player ID
  bool isLocked = false,  // true after vote submitted
})
```

Privacy: After submission, shows generic "Vote locked in" without displaying the target name prominently.

### VoteReveal

```dart
VoteReveal({
  required List<VoteResult> votes,
  required Map<String, int> tally,  // player ID → vote count
  required List<String> eliminatedPlayerIds,
})
```

### GameResults

```dart
GameResults({
  required GameResult result,
  VoidCallback? onPlayAgain,
  VoidCallback? onReturnToLobby,
})
```

Handles: single-winner, multi-winner (Tanner + Village), no-winner, all role reveals.
