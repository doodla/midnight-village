# Art Direction — Firelit Gothic

## Identity

| Field   | Value |
|---------|-------|
| type    | creative-direction |
| domain  | art |

This document is the art bible for Midnight Village. Every visual asset — role cards, sigils, backgrounds, particles, avatars — must be consistent with these constraints. If a generated asset doesn't feel like it belongs, this document explains why and what to fix.

All color references use tokens from `design-tokens.md`. No raw hex values.

---

## Visual Identity

### North Star

"Warm darkness, not cold tech dark mode. Candlelit tavern at midnight."

The aesthetic is **Firelit Gothic**: medieval-fantasy atmosphere rendered with the polish of a premium app. The intersection of Cult of the Lamb's personality and Linear's craft. Every visual element should feel hand-crafted and authored, never generated-looking or template-driven.

### Key Attributes

| Attribute | Description | Anti-Pattern |
|-----------|-------------|-------------|
| Warm | Amber candlelight, brown-gold tones, cozy shadows | Cool blue-grey, neon, clinical whites |
| Atmospheric | Layered depth, fog, embers, light sources that feel real | Flat fills, sharp clean edges, empty space |
| Theatrical | Dramatic moments earned through contrast with quieter ones | Everything dramatic, nothing resting |
| Authored | Every element placed with intention, consistent style | Generic icons, stock illustrations, default Material |
| Playful-dark | Spooky enough to be exciting, warm enough to laugh | Horror, gore, genuinely threatening imagery |

---

## Role Card Art

Role cards are the hero visual of the game. The role reveal is the signature moment — every card must be worthy of that 600ms card flip.

### Aspect Ratio & Dimensions

| Property | Value | Rationale |
|----------|-------|-----------|
| Aspect ratio | **3:4** (width:height) | Tall enough for dramatic portrait composition; compact enough to fit mobile viewports with room for UI chrome. Familiar from physical card games. |
| Render width | 780px | High-resolution source. Displays at responsive dp widths (max ~300dp on phone). |
| Render height | 1040px | Derived from 3:4 ratio at 780px width. |
| Display max width | 300dp | On a 360dp-wide phone with `AppSpacing.base` (16dp) padding on each side, card occupies 328dp minus card internal padding. |
| Display max height | 400dp | Derived from 3:4 at 300dp. Occupies ~55-65% of typical phone viewport. |
| Corner radius | `AppRadius.xxl` (24dp) | Generous rounding for the hero card surface. |
| Border | 1dp, team accent color | `AppColors.teamVillage`, `AppColors.teamWerewolf`, or `AppColors.teamIndependent`. |
| Background | `AppColors.surface` | Card surface color. Illustration composited on top. |

### Card Layout Zones

```
┌──────────────────────────┐
│                          │
│                          │
│    ILLUSTRATION ZONE     │
│    (top 60%)             │
│    Character portrait    │
│    centered in frame     │
│                          │
│                          │
├──────────────────────────┤
│  IDENTITY ZONE (bot 40%) │
│  ┌──────────────────┐    │
│  │ Role Name (H1)   │    │
│  │ Team Badge        │    │
│  │ Description (Body)│    │
│  └──────────────────┘    │
└──────────────────────────┘
```

| Zone | Height Share | Content | Typography |
|------|-------------|---------|------------|
| Illustration | 60% | Character portrait, transparent or dark background | — |
| Identity | 40% | Role name, team indicator, one-sentence description | `AppTextStyles.heading1` for name, `AppTextStyles.label` for team, `AppTextStyles.body` for description |

### Card Back (Face-Down State)

The face-down card back is what players see before the flip reveal. It must feel like a sealed artifact.

