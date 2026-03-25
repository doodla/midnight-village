# Icon Inventory — Midnight Village

Every Material Symbol used across the 14 Stitch mocks, mapped to Flutter availability.

## Flutter Package Options

1. **`Icons` class** (built-in) — Covers most Material Design icons. Free.
2. **`material_symbols_icons`** package — Full Material Symbols set including newer icons. Add to `pubspec.yaml`.
3. **Custom SVG** — For any icon not available in either package. Use `flutter_svg`.

**Recommendation:** Use `material_symbols_icons` package for broadest coverage of the Stitch-used icons.

---

## Icon Audit

### Navigation & Chrome

| Stitch Icon Name | Screens Used | Flutter `Icons` | `material_symbols_icons` | Fallback |
|------------------|-------------|-----------------|--------------------------|----------|
| `arrow_back` | Lobby, Vote Reveal | `Icons.arrow_back` | `Symbols.arrow_back` | — |
| `close` | Role Selection, Night Result | `Icons.close` | `Symbols.close` | — |
| `settings` | Welcome, Home | `Icons.settings` | `Symbols.settings` | — |
| `account_circle` | Home | `Icons.account_circle` | `Symbols.account_circle` | — |
| `logout` | Home | `Icons.logout` | `Symbols.logout` | — |

### Lobby & Setup

| Stitch Icon Name | Screens Used | Flutter `Icons` | `material_symbols_icons` | Fallback |
|------------------|-------------|-----------------|--------------------------|----------|
| `castle` | Welcome, Home (logo) | **No** | `Symbols.castle` | `Icons.fort` or custom SVG |
| `fort` | Bottom nav, multiple | `Icons.fort` | `Symbols.fort` | — |
| `add` | Home (Create Game) | `Icons.add` | `Symbols.add` | — |
| `group` / `groups` | Home (Join Game), Lobby | `Icons.group` | `Symbols.group` | — |
| `edit` | Lobby (role config) | `Icons.edit` | `Symbols.edit` | — |
| `check_circle` | Lobby (ready), Voting (voted) | `Icons.check_circle` | `Symbols.check_circle` | — |
| `radio_button_unchecked` | Lobby (not ready) | `Icons.radio_button_unchecked` | `Symbols.radio_button_unchecked` | — |
| `door_open` | Welcome (CTA) | **No** | `Symbols.door_open` | `Icons.meeting_room` |
| `content_copy` | Lobby (copy code) | `Icons.content_copy` | `Symbols.content_copy` | — |

### Roles & Game

| Stitch Icon Name | Screens Used | Flutter `Icons` | `material_symbols_icons` | Fallback |
|------------------|-------------|-----------------|--------------------------|----------|
| `theater_comedy` | Role Selection, Bottom nav | `Icons.theater_comedy` | `Symbols.theater_comedy` | — |
| `visibility` | Seer screens, Night | `Icons.visibility` | `Symbols.visibility` | — |
| `masks` | Robber screen | **No** | `Symbols.masks` | `Icons.theater_comedy` |
| `swap_horiz` | Troublemaker, Bottom nav | `Icons.swap_horiz` | `Symbols.swap_horiz` | — |
| `flare` | Role Reveal (Seer icon) | `Icons.flare` | `Symbols.flare` | — |
| `person_search` | Seer (Peek Player) | **No** | `Symbols.person_search` | `Icons.person_search` (M3) |
| `layers` | Seer (Peek Center) | `Icons.layers` | `Symbols.layers` | — |
| `bolt` | Troublemaker (swap action) | `Icons.bolt` | `Symbols.bolt` | — |
| `shield` | Elimination (Village Team) | `Icons.shield` | `Symbols.shield` | — |
| `remove` / `add` | Role Selection steppers | `Icons.remove` / `Icons.add` | `Symbols.remove` / `Symbols.add` | — |

### Phases & Timer

| Stitch Icon Name | Screens Used | Flutter `Icons` | `material_symbols_icons` | Fallback |
|------------------|-------------|-----------------|--------------------------|----------|
| `brightness_3` | Night Waiting (moon), Night Result | `Icons.brightness_3` | `Symbols.brightness_3` | `Icons.nightlight_round` |
| `hourglass_top` | Discussion (timer) | `Icons.hourglass_top` | `Symbols.hourglass_top` | — |
| `timer` | Troublemaker, timer areas | `Icons.timer` | `Symbols.timer` | — |
| `gavel` | Discussion (end), Voting (confirm) | `Icons.gavel` | `Symbols.gavel` | — |
| `forum` | Lobby bottom nav (Chat) | `Icons.forum` | `Symbols.forum` | — |

### Results & Info

| Stitch Icon Name | Screens Used | Flutter `Icons` | `material_symbols_icons` | Fallback |
|------------------|-------------|-----------------|--------------------------|----------|
| `history_edu` | Welcome (How to Play) | **No** | `Symbols.history_edu` | `Icons.menu_book` |
| `menu_book` | Bottom nav (Log/Journal) | `Icons.menu_book` | `Symbols.menu_book` | — |
| `storefront` | Bottom nav (Market) | `Icons.storefront` | `Symbols.storefront` | — |
| `skull` | Elimination | **No** | `Symbols.skull` | Custom SVG |
| `chevron_right` | Vote Reveal (arrows) | `Icons.chevron_right` | `Symbols.chevron_right` | — |
| `expand_more` | Discussion (collapse) | `Icons.expand_more` | `Symbols.expand_more` | — |
| `lock` | Voting (vote locked) | `Icons.lock` | `Symbols.lock` | — |
| `camping` | Night nav | **No** | `Symbols.camping` | `Icons.nights_stay` |
| `owl` | Vote Reveal nav | **No** | **No** | Custom SVG or `Icons.visibility` |

---

## Summary

| Category | Count | In Flutter Icons | Need Package/Custom |
|----------|-------|-----------------|---------------------|
| Navigation & Chrome | 5 | 5/5 | 0 |
| Lobby & Setup | 9 | 7/9 | 2 (`castle`, `door_open`) |
| Roles & Game | 10 | 7/10 | 3 (`masks`, `person_search`, `layers`) |
| Phases & Timer | 5 | 5/5 | 0 |
| Results & Info | 9 | 5/9 | 4 (`history_edu`, `skull`, `camping`, `owl`) |
| **Total** | **38** | **29/38** | **9 need package** |

**Recommendation:** Add `material_symbols_icons: ^4.x` to `pubspec.yaml`. This covers 36/38 icons. The remaining 2 (`owl`, custom decorative icons) need custom SVG assets.

### pubspec.yaml addition

```yaml
dependencies:
  material_symbols_icons: ^4.2789.0
```

### Import usage

```dart
import 'package:material_symbols_icons/symbols.dart';

// Then use:
Icon(Symbols.castle)
Icon(Symbols.masks)
Icon(Symbols.skull)
```
