# Design Tokens — Firelit Gothic

## Identity

| Field   | Value |
|---------|-------|
| type    | tokens |
| domain  | color, typography, spacing, radius, shadow, motion |

---

## Color Palette

### Core Palette

The Firelit Gothic palette is warm-dark. Every color has visible warmth except No Death Blue, which is intentionally cold as a contrast.

| Name | Dart Reference | Hex | RGB | Usage | Constraints |
|------|---------------|-----|-----|-------|-------------|
| Blood Ember | `AppColors.bloodEmber` | `#B8432F` | 184, 67, 47 | Primary CTA, danger actions, werewolf UI accent | Never use for body text. Always pair with Parchment text. Minimum touch target 48dp when used on buttons. |
| Tallow Gold | `AppColors.tallowGold` | `#C8A24D` | 200, 162, 77 | Selection state, highlights, village team accent, active indicators | Primary interactive color. Never use as background fill on areas larger than 64dp square. |
| Moonlit Sage | `AppColors.moonlitSage` | `#5B8A72` | 91, 138, 114 | Success confirmation, safe/positive accents | Use sparingly — max 2 instances per screen. Not a primary interactive color. |
| Deep Void | `AppColors.deepVoid` | `#0D0B0F` | 13, 11, 15 | Night phase background, deepest layer | Only as phase background. Never for cards or surfaces — too dark, kills contrast with other phase bgs. |
| Surface | `AppColors.surface` | `#1A1714` | 26, 23, 20 | Cards, panels, bottom sheets, elevated surfaces | Primary card background. Must sit on a phase background, never directly on Deep Void without a visible edge. |
| Surface Inset | `AppColors.surfaceInset` | `#13110E` | 19, 17, 14 | Input fields, wells, recessed areas within cards | Only inside Surface containers. Creates depth within cards. |
| Surface Elevated | `AppColors.surfaceElevated` | `#242019` | 36, 32, 25 | Tooltips, dropdowns, popovers, surfaces above cards | Must include a shadow (AppShadows.elevated) to distinguish from Surface. |
| Parchment | `AppColors.parchment` | `#E8DFD3` | 232, 223, 211 | Primary text, headings, high-emphasis content | Default text color on all dark surfaces. Contrast ratio vs Surface: 10.8:1. |
| Parchment Muted | `AppColors.parchmentMuted` | `#9C9084` | 156, 144, 132 | Secondary text, captions, timestamps, helper text | Never for interactive elements or headings. Contrast ratio vs Surface: 4.2:1 (meets AA for large text only). |
| Outline | `AppColors.outline` | `#3D362C` | 61, 54, 44 | Standard borders, dividers, card edges | Default border color. 1dp width. |
| Outline Subtle | `AppColors.outlineSubtle` | `#2A251F` | 42, 37, 31 | Hairline dividers, faint separators | Use for visual rhythm without strong visual weight. |
| Outline Strong | `AppColors.outlineStrong` | `#4D4438` | 77, 68, 56 | Focus rings, emphasized borders, active input borders | Use for focus-visible states and important boundaries. |
| Bloodmoon Red | `AppColors.bloodmoonRed` | `#C94038` | 201, 64, 56 | Werewolf team identification, elimination vignette | Team identification only. Do not use for CTA buttons (use Blood Ember for actions). |
| Grave Dust | `AppColors.graveDust` | `#8B7D6B` | 139, 125, 107 | Tanner/independent team, neutral accents | Intentionally muted. Do not brighten or saturate. |
| No Death Blue | `AppColors.noDeathBlue` | `#6B7B8B` | 107, 123, 139 | "No one dies" elimination outcome only | The only cold color in the palette. Never use outside the no-elimination context. One purpose, one place. |
| Ember Amber | `AppColors.emberAmber` | `#CC843A` | 204, 132, 58 | Timer warning state, transitional accent between gold and red | Timer ramp only. Not a general-purpose accent. Sits midway between Tallow Gold and Blood Ember in hue. |

### Phase Backgrounds