| Property | Value |
|----------|-------|
| Background | `AppColors.surface` |
| Pattern | Repeating gothic geometric (interlocking diamonds or quatrefoils) in `AppColors.outline` at 40% opacity |
| Center motif | Village seal — circular emblem with a wolf silhouette encircled by thorny vines |
| Seal color | `AppColors.tallowGold` at 60% opacity |
| Edge decoration | 1dp border in `AppColors.outline`, inner 4dp decorative frame in `AppColors.outlineSubtle` |
| Corner radius | `AppRadius.xxl` (24dp), matching face |

### Style Direction

All 12 role illustrations share a single consistent art style, as if painted by the same artist.

| Attribute | Specification | Constraints |
|-----------|--------------|-------------|
| Medium | Digital painting with visible brush texture | Not 3D renders. Not flat vector. Not photorealistic. |
| Lighting | Single warm light source from below-left (candlelight direction) | Consistent across all cards. Creates dramatic upward shadows on faces. |
| Palette | Dominated by the card's team accent + warm neutrals (browns, umbers, ochres) | Background illustration uses `AppColors.deepVoid` to `AppColors.surface` gradient. Clothing/props use team-adjacent tones. |
| Composition | Character from chest up, centered, facing viewer or 3/4 turn | No full-body poses. No dynamic action poses. Characters are still, present, watching. |
| Expression | Readable personality — each role's disposition visible in their face | Werewolves: sly, knowing. Seer: calm, penetrating. Villager: wary, honest. Tanner: desperate, manic. |
| Detail level | High detail on face and hands, atmospheric fade on edges and clothing | Focus the viewer on the character's face and expression. |
| Background | Dark atmospheric fade — not a scene, not a location | Subtle atmospheric elements (faint smoke, embers, candlelight flicker) are fine. No environmental storytelling. |
| Age/presentation | Varied — different ages, builds, skin tones across the 12 roles | The village is diverse. No homogeneous character design. |

### Color Treatment by Team

| Team | Primary Tones | Accent Placement | Background Tone |
|------|--------------|------------------|----------------|
| Village (`AppColors.teamVillage`) | Warm golds, browns, honey tones | Gold accents on clothing details, jewelry, eye highlights | Warm dark (`AppColors.surface` -> `AppColors.deepVoid`) |
| Werewolf (`AppColors.teamWerewolf`) | Deep reds, burgundy, ash grey | Red accents on eyes, claw marks, blood-tinged shadows | Cooler dark with red-tinted edges |
| Independent (`AppColors.teamIndependent`) | Muted earth tones, dusty browns, faded cloth | Desaturated overall — intentionally less vibrant than Village or Werewolf | Neutral dark, slightly washed out |

### Per-Role Art Direction

| Role | Team | Character Direction | Distinguishing Visual Elements |
|------|------|--------------------|-----------------------------|
| Werewolf | Werewolf | Human form with predatory undertone. Sharp features, amber-red eyes, slight lupine quality | Faint claw marks on collar. Shadow behind suggests wolf form. Eyes catch light unnaturally. |
| Minion | Werewolf | Servile, eager, slightly unsettling. Hooded or cloaked. | One eye visible, gleaming. Hands clasped or wringing. Hood casts deep shadow. |
| Villager | Village | Honest, plain, watchful. Farmer or tradesperson. | Simple clothing, work-worn hands. Direct gaze. Lantern or candle nearby. |
| Seer | Village | Wise, penetrating, otherworldly calm. Elder or mystic. | Crystal ball, scrying mirror, or glowing eye motif. Ornate shawl or robes. Third eye suggested in shadow. |
| Robber | Village | Roguish, charming, quick. Light fingers, quick eyes. | Mask pushed up on forehead or hanging from neck. Bag of stolen goods. Mischievous half-smile. |
| Troublemaker | Village | Chaotic, amused, wild-haired. Trickster energy. | Playing cards or dice in hand. Mismatched clothing. Spark of mischief in eye. |
| Drunk | Village | Bleary, confused, good-natured. Swaying slightly. | Tankard or bottle. Unfocused gaze. Warm ruddy cheeks. Crooked hat. |
| Insomniac | Village | Alert, anxious, wide-eyed. Cannot sleep. | Dark circles under bright eyes. Candle burning low. Nightclothes. Clutching blanket. |
| Mason (×2) | Village | Stoic, trustworthy, solid. Builder or craftsperson. | Mason's tools (square, compass, chisel). Apron. Calloused hands. Steady gaze. |
| Hunter | Village | Grim, determined, dangerous. Armed. | Crossbow slung or gripped. Weathered face. Scars. Eyes tracking something off-frame. |
| Tanner | Independent | Desperate, feverish, pitiful. Wants to be caught. | Stained leather apron. Chemical-burned hands. Wild eyes. Unkempt. Slightly repulsive. |
| Doppelganger | Village* | Uncanny, shifting, mirror-like. Identity unclear. | Face partially in shadow or reflection. Features subtly blurred. Two-toned or split lighting. Mirror shard or reflective surface. |

