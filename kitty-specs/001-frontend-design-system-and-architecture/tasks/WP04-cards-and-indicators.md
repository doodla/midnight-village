---
work_package_id: WP04
title: Game Components – Cards & Indicators
lane: planned
dependencies: [WP02, WP03]
subtasks:
- T021
- T022
- T023
- T024
- T025
phase: Phase C - Game Components
assignee: ''
agent: ''
shell_pid: ''
review_status: ''
reviewed_by: ''
history:
- timestamp: '2026-03-25T01:34:57Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
requirement_refs:
- FR-006
- FR-007
- FR-017
- FR-018
- FR-019
- FR-020
---

# Work Package Prompt: WP04 – Game Components – Cards & Indicators

## ⚠️ IMPORTANT: Review Feedback Status

**Read this first if you are implementing this task!**

- **Has review feedback?**: Check the `review_status` field above. If it says `has_feedback`, scroll to the **Review Feedback** section immediately.
- **You must address all feedback** before your work is complete.

---

## Review Feedback

*[This section is empty initially.]*

---

## Objectives & Success Criteria

Build the game-specific display components that show role information and game state:

1. **RoleCard** — Face-up/face-down card with team color, role icon, and role name for all 12 v1 roles.
2. **RoleTokenList** — Compact display of which roles are in the current game (public info).
3. **CenterCards** — 3 center cards, face-down or partially revealed.
4. **PhaseIndicator** — Shows current game phase with visual differentiation across 5 phases.
5. **GameTimer** — Countdown display with urgency color shift, readable at a glance (48dp+ digits).

**Success criteria**:
- All 12 role cards render with correct team colors and are visually distinguishable
- Face-down cards show card-back design without leaking role information
- PhaseIndicator clearly distinguishes all 5 phases
- GameTimer text is ≥48dp, readable from arm's length
- Timer color shifts from `timerNormal` to `timerUrgent` at low time
- All components render on 360dp width without layout overflow

**Implementation command**: `spec-kitty implement WP04 --base WP03`

## Context & Constraints

**Key documents**:
- Component APIs: `kitty-specs/001-frontend-design-system-and-architecture/contracts/component-api.md`
- Data model: `kitty-specs/001-frontend-design-system-and-architecture/data-model.md` (RoleId, GamePhase enums)

**Prerequisite code (from WP01-WP03)**:
- Token system: `frontend/lib/design_system/tokens/` (AppTokens, provider, bridge)
- Domain models: `frontend/lib/design_system/models/` (RoleId, TeamId, GamePhase)
- Core components: `frontend/lib/design_system/components/core/` (MvCard used by RoleCard)

**Constraints**:
- All components are `ConsumerWidget` reading `activeThemeProvider`
- Game components live in `frontend/lib/design_system/components/game/`
- Role illustrations are placeholder Material Icons for now (SVG later)
- Components are pure display widgets — no game logic, no API calls

## Subtasks & Detailed Guidance

### Subtask T021 – Create RoleCard component

- **Purpose**: Visual representation of a game role. Used during role reveal, night action results, and end-game reveals. The most visible game component.
- **File**: `frontend/lib/design_system/components/game/role_card.dart`
- **Steps**:
  1. Create `RoleCard` widget:
     ```dart
     class RoleCard extends ConsumerWidget {
       final RoleId role;
       final bool isFaceUp;
       final double? width;  // defaults to responsive sizing

       const RoleCard({
         super.key,
         required this.role,
         this.isFaceUp = true,
         this.width,
       });
     }
     ```
  2. **Face-up state**:
     - Use `MvCard` as the container with slightly elevated styling
     - Top border or accent in team color: `role.teamColor(tokens.colors)`
     - Role icon: `Icon(role.placeholderIcon)` centered, sized prominently (e.g., 48dp)
     - Icon color: team color
     - Role name: `tokens.typography.subheading` style, centered below icon
     - Card background: `tokens.colors.surface`
     - Minimum card size: `width ?? 120dp` wide, proportional height (e.g., 1.4:1 aspect ratio)
  3. **Face-down state**:
     - Same card dimensions as face-up
     - Background: `tokens.colors.cardBack`
     - Display: A generic card-back design — center a subtle icon (e.g., `Icons.question_mark` or a moon icon) in muted color
     - **CRITICAL**: No role information visible when face-down. No text, no role-specific icon.
  4. Consider responsive width: On smaller screens, cards should shrink proportionally.
