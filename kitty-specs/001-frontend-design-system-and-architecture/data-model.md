# Data Model: Frontend Design System & Architecture

**Feature**: 001-frontend-design-system-and-architecture
**Date**: 2026-03-24

## Entities

### AppTokens (Abstract Contract)

The root token contract. All themes implement this. The Dart abstract class enforces completeness at compile time — a theme that misses any token won't compile.

**Fields**:

| Field | Type | Description |
|-------|------|-------------|
| `name` | `String` | Theme display name (e.g., "Midnight Village") |
| `colors` | `AppColorTokens` | Color palette |
| `typography` | `AppTypographyTokens` | Typography scale |
| `spacing` | `AppSpacingTokens` | Spacing scale |
| `elevation` | `AppElevationTokens` | Elevation/shadow scale |

**Constraints**:
- All implementations must be `const`-constructible and immutable
- Reference equality (`identical()`) is sufficient for change detection

---

### AppColorTokens (Abstract)

Semantic color contract. Standard colors + game-specific team colors.

| Field | Type | Description |
|-------|------|-------------|
| `primary` | `Color` | Primary interactive color (firelight amber in default theme) |
| `onPrimary` | `Color` | Text/icon on primary |
| `secondary` | `Color` | Secondary accent |
| `onSecondary` | `Color` | Text/icon on secondary |
| `surface` | `Color` | Card/container backgrounds |
| `onSurface` | `Color` | Text/icon on surface |
| `background` | `Color` | Page background (deep night sky in default theme) |
| `onBackground` | `Color` | Text/icon on background |
| `error` | `Color` | Error/destructive |
| `onError` | `Color` | Text/icon on error |
| `outline` | `Color` | Borders, dividers |
| `disabled` | `Color` | Disabled elements |
| `onDisabled` | `Color` | Text on disabled elements |
| `werewolfTeam` | `Color` | Werewolf team indicator |
| `villageTeam` | `Color` | Village team indicator |
| `independentTeam` | `Color` | Independent/Tanner team indicator |
| `timerNormal` | `Color` | Timer in normal state |
| `timerUrgent` | `Color` | Timer when time is running low |
| `cardBack` | `Color` | Face-down card color |

---

### AppTypographyTokens (Abstract)

Typography scale. Each token is a `TextStyle` carrying font family, size, weight, letter spacing, and line height.

| Field | Type | Description |
|-------|------|-------------|
| `displayHeading` | `TextStyle` | Large display text (game title, phase names). Serif/semi-serif. |
| `heading` | `TextStyle` | Section headings. Serif/semi-serif. |
| `subheading` | `TextStyle` | Sub-section headings. |
| `body` | `TextStyle` | Standard body text. Sans-serif. |
| `caption` | `TextStyle` | Small supplementary text. |
| `label` | `TextStyle` | Button labels, input labels. Medium weight. |

**Font strategy**: Bundled in `assets/fonts/`. Heading: serif/semi-serif for atmosphere. Body: clean sans-serif for readability on phones.

---

### AppSpacingTokens (Abstract)

Spacing scale as `double` values (density-independent pixels).

| Field | Type | Value (default theme) | Description |
|-------|------|-----------------------|-------------|
| `xs` | `double` | 4.0 | Minimal gap |
| `s` | `double` | 8.0 | Tight spacing |
| `m` | `double` | 16.0 | Standard spacing |
| `l` | `double` | 24.0 | Comfortable spacing |
| `xl` | `double` | 32.0 | Section separation |
| `xxl` | `double` | 48.0 | Major section separation |

---

### AppElevationTokens (Abstract)

Elevation levels for shadows/depth. Values are logical elevation in dp.

| Field | Type | Value (default theme) | Description |
|-------|------|-----------------------|-------------|
| `flat` | `double` | 0.0 | No elevation (inline elements) |
| `raised` | `double` | 2.0 | Subtle lift (cards, buttons) |
| `floating` | `double` | 6.0 | Prominent lift (floating action, popovers) |
| `overlay` | `double` | 12.0 | Modal overlays (dialogs, bottom sheets) |

---

### ThemeAssets

Asset path resolver per theme. Holds the mapping from role identities to illustration paths.

| Field | Type | Description |
|-------|------|-------------|
| `themeId` | `String` | Theme identifier matching asset directory name |
| `roleCardPath(RoleId)` | `String` | Returns asset path for a role's illustration |
| `cardBackPath` | `String` | Path to face-down card design |

**Constraints**:
- All paths must be declared in `pubspec.yaml`
- Placeholder theme uses Material Icons (no SVG files) — the component handles fallback rendering

---

### RoleId (Enum)