Each game phase has a distinct background. All are warm-dark, distinguished by subtle temperature and lightness shifts. Applied as full-screen fills beneath all content.

| Phase | Dart Reference | Hex | RGB | Mood | Constraints |
|-------|---------------|-----|-----|------|-------------|
| Lobby | `AppColors.phaseLobby` | `#1A1410` | 26, 20, 16 | Warm interior, tavern glow | Warmest phase background. Slight amber cast. |
| Night | `AppColors.phaseNight` | `#0D0B0F` | 13, 11, 15 | Deepest void, silence | Identical to Deep Void. Coolest phase bg — slight violet cast. |
| Discussion | `AppColors.phaseDiscussion` | `#151210` | 21, 18, 16 | Dawn approaching, stirring | Warmer than Night, darker than Lobby. Transitional. |
| Voting | `AppColors.phaseVoting` | `#12100E` | 18, 16, 14 | Warm tension, stillness | Nearly neutral dark. Between Night and Discussion in lightness. |
| Results | `AppColors.phaseResults` | `#0F0D0B` | 15, 13, 11 | Settling into reveal, somber warmth | Dark but warm. Slight brown cast vs Night's violet. |

### Team Colors

Used for role card accents, team badges, result highlights, and glow effects.

| Team | Accent | Dart Reference | Background Tint | Dart Reference | Usage |
|------|--------|---------------|-----------------|---------------|-------|
| Village | `#C8A24D` | `AppColors.teamVillage` | `#C8A24D` at 8% opacity | `AppColors.teamVillageBg` | Role cards, result badges, win announcements |
| Werewolf | `#C94038` | `AppColors.teamWerewolf` | `#C94038` at 8% opacity | `AppColors.teamWerewolfBg` | Role cards, result badges, loss announcements |
| Independent | `#8B7D6B` | `AppColors.teamIndependent` | `#8B7D6B` at 8% opacity | `AppColors.teamIndependentBg` | Tanner role card, result badge |

### Timer Color Ramp

The discussion and voting timer shifts color as time runs out. Thresholds are percentages of the total timer duration.

| Time Remaining | Color | Dart Reference | Behavior | Constraints |
|---------------|-------|---------------|----------|-------------|
| 100%–50% | Tallow Gold `#C8A24D` | `AppColors.timerNormal` | Steady, no pulse | Default timer state |
| 50%–25% | Ember Amber `#CC843A` | `AppColors.timerWarning` | Steady, no pulse | Transition via 400ms crossfade at 50% threshold |
| 25%–10% | Blood Ember `#B8432F` | `AppColors.timerUrgent` | Slow pulse: 2s cycle, opacity 0.8–1.0 | Crossfade at 25% threshold. Pulse is subtle. |
| 10%–0% | Bloodmoon Red `#C94038` | `AppColors.timerCritical` | Fast pulse: 0.8s cycle, opacity 0.7–1.0 | Crossfade at 10% threshold. Pulse is assertive but not alarming. |

### Interactive State Colors

Applied as overlays on interactive elements. All use the element's own color modified by opacity or blend.

| State | Method | Dart Reference | Constraints |
|-------|--------|---------------|-------------|
| Pressed | Darken element by 15% | `AppColors.statePressed` | Apply via `Color.lerp(color, Colors.black, 0.15)`. Duration: 100ms. |
| Disabled | Element at 38% opacity | `AppColors.stateDisabled` | Apply via `.withOpacity(0.38)`. No interaction response. |
| Selected | Element at full opacity + selection glow | — | Combine with `AppGlows.selection`. |
| Focus Visible | Outline Strong ring, 2dp offset | — | Use `AppColors.outlineStrong`. Only shows on keyboard/switch navigation. |

### Opacity Scale