### Imagen Generation Constraints

When generating role card art via Imagen or similar AI image generation:

| Parameter | Value |
|-----------|-------|
| Style prompt prefix | "Digital painting, warm candlelight, visible brush texture, dark atmospheric background, portrait orientation, chest-up composition, single warm light source from below-left" |
| Negative prompt | "3D render, photorealistic, flat vector, cartoon, anime, chibi, neon colors, bright background, full body, action pose, text, watermark, frame, border" |
| Output format | PNG with transparency or dark background |
| Output resolution | 780 × 1040px minimum |
| Post-processing | Color grade to match team palette. Adjust warmth. Add subtle grain (2% overlay). Composite onto card template. |
| Consistency check | Compare against existing cards for lighting direction, detail level, color temperature, brush quality. Reject if style drifts. |

---

## Sigil Design Language

### Overview

Every player receives a randomly assigned gothic sigil paired with a deterministic color derived from their name. Sigils are the player's visual identity throughout the game — they appear on avatars, player grids, voting targets, and result tables.

### Sigil Symbol Vocabulary

20 symbols, all drawn from medieval and gothic iconography. Each must be recognizable at 24dp (`AppDimensions.iconMd`) and legible at 16dp (`AppDimensions.iconSm`).

| Index | Symbol | Visual Description | Silhouette Test |
|-------|--------|-------------------|-----------------|
| 0 | Crescent Moon | Waning crescent, horns pointing right | Distinct curved shape |
| 1 | Raven | Profile view, wings folded, perched | Bird silhouette, beak visible |
| 2 | Dagger | Straight blade, crossguard, pommel | Narrow vertical with cross |
| 3 | Chalice | Stemmed goblet, wide rim | Goblet shape, unmistakable |
| 4 | Skeleton Key | Ornate bow, long shaft, simple bit | Key shape, recognizable at all sizes |
| 5 | Watching Eye | Open eye with iris, stylized lashes | Almond shape with center dot |
| 6 | Candle Flame | Teardrop flame on narrow taper | Flame shape above line |
| 7 | Shield | Heater shield, no emblem | Triangle-rounded shape |
| 8 | Crown | Three-pointed crown, simple | Three peaks above band |
| 9 | Wolf Head | Profile, mouth closed, ear pointed | Canine silhouette |
| 10 | Skull | Front view, simplified | Round top, jaw, eye sockets |
| 11 | Rose | Open bloom, one leaf on stem | Flower with stem |
| 12 | Serpent | Coiled, head raised, forked tongue | S-curve with head |
| 13 | Pentacle Star | Five-pointed, single stroke | Star shape |
| 14 | Grimoire | Closed book, clasp visible | Rectangle with clasp |
| 15 | Bell | Traditional bell shape, clapper visible | Bell silhouette |
| 16 | Quill | Feather quill, angled | Feather shape |
| 17 | Compass Rose | Four-pointed directional star | Cross with pointed ends |
| 18 | Hourglass | Classic hourglass, sand falling | Two triangles touching |
| 19 | Lantern | Hanging lantern, glass panes, glow | Rectangle with handle and glow lines |

