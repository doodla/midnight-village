# Feature Specification: Frontend Design System & Architecture

**Feature Branch**: `001-frontend-design-system-and-architecture`
**Created**: 2026-03-24
**Status**: Draft
**Input**: Themeable design system with "Midnight Village" as default theme, full UI kit (tokens + core components + game-specific patterns), frontend architecture playbook, and testing strategy.

## User Scenarios & Testing

### User Story 1 - Themeable Token Foundation (Priority: P1)

A developer building game screens imports semantic design tokens (colors, typography, spacing, elevation) that resolve to the correct visual values for whichever theme is active. Tokens are defined as an abstract contract so that new themes can be added by implementing the contract without touching any component code.

The default "Midnight Village" theme establishes the visual identity: warm firelight ambers and oranges as accent/interactive colors, deep blues and indigos as background/surface colors evoking night sky, muted earth tones for secondary and neutral elements, and atmospheric serif-style headings paired with a clean sans-serif for body text.

**Why this priority**: Every component and screen depends on tokens. Nothing else can be built until the token abstraction and default theme exist. This is the foundation layer.

**Independent Test**: Import the token provider, activate the default theme, and verify that all semantic tokens (e.g., "surface", "primary", "onPrimary", "bodyFont", "headingFont", "spacingM") resolve to concrete values. Switch to a test/stub theme and verify all tokens resolve to different values.

**Acceptance Scenarios**:

1. **Given** the app starts with no explicit theme set, **When** a widget reads a color token (e.g., "primary"), **Then** it receives the Midnight Village theme value (a warm amber/orange).
2. **Given** a developer creates a new theme implementing the token contract, **When** that theme is activated, **Then** all widgets using tokens automatically reflect the new theme's values without code changes to components.
3. **Given** the token contract, **When** a developer reviews it, **Then** it includes at minimum: a complete color palette (primary, secondary, surface, background, error, onPrimary, onSurface, onBackground, onError, plus game-specific semantic colors for each team — werewolf, village, independent/tanner), a typography scale (heading display, heading, subheading, body, caption, label), a spacing scale (at least 5 graduated steps), and an elevation/shadow scale (flat, raised, floating, overlay).
4. **Given** the Midnight Village theme is active, **When** the app renders, **Then** background surfaces use deep blue/indigo tones, interactive elements use warm amber/orange tones, text on dark surfaces is legible with sufficient contrast, and headings use a serif or semi-serif typeface distinct from body text.

---

### User Story 2 - Core UI Components (Priority: P2)

A developer building any screen can compose it from pre-built, themed components that draw all visual properties from the active theme's tokens. These components cover the universal building blocks needed across all screens: buttons (primary, secondary, destructive, disabled states), cards (content containers with optional header/footer), text inputs (with label, hint, error states), dialogs (confirmation, information, and error variants), scaffold/page layouts (consistent structure with app bar, body, optional bottom bar), and feedback states (loading indicators, error displays with retry, empty states).

**Why this priority**: Core components are reused across every screen. Building them before game-specific patterns prevents duplication and ensures visual consistency.

**Independent Test**: Render each component in isolation with the default theme and verify it displays correctly. Switch themes and verify the component adapts. Test interactive states (pressed, disabled, error) for each component.

**Acceptance Scenarios**:

1. **Given** a button component, **When** rendered in primary style, **Then** it uses the theme's primary color for the background and onPrimary for the text, and responds visually to press/disabled states.
2. **Given** a text input component, **When** the user enters invalid data and an error message is provided, **Then** the input border and error text display in the theme's error color.
3. **Given** a dialog component, **When** displayed as a confirmation dialog, **Then** it includes a title, body text, and two action buttons (confirm/cancel), all styled from theme tokens.
4. **Given** a scaffold/page layout, **When** used on different screen sizes (phone portrait, phone landscape, tablet), **Then** it adapts its padding and content width appropriately while maintaining the theme's visual identity.
5. **Given** a loading state component, **When** displayed during an async operation, **Then** it shows a themed loading indicator that is visually consistent with the overall design language.

---

### User Story 3 - Game UI Patterns: Night Actions (Priority: P3)