| Name | Dart Reference | Value | Usage |
|------|---------------|-------|-------|
| Scrim | `AppOpacity.scrim` | 0.60 | Modal backdrop, phase transition overlay |
| Overlay | `AppOpacity.overlay` | 0.40 | Partial obscuring, dim behind drawers |
| Disabled | `AppOpacity.disabled` | 0.38 | Disabled elements |
| Hint | `AppOpacity.hint` | 0.20 | Ghost elements, placeholder slots |
| Subtle | `AppOpacity.subtle` | 0.10 | Tinted backgrounds, team bg overlays |
| Grain | `AppOpacity.grain` | 0.03 | Noise texture overlay |

---

## Typography

### Font Families

| Role | Font Family | Dart Reference | Google Fonts | Character | Constraints |
|------|------------|---------------|-------------|-----------|-------------|
| Headlines & Display | Epilogue | `AppFonts.headline` | `google_fonts: epilogue` | Serif-gothic gravitas, architectural | Headings and display text only. Never for body paragraphs. |
| Body & UI | DM Sans | `AppFonts.body` | `google_fonts: dm_sans` | Clean readability, neutral warmth | Default for all readable text. Regular (400), Medium (500), Bold (700). |
| Labels & Data | Space Grotesk | `AppFonts.label` | `google_fonts: space_grotesk` | Game UI precision, monospaced feel | Timers, lobby codes, labels, counters, badges. Medium (500), Bold (700). |
| Atmospheric | Libre Baskerville | `AppFonts.flavor` | `google_fonts: libre_baskerville` | Italic warmth, storytelling | Always italic. Narrator text, flavor text. Never for UI controls. |

### Type Scale

Every text style in the system. "Height" is computed line-height in dp; "height multiplier" is the Flutter `height` property on `TextStyle`.

| Name | Dart Reference | Family | Weight | Size (dp) | Height (dp) | Height Multiplier | Letter Spacing (dp) | Usage |
|------|---------------|--------|--------|-----------|-------------|-------------------|---------------------|-------|
| Display XL | `AppTextStyles.displayXl` | Epilogue | 700 | 40 | 48 | 1.20 | -0.5 | Result headlines ("VILLAGE WINS!"), game-over outcome |
| Display | `AppTextStyles.display` | Epilogue | 700 | 32 | 40 | 1.25 | -0.5 | Phase titles, major screen headings |
| Heading 1 | `AppTextStyles.heading1` | Epilogue | 600 | 24 | 32 | 1.33 | 0 | Screen titles, role name on reveal card |
| Heading 2 | `AppTextStyles.heading2` | Epilogue | 600 | 20 | 28 | 1.40 | 0 | Section headings, dialog titles |
| Heading 3 | `AppTextStyles.heading3` | Epilogue | 500 | 18 | 24 | 1.33 | 0 | Subsection headings, card titles |
| Body Large | `AppTextStyles.bodyLarge` | DM Sans | 400 | 16 | 24 | 1.50 | 0 | Role descriptions, prominent body text |
| Body | `AppTextStyles.body` | DM Sans | 400 | 14 | 20 | 1.43 | 0 | Default body text, list items, descriptions |
| Body Bold | `AppTextStyles.bodyBold` | DM Sans | 700 | 14 | 20 | 1.43 | 0 | Inline emphasis within body text |
| Body Small | `AppTextStyles.bodySmall` | DM Sans | 400 | 12 | 16 | 1.33 | 0 | Captions, helper text, secondary info |
| Label Large | `AppTextStyles.labelLarge` | Space Grotesk | 500 | 14 | 20 | 1.43 | 0.5 | Button text, tab labels, prominent controls |
| Label | `AppTextStyles.label` | Space Grotesk | 500 | 12 | 16 | 1.33 | 0.5 | Badges, chips, small labels |
| Label Small | `AppTextStyles.labelSmall` | Space Grotesk | 500 | 10 | 14 | 1.40 | 0.5 | Fine print, timestamps, micro-labels |
| Timer Display | `AppTextStyles.timerDisplay` | Space Grotesk | 700 | 56 | 64 | 1.14 | 2 | Hero countdown timer (discussion/voting) |
| Timer | `AppTextStyles.timer` | Space Grotesk | 700 | 40 | 48 | 1.20 | 1.5 | Standard timer display |
| Timer Compact | `AppTextStyles.timerCompact` | Space Grotesk | 700 | 24 | 32 | 1.33 | 1 | Inline timer, wave timer |
| Code Display | `AppTextStyles.codeDisplay` | Space Grotesk | 700 | 48 | 56 | 1.17 | 10 | Lobby code — big, bold, dramatically letter-spaced |
| Narrator | `AppTextStyles.narrator` | Libre Baskerville | 400i | 22 | 32 | 1.45 | 0.3 | Narrator overlay text ("Night falls on the village...") |
| Flavor | `AppTextStyles.flavor` | Libre Baskerville | 400i | 16 | 24 | 1.50 | 0.15 | Atmospheric descriptions, error headlines |
| Flavor Small | `AppTextStyles.flavorSmall` | Libre Baskerville | 400i | 14 | 22 | 1.57 | 0.15 | Minor atmospheric text, card flavor text |