### Sigil Style Constraints

| Property | Value | Constraints |
|----------|-------|-------------|
| Stroke style | Single-weight line art, 2dp stroke at medium size | No fills — outline only. Maintains legibility at all sizes. |
| Complexity | Max 20 anchor points per symbol | Simple enough for 16dp rendering. Recognizable as silhouette. |
| Corner style | Slightly rounded, not sharp | Matches the warm aesthetic. No hard geometric precision. |
| Rendering | Vector (SVG source), rasterized per size | Scale-independent source. Pre-render at each avatar size. |

### Sigil Color Palette

10 muted colors assigned deterministically based on player name hash. All colors have similar perceived brightness (~55-65% luminance) to ensure no player's sigil is harder to read than others.

| Index | Name | Hex | Perceived Brightness | Constraints |
|-------|------|-----|---------------------|-------------|
| 0 | Warm Rose | `#D48A8A` | ~62% | Avoids confusion with `AppColors.bloodmoonRed` (more muted, more pink) |
| 1 | Copper | `#C89A6C` | ~65% | Avoids confusion with `AppColors.tallowGold` (more brown, less saturated) |
| 2 | Sage | `#8AAC96` | ~63% | Close to `AppColors.moonlitSage` but lighter — acceptable, different context |
| 3 | Lavender | `#AC9BC6` | ~62% | Only purple in the system. Unique identification. |
| 4 | Amber | `#D4AC6C` | ~70% | Brightest sigil color. Warm gold family. |
| 5 | Slate | `#8A9CA6` | ~61% | Cool accent. Distinguishable from `AppColors.noDeathBlue` (different context). |
| 6 | Sienna | `#B0806A` | ~56% | Warm brown. Darkest sigil color. |
| 7 | Teal | `#6CACA6` | ~63% | Cool-warm. Stands out against warm backgrounds. |
| 8 | Mauve | `#C68AA6` | ~60% | Pink-purple. Unique hue in the system. |
| 9 | Ochre | `#C6AC6A` | ~68% | Golden brown. Earthy. |

### Sigil Assignment Algorithm

```
symbolIndex = hash(playerName) % 20
colorIndex  = hash(playerName + "color") % 10
```

The hash function must be deterministic and stable across sessions (same name always gets the same sigil). Use a simple string hash (djb2 or similar). The salt "color" ensures symbol and color assignments are independent — a player doesn't always get the same color with the same symbol position.

### Sigil Rendering by Size

| Avatar Size | Sigil Render Size | Stroke Width | Background |
|-------------|------------------|-------------|------------|
| Small (32dp) | 16dp | 1.5dp | Circular dark fill (`AppColors.surfaceInset`) |
| Medium (48dp) | 24dp | 2dp | Circular dark fill (`AppColors.surfaceInset`) |
| Large (64dp) | 32dp | 2.5dp | Circular dark fill (`AppColors.surfaceInset`) |

All sigil avatars render as a circle with `AppColors.surfaceInset` fill, 1dp `AppColors.outline` border, and the sigil icon centered in the assigned sigil color.

---

## Avatar System

### Default: Sigil Avatar

Every player starts with a sigil avatar (see Sigil Design Language above). No setup required — the sigil is assigned the moment a player enters a name.

### Optional: Photo Avatar

Players can upload a photo. The system stylizes it to match the Firelit Gothic aesthetic using AI image processing.

| Property | Value |
|----------|-------|
| Input | Player selfie or photo (any aspect ratio) |
| Crop | Center-crop to 1:1 square |
| Output size | 256 × 256px (source), displayed at avatar token sizes |
| Display shape | Circular clip with 1dp `AppColors.outline` border |

### Photo Stylization Constraints

