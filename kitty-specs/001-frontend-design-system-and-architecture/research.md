# Research: Frontend Design System & Architecture

**Feature**: 001-frontend-design-system-and-architecture
**Date**: 2026-03-24

## Research Areas

### 1. Custom Token Provider Mechanism

**Decision**: Riverpod-based token provider with Material ThemeData bridge.

**Rationale**:
- Every widget in the project is already a `ConsumerWidget`. Adding `ref.watch(activeThemeProvider)` introduces zero new patterns.
- `@Riverpod(keepAlive: true)` Notifier holds `AppTokens`, exposes `switchTheme()` method. Theme survives navigation.
- Testing via `ProviderScope(overrides: [activeThemeProvider.overrideWithValue(TestTokens())])` — same pattern already used for auth service tests.
- `ref.watch(provider.select((t) => t.colors.primary))` enables fine-grained rebuilds if needed.
- Abstract class `AppTokens` enforces completeness at compile time — a theme implementation that misses a token won't compile. Satisfies the "fail loudly" edge case requirement.

**Alternatives considered**:
- **InheritedWidget-only**: Would work but requires custom state management for theme switching. Inconsistent with Riverpod-everywhere pattern in this project.
- **Hybrid (Riverpod + InheritedWidget)**: Two parallel systems, violates "no premature abstraction" principle. Not needed since all widgets are already ConsumerWidget.

**Material bridge**:
- Generate `ThemeData` from `AppTokens` at `MaterialApp.router(theme: ...)` in `app.dart`.
- Use `ColorScheme.fromSeed()` with the token's primary color as seed, then override key slots (primary, surface, error, etc.) with exact token values.
- Material widgets (TextField, ElevatedButton, Scaffold) automatically pick up correct colors.
- Game-specific components read tokens directly via `ref.watch(activeThemeProvider)`.

### 2. Token Contract Structure

**Decision**: Grouped flat structure with typed sub-objects.

**Rationale**:
- One level of namespacing: `tokens.colors.primary`, `tokens.typography.heading`, `tokens.spacing.m`.
- Readable, supports Riverpod `.select()` at sub-object level.
- Game-specific semantic colors (`werewolfTeam`, `villageTeam`, `independentTeam`) live alongside standard colors in `AppColorTokens` — they're semantic colors, not a separate category.
- `const` data classes with immutable fields. Theme instances are singletons; reference equality (`identical()`) works for `!=` comparisons.

**Token categories**:
- **Colors** (`AppColorTokens`): primary, onPrimary, secondary, onSecondary, surface, onSurface, background, onBackground, error, onError, werewolfTeam, villageTeam, independentTeam, timerNormal, timerUrgent, cardBack
- **Typography** (`AppTypographyTokens`): displayHeading, heading, subheading, body, caption, label — each a `TextStyle` with font family, size, weight, letter spacing
- **Spacing** (`AppSpacingTokens`): xs (4), s (8), m (16), l (24), xl (32), xxl (48) — `double` values
- **Elevation** (`AppElevationTokens`): flat (0), raised (2), floating (6), overlay (12) — `double` values mapped to shadow configs

### 3. Asset Pipeline for Themed Illustrations

**Decision**: SVG via `flutter_svg`, with Material Icons as placeholders for v1.

**Rationale**:
- SVG is scalable, single file per role, smaller bundle than multi-resolution PNGs.
- `flutter_svg` is the standard Flutter SVG package, supports color injection via `colorFilter`, compatible with all target platforms.
- Authoring constraint: SVGs must use inline attributes, not CSS classes (flutter_svg limitation). Manageable with proper export settings.
- Placeholders: Material Icons mapped to roles (e.g., `Icons.pets` for Werewolf, `Icons.visibility` for Seer) inside themed card containers. Zero additional dependencies. Validates card component layout without needing illustrations.

**Alternatives considered**:
- **PNG**: Simpler but requires 3x resolution variants, larger bundle, not scalable.
- **jovial_svg**: Faster binary format but smaller community, extra build step. Good escape hatch if `flutter_svg` performance is insufficient.
- **CustomPainter**: Too labor-intensive for 12 illustration-level role cards.

**Asset structure**:
```
assets/
  themes/
    midnight-village/
      roles/           # 12 SVG files: werewolf.svg, seer.svg, etc.
      card-back.svg    # Face-down card design
    _placeholder/      # Minimal test/dev theme
      roles/
      card-back.svg
  fonts/               # Bundled font families
```

**Caching strategy**: Precache role SVGs at lobby-to-game transition (not app startup). Only precache the 8 roles in the active game, not all 12.

### 4. Design System File Structure

**Decision**: `lib/design_system/` as top-level peer to `core/` and `features/`.

**Rationale**:
- Design system is a first-class concern, distinct from infrastructure (`core/`) and features.
- `core/` groups infrastructure by responsibility (api, config, router, storage). A design system producing visual building blocks does not belong alongside `api_client.dart`.
- Categorized components: `components/core/` (universal widgets) and `components/game/` (game-specific widgets). Reflects the spec's natural boundary.
- No barrel files — consistent with existing project style (zero barrel files in codebase). Direct imports keep dependencies explicit.
- Tests mirror source tree: `test/design_system/` mirrors `lib/design_system/`.

**Alternatives considered**:
- **`lib/core/design_system/`**: Overloads `core/` with unrelated concerns.
- **`lib/core/theme/` + `lib/core/components/`**: Fragments a unified concept.
- **Separate package**: Overhead not justified for solo developer, single app.

### 5. Font Strategy

**Decision**: Bundle font assets in `assets/fonts/`.

**Rationale**:
- Game is played in-person; players may have unreliable wifi.
- `google_fonts` requires network on first load (iOS/Android). Bundled fonts work offline.
- Serif/semi-serif heading font + clean sans-serif body font. Specific fonts chosen during implementation — open-source licensed (e.g., from Google Fonts catalog, downloaded and bundled).
- Font files declared in `pubspec.yaml` under `fonts:` section.

### 6. Role Token Granularity

**Decision**: Three team-level color tokens, not per-role tokens.

**Rationale**:
- Roles are visually differentiated by: role name text + team color + illustration. Team color is the primary semantic signal.
- Three tokens (`werewolfTeam`, `villageTeam`, `independentTeam`) cover all 12 roles via team affiliation mapping.
- Per-role tokens (12+ entries) would bloat the contract without clear benefit — themes would struggle to assign 12 meaningfully distinct colors.
- If a future theme needs per-role colors, they can be derived from team colors + role identity in the component, not the token contract.

## Open Questions Resolved

| Question | Resolution |
|----------|------------|
| Scoped themes (different theme in a subtree)? | Not needed for v1. Riverpod-only approach is sufficient. |
| ThemeData ColorScheme completeness? | `ColorScheme.fromSeed()` fills all 30+ Material slots; override key slots with exact token values. |
| Token equality strategy? | `const` singletons with reference equality. Themes are immutable. |
| Barrel files? | No. Revisit if game screens need 8+ imports per file. |
| flutter_gen for type-safe paths? | Add during implementation. Compatible with existing build_runner. |
| Web renderer? | Default (CanvasKit/Skwasm). No HTML renderer forcing. SVGs render correctly. |
