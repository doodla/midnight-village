# Research: Firelit Gothic Design System

**Feature**: 003-firelit-gothic-design-system
**Date**: 2026-03-26

---

## R1: Google Fonts Integration Strategy

**Decision**: Use the `google_fonts` Flutter package for all four font families (Epilogue, DM Sans, Space Grotesk, Libre Baskerville).

**Rationale**:
- Google Fonts fetches from CDN at runtime and caches locally. This eliminates the need to bundle font assets.
- All four families are available in Google Fonts.
- The package is the standard Flutter approach for Google-hosted fonts.
- Existing bundled PlayfairDisplay and Inter assets in `assets/fonts/` will be removed.
- The `fonts:` section in `pubspec.yaml` will be deleted; Google Fonts doesn't need it.

**Alternatives considered**:
- **Keep bundled fonts**: Rejected — spec explicitly requires switching to Epilogue/DM Sans/Space Grotesk, and bundling four font families with multiple weights increases app size. Google Fonts caching provides offline support after first load.
- **Hybrid (bundle + Google Fonts)**: Rejected — unnecessary complexity; either approach works but mixing creates confusion about which fonts use which loading path.

**Fallback behavior**: When Google Fonts CDN is unreachable (no network, CDN down), Flutter falls back to system fonts. The app remains usable — this is an acceptable degradation per the spec's edge case section.

**Test impact**: Golden tests that depend on font rendering will need regeneration. The test helper `flutter_test_config.dart` may need updating to ensure Google Fonts loads in test environments (use `GoogleFonts.config.allowRuntimeFetching = false` in tests and provide font assets via `FontLoader` or mock the text styles).

---

## R2: Noise Grain Texture Implementation

**Decision**: Use a pre-rendered PNG texture at fixed resolution, composited as a semi-transparent overlay via `Opacity` + `Image.asset`.

**Rationale**:
- The spec explicitly says: "The overlay must use a pre-rendered PNG at fixed resolution, not a real-time shader, to avoid performance issues."
- A 512×512 grayscale noise PNG at 3-5% opacity tiled across the background provides the effect seen in the Stitch mocks.
- This avoids Flutter's custom shader complexity and works identically on web, iOS, and Android.

**Alternatives considered**:
- **Real-time shader via `FragmentProgram`**: Rejected — performance concern on low-end mobile, cross-platform shader compatibility issues, and spec explicitly prohibits this.
- **`ImageFiltered` with `ShaderMask`**: Rejected — still requires a shader pipeline; the pre-rendered PNG is simpler and more performant.
- **SVG `feTurbulence` (what Stitch uses)**: Rejected — Flutter doesn't natively support SVG filter effects. Would require `flutter_svg` with limited filter support.

**Asset**: Create `frontend/assets/textures/noise_grain.png` — a 512×512 grayscale Perlin noise texture. This is a one-time asset creation.

---

## R3: Spacing Token Rename Strategy

**Decision**: Expand the `AppSpacingTokens` interface with new names matching the spec scale. Rename existing getters to align with the Firelit Gothic naming convention.

**Current spacing scale** (6 values):
| Name | Value |
|------|-------|
| `xs` | 4.0 |
| `s`  | 8.0 |
| `m`  | 16.0 |
| `l`  | 24.0 |
| `xl` | 32.0 |
| `xxl`| 48.0 |

**New spacing scale** (7 values, per spec FR-004):
| Name  | Value |
|-------|-------|
| `xs`  | 4.0 |
| `sm`  | 8.0 |
| `md`  | 12.0 |
| `lg`  | 16.0 |
| `xl`  | 24.0 |
| `xxl` | 32.0 |
| `xxxl`| 48.0 |

**Rationale**:
- The spec defines a 7-step scale (xs, sm, md, lg, xl, xxl, xxxl). The current 6-step scale is missing `md=12` and has different name→value mappings (`m=16` vs `lg=16`).
- Since this feature IS the design system migration, renaming is acceptable — all consumers will be updated in the same feature's work packages.
- Using the spec naming provides consistency with the `token-map.md` reference and the Stitch design system.

**Migration impact**:
- `s` → `sm` (same value 8.0)
- `m` → `lg` (same value 16.0) — **name changes, value stays**
- `l` → `xl` (same value 24.0)
- `xl` → `xxl` (same value 32.0)
- `xxl` → `xxxl` (same value 48.0)
- NEW: `md` = 12.0

**All consumers** (7 core widgets, 9 game widgets, test theme) must be updated in the same work package that changes the interface.

**Alternatives considered**:
- **Add new names alongside old**: Rejected — creates confusion with two naming schemes in the same interface, and the old names become misleading (`m` meaning 16 while `md` means 12).
- **Keep old names, just add `md` and `xxxl`**: Rejected — `m=16` doesn't align with the spec's `md=12`, creating inconsistency between the token-map reference docs and the actual code.

---

## R4: AppTokens Interface Expansion Strategy

**Decision**: Expand existing abstract classes and add two new abstract classes. The expanded interface is the minimum needed to represent all Firelit Gothic tokens.

**New/expanded abstract classes**:

1. **`AppColorTokens`** — add 10 new getters:
   - Phase backgrounds: `nightBg`, `lobbyBg`, `discussionBg`, `votingBg`, `resultsBg`
   - Decorations: `danger`, `warning`
   - Accents: `noDeathBlue`, `surfaceDark`
   - Alias: `tertiary` (for Moonlit Sage — not currently in the interface)

