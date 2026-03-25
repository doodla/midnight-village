# Flutter Component Inventory — Midnight Village

Derived from reviewing all 14 Stitch UI mocks. This document maps every reusable widget needed to implement the frontend, organized by category. Components are listed with where they appear, their variants, and their data requirements.

---

## 1. Design Foundation

### 1.1 Theme (`lib/core/theme/`)

These are not widgets but the foundational tokens consumed by all widgets.

#### `AppColors`
Static color constants derived from the Stitch design system.

| Token | Hex | Dart Name | Usage |
|-------|-----|-----------|-------|
| Blood Ember | `#B8432F` | `emberRed` | Primary CTA, danger, werewolf accent |
| Tallow Gold | `#C8A24D` | `tallowGold` | Secondary accent, selection glow, village team |
| Moonlit Sage | `#5B8A72` | `moonSage` | Tertiary, safe indicators |
| Deep Void | `#0D0B0F` | `voidBlack` | Night phase background |
| Surface | `#1A1714` | `surface` | Cards, elevated containers |
| Surface Dark | `#0F0D0C` | `surfaceDark` | Deeper surface variant |
| On-Surface | `#E8DFD3` | `parchment` | Primary text |
| On-Surface Muted | `#9C9084` | `parchmentMuted` | Secondary text |
| Outline | `#3D362C` | `outline` | Borders, dividers |
| Werewolf Team | `#C94038` | `teamWerewolf` | Werewolf cards/badges |
| Village Team | `#C8A24D` | `teamVillage` | Village cards/badges (same as gold) |
| Independent | `#8B7D6B` | `teamIndependent` | Tanner cards/badges |

#### `AppTypography`
Google Fonts configuration. Requires `google_fonts` package.

| Style | Font | Weight | Size | Usage |
|-------|------|--------|------|-------|
| `displayLarge` | Epilogue | 700 | 32sp | Game title "MIDNIGHT VILLAGE" |
| `headlineLarge` | Epilogue | 600 | 24sp | Role names, phase titles |
| `headlineMedium` | Epilogue | 500 | 20sp | Section headers |
| `bodyLarge` | DM Sans | 400 | 16sp | Instructions, descriptions |
| `bodyMedium` | DM Sans | 400 | 14sp | Player names, secondary text |
| `labelLarge` | Space Grotesk | 600 | 48sp | Timer digits |
| `labelMedium` | Space Grotesk | 500 | 28sp | Lobby code display |
| `labelSmall` | Space Grotesk | 500 | 12sp | Badges, phase labels |

#### `AppDecorations`
Shared visual effects appearing across screens.

| Effect | CSS Equivalent | Screens Used |
|--------|---------------|--------------|
| `fireGlow` | `box-shadow: 0 0 20px rgba(184,67,47, 0.15)` | Welcome, lobby, role cards |
| `visionGlow` | Radial gradient tallow-gold center | Night result, role reveal |
| `bloodVignette` | Radial gradient ember-red edges | Elimination |
| `noiseOverlay` | SVG fractalNoise at 0.03-0.05 opacity | Night waiting, backgrounds |
| `candleGlow` | Radial gradient transparent→void from center | Role reveal, night screens |

---

## 2. Navigation & Layout

### 2.1 `VillageAppBar`
**Screens:** All screens (14/14)
**Variants:**

| Variant | Leading | Title | Trailing | Screens |
|---------|---------|-------|----------|---------|
| Brand | Castle icon | "Midnight Village" | Settings/Profile icon | Welcome, Home |
| Back | Back arrow | Text title | Optional actions | Lobby, Role Selection, Vote Reveal |
| Phase | None | Phase label (gold, small-caps) | Timer widget | Discussion, Voting |
| Minimal | None | Role name + icon | Timer ring | All night screens |
| None | — | — | — | Elimination, Results winner stage |

**Props:** `leading`, `title`, `trailing`, `variant`, `backgroundColor`

### 2.2 `VillageBottomNav`
**SKIP — DO NOT IMPLEMENT.** Stitch added bottom nav bars to several screens as a default pattern, but the game is a linear phase-based flow (lobby → night → discussion → voting → results). Navigation is driven by the state machine, not user tab-switching. A persistent bottom nav contradicts this UX. Use GoRouter for all navigation.

**If kept — tabs observed:**
- Village (fort icon)
- Roles (theater_comedy)
- Chat/Forum (forum)
- Settings (settings)