---

## Spacing

### Spacing Scale

Base unit: 4dp. All spacing values are multiples or halves of the base unit.

| Name | Dart Reference | Value (dp) | Usage |
|------|---------------|------------|-------|
| 3xs | `AppSpacing.xxxs` | 2 | Hairline gaps, icon-to-text micro spacing |
| 2xs | `AppSpacing.xxs` | 4 | Tight internal padding (badges, chips) |
| xs | `AppSpacing.xs` | 6 | Compact element gaps |
| sm | `AppSpacing.sm` | 8 | Standard element gaps, inline spacing |
| md | `AppSpacing.md` | 12 | Card internal padding (tight), list item gaps |
| base | `AppSpacing.base` | 16 | Default content padding, standard card padding |
| lg | `AppSpacing.lg` | 20 | Section gaps within a card |
| xl | `AppSpacing.xl` | 24 | Inter-card gaps, major section separation |
| 2xl | `AppSpacing.xxl` | 32 | Screen section separation |
| 3xl | `AppSpacing.xxxl` | 40 | Hero element vertical breathing room |
| 4xl | `AppSpacing.xxxxl` | 48 | Major screen region separation |
| 5xl | `AppSpacing.xxxxxl` | 64 | Phase transition overlay padding |
| 6xl | `AppSpacing.xxxxxxl` | 80 | Maximum breathing room (results headline) |

### Content Dimensions

| Name | Dart Reference | Value (dp) | Usage | Constraints |
|------|---------------|------------|-------|-------------|
| Screen Padding | `AppDimensions.screenPadding` | 16 | Horizontal padding from screen edge | Applied to all scrollable content. Never place content edge-to-edge. |
| Max Content Width | `AppDimensions.maxContentWidth` | 480 | Maximum width for content on wide screens | Centers content with padding on screens wider than 480dp. Preserves intimate mobile feel. |
| Touch Target Min | `AppDimensions.touchTargetMin` | 48 | Minimum interactive area size | Every tappable element must meet this. Visual size can be smaller if hit area is padded. |
| Avatar Small | `AppDimensions.avatarSm` | 32 | Lists, compact player displays | |
| Avatar Medium | `AppDimensions.avatarMd` | 48 | Player grids, voting grid, player cards | |
| Avatar Large | `AppDimensions.avatarLg` | 64 | Featured moments, results spotlight, elimination | |
| Icon Small | `AppDimensions.iconSm` | 16 | Inline icons, badge icons | |
| Icon Medium | `AppDimensions.iconMd` | 24 | Standard action icons, navigation | Default icon size. |
| Icon Large | `AppDimensions.iconLg` | 32 | Prominent icons, empty states | |

---

## Border Radius

