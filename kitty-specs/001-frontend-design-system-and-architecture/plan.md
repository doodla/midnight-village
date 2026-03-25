# Implementation Plan: Frontend Design System & Architecture

**Branch**: `001-frontend-design-system-and-architecture` | **Date**: 2026-03-24 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `kitty-specs/001-frontend-design-system-and-architecture/spec.md`

## Summary

Build a themeable design system for Midnight Village with a custom Riverpod-based token provider, Material ThemeData bridge, core UI components, and game-specific components for all ONUW v1 screens. Includes a frontend architecture playbook defining how game features are structured, how WebSocket events flow through Riverpod state, and how game phases drive navigation. Accompanied by a testing strategy covering unit, widget, and theme compatibility tests. The default "Midnight Village" theme evokes a mysterious village at night by firelight — warm ambers/oranges, deep blues/indigos, muted earth tones, and atmospheric serif headings.

## Technical Context

**Language/Version**: Dart 3.10+, Flutter 3.38.5
**Primary Dependencies**: Riverpod 3.x (codegen), GoRouter 17.x, Dio 5.x, Freezed 3.x, flutter_svg (new)
**Storage**: N/A (design system is purely UI)
**Testing**: flutter_test + mocktail, 80% coverage enforced
**Target Platform**: Web (Chrome), iOS, Android — phones as primary form factor (360dp+ width)
**Project Type**: Mobile + Web (Flutter cross-platform)
**Performance Goals**: Theme switch within single frame rebuild. SVG role card rasterization < 50ms on mid-range device.
**Constraints**: Offline-capable fonts (bundled, no network dependency). All components themed via tokens — zero hardcoded visual values.
**Scale/Scope**: 12 v1 role cards, ~12 game screens, 3-10 players per game, core + game component libraries

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| Server-authoritative | PASS | Design system is purely client-side UI. No game logic. Components display server-provided state. |
| Hidden information | PASS | Components render only what the server sends. Role card component takes role data as input — doesn't know about other players. |
| State machine | PASS | Phase indicator component renders current phase from server state. No client-side phase transitions. |
| Atomicity | N/A | No game state mutations in design system. |
| Determinism | N/A | No randomness in UI components. |
| Separate game apps | PASS | Design system is in `lib/design_system/`, not in a game app. Game-specific components are in `components/game/` but have no backend coupling. |
| 80% test coverage | GATE | Must be met for all design system code. Widget tests for every component. |
| No hardcoded styles | GATE | FR-004/SC-002: All visual properties from tokens. Verified by code review and tests. |
| Commit format | GATE | `type(scope): description` — use `feat(design-system):`, `test(design-system):`, etc. |

**Post-Phase 1 re-check**: Token contract is an abstract class — compiler enforces completeness. Riverpod provider + Material bridge keeps design system decoupled from game logic. No constitution violations.

## Project Structure

### Documentation (this feature)

```
kitty-specs/001-frontend-design-system-and-architecture/
├── plan.md              # This file
├── research.md          # Phase 0 research findings
├── data-model.md        # Token contract, component prop models, theme entity
├── quickstart.md        # How to use the design system in a new screen
├── contracts/           # Token contract interface, component APIs
└── tasks.md             # Phase 2 output (created by /spec-kitty.tasks)
```

### Source Code (repository root)