### 2.3 `PhaseTransitionOverlay`
**Screens:** Between every phase (night→discussion, discussion→voting, voting→reveal, reveal→elimination, elimination→results)
**Behavior:** Full-screen dark overlay that fades in, shows brief phase text (e.g., "Everyone open your eyes"), then fades to the new screen.
**Props:** `text`, `duration`, `onComplete`

---

## 3. Player Components

### 3.1 `PlayerAvatar`
**Screens:** 11/14 (all except welcome, role reveal, elimination)
**The most reused component in the app.**

A circular avatar showing player initials in a unique hue.

**Props:** `displayName`, `colorIndex`, `size` (small/medium/large), `sigil` (optional icon)
**Sizes:** Small (32dp) for lists, Medium (48dp) for grids, Large (64dp) for featured

### 3.2 `PlayerTile`
**Screens:** Lobby (ready list), Discussion (player list), Results (role table)
**A horizontal list item with avatar, name, and trailing status.**

| Variant | Trailing Content | Screen |
|---------|-----------------|--------|
| Ready status | Green check / grey circle | Lobby |
| Host badge | "Host" chip | Lobby |
| Claimed role | Role badge chip | Discussion |
| Role reveal | Original → Final role, outcome badge | Results |
| Vote target | "Voted for: X" text | Results |

**Props:** `player`, `trailing`, `isCurrentUser` (highlighted border), `isHost`, `onTap`

### 3.3 `PlayerCard`
**Screens:** Night actions (Seer, Robber, Troublemaker), Voting
**A tappable card in a grid layout showing avatar + name. Supports selection state.**