A developer building the night phase screen can use purpose-built components for each night action type. The player sees their role card, the action prompt for their role, and the appropriate interaction UI:

- **Peek actions** (Seer peeking a player or center cards, Insomniac viewing own card): Display the target selection UI, then reveal the peeked card(s) with the role name and team color.
- **Swap actions** (Robber swapping with player, Troublemaker swapping two others, Drunk swapping with center): Display target selection UI appropriate to the swap type, confirm the swap, and show the result (new card for Robber; blind confirmation for Troublemaker/Drunk).
- **See-team actions** (Werewolves, Masons, Minion): Display the list of revealed teammates (or "you are the lone werewolf" messaging for lone wolf).
- **Skip/no-action**: Display a waiting message for roles with no action (Villager, Tanner, Hunter) or when a player declines an optional action.
- **Timer**: A countdown timer visible during the action window, with visual urgency as time runs low.

**Why this priority**: Night actions are the core mechanical interaction in ONUW. They involve hidden information display and time-sensitive input — the most complex UI in the game.

**Independent Test**: Render each action type component with mock game state and verify: correct prompt text appears, target selection works, results display correctly, timer counts down, and skip/timeout is handled gracefully.

**Acceptance Scenarios**:

1. **Given** a player with the Seer role during the night phase, **When** the Seer's action prompt appears, **Then** the player sees two options: peek one player's card or peek two center cards, with clear visual distinction between the options.
2. **Given** a Seer who chose to peek a player, **When** the result is revealed, **Then** the peeked role is displayed as a styled role card showing the role name and team color (werewolf-red, village-blue, independent-neutral).
3. **Given** a player whose role has no night action (Villager), **When** the night phase is active, **Then** the player sees a themed waiting screen indicating the night is in progress without revealing any information about other players' actions.
4. **Given** a night action timer with 3 seconds remaining, **When** the timer enters the final moments, **Then** the timer display signals urgency visually (color shift, pulse, or similar — without animation, just state change).
5. **Given** a player who does not submit an action before the timer expires, **When** the timeout occurs, **Then** the UI transitions gracefully to a "time expired — action skipped" confirmation state.

---

### User Story 4 - Game UI Patterns: Role Cards & Public Info (Priority: P4)

A developer building lobby, discussion, or results screens can use role card and game information components:

- **Role card**: A styled card displaying a role's name, team affiliation (color-coded), and a visual identity for the role. Used during role reveal (start of game), night action results, and end-of-game reveals. Cards have face-down (hidden) and face-up (revealed) states.
- **Role token list**: A display of all roles in the current game (public information visible to all players). Shows which roles are in play without revealing assignments.
- **Center card display**: A visual representation of the 3 center cards (face-down during play, optionally revealed at game end).
- **Player list/circle**: A display of all players in the game, used for target selection (night actions, voting) and status display (alive/eliminated at results). Supports highlighting (e.g., "select a player to peek at").

**Why this priority**: Role cards and player displays are the most visible game-specific elements. They're used across multiple phases and set the visual tone for the game.

**Independent Test**: Render each component with mock data (role names, player names, team affiliations) and verify correct display. Test face-down/face-up card transitions. Test player selection interaction on the player circle.

**Acceptance Scenarios**:

1. **Given** a role card for "Werewolf", **When** displayed face-up, **Then** it shows the role name, uses the werewolf team color, and is visually distinct from village and independent role cards.
2. **Given** a role card in face-down state, **When** displayed, **Then** it shows a consistent card-back design from the active theme without leaking any role information.
3. **Given** a role token list for a 5-player game (8 roles), **When** displayed, **Then** all 8 roles are visible with their team color indicators, and the list is legible on a phone screen.
4. **Given** a player circle with 6 players during voting, **When** a player needs to select a vote target, **Then** all other players are tappable targets, the current player is visually excluded (cannot self-vote), and the selected target is clearly highlighted.
5. **Given** the results phase, **When** eliminated players are shown, **Then** their role cards are face-up and their status (eliminated) is visually distinct from surviving players.

---

### User Story 5 - Game UI Patterns: Phase & Voting (Priority: P5)