Identifies the 12 v1 roles. Used by components to look up team color and illustration.

| Value | Team |
|-------|------|
| `werewolf` | Werewolf |
| `minion` | Werewolf |
| `villager` | Village |
| `seer` | Village |
| `robber` | Village |
| `troublemaker` | Village |
| `drunk` | Village |
| `insomniac` | Village |
| `mason` | Village |
| `hunter` | Village |
| `tanner` | Independent |
| `doppelganger` | Village (changes on copy) |

**Derived properties**:
- `teamColor(AppColorTokens)` → returns the appropriate team color token
- `displayName` → human-readable name (e.g., "Troublemaker")

---

### TeamId (Enum)

Game teams for color-coding.

| Value | Description |
|-------|-------------|
| `werewolf` | Werewolf team |
| `village` | Village team |
| `independent` | Independent/Tanner |

---

### GamePhase (Enum)

Game phases for the phase indicator component.

| Value | Display Name |
|-------|-------------|
| `lobby` | Lobby |
| `night` | Night |
| `discussion` | Discussion |
| `voting` | Voting |
| `results` | Results |

---

### NightActionType (Enum)

Action types that drive the night action prompt component UI.

| Value | UI Pattern | Used By |
|-------|-----------|---------|
| `peekPlayer` | Select 1 player → reveal card | Seer (option A) |
| `peekCenter` | Select 2 center cards → reveal cards | Seer (option B), Lone Werewolf |
| `swapWithPlayer` | Select 1 player → swap → reveal new card | Robber |
| `swapWithCenter` | Select 1 center card → swap (blind) | Drunk |
| `swapOthers` | Select 2 players → swap (blind) | Troublemaker |
| `seeTeam` | Display teammate list | Werewolf, Mason, Minion |
| `none` | Waiting screen | Villager, Tanner, Hunter |

---

### PlayerDisplay

Data needed to render a player in the player circle component.

| Field | Type | Description |
|-------|------|-------------|
| `id` | `String` | Player identifier |
| `displayName` | `String` | Player's chosen name |
| `isCurrentPlayer` | `bool` | Whether this is the local player |
| `isSelectable` | `bool` | Whether this player can be tapped (target selection) |
| `isSelected` | `bool` | Whether this player is currently selected |
| `status` | `PlayerStatus` | Active, eliminated, or disconnected |

---

### VoteResult

Data needed to render the vote reveal.

| Field | Type | Description |
|-------|------|-------------|
| `voterId` | `String` | Who voted |
| `voterName` | `String` | Voter's display name |
| `targetId` | `String` | Who they voted for |
| `targetName` | `String` | Target's display name |

---

### GameResult

Data needed to render the win/loss results screen.

| Field | Type | Description |
|-------|------|-------------|
| `winningTeams` | `List<TeamId>` | Teams that won (can be multiple: Tanner + Village) |
| `players` | `List<PlayerResult>` | Each player's final role and outcome |

### PlayerResult

| Field | Type | Description |
|-------|------|-------------|
| `id` | `String` | Player identifier |
| `displayName` | `String` | Player name |
| `originalRole` | `RoleId` | Role dealt at start |
| `finalRole` | `RoleId` | Role at end of night (may differ from original) |
| `team` | `TeamId` | Team based on final role |
| `isEliminated` | `bool` | Whether this player was eliminated |
| `isWinner` | `bool` | Whether this player's team won |

## Relationships

```
AppTokens
├── AppColorTokens
├── AppTypographyTokens
├── AppSpacingTokens
└── AppElevationTokens

ThemeAssets (separate from AppTokens — asset paths, not visual tokens)

RoleId → TeamId (each role maps to a team)
RoleId → ThemeAssets.roleCardPath() (each role has an illustration)

NightActionType → night_action_prompt component UI variant

PlayerDisplay → player_circle component rendering
VoteResult → vote_reveal component rendering
GameResult → game_results component rendering
```

## State Transitions

### Theme Switching

```
ActiveTheme (Riverpod Notifier)
  state: AppTokens = MidnightVillageTheme()

  switchTheme(AppTokens newTheme):
    state = newTheme
    → All ref.watch(activeThemeProvider) consumers rebuild
    → ThemeData bridge recomputes MaterialApp theme
    → Single frame: all components reflect new theme
```

### Role Card States

```
FaceDown → FaceUp (role reveal, night action result, end-game reveal)
```

No reverse transition. Once revealed, a card stays face-up for that context.

### Player Selection States (player_circle)

```
Idle → Selecting (action prompt active) → Selected (target chosen) → Confirmed (action submitted)
```

Selection resets when the action completes or a new action prompt begins.