2. **`AppTypographyTokens`** — add 4 new getters:
   - `timerDigits` (Space Grotesk 48sp, for countdown)
   - `lobbyCode` (Space Grotesk 28sp, for lobby code display)
   - `phaseLabel` (Space Grotesk 12sp, for badges/labels)
   - `serifAccent` (Libre Baskerville 16sp italic, for atmospheric flavor text)

3. **`AppSpacingTokens`** — rename to 7-step scale (see R3)

4. **NEW `AppRadiusTokens`** — border radius scale:
   - `small` (4), `medium` (8), `large` (12), `xl` (16), `full` (999)

5. **NEW `AppDecorationTokens`** — glow/gradient presets:
   - `fireGlow`, `selectionGlow`, `dangerGlow` → `List<BoxShadow>`
   - `visionGlow`, `bloodVignette`, `candleGlow` → `Gradient` (RadialGradient)
   - `noiseOverlayAsset` → `String` (asset path for noise texture)

6. **`AppTokens`** root — add `radius` and `decorations` getters.

**Rationale**:
- The spec (FR-013) requires the expanded contract. Adding to existing interfaces (rather than replacing) means the `MidnightVillageTheme` must also implement the new getters — this is intentional as it ensures all themes are complete.
- Decoration tokens (glows, gradients) are themeable because different themes might want different glow colors. Putting them in the token system preserves the abstraction.

**Impact on existing implementations**:
- `MidnightVillageTheme` needs new classes: `MidnightVillageRadius`, `MidnightVillageDecorations`, and expanded `MidnightVillageColors`/`MidnightVillageTypography`.
- `TestThemeTokens` (test helper) needs the same expansions.
- All changes are compile-error-driven: adding a new abstract getter immediately breaks all implementations, forcing updates.

---

## R5: Component Migration Strategy

**Decision**: Migrate components in dependency order. Token interface changes first, then theme implementations, then consumers.

**Execution order**:
1. **Expand interfaces** (`app_tokens.dart`) — add all new getters
2. **Create `FirelitGothicTheme`** — implements expanded `AppTokens` with Stitch values
3. **Update `MidnightVillageTheme`** — implement new getters with reasonable defaults (may be retained as alternative or removed later)
4. **Update `TestThemeTokens`** — implement new getters with visually distinct test values
5. **Update `ThemeBridge`** (`theme_bridge.dart`) — expand `generateThemeData` to use new tokens
6. **Build new foundation widgets** — `AtmosphericBackground`, `VillageAppBar`, `PrimaryButton`, `PlayerAvatar`
7. **Update existing core widgets** — `MvScaffold`, `MvCard`, `MvTextInput`, `MvLoading`, `MvError`, `MvDialog` (compile with new spacing names)
8. **Update existing game widgets** — all 9 game components (compile with new token names)
9. **Remove `MvButton`** — replaced by `PrimaryButton`; update all references
10. **Remove old fonts** — delete `assets/fonts/`, update `pubspec.yaml`
11. **Regenerate golden images** — re-run golden tests
12. **Verify** — `just check` + `just flutter-test` pass

**Rationale**: Dependency ordering prevents partial compilation states. Interfaces first ensures all downstream changes are compiler-guided.

---

## R6: PrimaryButton vs MvButton Migration

**Decision**: Create `PrimaryButton` as a new widget. Then find-and-replace all `MvButton` usages with `PrimaryButton` equivalents. Finally remove `MvButton`.

**Mapping**:
| MvButton API | PrimaryButton API |
|---|---|
| `MvButton(label:, onPressed:, variant: primary)` | `PrimaryButton(label:, onPressed:)` |
| `MvButton(label:, onPressed:, variant: secondary)` | `PrimaryButton.outlined(label:, onPressed:)` |
| `MvButton(label:, onPressed:, variant: destructive)` | `PrimaryButton(label:, onPressed:)` with error color (or keep destructive as a separate concern) |
| `MvButton(isLoading: true)` | `PrimaryButton(isLoading: true)` |
| `MvButton(onPressed: null)` | `PrimaryButton(onPressed: null)` (disabled) |

**Note**: The `destructive` variant doesn't have a direct PrimaryButton equivalent in the spec. Options:
- Option A: Add a `destructive` parameter to PrimaryButton
- Option B: Keep destructive as a separate button or use outlined variant with red text
- **Chosen**: Option A — add `isDestructive` bool that uses error color instead of ember red. This covers the existing usage without introducing a new widget.

---

## R7: Google Fonts in Flutter Tests

**Decision**: Disable runtime font fetching in tests and use default text rendering.

**Approach**:
- In `flutter_test_config.dart`, set `GoogleFonts.config.allowRuntimeFetching = false`.
- Tests will render with Flutter's default test font (Ahem or Roboto depending on platform).
- Typography token tests verify `TextStyle` properties (fontFamily, fontSize, fontWeight) without requiring actual font rendering.
- Golden tests will render with whatever fonts are available in the test environment — the golden images will be regenerated to match.

**Rationale**: Attempting to load real Google Fonts in tests adds flakiness (network dependency) and complexity. The test contract is that tokens produce the correct `TextStyle` properties, not that the font file renders pixel-perfectly.
