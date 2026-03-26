# Feature Specification: Firelit Gothic Design System

**Feature Branch**: `003-firelit-gothic-design-system`
**Created**: 2026-03-26
**Status**: Draft
**Input**: Replace the current design token system with the Stitch-specified "Firelit Gothic" design system and build P0 foundation components.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Visual Identity Matches Design Mocks (Priority: P1)

A developer building any game screen references the design token API via Riverpod (`ref.watch(activeThemeProvider).colors.primary`, etc.) and gets visuals that match the Stitch UI mocks: warm dark backgrounds, Blood Ember primary actions, Tallow Gold highlights, Epilogue headlines, DM Sans body text, and Space Grotesk labels.

**Why this priority**: Every future screen and component depends on correct tokens. Nothing can be built to spec without this.

**Independent Test**: Render a simple card with primary button, headline, body text, and team color badges. Visually compare to the Stitch design system palette. Confirm hex values match the spec.

**Acceptance Scenarios**:

1. **Given** a fresh app launch, **When** the theme is applied, **Then** the scaffold background is Deep Void (`#0D0B0F`), primary color is Blood Ember (`#B8432F`), and text renders in Epilogue/DM Sans/Space Grotesk as specified.
2. **Given** a widget using `AppColors.teamWerewolf`, **When** rendered, **Then** the color is `#C94038` (Bloodmoon Red).
3. **Given** a `TextTheme` lookup for `headlineLarge`, **When** rendered, **Then** it uses Epilogue at 24sp/w600 in parchment color (`#E8DFD3`).
4. **Given** a `TextTheme` lookup for `labelLarge`, **When** rendered, **Then** it uses Space Grotesk at 48sp/w600 in Tallow Gold (`#C8A24D`) — the timer digit style.

---

### User Story 2 - Phase-Aware Atmospheric Backgrounds (Priority: P1)

Every game screen is wrapped in an `AtmosphericBackground` widget that sets the mood per game phase. Night screens show Deep Void with a subtle candle glow. Lobby screens show warm Surface tones. Discussion and voting have slightly different warm-dark tones. A subtle noise grain overlay is present across night-phase screens.

**Why this priority**: The atmospheric background appears on all 15 screens. It is the most visible single component in the app and defines the "Firelit Gothic" feel.

**Independent Test**: Render `AtmosphericBackground` for each of the 5 game phases and verify the background color and overlay effects match the spec.

**Acceptance Scenarios**:

1. **Given** `AtmosphericBackground(phase: GamePhase.night)`, **When** rendered, **Then** the background is Deep Void (`#0D0B0F`) with a radial candle glow from center and a noise grain overlay at low opacity.
2. **Given** `AtmosphericBackground(phase: GamePhase.lobby)`, **When** rendered, **Then** the background is `#1A1714` with a warm glow.
3. **Given** `AtmosphericBackground(phase: GamePhase.discussion)`, **When** rendered, **Then** the background is `#151210`.
4. **Given** `AtmosphericBackground(phase: GamePhase.voting)`, **When** rendered, **Then** the background is `#12100E`.
5. **Given** `AtmosphericBackground(phase: GamePhase.results)`, **When** rendered, **Then** the background is `#0F0D0B`.

---

### User Story 3 - App Bar Adapts to Context (Priority: P2)

The app bar (`VillageAppBar`) has four variants that appear across different screens: Brand (Welcome/Home with castle icon and title), Back (Lobby/Role Selection with back arrow), Phase (Discussion/Voting with phase label and timer slot), and Minimal (Night screens with role name and timer ring slot). The developer picks a variant and the bar renders appropriately.

**Why this priority**: Present on 13 of 15 screens; needed before any screen can be built to spec.

**Independent Test**: Render each VillageAppBar variant in isolation and verify the layout matches the Stitch mocks.

**Acceptance Scenarios**:

1. **Given** `VillageAppBar.brand()`, **When** rendered, **Then** it shows a castle icon as leading, "Midnight Village" as title, and a trailing action slot.
2. **Given** `VillageAppBar.back(title: 'Lobby')`, **When** rendered, **Then** it shows a back arrow as leading and the given title.
3. **Given** `VillageAppBar.phase(label: 'DISCUSSION', trailing: timerWidget)`, **When** rendered, **Then** it shows a small-caps gold phase label and the timer widget in the trailing position.
4. **Given** `VillageAppBar.minimal(roleName: 'SEER', icon: seerIcon)`, **When** rendered, **Then** it shows the role name and icon with a transparent background.

---

### User Story 4 - Primary Button Matches Spec (Priority: P2)

The primary action button renders as a full-width ember red filled button with parchment text. It supports disabled, loading (spinner replacing text), and outlined (secondary) variants. It replaces the current `MvButton`.

**Why this priority**: Present on all 15 screens. The most interacted-with component.

**Independent Test**: Render PrimaryButton in all four states (default, disabled, loading, outlined) and verify visual output.

**Acceptance Scenarios**:

1. **Given** `PrimaryButton(label: 'Enter the Village', onPressed: action)`, **When** rendered, **Then** it shows a full-width button with ember red (`#B8432F`) background, parchment text, and 8px border radius.
2. **Given** `PrimaryButton(label: 'Start', onPressed: null)`, **When** rendered, **Then** the button is visually desaturated and non-interactive.
3. **Given** `PrimaryButton(label: 'Joining...', isLoading: true)`, **When** rendered, **Then** a circular spinner replaces the label text.
4. **Given** `PrimaryButton.outlined(label: 'Leave')`, **When** rendered, **Then** it renders with transparent background, outline border, and parchment text.

---

### User Story 5 - Player Avatar Renders Initials (Priority: P2)

A circular avatar renders a player's initials in a deterministic hue derived from their name. Three sizes (small 32dp, medium 48dp, large 64dp) are available. An optional sigil icon can overlay the avatar.

**Why this priority**: Appears on 11 of 15 screens. Core to player identity throughout the game.

**Independent Test**: Render PlayerAvatar with various names and sizes, verify initials extraction, color consistency, and size correctness.

**Acceptance Scenarios**:

1. **Given** `PlayerAvatar(displayName: 'Alice', size: AvatarSize.medium)`, **When** rendered, **Then** it shows a 48dp circle with "A" initial and a deterministic background hue.
2. **Given** the same displayName rendered twice, **When** compared, **Then** the background hue is identical (deterministic).
3. **Given** `PlayerAvatar(displayName: 'Bob', size: AvatarSize.small)`, **When** rendered, **Then** it shows a 32dp circle.
4. **Given** `PlayerAvatar(displayName: 'Carol', sigil: Icons.check)`, **When** rendered, **Then** the check icon appears as a small badge overlay.

---

### User Story 6 - Decorative Effects Available as Tokens (Priority: P3)

Developers can apply `AppShadows.fireGlow`, `AppDecorations.visionGlow`, `AppDecorations.bloodVignette`, and `AppDecorations.candleGlow` as decoration properties. These produce the warm atmospheric glow effects seen in the Stitch mocks.

**Why this priority**: Used across 10+ screens but as secondary embellishment; screens function without them.

**Independent Test**: Apply each decoration to a Container and verify the visual output renders without errors and produces visible effects.

**Acceptance Scenarios**:

1. **Given** a Container with `boxShadow: AppShadows.fireGlow`, **When** rendered, **Then** a subtle ember-red glow (`rgba(184,67,47, 0.15)`) appears around the widget.
2. **Given** a Container with `AppDecorations.visionGlow` as foreground decoration, **When** rendered, **Then** a radial tallow-gold gradient emanates from center.
3. **Given** a Container with `AppDecorations.bloodVignette`, **When** rendered, **Then** ember-red darkening appears at edges (elimination screen effect).

---

