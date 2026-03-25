# Stitch UI Mocks — Midnight Village

## Project

- **Stitch Project:** `projects/2967164515754811325`
- **Title:** Midnight Village — ONUW Mobile Game
- **Created:** 2026-03-25
- **Device:** Mobile
- **Design System:** Firelit Gothic (`assets/13353922937867081735`)

## Design System: Firelit Gothic

| Token | Value |
|-------|-------|
| colorMode | DARK |
| headlineFont | EPILOGUE |
| bodyFont | DM_SANS |
| labelFont | SPACE_GROTESK |
| roundness | ROUND_EIGHT |
| customColor (seed) | `#B8432F` (Blood Ember) |
| colorVariant | FIDELITY |
| overridePrimaryColor | `#B8432F` (Blood Ember) |
| overrideSecondaryColor | `#C8A24D` (Tallow Gold) |
| overrideTertiaryColor | `#5B8A72` (Moonlit Sage) |
| overrideNeutralColor | `#1A1714` (Warm Near-Black) |

### Color Palette

| Name | Hex | Usage |
|------|-----|-------|
| Blood Ember | `#B8432F` | Primary actions, danger, CTA buttons |
| Tallow Gold | `#C8A24D` | Highlights, selected states, village team |
| Moonlit Sage | `#5B8A72` | Sparingly for safe/village indicators |
| Bloodmoon Red | `#C94038` | Werewolf team |
| Grave Dust | `#8B7D6B` | Tanner/independent team |
| Deep Void | `#0D0B0F` | Night phase background |
| Surface | `#1A1714` | Cards, elevated elements |
| On-Surface | `#E8DFD3` | Primary text (warm off-white) |
| On-Surface Variant | `#9C9084` | Secondary/muted text |
| Outline | `#3D362C` | Borders, dividers |
| Danger | `#E05A3A` | Timer danger pulse (derived) |
| Warning | `#D47A3A` | Timer warning (derived) |
| No Death Blue | `#6B7B8B` | "No One Dies" elimination — the only cold color in the palette |

### Phase Backgrounds

| Phase | Hex | Notes |
|-------|-----|-------|
| Night | `#0D0B0F` | Deep Void — darkest |
| Lobby | `#1A1714` | Surface — warm interior |
| Discussion | `#151210` | Slightly warmer than night (dawn approaching) |
| Voting | `#12100E` | Warm tension |
| Results | `#0F0D0B` | Dark, settles into reveal |

### Role Icon Mapping

| Role | Icon | Package | Team Color |
|------|------|---------|------------|
| Werewolf | `Symbols.pets` | material_symbols_icons | `#C94038` |
| Minion | `Symbols.psychology` | material_symbols_icons | `#C94038` |
| Seer | `Symbols.visibility` | built-in | `#C8A24D` |
| Robber | `Symbols.masks` | material_symbols_icons | `#C8A24D` |
| Troublemaker | `Symbols.swap_horiz` | built-in | `#C8A24D` |
| Drunk | `Symbols.wine_bar` | material_symbols_icons | `#C8A24D` |
| Insomniac | `Symbols.bedtime_off` | material_symbols_icons | `#C8A24D` |
| Mason | `Symbols.handshake` | material_symbols_icons | `#C8A24D` |
| Hunter | `Symbols.target` | material_symbols_icons | `#C8A24D` |
| Villager | `Symbols.shield` | built-in | `#C8A24D` |
| Tanner | `Symbols.skull` | material_symbols_icons | `#8B7D6B` |
| Doppelganger | `Symbols.content_copy` | built-in | `#C8A24D` |

### Aesthetic Direction

"Firelit Gothic" — warm darkness, not cold tech dark mode. Candlelit tavern at midnight. The UI feels like an artifact from the village itself, not a Silicon Valley app.

## Screen Inventory

| # | Screen | Stitch ID | Game Phase |
|---|--------|-----------|------------|
| 1 | [Welcome/Auth](01-welcome.md) | `bf6805196fe34a6cbdb0c552daccb018` | Pre-game |
| 2 | [Home (Create/Join)](02-home.md) | `2edeb079ce89482585594235140fcd76` | Pre-game |
| 3 | [Lobby Waiting Room](03-lobby.md) | `9697d1c72b874004920415b80895fe6f` | Lobby |
| 4 | [Role Selection](04-role-selection.md) | `4dfd4d3bfa7f4bb49ef9286dc409cb79` | Lobby (host) |
| 5 | [Night Role Reveal](05-role-reveal.md) | `9e6725f960bc450c8434f88aadbb23d9` | Night |
| 6 | [Night Action — Seer](06-night-seer.md) | `3cc5d237e52c48b8b0350baee041771a` | Night (Wave 3) |
| 7 | [Night Action — Robber](07-night-robber.md) | `2efa48a94d4449d69a96567f9298d55a` | Night (Wave 3) |
| 8 | [Night Action — Troublemaker](08-night-troublemaker.md) | `05c311ebe75741a78400de15d4df6554` | Night (Wave 3) |
| 9 | [Night Waiting](09-night-waiting.md) | `036587c80dce4447b2557e463ab834c3` | Night (all waves) |
| 10 | [Night Action Result](10-night-result.md) | `76d3795d919940e4a9e4555a3fdbd6f2` | Night |
| 11 | [Discussion](11-discussion.md) | `f5c95559e35e477ab40c4e0340b63c97` | Discussion |
| 12 | [Voting](12-voting.md) | `790a6b1760da44c3bd265fbce19ca389` | Voting |
| 13 | [Vote Reveal](13-vote-reveal.md) | `ae0a67d7c8754e5b9cadcaf6273a8fdd` | Voting → Results |
| 14 | [Elimination](14-elimination.md) | `9f9ec58f42984d4890a688a74d844c67` | Results |
| 15 | [Results](15-results.md) | `ce4acd57bb0f485aa093dd14fb92544e` | Results |

### Additional Screen Variants (mocked)

| Screen | Stitch ID | Variant |
|--------|-----------|---------|
| Role Reveal — Werewolf | `ccf67172646346b79fd5db32aeb263eb` | Red team variant |
| Elimination — No One Dies | `2448c74bf3c74844aa13c593a217ff95` | No elimination variant |
| Results — Village Wins | `63216f7570b14d50a77f57e8bdb7b7ae` | Gold theme variant |
| Night Action — Drunk | `ad43d58e5dba4358ac8e3a73a3bdc5c4` | Center card selection |
| Night Action — See Team | `46a1210b83404c17ae37d3bf7fb453d6` | Werewolves variant |

### Night Action Screens (layout docs, no separate mocks)

These screens reuse the night action shell with role-specific components. See individual docs for layouts:

| Screen | Doc | Components Used |
|--------|-----|-----------------|
| [Drunk](08b-night-drunk.md) | Center card selection | `CenterCardRow` |
| [See Team](08c-night-see-team.md) | Werewolves/Masons/Minion | `TeamRevealDisplay` |
| [Doppelganger](08d-night-doppelganger.md) | Two-step: peek + follow-up | `PlayerGrid` → `RoleCard` → role-specific |
| [Insomniac](08e-night-insomniac.md) | Auto-peek own card | `RoleCard` (result layout) |

## User Flow

```
Welcome → Home → Lobby → (Role Selection) → Night Role Reveal
  → Night Actions (per wave) → Night Action Result → Night Waiting (per wave)
  → Discussion → Voting → Vote Reveal → Elimination → Results
  → (Play Again → Lobby)
```

For full state coverage and mock gaps, see [screen-inventory.md](screen-inventory.md).