| Name | Dart Reference | Value (dp) | Usage | Constraints |
|------|---------------|------------|-------|-------------|
| none | `AppRadius.none` | 0 | Sharp edges, dividers | |
| xs | `AppRadius.xs` | 2 | Subtle rounding on small elements | |
| sm | `AppRadius.sm` | 4 | Chips, badges, inline tags | |
| md | `AppRadius.md` | 8 | Buttons, input fields, small cards | Default interactive element radius. |
| lg | `AppRadius.lg` | 12 | Standard cards, panels, dialogs | Primary card radius. |
| xl | `AppRadius.xl` | 16 | Bottom sheets, large cards | |
| 2xl | `AppRadius.xxl` | 24 | Hero cards (role reveal card), modal sheets | Used for the most prominent, standalone card surfaces. |
| full | `AppRadius.full` | 9999 | Circular avatars, pill buttons, round indicators | Always produces a circle or pill shape. |

---

## Shadows & Elevation

All shadows use pure black with warm alpha, appropriate for dark UI. Shadows on dark backgrounds need higher opacity than light themes to be visible.

| Level | Dart Reference | Offset X, Y | Blur | Spread | Color | Usage | Constraints |
|-------|---------------|-------------|------|--------|-------|-------|-------------|
| 0 | `AppShadows.none` | 0, 0 | 0 | 0 | transparent | Flat elements, backgrounds | |
| 1 | `AppShadows.card` | 0, 2 | 8 | 0 | `#000000` at 0.30 | Standard cards on phase backgrounds | Default card elevation. |
| 2 | `AppShadows.elevated` | 0, 4 | 16 | 0 | `#000000` at 0.40 | Floating elements, popovers, dropdown menus | Pair with Surface Elevated background. |
| 3 | `AppShadows.overlay` | 0, 8 | 32 | -2 | `#000000` at 0.50 | Modals, bottom sheets, dialogs | Must include scrim backdrop (`AppOpacity.scrim`). |

---

## Glows & Themed Effects

Themed light effects that reinforce the Firelit Gothic aesthetic. These are BoxShadow or RadialGradient effects applied to specific UI contexts.

### Selection & Interaction Glows

| Name | Dart Reference | Type | Color | Blur (dp) | Spread (dp) | Usage | Constraints |
|------|---------------|------|-------|-----------|-------------|-------|-------------|
| Selection | `AppGlows.selection` | BoxShadow | `#C8A24D` at 0.30 | 12 | 2 | Selected player in voting grid, selected center card, active night action target | Animate in over 200ms on select. Remove on deselect. |
| CTA Glow | `AppGlows.cta` | BoxShadow | `#B8432F` at 0.25 | 16 | 0 | Primary CTA button ambient glow | Continuous subtle pulse: 3s cycle, opacity 0.15–0.25. Draws eye to action. |
| Focus Ring | `AppGlows.focus` | BoxShadow | `#4D4438` at 1.0 | 0 | 3 | Keyboard/switch focus indicator | 2dp offset from element edge. Only visible on focus-visible, not on tap. |

### Team Glows

Applied to role cards during reveal and in result screens.

| Team | Dart Reference | Color | Blur (dp) | Spread (dp) | Usage |
|------|---------------|-------|-----------|-------------|-------|
| Village | `AppGlows.teamVillage` | `#C8A24D` at 0.25 | 20 | 4 | Village role card reveal, village win highlight |
| Werewolf | `AppGlows.teamWerewolf` | `#C94038` at 0.25 | 20 | 4 | Werewolf role card reveal, werewolf elements |
| Independent | `AppGlows.teamIndependent` | `#8B7D6B` at 0.20 | 20 | 4 | Tanner role card reveal |

### Atmospheric Glows

Full-screen or large-area effects that set mood.

| Name | Dart Reference | Type | Definition | Usage | Constraints |
|------|---------------|------|------------|-------|-------------|
| Candle Glow | `AppGlows.candle` | RadialGradient | Center: `#C8A24D` at 0.08, radius 50% of screen height, fading to transparent | Night screens — ambient warmth from center | Positioned at screen center. Rendered beneath all content, above phase background. |
| Blood Vignette | `AppGlows.bloodVignette` | RadialGradient | Center: transparent, edge: `#B8432F` at 0.20 | Elimination announcement screen | Full-screen overlay. Fades in over 600ms with elimination reveal. |
| Vision Glow | `AppGlows.vision` | RadialGradient | Center: `#C8A24D` at 0.12, radius 60% of screen height, fading to transparent | Seer peek result, role reveal flip moment | Intensifies during card flip (opacity 0.12 -> 0.20 over 300ms), then settles back. |
| No Death Wash | `AppGlows.noDeathWash` | RadialGradient | Center: `#6B7B8B` at 0.10, radius 50% of screen height, fading to transparent | "No one dies" elimination result | Replaces Blood Vignette when no player is eliminated. Cold and solemn. |