| Parameter | Value |
|-----------|-------|
| Style | Dark, warm, painterly — as if the player sat for a portrait by the village painter |
| Color grade | Desaturate by 30%, shift white balance warm (+15% toward amber), increase contrast |
| Lighting | Simulate single candle light source: warm highlights on face, deep shadows opposite |
| Background | Strip and replace with dark atmospheric gradient (`AppColors.deepVoid` -> `AppColors.surface`) |
| Vignette | Subtle dark vignette, 15% darken at edges |
| Grain | Match `AppOpacity.grain` (3%) overlay |
| Likeness | Must remain immediately recognizable — stylization enhances, never obscures |

### Avatar Display States

| State | Treatment | Context |
|-------|-----------|---------|
| Default | Standard render (sigil or photo) | Player lists, grids, lobby |
| Selected | `AppGlows.selection` glow ring around avatar | Voting target, night action target |
| Eliminated | Greyscale desaturation + 30% opacity reduction | Results table, eliminated player |
| Disconnected | Faded to 50% opacity, fog particle overlay | Disconnection notification |
| Host | `AppColors.tallowGold` 2dp border ring replacing standard border | Lobby, any player list |

---

## Background Illustrations

### Philosophy

Backgrounds create atmosphere without demanding attention. They are mood-setters, not focal points. All backgrounds must work as deep layers beneath cards, text, and interactive elements.

### Phase Background Treatment

Each phase uses its phase background color (from `design-tokens.md`) as the flat base, with an optional atmospheric illustration layer on top.

| Phase | Base Color Token | Illustration Layer | Illustration Opacity | Mood |
|-------|-----------------|-------------------|---------------------|------|
| Welcome / Auth | `AppColors.phaseLobby` | Misty village silhouette — clustered buildings, church steeple, bare trees against moonlit sky | 12% | Approaching the village at night. Mystery. Invitation. |
| Lobby | `AppColors.phaseLobby` | Tavern interior suggestion — timber beams, hanging lantern shapes, fireplace glow | 10% | Inside the tavern. Warm, social, anticipation. |
| Night | `AppColors.phaseNight` | None — rely on particle effects (embers, fog) and candle glow | — | Pure darkness with living light. Void with warmth. |
| Discussion | `AppColors.phaseDiscussion` | Faint village square — cobblestones, well, distant building outlines | 8% | Dawn stirring. The village wakes. |
| Voting | `AppColors.phaseVoting` | None — rely on environmental darkening and pressure effects | — | Stripped back. Tension. Focus on the vote. |
| Results | `AppColors.phaseResults` | Faint graveyard elements — iron fence, headstones, bare tree | 8% | Resolution. Aftermath. Reveal. |

### Illustration Style Constraints

| Property | Value | Constraints |
|----------|-------|-------------|
| Medium | Silhouette / outline art | No filled areas. No detail. Shapes only. |
| Color | Monochrome, slightly lighter than phase background | Use phase background hex lightened by 8-12%. Never introduce new hues. |
| Complexity | 3-5 major shapes per illustration | Too much detail becomes noise. Too little reads as empty. |
| Position | Bottom-anchored, bleeding off bottom and sides | Illustrations are grounded — buildings rise from the bottom, not floating. |
| Parallax | Optional: 2-3dp horizontal shift on device tilt | Subtle depth cue. Never more than 3dp displacement. |
| Tile edge | Illustrations must not repeat or tile. Single-screen compositions. | Unique per phase. Sized to cover max content width. |

### Illustration Rendering

| Property | Value |
|----------|-------|
| Source format | SVG (vector) |
| Render resolution | Match screen resolution |
| Blend mode | Screen (lightens the base) or Normal at low opacity |
| Layer position | Above phase background fill, below noise grain, below all content |

---

## Particle Effects — Art Direction

Particle parameters (count, size, speed) are defined in `design-tokens.md` under Particle Effect Tokens. This section defines the **visual quality** and artistic intent.

### Floating Embers (`AppParticles.embers`)