A developer building the discussion and voting phases can use phase-aware components:

- **Phase indicator**: Shows the current game phase (lobby, night, discussion, voting, results) with clear visual differentiation. Visible throughout the game so players always know where they are.
- **Discussion timer**: A prominent countdown for the discussion phase (configurable, typically 5-10 minutes). Should be readable at a glance since players are talking face-to-face and only glancing at phones.
- **Vote submission UI**: A player selects one other player to vote for. Votes are hidden until all are in (or timer expires). Shows vote-submitted confirmation without revealing the choice to nearby players.
- **Vote reveal**: Simultaneous display of all votes — who voted for whom. Tally results showing vote counts per player. Clear indication of who (if anyone) is eliminated.
- **Win/loss results**: Team-based outcome display — which team(s) won, which players were on which team, with role reveals for all players. Handles multi-winner scenarios (Tanner + Village both winning).

**Why this priority**: Phase and voting UI complete the game loop. These are the final screens needed for a playable end-to-end game.

**Independent Test**: Render each component with mock phase/voting data. Verify phase indicator reflects correct phase, timer counts down, vote submission works, vote reveal displays all votes correctly, and win conditions render properly for each scenario (village win, werewolf win, tanner win, multi-winner).

**Acceptance Scenarios**:

1. **Given** the game is in the discussion phase, **When** the phase indicator renders, **Then** it clearly shows "Discussion" and is visually distinct from all other phases.
2. **Given** the discussion timer is active, **When** a player glances at their phone, **Then** the remaining time is readable in under 1 second — large, high-contrast, prominent.
3. **Given** a player submitting a vote, **When** they select a target and confirm, **Then** the UI shows a confirmation that their vote is locked in without displaying the target name prominently (privacy from nearby players glancing at the screen).
4. **Given** all votes are collected, **When** the reveal happens, **Then** each player's vote target is shown, a tally is displayed, and the eliminated player(s) (if any) are clearly identified.
5. **Given** a game where both the Tanner and a Werewolf are eliminated, **When** results display, **Then** both "Tanner wins" and "Village wins" are shown, with each player's final role and team visible.

---

### User Story 6 - Frontend Architecture Playbook (Priority: P6)

A developer starting work on a new game feature (e.g., "night phase screen") follows a documented architecture that defines:

- How to structure the feature (domain models, data layer with repository/service, presentation layer with Riverpod notifiers and widgets)
- How real-time game events flow from the server through WebSockets into Riverpod state, triggering UI updates
- How game phase transitions drive navigation (e.g., server sends "phase: voting" event, client navigates to voting screen)
- How player-scoped state is managed (the client only knows what the server tells it — no local game logic)
- How to handle errors, disconnection, and reconnection (player rejoins mid-game)
- Dependency rules: presentation depends on domain, domain has no dependencies, data bridges domain and external services

**Why this priority**: Architecture patterns must exist before multiple developers (or agents) build game screens in parallel, to ensure consistency. Ranked below the design system because the design system has zero existing foundation, while the architecture already has partial patterns from the auth feature.

**Independent Test**: A developer can read the architecture spec and correctly structure a new feature module without referring to other features for guidance. The spec answers "where does this go?" for any piece of code.

**Acceptance Scenarios**:

1. **Given** a developer starting a new feature, **When** they read the architecture spec, **Then** they can identify exactly which files to create and in which directories.
2. **Given** a WebSocket event arrives from the server (e.g., "night_action_result"), **When** the developer reads the architecture spec, **Then** they know exactly how that event flows from the WebSocket connection through to a UI update (the data path is documented).
3. **Given** a player disconnects and reconnects mid-game, **When** the developer reads the architecture spec, **Then** they know the reconnection pattern: how the client re-establishes the WebSocket connection, fetches current game state, and resumes the correct screen.
4. **Given** the architecture spec, **When** reviewed for server-authority compliance, **Then** no pattern suggests computing game logic client-side — all game state comes from the server.

---

### User Story 7 - Testing Strategy (Priority: P7)

A developer writing tests for frontend code follows a documented testing strategy that covers:

- **Unit tests**: How to test domain models (pure Dart, no Flutter dependencies), Riverpod notifiers (state transitions), and data layer services (mocked HTTP/WebSocket)
- **Widget tests**: How to test individual components and composed screens with mock providers, verifying rendering, interaction, and state-driven UI changes
- **Theme tests**: How to verify components render correctly across different themes
- **Game state tests**: How to test complex game state scenarios (phase transitions, night action flows, vote reveal sequences) at the widget level with mock game state
- **What to mock**: External services (HTTP, WebSocket, storage). What NOT to mock: domain models, Riverpod state logic, widget rendering.

**Why this priority**: Testing strategy is essential but depends on the architecture and components being defined first. It codifies how to verify everything built in stories 1-6.

**Independent Test**: A developer can read the testing spec and write a correct test for any component or feature module without guessing at patterns.

**Acceptance Scenarios**:

1. **Given** a developer writing a widget test for a role card component, **When** they read the testing strategy, **Then** they know how to set up the test: provide a mock theme, render the widget, and assert on visual properties.
2. **Given** a developer testing a Riverpod notifier that handles night action state, **When** they read the testing strategy, **Then** they know how to create a test container, mock the data layer, trigger state transitions, and assert on emitted states.
3. **Given** a developer testing theme compatibility, **When** they read the testing strategy, **Then** they know the pattern for rendering a component with each registered theme and verifying it renders without errors and with correct token values.
4. **Given** the testing strategy, **When** reviewed against the project's quality gates, **Then** it accounts for the 80% coverage minimum and identifies which areas are highest priority for coverage.

---

### Edge Cases

- Theme with missing or incomplete token values: The system must fail loudly (development error) rather than silently falling back, so theme authors catch gaps immediately.
- Extremely long player names: Components must truncate or ellipsize gracefully without breaking layout.
- 3-player games vs. 10-player games: Player circle/list components must scale from minimum (3) to maximum (10) player counts without layout breakage.
- All votes tied (no one eliminated): Results UI must handle the "no elimination" outcome clearly.
- Doppelganger role display: When showing a player's role at results, the Doppelganger's display must indicate both "Doppelganger" (the card) and the copied role (the effective identity).
- Multiple simultaneous themes in test: Testing infrastructure must support rendering the same component tree with different themes in the same test run.
- Right-to-left (RTL) text: Design tokens should not assume left-to-right layout; components should respect platform text direction.
- Dark/light mode interaction: The Midnight Village theme is inherently dark. The theme contract should allow both dark and light themes, but the default theme is dark-only.

## Requirements

### Functional Requirements

- **FR-001**: The system MUST define a theme contract (token interface) that all themes implement, covering color palette, typography scale, spacing scale, and elevation scale.
- **FR-002**: The system MUST include a default theme ("Midnight Village") implementing the full token contract with a visual identity evoking a mysterious village at night by firelight.
- **FR-003**: Themes MUST be swappable at runtime — changing the active theme updates all rendered components without app restart.
- **FR-004**: All UI components MUST derive their visual properties exclusively from theme tokens — no hardcoded colors, font sizes, or spacing values in component code.
- **FR-005**: The system MUST provide core components: buttons (primary, secondary, destructive), cards, text inputs (with error states), dialogs (confirmation, information, error), page scaffolds, and feedback states (loading, error, empty).
- **FR-006**: The system MUST provide game-specific components: role cards (face-up/face-down, all 12 v1 roles), role token list, center card display, player circle/list (with selection), phase indicator, discussion timer, vote submission UI, vote reveal display, and win/loss results display.
- **FR-007**: Role cards MUST be color-coded by team affiliation: distinct colors for Werewolf team, Village team, and Independent (Tanner).
- **FR-008**: Night action components MUST support all v1 action types: peek_player, peek_center, swap_with_player, swap_with_center, swap_others, see_team, and no-action/skip.
- **FR-009**: The vote submission UI MUST hide the player's vote choice from casual observation by nearby players (vote privacy on shared physical space).
- **FR-010**: The vote reveal MUST display all votes simultaneously with per-player tallies and clear elimination outcome.
- **FR-011**: The results display MUST handle all win condition combinations: village-only win, werewolf-only win, tanner-only win, tanner + village dual win, and no-team-wins.
- **FR-012**: The frontend architecture MUST follow server-authoritative design — all game state originates from the server; the client never computes game logic.
- **FR-013**: The architecture MUST define a clear pattern for WebSocket event consumption: how events flow from the connection through state management to UI updates.
- **FR-014**: The architecture MUST define a reconnection pattern for players who disconnect mid-game — re-establish connection, fetch current state, resume correct screen.
- **FR-015**: The architecture MUST define the feature module structure: domain layer (models), data layer (services, repositories), and presentation layer (notifiers, widgets).
- **FR-016**: The testing strategy MUST define patterns for unit tests (domain/notifiers), widget tests (components/screens), and theme compatibility tests.
- **FR-017**: Components MUST render correctly for game sizes from 3 to 10 players without layout breakage.
- **FR-018**: The phase indicator MUST be visible throughout the game so players always know the current phase (lobby, night, discussion, voting, results).
- **FR-019**: The discussion timer MUST be readable at a glance — large, high-contrast display suitable for players who are talking face-to-face and only intermittently checking their phones.
- **FR-020**: The theme contract MUST support game-specific semantic colors: werewolf team color, village team color, independent team color, and role-specific accent colors.