- **Validation**:
  - [ ] Werewolf card: red team border, `Icons.pets`, "Werewolf" text
  - [ ] Seer card: blue team border, `Icons.visibility`, "Seer" text
  - [ ] Tanner card: gold/amber team border, `Icons.work`, "Tanner" text
  - [ ] Face-down: No role info visible, card-back color applied
  - [ ] All 12 roles render with distinct icons and correct team colors
  - [ ] Card respects width parameter and maintains aspect ratio

### Subtask T022 – Create RoleTokenList component

- **Purpose**: Show which roles are in the current game. Public information visible to all players. Displayed in lobby and during game.
- **File**: `frontend/lib/design_system/components/game/role_token_list.dart`
- **Steps**:
  1. Create `RoleTokenList` widget:
     ```dart
     class RoleTokenList extends ConsumerWidget {
       final List<RoleId> rolesInGame;
       const RoleTokenList({super.key, required this.rolesInGame});
     }
     ```
  2. Build: `Wrap` widget containing small role badges:
     - Each badge: Small chip/pill showing role icon + abbreviated name
     - Background: `tokens.colors.surface`
     - Border/accent: Team color for that role
     - Icon: Small (16dp) placeholder icon
     - Text: `tokens.typography.caption` with role display name
     - Spacing: `tokens.spacing.xs` between badges
  3. Must be legible on phone screen with 8 roles (typical game). Test with maximum of 12 roles.
  4. Consider horizontal scrolling for overflow, or use `Wrap` for multi-row layout.
- **Parallel?**: Yes — independent of T023-T025.
- **Validation**:
  - [ ] All roles in list render as badges
  - [ ] Team colors are visible on each badge
  - [ ] Layout handles 3 roles (minimum game) and 8 roles (typical) without overflow
  - [ ] Readable on 360dp width

### Subtask T023 – Create CenterCards component

- **Purpose**: Display the 3 center cards — typically face-down during play, optionally revealed at game end or during Seer peek.
- **File**: `frontend/lib/design_system/components/game/center_cards.dart`
- **Steps**:
  1. Create `CenterCards` widget:
     ```dart
     class CenterCards extends ConsumerWidget {
       final int count;  // always 3 for v1
       final List<RoleId>? revealedRoles;  // null = all face-down

       const CenterCards({
         super.key,
         this.count = 3,
         this.revealedRoles,
       });
     }
     ```
  2. Build: Row of `count` cards, each using `RoleCard`:
     - If `revealedRoles` is null: all cards face-down
     - If `revealedRoles` has entries: revealed cards are face-up, remaining are face-down
     - Cards should be smaller than player role cards (e.g., 80dp wide)
     - Labels: "Center 1", "Center 2", "Center 3" below each card
  3. Spacing: `tokens.spacing.s` between cards
  4. Center the row horizontally
- **Parallel?**: Yes.
- **Validation**:
  - [ ] 3 face-down cards render by default
  - [ ] Providing `revealedRoles` reveals those cards face-up
  - [ ] Partial reveal works (e.g., 2 revealed, 1 face-down)
  - [ ] Cards fit on phone screen width

### Subtask T024 – Create PhaseIndicator component