### User Story 7 - Existing Auth Flow Works with New Design System (Priority: P1)

The existing Welcome/Auth screen continues to function after the design system migration. The screen renders with the new Firelit Gothic styling. No regressions in authentication behavior.

**Why this priority**: The only existing user-facing screen. Regression here means the app is broken.

**Independent Test**: Launch the app, verify the auth flow (enter name, submit, see authenticated state) works end-to-end with the new theme applied.

**Acceptance Scenarios**:

1. **Given** a user launches the app, **When** the welcome screen renders, **Then** it displays with Firelit Gothic colors and typography (not the old PlayfairDisplay/Inter theme).
2. **Given** a user enters a display name and taps "Enter the Village", **When** the auth completes, **Then** the authenticated state renders correctly with the new design system.
3. **Given** all existing widget and integration tests, **When** run after the migration, **Then** all tests pass (with updated golden images where applicable).

---

### Edge Cases

- What happens when Google Fonts fails to load (no network, font CDN down)? Flutter falls back to system fonts. The app must remain usable with fallback fonts.
- What happens when a developer accesses a token that was renamed or moved in the expanded contract? Changed signatures must produce compile errors, not silent defaults.
- What happens with the noise grain overlay on low-end devices? The overlay must use a pre-rendered PNG at fixed resolution, not a real-time shader, to avoid performance issues.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a static `AppColors` class with all Firelit Gothic color constants matching the hex values in `docs/stitch/00-project-overview.md`.
- **FR-002**: System MUST provide a static `AppTypography` class producing a `TextTheme` using Epilogue (headlines), DM Sans (body), and Space Grotesk (labels) via the `google_fonts` package.
- **FR-003**: System MUST provide a static `AppRadius` class with border radius constants (small 4px, medium 8px, large 12px, xl 16px, full 999px).
- **FR-004**: System MUST provide a static `AppSpacing` class with spacing constants (xs 4, sm 8, md 12, lg 16, xl 24, xxl 32, xxxl 48).
- **FR-005**: System MUST provide `AppShadows` with `fireGlow`, `selectionGlow`, and `dangerGlow` box shadow presets.
- **FR-006**: System MUST provide `AppDecorations` with `visionGlow`, `bloodVignette`, `candleGlow`, and `noiseOverlay` gradient/effect presets.
- **FR-007**: System MUST provide a `buildAppTheme()` function returning a complete `ThemeData` with the Firelit Gothic `ColorScheme`, `TextTheme`, and component themes (card, button, input, appbar, divider).
- **FR-008**: System MUST provide an `AtmosphericBackground` widget that accepts a `GamePhase` and renders the correct phase-specific background color with optional overlay effects.
- **FR-009**: System MUST provide a `VillageAppBar` widget with four variants: brand, back, phase, and minimal.
- **FR-010**: System MUST provide a `PrimaryButton` widget with default (filled), disabled, loading, and outlined states.
- **FR-011**: System MUST provide a `PlayerAvatar` widget rendering initials in a circular container with deterministic hue, supporting small (32dp), medium (48dp), and large (64dp) sizes.
- **FR-012**: System MUST include a pre-rendered noise grain texture asset for the atmospheric overlay effect.
- **FR-013**: System MUST preserve and expand the existing theme abstraction layer (`AppTokens` interface, `ThemeBridge`, `activeThemeProvider`). The `AppTokens` / `AppColorTokens` / `AppTypographyTokens` contracts MUST be expanded to cover Firelit Gothic tokens not currently represented: phase background colors, decoration presets (glows, vignettes), border radius scale, the label/timer font family, and a serif accent style. A new `FirelitGothicTheme` class implementing `AppTokens` MUST be created as the new default theme. The existing `MidnightVillageTheme` MAY be retained as an alternative or removed — but the abstraction layer itself MUST remain to support multiple themes in the future.
- **FR-014**: System MUST remove the old bundled font assets (PlayfairDisplay, Inter) from `assets/fonts/`.
- **FR-015**: System MUST update all existing components (`MvScaffold`, `MvCard`, `MvTextInput`, `MvLoading`, `MvError`, `MvDialog`, and all game components) to compile and render correctly with the expanded token API. Components MUST continue consuming tokens via the Riverpod `activeThemeProvider`, not via static constants, to preserve theme-switching capability.
- **FR-016**: System MUST update all existing tests (unit, widget, golden, integration) to pass with the new design system. Golden images must be regenerated.
- **FR-017**: System MUST add a serif accent style (`displaySerif`) using Libre Baskerville for atmospheric flavor text.