---

## Decorative Effects

### Noise Grain

A static film-grain texture overlaid on all screens to add tactile warmth and break up digital flatness.

| Property | Value | Dart Reference |
|----------|-------|---------------|
| Type | Perlin noise / film grain | — |
| Opacity | 3% (`AppOpacity.grain`) | `AppEffects.grainOpacity` |
| Blend mode | Overlay | `AppEffects.grainBlendMode` |
| Resolution | 2x screen resolution | — |
| Animation | Static (no animation) | — |
| Layer position | Above phase background, below all content and effects | — |

### Particle Effect Tokens

Parameters for the ambient particle systems that make screens feel alive. Particle systems run continuously in the background.

| Effect | Dart Reference | Particle Count | Size Range (dp) | Speed (dp/s) | Opacity Range | Color | Screens |
|--------|---------------|---------------|-----------------|-------------- |---------------|-------|---------|
| Floating Embers | `AppParticles.embers` | 15–25 | 2–5 | 8–20 (upward drift) | 0.15–0.40 | `#C8A24D` | Night, Discussion, Voting |
| Dust Motes | `AppParticles.dust` | 20–35 | 1–3 | 3–8 (random drift) | 0.08–0.20 | `#E8DFD3` | All screens |
| Fog Wisps | `AppParticles.fog` | 3–6 | 40–120 | 2–5 (horizontal drift) | 0.03–0.08 | `#E8DFD3` | Night, Voting |

| Property | Value | Constraints |
|----------|-------|-------------|
| Layer position | Above grain, below UI content | Particles never obscure interactive elements |
| Reduced motion | Replace with static scattered dots at mid-opacity | Respect `MediaQuery.disableAnimations` |
| Performance budget | Max 60 particles total across all active systems | Drop oldest particles if budget exceeded |

---

## Motion Tokens

### Durations

| Name | Dart Reference | Value (ms) | Usage | Constraints |
|------|---------------|------------|-------|-------------|
| Micro | `AppDurations.micro` | 100 | Button press feedback, icon state change, ripple start | Imperceptible as motion — feels instant. |
| Fast | `AppDurations.fast` | 200 | Tooltip appear/dismiss, badge count change, glow in/out | Quick but visible. |
| Standard | `AppDurations.standard` | 300 | Menu open/close, drawer slide, most state transitions | Default transition duration when no specific value is given. |
| Crossfade | `AppDurations.crossfade` | 400 | Sub-state transitions within a phase, timer color shift | Per vision brief section 5: "Smooth crossfades between sub-states within a phase (400ms)." |
| Theatrical | `AppDurations.theatrical` | 600 | Card flip (role reveal), elimination card reveal | Per vision brief: "3D Y-axis rotation (~600ms)." Reserved for hero moments. |
| Cinematic | `AppDurations.cinematic` | 2500 | Phase transition overlays ("Night falls on the village...") | Per vision brief: "2-3 second atmospheric transition." Full-screen overlay sequences. |
| Vote Build | `AppDurations.voteBuild` | 6000 | Vote tally progressive reveal | Per vision brief: "Controlled 5-7 second tally build." Total sequence, not per-vote. |

### Easing Curves

| Name | Dart Reference | Curve | Usage |
|------|---------------|-------|-------|
| Standard | `AppCurves.standard` | `Curves.easeInOut` | General-purpose transitions, most UI motion |
| Enter | `AppCurves.enter` | `Curves.decelerate` | Elements appearing on screen, bottom sheets sliding up |
| Exit | `AppCurves.exit` | `Curves.easeIn` | Elements leaving screen, dismissals |
| Dramatic | `AppCurves.dramatic` | `Curves.easeInOutCubicEmphasized` | Card flip, phase transitions, theatrical moments |
| Bounce | `AppCurves.bounce` | `Curves.elasticOut` | Playful emphasis — vote count landing, win announcement pop |