| Property | Direction |
|----------|-----------|
| Shape | Soft-edged circles and irregular ovals. Not sharp geometric. |
| Color | `AppColors.tallowGold` with per-particle opacity variation (0.15–0.40 per `design-tokens.md`) |
| Behavior | Gentle upward drift with slight horizontal wander. Occasional brighter "spark" particle (1 in 10, opacity 0.5). |
| Birth/death | Fade in from 0 opacity at bottom of screen, fade out near top. No popping in or out. |
| Context | Embers suggest a fire below the visible area. The room has a hearth. |

### Dust Motes (`AppParticles.dust`)

| Property | Direction |
|----------|-----------|
| Shape | Tiny circles, 1-3dp. Nearly invisible individually. |
| Color | `AppColors.parchment` at very low opacity (0.08–0.20 per `design-tokens.md`) |
| Behavior | Random Brownian drift — no dominant direction. Catch light briefly (opacity spike to 0.30 for 200ms) then fade. |
| Birth/death | Appear and disappear gradually. Distributed across entire screen. |
| Context | Dust in the air, caught in candlelight. Suggests a real, physical space. |

### Fog Wisps (`AppParticles.fog`)

| Property | Direction |
|----------|-----------|
| Shape | Large soft blobs (40-120dp per `design-tokens.md`). Gaussian blur at 20dp radius. |
| Color | `AppColors.parchment` at extremely low opacity (0.03–0.08 per `design-tokens.md`) |
| Behavior | Slow horizontal drift, left to right. Each wisp has independent speed. Subtle vertical undulation (sine wave, 0.5Hz, 5dp amplitude). |
| Birth/death | Drift in from left edge, drift out past right edge. Lifecycle: 15-30 seconds per wisp. |
| Context | Ground fog creeping through the village. Eerie but gentle. |

### Reduced Motion Fallback

When `MediaQuery.disableAnimations` is true, replace all particle systems with:

| Replacement | Description |
|-------------|-------------|
| Static embers | 8-12 fixed ember dots placed in natural-looking positions (not grid). Mid-opacity (0.25). |
| Static dust | Skip entirely — too subtle to justify static version. |
| Static fog | 2-3 fixed fog patches at bottom of screen, low opacity (0.05). |

---

## Decorative Patterns

### Card Back Pattern

The geometric pattern on face-down role cards.

| Property | Value |
|----------|-------|
| Pattern type | Interlocking quatrefoils (four-lobed shapes) in a diagonal grid |
| Stroke | 0.5dp in `AppColors.outline` at 40% opacity |
| Fill | None (transparent) |
| Grid spacing | 24dp center-to-center |
| Lobe radius | 6dp |
| Orientation | 45-degree rotation for diamond arrangement |

### Wax Seal (Card Back Center)

| Property | Value |
|----------|-------|
| Shape | Circle, 64dp diameter |
| Color | `AppColors.tallowGold` at 60% opacity |
| Content | Wolf head silhouette (sigil index 9) centered |
| Texture | Subtle wax-drip edge irregularity — not a perfect circle |
| Shadow | 2dp inset shadow for wax depth effect |

### Decorative Frame (Card Back Edge)

| Property | Value |
|----------|-------|
| Inset | 4dp from card edge |
| Stroke | 0.5dp in `AppColors.outlineSubtle` |
| Corners | Matched to card corner radius minus 4dp (`AppRadius.xxl` - 4 = 20dp) |
| Decoration | Small gothic trefoils at each corner (4dp size) |

---

## Usage Rules