**States:**
- Default: Dark surface, avatar, name
- Selected: Gold (#C8A24D) glowing border (night) or red (#B8432F) border (voting)
- Voted: Checkmark overlay (voting screen)
- Disabled: Greyed out, non-interactive (self in voting)
- Numbered: Selection order badge "1", "2" (Troublemaker)
- Dimmed: Non-selected when others are selected

**Props:** `player`, `isSelected`, `isDisabled`, `selectionIndex`, `hasVoted`, `onTap`

### 3.4 `PlayerGrid`
**Screens:** Night actions, Voting
**A responsive grid of `PlayerCard` widgets.**

**Layout:** 2-column grid with consistent spacing. If odd number of players, last card centered. Adapts to 3-10 players.

**Props:** `players`, `selectedIds`, `maxSelections` (1 for Seer/Robber/Voting, 2 for Troublemaker), `disabledIds`, `onSelectionChanged`

---

## 4. Role Components

### 4.1 `RoleCard`
**Screens:** Role Reveal, Night Action Result
**A large portrait card showing a role's identity.**

**Structure:**
```
┌─────────────────────────┐
│ ▓▓▓ team color bar ▓▓▓  │
│                         │
│      [Role Icon]        │
│                         │
│       ROLE NAME         │
│    "Team Label"         │
│  ─────────────────      │
│  Role description text  │
│                         │
└─────────────────────────┘
```

**Props:** `roleName`, `team`, `description`, `icon`, `isRevealed` (for flip animation)
**Animation:** 3D Y-axis flip from face-down to face-up (~600ms)

**States:**
- Face down: Dark patterned back, no role info
- Face up: Full role display
- Eliminated: Desaturated, slight rotation, dark overlay

### 4.2 `RoleBadge`
**Screens:** Discussion (your info, claimed roles), Role Selection, Results
**A compact inline chip showing a role name with team color.**

**Structure:** `[team-color dot] RoleName`
**Props:** `roleName`, `team`, `size` (compact/standard)

### 4.3 `RoleSelectionCard`
**Screens:** Role Selection (host only)
**A list tile for picking how many of each role to include.**

**Structure:**
```
┌────────────────────────────────────────────┐
│ [●] Werewolf                    [- 2 +]   │
│     "Knows other werewolves"               │
└────────────────────────────────────────────┘
```

**Props:** `role`, `count`, `minCount`, `maxCount`, `onCountChanged`
**Special:** Mason stepper jumps 0→2→0 (skips 1)

### 4.4 `TeamSectionHeader`
**Screens:** Role Selection, Results
**A section divider with team name and colored accent bar.**

**Structure:** Colored left bar + team name in small-caps
**Colors:** Red (#C94038) for Werewolf, Gold (#C8A24D) for Village, Grey (#8B7D6B) for Independent
**Props:** `teamName`, `teamColor`

---

## 5. Timer Components

### 5.1 `CountdownTimer`
**Screens:** Discussion, Voting
**A text-based countdown display.**

**Format:** `MM:SS` in Space Grotesk monospace
**Color ramp:** Gold (>50%) → Amber (25-50%) → Red pulse (10-25%) → Red fast pulse (<10%)
**Props:** `duration`, `remaining`, `onExpired`

### 5.2 `TimerRing`
**Screens:** Role Reveal, all Night Action screens
**A circular arc timer that depletes clockwise.**

**Structure:** SVG/CustomPainter circle with a thick (4dp) stroke arc. Digits in center.
**Animation:** `stroke-dashoffset` transition for smooth depletion
**Color ramp:** Same as CountdownTimer
**Props:** `duration`, `remaining`, `size`, `strokeWidth`

### 5.3 `VoteCounter`
**Screens:** Voting
**Shows "X/Y VOTES" as votes come in.**

**Props:** `submitted`, `total`

---

## 6. Action Components

### 6.1 `PrimaryButton`
**Screens:** All screens (14/14)
**Full-width filled button in ember red.**

**Variants:**
- Default: Ember red background, parchment text
- Disabled: Desaturated, reduced opacity
- Loading: Circular progress indicator replaces text
- Outlined: For secondary actions (e.g., "End Discussion Early", "Leave")

**Props:** `label`, `onPressed`, `isLoading`, `isEnabled`, `icon`, `variant`

### 6.2 `ActionChoiceCards`
**Screens:** Seer Night Action
**Two side-by-side tappable cards for choosing between action modes.**

**Structure:**
```
┌──────────┐  ┌──────────┐
│  [icon]  │  │  [icon]  │
│ "Peek    │  │ "Peek    │
│  Player" │  │  Center" │
│  desc    │  │  desc    │
└──────────┘  └──────────┘
```

**Props:** `options` (list of `{icon, title, description}`), `selectedIndex`, `onSelected`

### 6.3 `ConfirmPanel`
**Screens:** Voting
**A bottom-anchored panel that slides up when a selection is made.**

**Structure:** Dark surface with confirmation text + "CONFIRM" button + "Change" text button
**Animation:** Slide up from bottom (300ms)
**Props:** `text`, `onConfirm`, `onCancel`

### 6.4 `CountStepper`
**Screens:** Role Selection
**A +/- stepper control for adjusting role counts.**

**Structure:** `[- button] [count] [+ button]`
**Props:** `value`, `min`, `max`, `step` (usually 1, but 2 for Masons), `onChanged`

---

## 7. Information Display Components

### 7.1 `YourInfoCard`
**Screens:** Discussion
**A compact expandable card showing your role and night knowledge.**

**Structure:**
```
┌────────────────────────────────────────┐
│ [eye icon] SEER    You saw Carol's     │
│                    card: Werewolf      │
└────────────────────────────────────────┘
```

**Props:** `roleName`, `roleIcon`, `nightSummary`
**Night summary is generated client-side** from `night_action_data` based on role type.

### 7.2 `RolesInPlayChips`
**Screens:** Discussion
**A collapsible wrap of role badge chips showing all roles in the game.**

**Structure:** Expandable section header + Wrap of `RoleBadge` chips with count suffixes ("x2")
**Props:** `roles` (map of role→count), `isExpanded`, `onToggle`

### 7.3 `LobbyCodeDisplay`
**Screens:** Lobby (hero), Home (input)
**Large monospace display of the lobby code.**

**Variants:**
- Display: Large gold text, letter-spaced, tap to copy
- Input: 6 individual character cells with underline, auto-advance

**Display props:** `code`, `onTap` (copy)
**Input props:** `onComplete(code)`, `controller`

### 7.4 `ValidationBanner`
**Screens:** Role Selection
**An error/warning banner for role configuration issues.**

**Props:** `errors` (list of strings), `severity` (error/warning)

---

## 8. Vote & Results Components

### 8.1 `VoteArrowRow`
**Screens:** Vote Reveal
**A single row showing voter → target.**

**Structure:** `[VoterName]  ──────>  [TargetName]`
**Animation:** Fade in from left, arrow draws (400ms per row, staggered)
**Props:** `voterName`, `targetName`, `animationDelay`

### 8.2 `TallyBar`
**Screens:** Vote Reveal
**A horizontal bar chart row for vote counts.**

**Structure:** `[PlayerName] [████████] N votes`
**Colors:** Red for max votes, grey for others
**Animation:** Bar width animates from 0 → proportional width (500ms)
**Props:** `playerName`, `voteCount`, `maxVotes`, `isMaximum`

### 8.3 `EliminationAnnouncement`
**Screens:** Elimination
**Full-screen dramatic name display.**

**Variants:**
- Eliminated: Red name, skull icon, "has been eliminated"
- No elimination: Blue/muted "NO ONE DIES"
- Hunter chain: Second elimination appears after 2s delay

**Props:** `eliminatedPlayers`, `hunterChain`
**Effects:** `bloodVignette` background, `skull-glow` drop-shadow filter, `loading-pulse` animation

### 8.4 `WinnerBanner`
**Screens:** Results (Stage 1)
**Full-screen winner announcement with personal outcome.**

**Structure:**
```
    WEREWOLVES WIN!
  No Werewolf was eliminated.
        YOU LOSE
```

**Colors by winner:** Village → gold, Werewolf → red, Tanner → grey, Nobody → muted
**Props:** `winningTeams`, `reason`, `personalOutcome` (win/lose)

### 8.5 `PlayerRoleRow`
**Screens:** Results (Stage 2)
**A detailed row for each player in the results table.**

**Structure:**
```
┌────────────────────────────────────────┐
│ [Avatar] Alice                  [LOSE] │
│          Robber → Werewolf      [💀]   │
│          Voted for: Carol              │
└────────────────────────────────────────┘
```

**Props:** `player`, `originalRole`, `finalRole`, `outcome`, `isEliminated`, `voteTarget`, `isCurrentUser`
**Special:** Arrow between roles only shown when `originalRole != finalRole`

### 8.6 `NightLogSection`
**Screens:** Results (Stage 3)
**A collapsible section showing the chronological night action log.**

**Structure:** Wave headers with action entries formatted as human-readable text.
**Text generation:** Client-side from structured `night_actions_log` data.
**Props:** `nightActions` (list), `isExpanded`, `onToggle`

---

## 9. Atmospheric Components

### 9.1 `AtmosphericBackground`
**Screens:** All screens
**The background layer that sets the mood per phase.**

**Variants:**

| Phase | Background | Overlay |
|-------|-----------|---------|
| Pre-game | Tavern texture image | Radial ember gradient |
| Lobby | Village scene image | Warm glow, noise grain |
| Night | Solid void (#0D0B0F) | Candle glow center, noise |
| Discussion | Slightly warmer (#151210) | Subtle grain |
| Voting | Tense dark (#12100E) | Radial glow |
| Results | Dark (#0F0D0B) | Team-tinted wash |

**Props:** `phase`, `child`

### 9.2 `WaveProgressDots`
**Screens:** Night Waiting
**A 4-dot indicator showing night wave progress.**

**States per dot:** Completed (dim gold fill), Active (bright gold fill), Pending (grey outline)
**Props:** `currentWave`, `totalWaves`

### 9.3 `NightWaitingDisplay`
**Screens:** Night Waiting
**The atmospheric waiting screen content — moon icon, "The village sleeps...", wave dots.**

**Props:** `currentWave`, `totalWaves`

---

## 10. New Components (from additional screen states)

After generating additional screen mocks (Werewolf reveal, Drunk action, See Team, No One Dies, Village Wins), the following new components were identified:

### 10.1 `CenterCardSlot`
**Screens:** Drunk Night Action, Seer Peek Center
**A face-down card slot representing a center card.**

**Structure:** Dark card (#1A1714) with "?" symbol, label "Card 1/2/3" below. Selectable with gold glow.
**States:** Unselected (dark, muted "?"), Selected (gold border glow)
**Props:** `index`, `isSelected`, `onTap`

### 10.2 `CenterCardRow`
**Screens:** Drunk Night Action, Seer Peek Center
**A horizontal row of 3 `CenterCardSlot` widgets.**

**Props:** `selectedIndices`, `maxSelections` (1 for Drunk, 2 for Seer), `onSelectionChanged`

### 10.3 `TeamRevealCard`
**Screens:** Werewolves See Team, Masons See Team, Minion See Werewolves
**A player card with team-colored glow showing a revealed teammate.**

Different from `PlayerCard` (which is for selection). This is display-only with team tint.
**Structure:** Avatar with team-colored border/glow + name + team label
**Props:** `player`, `teamColor`, `label` (e.g., "Werewolf", "Mason")

### 10.4 `TeamRevealDisplay`
**Screens:** All "See Team" night actions
**Container for `TeamRevealCard` widgets with header and summary text.**

**Variants:**
- Multiple teammates: "Your Pack" header, cards side by side
- Lone wolf/mason: "You are alone" message + optional center peek prompt
- Minion: "The Werewolves are:" header, cards shown

**Props:** `teammates`, `teamName`, `summaryText`, `isLone`

### 10.5 `OutcomeBadge`
**Screens:** Results
**A small colored chip showing WIN or LOSE.**

**Colors:** Win → moonSage (#5B8A72), Lose → teamWerewolf (#C94038)
**Props:** `outcome` (win/lose), `size`

### 10.6 `SkipButton`
**Screens:** Night Action Result (auto-dismiss), optional on Seer/Robber/Troublemaker
**A small dismissive text button for skipping or fast-forwarding.**

**Structure:** Small "Skip" text or close icon, positioned top-right or bottom
**Props:** `onTap`, `label`

### 10.7 `ErrorSnackBar`
**Screens:** Welcome (network error), Home (lobby errors), Lobby (connection errors)
**A themed snackbar for error messages.**

Not a standalone widget — use Flutter's `ScaffoldMessenger.showSnackBar` with consistent styling:
- Background: `AppColors.surface`
- Text: `AppColors.parchment`
- Action: `AppColors.tallowGold`
- Border: 1px `AppColors.outline`

### 10.8 `ReconnectionBanner`
**Screens:** Lobby, Game screens
**A subtle persistent banner shown during WebSocket reconnection.**

**Structure:** Thin bar at top of screen with "Reconnecting..." text and a pulse animation
**Props:** `isVisible`

---

## 10b. Updated Component Count

| Category | Original | New | Total |
|----------|----------|-----|-------|
| Design Foundation | 3 | 0 | 3 |
| Navigation & Layout | 3 | 0 | 3 |
| Player Components | 4 | 0 | 4 |
| Role Components | 4 | 0 | 4 |
| Timer Components | 3 | 0 | 3 |
| Action Components | 4 | 0 | 4 |
| Information Display | 4 | 0 | 4 |
| Vote & Results | 6 | 1 (OutcomeBadge) | 7 |
| Atmospheric | 3 | 0 | 3 |
| **New (Night actions)** | — | 4 (CenterCard, TeamReveal) | 4 |
| **New (Chrome)** | — | 3 (Skip, Error, Reconnect) | 3 |
| **Total** | **34** | **8** | **42** |

Note: "Original" count is 34 (from the 9 original categories). Adding 8 new components = 42 total. However, `VillageBottomNav` is marked SKIP, bringing the effective total to **41 implementable components**.

---

## 11. Component → Screen Mapping (updated)

| Component | Welcome | Home | Lobby | RoleSel | Reveal | Seer | Robber | TM | Wait | Result | Discuss | Vote | VReveal | Elim | Results |
|-----------|:-------:|:----:|:-----:|:-------:|:------:|:----:|:------:|:--:|:----:|:------:|:-------:|:----:|:-------:|:----:|:-------:|
| VillageAppBar | brand | brand | back | back | minimal | minimal | minimal | minimal | — | minimal | phase | phase | back | — | — |
| PlayerAvatar | — | — | x | — | — | x | x | x | — | — | x | x | — | — | x |
| PlayerTile | — | — | x | — | — | — | — | — | — | — | x | — | — | — | x |
| PlayerCard | — | — | — | — | — | x | x | x | — | — | — | x | — | — | — |
| PlayerGrid | — | — | — | — | — | x | x | x | — | — | — | x | — | — | — |
| RoleCard | — | — | — | — | x | — | — | — | — | x | — | — | — | — | — |
| RoleBadge | — | — | — | x | — | — | — | — | — | — | x | — | — | — | x |
| TimerRing | — | — | — | — | x | x | x | x | — | x | — | — | — | — | — |
| CountdownTimer | — | — | — | — | — | — | — | — | — | — | x | x | — | — | — |
| PrimaryButton | x | x | x | x | — | x | x | x | — | — | x | x | — | — | x |
| LobbyCodeDisplay | — | x | x | — | — | — | — | — | — | — | — | — | — | — | — |
| AtmosphericBG | x | x | x | — | x | x | x | x | x | x | x | x | x | x | x |

---

## 12. File Structure

```
frontend/lib/
  core/
    theme/
      app_theme.dart              # ThemeData construction
      app_colors.dart             # Color constants
      app_typography.dart         # TextTheme with Google Fonts
      app_decorations.dart        # BoxShadow, gradient presets
    widgets/
      village_app_bar.dart        # AppBar variants
      primary_button.dart         # PrimaryButton + variants
      atmospheric_background.dart # Phase-aware background
      phase_transition_overlay.dart
  features/
    auth/
      presentation/
        welcome_screen.dart
    lobby/
      presentation/
        widgets/
          lobby_code_display.dart  # Display + input variants
          player_tile.dart         # List tile with ready/role/vote
          validation_banner.dart
          role_selection_card.dart
          count_stepper.dart
          team_section_header.dart
    game/
      presentation/
        widgets/
          player_avatar.dart       # Circular initial avatar
          player_card.dart         # Selectable grid card
          player_grid.dart         # Responsive 2-col grid
          role_card.dart           # Large portrait role card
          role_badge.dart          # Compact inline chip
          timer_ring.dart          # Circular arc timer
          countdown_timer.dart     # Text countdown
          vote_counter.dart        # X/Y votes display
          action_choice_cards.dart # Seer's peek player/center choice
          confirm_panel.dart       # Slide-up confirmation
          your_info_card.dart      # Discussion role reminder
          roles_in_play_chips.dart # Expandable role chip wrap
          wave_progress_dots.dart  # Night wave indicator
          vote_arrow_row.dart      # Voter → target row
          tally_bar.dart           # Horizontal bar chart row
          winner_banner.dart       # Full-screen win/lose
          player_role_row.dart     # Results table row
          night_log_section.dart   # Expandable night recap
          elimination_announcement.dart
          night_waiting_display.dart
```

---

## 13. Implementation Priority

### P0 — Foundation (needed by everything)
1. `AppColors`, `AppTypography`, `AppDecorations`
2. `AtmosphericBackground`
3. `VillageAppBar`
4. `PrimaryButton`
5. `PlayerAvatar`

### P1 — Lobby screens
6. `LobbyCodeDisplay`
7. `PlayerTile`
8. `RoleSelectionCard` + `CountStepper` + `TeamSectionHeader`
9. `ValidationBanner`

### P2 — Night phase
10. `RoleCard` (with flip animation)
11. `TimerRing`
12. `PlayerCard` + `PlayerGrid`
13. `ActionChoiceCards`
14. `WaveProgressDots` + `NightWaitingDisplay`
15. `RoleBadge`

### P3 — Day phase
16. `CountdownTimer`
17. `YourInfoCard`
18. `RolesInPlayChips`
19. `ConfirmPanel`
20. `VoteCounter`

### P4 — Results
21. `VoteArrowRow` + `TallyBar`
22. `EliminationAnnouncement`
23. `WinnerBanner`
24. `PlayerRoleRow`
25. `NightLogSection`
26. `PhaseTransitionOverlay`

---

## 14. Design Review Notes

Observations from reviewing the Stitch-generated HTML:

1. **Bottom nav bars:** Stitch added them to most screens. These should be **omitted** in implementation — the game is a linear flow (lobby → night → discussion → voting → results). A persistent bottom nav contradicts the phase-based UX. Navigation is driven by the state machine, not user tab-switching.

2. **Serif accent font:** Stitch introduced Libre Baskerville / Crimson Pro as a serif accent on some screens. This was not in our design system spec but adds warmth. Consider adding as a `displaySerif` style for flavor text (taglines, atmospheric text like "The night begins...").

3. **Player avatars:** Stitch used actual portrait images for player avatars. In implementation, use initial-letter circles with unique hues (we can't generate portrait art per player). The Stitch mocks show the desired *size and placement*, not the actual avatar rendering.

4. **Noise/grain overlay:** Consistently used via SVG `feTurbulence` filter at low opacity. In Flutter, implement as a `ShaderMask` or pre-rendered noise texture PNG overlay.

5. **Glow effects:** `fireGlow`, `visionGlow`, `skull-glow` are used liberally. In Flutter, use `BoxShadow` with appropriate colors and blur radii. For the timer ring glow, use a `Paint` with `MaskFilter.blur`.

6. **Material Symbols icons:** All screens use Material Symbols Outlined. Flutter's built-in `Icons` class covers most of these. For specialty icons (castle, masks, theater_comedy), use the `material_symbols_icons` package or custom SVG.