```
frontend/
├── lib/
│   ├── core/                          # Existing — infrastructure
│   │   ├── api/
│   │   ├── config/
│   │   ├── logging/
│   │   ├── router/
│   │   └── storage/
│   ├── design_system/                 # NEW — visual language and component library
│   │   ├── tokens/
│   │   │   ├── app_tokens.dart        # Abstract contract: AppTokens, AppColorTokens, etc.
│   │   │   ├── app_tokens_provider.dart  # Riverpod Notifier: ActiveTheme provider
│   │   │   ├── theme_bridge.dart      # Generates ThemeData from AppTokens for MaterialApp
│   │   │   ├── theme_assets.dart      # Theme-specific asset paths (icons, card backs)
│   │   │   └── midnight_village_theme.dart  # Default theme implementation
│   │   ├── models/
│   │   │   ├── role.dart              # RoleId, TeamId enums with team color mapping
│   │   │   ├── game_phase.dart        # GamePhase enum
│   │   │   ├── night_action.dart      # NightActionType enum, NightActionSelection sealed class
│   │   │   ├── player_display.dart    # PlayerDisplay, PlayerStatus data models
│   │   │   └── game_result.dart       # VoteResult, GameResult, PlayerResult models
│   │   └── components/
│   │       ├── core/                  # Universal building blocks
│   │       │   ├── mv_button.dart     # Primary, secondary, destructive buttons
│   │       │   ├── mv_card.dart       # Content container with header/footer
│   │       │   ├── mv_text_input.dart # Input with label, hint, error states
│   │       │   ├── mv_dialog.dart     # Confirmation, info, error dialogs
│   │       │   ├── mv_scaffold.dart   # Page layout: app bar, body, bottom bar
│   │       │   ├── mv_loading.dart    # Loading indicator
│   │       │   ├── mv_error.dart      # Error display with retry
│   │       │   └── mv_empty.dart      # Empty state with message + optional action
│   │       └── game/                  # Game-specific patterns
│   │           ├── role_card.dart     # Face-up/face-down, 12 roles, team colors
│   │           ├── role_token_list.dart # Public info: which roles are in play
│   │           ├── center_cards.dart  # 3 center cards display
│   │           ├── player_circle.dart # Player list with selection (3-10 players)
│   │           ├── phase_indicator.dart # Current game phase display
│   │           ├── game_timer.dart    # Countdown timer (discussion, night actions)
│   │           ├── night_action_prompt.dart # Action UI per action type
│   │           ├── vote_submission.dart    # Vote target selection with privacy
│   │           ├── vote_reveal.dart   # Simultaneous vote display + tally
│   │           └── game_results.dart  # Win/loss, team reveals, role reveals
│   ├── features/                      # Existing — feature modules
│   │   ├── auth/
│   │   └── game/                      # Future — uses design system components
│   └── app.dart                       # MODIFIED — add token provider + ThemeData bridge
├── test/
│   ├── design_system/                 # NEW — mirrors lib/design_system/
│   │   ├── tokens/
│   │   │   ├── app_tokens_test.dart
│   │   │   ├── app_tokens_provider_test.dart
│   │   │   ├── theme_bridge_test.dart
│   │   │   └── midnight_village_theme_test.dart
│   │   ├── components/
│   │   │   ├── core/
│   │   │   │   ├── mv_button_test.dart
│   │   │   │   └── ... (one test per component)
│   │   │   └── game/
│   │   │       ├── role_card_test.dart
│   │   │       └── ... (one test per component)
│   │   └── test_helpers/
│   │       ├── test_theme.dart        # Stub theme for testing
│   │       └── pump_with_tokens.dart  # Helper to wrap widget with token provider
│   └── ...                            # Existing test directories
└── assets/                            # NEW
    ├── themes/
    │   ├── midnight-village/
    │   │   ├── roles/                 # Placeholder SVGs (later: real illustrations)
    │   │   └── card-back.svg
    │   └── _placeholder/             # Minimal test theme assets
    │       ├── roles/
    │       └── card-back.svg
    └── fonts/                         # Bundled font families
        ├── [heading-font]/
        └── [body-font]/
```

**Structure Decision**: `lib/design_system/` as a top-level peer to `core/` and `features/`. The design system is a first-class concern — not infrastructure (core) and not a feature. Components split into `core/` (universal) and `game/` (ONUW-specific). Tests mirror source tree. No barrel files — direct imports consistent with existing codebase style.

## Parallel Work Analysis

### Dependency Graph

```
Phase A: Foundation (tokens + provider + bridge + test helpers)
    ↓
Phase B: Core Components (all independent of each other, parallel within phase)
    │   ├── mv_button
    │   ├── mv_card
    │   ├── mv_text_input
    │   ├── mv_dialog
    │   ├── mv_scaffold
    │   ├── mv_loading
    │   └── mv_error
    ↓
Phase C: Game Components (some independent, some depend on core components)
    │   ├── role_card (depends on mv_card)
    │   ├── role_token_list (depends on role_card)
    │   ├── center_cards (depends on role_card)
    │   ├── player_circle (independent)
    │   ├── phase_indicator (independent)
    │   ├── game_timer (independent)
    │   ├── night_action_prompt (depends on player_circle, role_card, game_timer)
    │   ├── vote_submission (depends on player_circle)
    │   ├── vote_reveal (depends on player_circle)
    │   └── game_results (depends on role_card, player_circle)
    ↓
Phase D: Architecture Playbook + Testing Strategy (docs, depends on patterns established in A-C)
    ↓
Phase E: Integration (wire into app.dart, update existing auth screen to use design system)
```

### Work Distribution

- **Sequential work (must be first)**: Token contract, provider, Material bridge, test helpers. Everything else depends on these.
- **Parallel streams within Phase B**: All 7 core components are independent — can be built in any order or simultaneously.
- **Parallel streams within Phase C**: `player_circle`, `phase_indicator`, `game_timer` are independent. `role_card` must come before `role_token_list`, `center_cards`, and components that compose it. `night_action_prompt` is the most complex — depends on multiple other game components.

### Coordination Points

- **After Phase A**: Verify token contract is complete, provider works, Material bridge generates valid ThemeData. All subsequent work depends on this.
- **After Phase B**: Verify core components all render with default + test theme. Ready for game components to compose them.
- **After Phase C**: Full component catalog. Architecture playbook can document actual patterns used.
- **After Phase E**: Auth screen migrated to design system. `just check` and `just flutter-test` pass.

## Complexity Tracking

*No constitution violations requiring justification.*

| Decision | Rationale |
|----------|-----------|
| Custom token provider (not ThemeData) | User chose this for cleaner separation. Bridged to Material via ThemeData generation. |
| `flutter_svg` dependency added | Required for themed SVG illustrations. Minimal cost — well-established Flutter package. |
| Bundled fonts (not google_fonts) | Offline-capable for in-person gameplay. No network dependency. |
| `mv_` component prefix | Avoids shadowing Flutter's built-in widget names (Card, Button) in IDE autocomplete. |