- DO: Generate all role art from the same Imagen prompt template, varying only the character-specific details. This ensures style consistency.
- DO: Color-grade every generated asset to match the token palette before use. Raw AI output will drift.
- DO: Test every illustration at 1x, 2x, and 3x display density for legibility.
- DO: Verify sigil legibility at all three avatar sizes (32dp, 48dp, 64dp) before adding to the vocabulary.
- DO: Keep background illustrations as the quietest visual layer. They should be nearly invisible when the player is focused on content.
- DO: Use team glow effects (`AppGlows.teamVillage`, etc.) on role cards during reveal to reinforce team identity through light, not just color.
- DO NOT: Use different art styles across role cards. One artist, one style, one lighting setup.
- DO NOT: Include text in illustrations. All text is rendered by the type system.
- DO NOT: Use bright, saturated colors in background illustrations. They must be barely visible over the phase background.
- DO NOT: Generate role art with environmental backgrounds (rooms, landscapes). Characters exist against atmospheric void.
- DO NOT: Use the wolf sigil symbol (#9) in player avatars during a game where Werewolf is in play. This creates unfair meta-associations. Replace with next symbol in sequence (Skull, #10) if collision occurs.
- DO NOT: Allow particle effects to layer over interactive elements in a way that implies interactivity (no ember directly over a button).

## Pairing Rules

- Role card illustration zone always pairs with team-colored border and team glow during reveal animation.
- Sigil avatars always pair with circular dark fill (`AppColors.surfaceInset`) and 1dp `AppColors.outline` border.
- Photo avatars always pair with circular clip, 1dp `AppColors.outline` border, and the same sizing tokens as sigil avatars.
- Host avatars always pair with `AppColors.tallowGold` 2dp border ring, replacing the standard `AppColors.outline` border.
- Background illustrations always pair with noise grain above them and phase background below them. They are never the topmost visual layer.
- `AppParticles.embers` always pairs with `AppGlows.candle` on Night screens. One without the other feels incomplete.
- Blood Vignette (`AppGlows.bloodVignette`) never pairs with embers or candle glow — the elimination moment has its own distinct atmosphere.

## Examples

### Dart: Building a Sigil Avatar Widget

```dart
Widget buildSigilAvatar(String playerName, {required AvatarSize size}) {
  final symbolIndex = djb2Hash(playerName) % 20;
  final colorIndex = djb2Hash('$playerName:color') % 10;
  final sigilColor = AppSigilColors.values[colorIndex];
  final diameter = switch (size) {
    AvatarSize.small => AppDimensions.avatarSm, // 32dp
    AvatarSize.medium => AppDimensions.avatarMd, // 48dp
    AvatarSize.large => AppDimensions.avatarLg, // 64dp
  };

  return Container(
    width: diameter,
    height: diameter,
    decoration: BoxDecoration(
      color: AppColors.surfaceInset,
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.outline, width: 1),
    ),
    child: Center(
      child: SigilIcon(
        symbol: SigilSymbol.values[symbolIndex],
        color: sigilColor,
        size: diameter * 0.5,
      ),
    ),
  );
}
```

### Imagen: Role Card Generation Prompt Template

```
Style: "Digital painting, warm candlelight, visible brush texture,
        dark atmospheric background, portrait from chest up,
        single warm light source from below-left,
        medieval fantasy, Firelit Gothic, hand-painted feel"

Character: "[ROLE-SPECIFIC CHARACTER DESCRIPTION]"

Negative: "3D render, photorealistic, flat vector, cartoon, anime,
           chibi, neon, bright background, full body, action pose,
           text, watermark, frame, border, modern clothing"

Aspect ratio: 3:4
Resolution: 780 × 1040px
```

### Background Illustration Composition

```
Welcome screen background:
┌─────────────────────────────────┐
│                                 │
│         ○ (moon, faint)         │
│                                 │
│    ╱╲   ╱╲                      │
│   ╱  ╲ ╱  ╲  ╱╲                │  <- Building silhouettes
│──╱────╲╱────╲╱──╲─── ─── ───   │     at 12% opacity
│ ╱  ┌┐  ╳  ┌┐ ╲  ╲              │
│╱   └┘     └┘  ╲  ╲    ╱╲       │
│═══════════════════════════════  │  <- Ground line
└─────────────────────────────────┘
  Anchored to bottom. Bleeds off sides.
  Phase background color fills everything above.
```

---

## Open Questions

(none)