### Key Entities

- **Theme**: A complete set of design tokens implementing the theme contract. Has a name, color palette, typography scale, spacing scale, and elevation scale.
- **Design Token**: A named, semantic value (e.g., "primary", "surface", "headingFont", "spacingM") that maps to a concrete visual property. Tokens are the abstraction layer between components and themes.
- **Role Card**: A visual representation of a game role with name, team affiliation, face-up/face-down state, and theme-derived styling.
- **Player Display**: A representation of a player in the game showing name, status (active, eliminated), and optional selection state (for targeting during night actions and voting).
- **Phase State**: The current game phase (lobby, night, discussion, voting, results) driving UI layout, available interactions, and visible information.
- **Night Action Prompt**: A player-specific interaction prompt driven by their role's action type, including target selection UI, timer, and result display.

## Success Criteria

### Measurable Outcomes

- **SC-001**: All core UI components render correctly with the default theme and at least one alternate test theme, verified by automated widget tests.
- **SC-002**: Zero hardcoded color, font-size, or spacing values exist in component code — all visual properties trace back to theme tokens, verifiable by code review.
- **SC-003**: A developer unfamiliar with the codebase can create a new correctly-structured feature module by following the architecture spec alone, without referring to other feature implementations for guidance.
- **SC-004**: Widget test coverage for all design system components reaches at least 80%.
- **SC-005**: All 12 v1 role cards render with correct team-color coding and are distinguishable by a unique (icon, team-color) combination per role, verified by widget test.
- **SC-006**: Player circle component supports 3 to 10 players with no layout overflow or illegible text on a standard phone screen (360dp width minimum).
- **SC-007**: Discussion timer text is legible from arm's length — minimum effective display size of 48dp for the time digits.
- **SC-008**: Theme switching takes effect on all visible components within a single frame rebuild — no visual artifacts or partial-theme states.
- **SC-009**: The architecture spec documents the complete data path for at least 3 representative scenarios: receiving a night action result, submitting a vote, and handling a disconnection/reconnection.
- **SC-010**: The testing strategy provides runnable example patterns for each test type (unit, widget, theme) that a developer can copy and adapt.

## Assumptions

- The backend WebSocket API contract (event names, payload shapes) is stable enough to design the frontend consumption pattern, though exact payloads may be refined during implementation.
- Flutter's built-in theming infrastructure (ThemeData, InheritedWidget) is the appropriate mechanism for theme switching — no need for a custom theme engine.
- The app targets phones as the primary form factor (3.5" to 6.7" screens). Tablet and web are secondary and should work but don't drive design decisions.
- Google Fonts or bundled font assets are acceptable for custom typography — no licensing constraints on open-source fonts.
- The 12 v1 roles are the complete set for initial implementation. Daybreak expansion roles are out of scope for this design system version but the architecture should not preclude adding them later.