### Key Entities

- **AppTokens** (expanded): Abstract interface defining the full token contract — colors, typography, spacing, elevation, border radius, phase backgrounds, and decoration presets.
- **AppColorTokens** (expanded): Abstract color contract. Extended to include phase background colors, decoration colors (glows, vignettes), danger/warning semantic colors, and the "no death blue" accent.
- **AppTypographyTokens** (expanded): Abstract typography contract. Extended to include the label/timer font (Space Grotesk), timer digit style, lobby code style, and serif accent style (Libre Baskerville).
- **FirelitGothicTheme**: New concrete implementation of `AppTokens` with all Stitch-specified values.
- **GamePhase**: Enum already exists. Extended with background color mapping consumed by `AtmosphericBackground`.
- **AvatarSize**: Enum (small, medium, large) with pixel value mapping.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All 11 core color constants match their Stitch-specified hex values exactly (verified by unit test).
- **SC-002**: All 8 typography styles render in the correct font family and weight (verified by unit test checking TextStyle properties).
- **SC-003**: `AtmosphericBackground` renders the correct background color for all 5 game phases (verified by widget test).
- **SC-004**: `VillageAppBar` renders all 4 variants without overflow or rendering errors (verified by widget test).
- **SC-005**: `PrimaryButton` renders all 4 states correctly (verified by widget test).
- **SC-006**: `PlayerAvatar` produces deterministic colors for the same input across multiple renders (verified by unit test).
- **SC-007**: The existing auth flow integration test passes with the new design system.
- **SC-008**: The `AppTokens` abstraction layer is preserved. A new `FirelitGothicTheme` implementing the expanded `AppTokens` contract is the default theme. All components consume tokens via provider, not static classes.
- **SC-009**: `just check` and `just flutter-test` pass with zero failures.
- **SC-010**: No bundled PlayfairDisplay or Inter font files remain in `assets/fonts/`.

## Assumptions

- The `google_fonts` package is acceptable for font loading (it fetches from Google's CDN at runtime, with caching).
- The noise grain overlay will use a pre-rendered PNG asset rather than a real-time shader, for performance and simplicity.
- The existing `material_symbols_icons` package (or built-in `Icons`) covers all role icons specified in the Stitch mocks. No custom SVG icons are needed for this feature.
- The `RoleCard`, `PlayerCircle`, and other existing game components will be updated to compile with new tokens but will NOT be redesigned to fully match Stitch component specs — that's a future feature.
- The `MvButton` widget will be replaced by `PrimaryButton`. Any screen using `MvButton` will be updated to use the new widget.
- The `AppTokens` abstraction layer is preserved. The `FirelitGothicTheme` becomes the default, but the architecture supports swapping in a different theme implementation in the future.
- Components consume tokens via the Riverpod `activeThemeProvider` pattern, not via static color/typography constants, to maintain theme-switching capability.

## Reference Documents

- `docs/stitch/00-project-overview.md` — Authoritative color palette, font families, role icon mapping
- `docs/stitch/token-map.md` — Stitch → Flutter token mapping with copy-paste-ready Dart code
- `docs/stitch/components.md` — Full component inventory with P0 priorities
- `docs/stitch/icons.md` — Icon package decisions
- `docs/stitch/strings.md` — String constants (out of scope for this feature, referenced for context)