---

## Usage Rules

### Color

- DO: Reference tokens by Dart name (`AppColors.bloodEmber`), never raw hex values, in all behavioral specs, code, and component definitions.
- DO: Use phase backgrounds as the root layer of every screen. No screen has a flat black or flat grey background.
- DO: Apply team colors through the `AppColors.team*` tokens for role cards, badges, and result highlights.
- DO: Layer surfaces in order: phase background -> Surface -> Surface Elevated. Never skip a level.
- DO NOT: Use Blood Ember and Bloodmoon Red interchangeably. Blood Ember is for actions (CTA, danger). Bloodmoon Red is for team identity (werewolf badge, result tag).
- DO NOT: Place Parchment Muted text on interactive elements. It does not meet contrast requirements for body text (only passes AA Large).
- DO NOT: Use No Death Blue outside the "no one dies" elimination context. It is not a general accent.
- DO NOT: Apply team background tints to areas larger than a single card or badge. They are subtle highlights, not section fills.

### Typography

- DO: Use one text style per element. No mixing fonts within a single text block (except Flavor within a Narrator passage).
- DO: Apply Epilogue only to display and heading styles. It is not a body font.
- DO: Use Space Grotesk for all numeric/data displays: timers, counters, lobby codes, vote tallies.
- DO: Use Libre Baskerville italic for all narrator and atmospheric text. It is always italic — there is no roman-weight usage.
- DO NOT: Use more than 3 distinct text styles on a single screen (excluding timer and narrator overlays).
- DO NOT: Set text smaller than 10dp (`AppTextStyles.labelSmall`). Nothing in the system goes below this.
- DO NOT: Use Epilogue for body paragraphs or descriptions. It is a display face, not a reading face.

### Spacing

- DO: Use spacing tokens for all margins and paddings. No arbitrary values.
- DO: Apply `AppDimensions.screenPadding` (16dp) to all scrollable content as horizontal inset.
- DO: Center content within `AppDimensions.maxContentWidth` (480dp) on screens wider than that value.
- DO NOT: Use spacing values outside the defined scale. If a layout needs a gap between defined values, use the larger value.
- DO NOT: Remove screen padding for "edge-to-edge" effects on content. Phase backgrounds and atmospheric effects are edge-to-edge; content is not.

### Motion

- DO: Use `AppDurations.standard` (300ms) as the default when no specific duration is specified.
- DO: Use `AppCurves.dramatic` for all theatrical moments (card flip, phase transition, elimination).
- DO: Provide static alternatives for all animated effects when reduced motion is enabled.
- DO NOT: Use `AppDurations.theatrical` or `AppDurations.cinematic` for standard UI transitions. These are reserved for game beat moments.
- DO NOT: Chain more than 2 sequential animations on a single element without a clear dramatic purpose.
- DO NOT: Animate opacity below 0.0 or above 1.0, or animate scale below 0.0.

---

## Pairing Rules

### Color Pairings

- `AppColors.parchment` always pairs with dark backgrounds (Surface, Surface Inset, phase backgrounds). Never place on light surfaces.
- `AppColors.parchmentMuted` always pairs with Surface or darker. Not to be used on Surface Elevated (insufficient contrast).
- `AppColors.bloodEmber` CTA buttons always use `AppColors.parchment` for button text. No other text color on Blood Ember backgrounds.
- `AppColors.tallowGold` selection indicators always pair with `AppGlows.selection` on the selected element.
- Team accent colors (`teamVillage`, `teamWerewolf`, `teamIndependent`) always pair with their corresponding glow (`AppGlows.teamVillage`, etc.) on role card reveal.

### Typography Pairings