- **Purpose**: Shows current game phase so players always know where they are. Visible throughout the game.
- **File**: `frontend/lib/design_system/components/game/phase_indicator.dart`
- **Steps**:
  1. Create `PhaseIndicator` widget:
     ```dart
     class PhaseIndicator extends ConsumerWidget {
       final GamePhase currentPhase;
       const PhaseIndicator({super.key, required this.currentPhase});
     }
     ```
  2. Build: Horizontal stepper-style display showing all 5 phases:
     - Each phase: label text + indicator dot/circle
     - Current phase: Highlighted with `tokens.colors.primary` + bold text
     - Past phases: Muted with `tokens.colors.disabled` + completed indicator
     - Future phases: Outlined/empty with `tokens.colors.outline`
     - Connecting lines between phases (optional, space permitting)
  3. Phase labels: Use `GamePhase.displayName` with `tokens.typography.caption`
  4. Current phase label: Use `tokens.typography.label` (slightly larger/bolder)
  5. Compact enough for phone app bar or top-of-screen placement
- **Parallel?**: Yes.
- **Validation**:
  - [ ] Each of 5 phases renders with distinct visual state (past/current/future)
  - [ ] Current phase is clearly highlighted (primary color)
  - [ ] Phase labels are readable on phone screen
  - [ ] Compact enough to fit in app bar area

### Subtask T025 – Create GameTimer component

- **Purpose**: Countdown timer display for discussion and night action phases. Must be readable at a glance since players are talking face-to-face.
- **File**: `frontend/lib/design_system/components/game/game_timer.dart`
- **Steps**:
  1. Create `GameTimer` widget:
     ```dart
     class GameTimer extends ConsumerWidget {
       final Duration remaining;
       final Duration total;
       final bool showUrgency;  // color shift at low time

       const GameTimer({
         super.key,
         required this.remaining,
         required this.total,
         this.showUrgency = true,
       });
     }
     ```
  2. Build:
     - Format remaining as `M:SS` (e.g., `5:00`, `0:15`)
     - Text size: **Minimum 48dp** (`tokens.typography.displayHeading` is a good starting point, but override font size if needed to reach 48dp)
     - Color logic (when `showUrgency` is true):
       - Normal: `tokens.colors.timerNormal`
       - Urgent (remaining ≤ 20% of total): `tokens.colors.timerUrgent`
     - Center the timer text
     - Optional: circular progress indicator ring around the time showing proportion remaining (using `tokens.colors.primary` for the ring, `tokens.colors.outline` for the track)
  3. This is a **pure display widget** — no countdown logic. The parent provides `remaining` via a `Timer` or server-driven state. The widget just renders what it's given.
  4. High contrast: Timer text must be legible on dark background at arm's length.
- **Notes**: The 48dp minimum is non-negotiable (SC-007 in spec). This is a game played in person — players glance at their phones during face-to-face conversation.
- **Parallel?**: Yes.
- **Validation**:
  - [ ] Timer text is ≥48dp font size
  - [ ] Format is M:SS (e.g., "5:00", "0:03")
  - [ ] Normal state: timer uses `timerNormal` color
  - [ ] Urgent state (≤20% remaining): timer uses `timerUrgent` color
  - [ ] Readable on dark background from arm's length
  - [ ] Edge: 0:00 renders correctly

## Risks & Mitigations

- **RoleCard aspect ratio**: Fixed aspect ratio (1.4:1) prevents distortion across screen sizes. Use `AspectRatio` widget.
- **PhaseIndicator overflow**: 5 phases with labels on a narrow phone screen. Use compact labels and consider abbreviation if needed (e.g., "Disc." for "Discussion").
- **GameTimer font size**: 48dp is large. Ensure it doesn't push other content off-screen. Timer should be the dominant element when visible.
- **RoleTokenList with 12 roles**: Maximum case. Use `Wrap` widget which auto-wraps to multiple rows.

## Review Guidance

- **Team colors**: Verify all 12 roles show correct team color (werewolf=red, village=blue, independent=gold).
- **Face-down security**: Inspect face-down RoleCard — zero role information must be visible (no text, no role icon, no clues).
- **Timer readability**: View GameTimer at 48dp+ on a phone screen. Is it readable at arm's length?
- **Layout on 360dp**: All components must fit on minimum phone width without horizontal overflow.
- **No hardcoded values**: All colors, typography, spacing from tokens.

## Activity Log

- 2026-03-25T01:34:57Z – system – lane=planned – Prompt created.