- `AppTextStyles.narrator` always pairs with `AppGlows.candle` or `AppGlows.vision` as an ambient background effect.
- `AppTextStyles.displayXl` for result headlines always uses `AppColors.parchment` for the team outcome and team accent for emphasis.
- `AppTextStyles.codeDisplay` for lobby codes always sits on `AppColors.surface` with `AppColors.parchment` color.
- `AppTextStyles.timerDisplay` color is always one of the timer ramp colors (`timerNormal` through `timerCritical`), never static.

### Surface Pairings

- `AppShadows.card` always pairs with `AppColors.surface` background.
- `AppShadows.elevated` always pairs with `AppColors.surfaceElevated` background.
- `AppShadows.overlay` always pairs with a scrim backdrop (`AppOpacity.scrim` over the underlying screen).
- `AppColors.surfaceInset` always lives inside a `AppColors.surface` container (input fields, wells, toggle backgrounds).

### Effect Pairings

- `AppGlows.bloodVignette` always pairs with the elimination announcement. Never used in other contexts.
- `AppGlows.noDeathWash` replaces `AppGlows.bloodVignette` when no player is eliminated. They are mutually exclusive.
- `AppGlows.candle` and `AppParticles.embers` always appear together on Night screens.
- `AppGlows.vision` always appears during card peek/reveal moments — Seer peek result and role reveal.

---

## Examples

### Dart: Defining a Core Color

```dart
abstract final class AppColors {
  static const Color bloodEmber = Color(0xFFB8432F);
  static const Color tallowGold = Color(0xFFC8A24D);
  static const Color surface = Color(0xFF1A1714);
  static const Color parchment = Color(0xFFE8DFD3);

  // Phase backgrounds
  static const Color phaseLobby = Color(0xFF1A1410);
  static const Color phaseNight = Color(0xFF0D0B0F);

  // Team colors
  static const Color teamVillage = Color(0xFFC8A24D);
  static const Color teamWerewolf = Color(0xFFC94038);
  static const Color teamIndependent = Color(0xFF8B7D6B);

  // Team background tints
  static Color teamVillageBg = teamVillage.withOpacity(0.08);
  static Color teamWerewolfBg = teamWerewolf.withOpacity(0.08);
}
```

### Dart: Defining a Text Style

```dart
abstract final class AppTextStyles {
  static const TextStyle heading1 = TextStyle(
    fontFamily: 'Epilogue',
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.33,
    letterSpacing: 0,
    color: AppColors.parchment,
  );

  static const TextStyle narrator = TextStyle(
    fontFamily: 'LibreBaskerville',
    fontSize: 22,
    fontWeight: FontWeight.w400,
    fontStyle: FontStyle.italic,
    height: 1.45,
    letterSpacing: 0.3,
    color: AppColors.parchment,
  );

  static const TextStyle timerDisplay = TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontSize: 56,
    fontWeight: FontWeight.w700,
    height: 1.14,
    letterSpacing: 2,
    color: AppColors.tallowGold, // Default; overridden by timer ramp
  );
}
```

### Dart: Applying a Card Surface

```dart
Container(
  decoration: BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(AppRadius.lg), // 12dp
    border: Border.all(color: AppColors.outline, width: 1),
    boxShadow: [AppShadows.card],
  ),
  padding: EdgeInsets.all(AppSpacing.base), // 16dp
  child: // ...
)
```

### Dart: Role Card with Team Glow

```dart
Container(
  decoration: BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(AppRadius.xxl), // 24dp
    border: Border.all(color: AppColors.teamVillage, width: 1),
    boxShadow: [
      AppShadows.card,
      AppGlows.teamVillage, // Golden glow for village role
    ],
  ),
  // ...
)
```

### Dart: Timer with Color Ramp

```dart
Color timerColor(double fractionRemaining) {
  if (fractionRemaining > 0.50) return AppColors.timerNormal;
  if (fractionRemaining > 0.25) return AppColors.timerWarning;
  if (fractionRemaining > 0.10) return AppColors.timerUrgent;
  return AppColors.timerCritical;
}
```

---

## Open Questions

(none)
