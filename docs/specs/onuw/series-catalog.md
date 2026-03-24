# One Night Series — Complete Catalog

All games published by Bezier Games in the One Night series. These are listed for reference and future planning — only the base ONUW game is in v1 scope.

## Games

### One Night Ultimate Werewolf (2014)

| Property | Value |
|----------|-------|
| Type | Standalone |
| Players | 3–10 |
| Unique roles | 12 (16 cards total) |
| Theme | Medieval werewolf village |
| App required | No |

The base game. Single night phase, 3 center cards, Doppelganger copies roles. See [overview.md](overview.md) and [roles.md](roles.md) for full specs.

### One Night Ultimate Werewolf Daybreak (2015)

| Property | Value |
|----------|-------|
| Type | Standalone / Expansion |
| Players | 3–7 standalone; up to 10 combined with base |
| Unique roles | 11 |
| Theme | Werewolf village (dawn) |
| App required | No |

First expansion. Introduces the Artifact token system (Curator), Shield tokens (Sentinel), a fourth center card (Alpha Wolf), and roles where all have abilities (no plain Villagers). See [daybreak-overview.md](daybreak-overview.md) for full specs.

### One Night Ultimate Vampire (2015/2016)

| Property | Value |
|----------|-------|
| Type | Standalone |
| Players | 3–10 |
| Unique roles | 14 + 29 mark tokens |
| Theme | Gothic vampire |
| App required | No |

Major mechanical departure. Introduces the **Dusk phase** (pre-night mark distribution) and the **Mark system** — 29 tokens that alter player roles and allegiances mid-game. Marks include: Mark of the Vampire (team conversion), Mark of Fear (blocks night action), Mark of Love (linked death), Mark of Disease (voters can't win), Mark of Traitor, Mark of the Assassin.

**Key roles:** Vampire, The Master, The Count, Renfield (Vampire team); Diseased, Cupid, Instigator, Priest, Marksman, Pickpocket, Gremlin (Village); Assassin, Apprentice Assassin (Independent); Copycat.

### One Night Ultimate Alien (2016/2017)

| Property | Value |
|----------|-------|
| Type | Standalone |
| Players | 3–10 |
| Unique roles | 13 |
| Theme | Sci-fi / extraterrestrial |
| App required | **Yes (mandatory)** |

The only game in the series where the app is required. Several roles (Psychic, Rascal, Exposer) receive **randomized instructions from the app** that vary each game, making the night phase non-deterministic without the app. Also introduces physical interaction mechanics (Cow extends fist, Aliens tap adjacent players).

**Key roles:** Alien, Groob & Zerb (paired rival leaders), Oracle, Cow, Leader, Psychic, Rascal, Exposer, Synthetic Alien (independent), Blob (adjacent team conversion), Mortician.

**Architectural note:** The variable-instruction mechanic is fundamentally different from ONUW's deterministic model and would require server-side instruction generation per game session.

### One Night Ultimate Super Villains (2018/2019)

| Property | Value |
|----------|-------|
| Type | Standalone |
| Players | 3–10 |
| Unique roles | 16 |
| Theme | Superhero comic books |
| App required | No |

Heroes (SCOOP team) vs. Super Villains. Many roles are functional analogs of base ONUW roles with new names and themes. Introduces physical interaction mechanics (Evilometer, Annoying Lad) and the Temptress role (injects extra villain card into game mid-night).

**Key roles:** Temptress, Dr. Peeker, Rapscallion, Henchman #7 (Villain); Evilometer, Annoying Lad, Detector, Role Retriever, Voodoo Lou, Switcheroo, Self-Awareness Girl, Flipper (Hero); Mad Scientist, Intern (Independent); Mirror Man, Innocent Bystander.

### One Night Ultimate Bonus Roles (2019)

| Property | Value |
|----------|-------|
| Type | Expansion only (requires base game) |
| Players | Extends to 11–12 |
| Unique roles | 16 |
| Artifact tokens | 6 |
| Theme | Cross-series |

Consolidates the earlier Bonus Packs 1–4 (minus alternate artwork). Designed to work with any One Night game. Includes player number tokens for positions 11 and 12.

**Roles:** Aura Seer, Cursed, Prince, Apprentice Tanner, Beholder, Thing (that goes bump in the night), Squire, Body Snatcher, Empath, Nostradamus, Family Man, Windy Wendy, Defender-er, The Sponge, Ricochet Rhino, Innocent Bystander.

**Artifact tokens:** Bow of the Hunter, Cloak of the Prince, Sword of the Bodyguard, Mist of the Vampire, Dagger of the Traitor, Alien Artifact.

**Note:** Several Bonus Roles (Cursed, Prince, Ricochet Rhino) have **vote-phase mechanics** rather than night-phase mechanics. This requires hooks in the elimination resolver, not just the night engine.

### One Night Ultimate Werewolf: Epic Battle (2020)

| Property | Value |
|----------|-------|
| Type | Standalone (Ravensburger, licensed from Bezier) |
| Players | 3–10 |
| Unique roles | 29 (curated from Werewolf, Daybreak, Vampire) |
| Theme | Multi-faction battle |
| App required | No |

A curated product mixing roles from three games. When 3+ factions are active, "Epic Battle" mode triggers with fundamentally different win conditions and voting rules.

**Critical rule change:** At least **2 players always die** — the most-voted AND second-most-voted players are both eliminated. This is a major departure from base ONUW.

**Multi-faction win conditions:**
- Village wins if members of 2+ enemy factions are eliminated
- Each evil faction wins if they survive AND a member of another evil faction dies
- Tanner still wins independently if eliminated

## Compatibility Matrix

All One Night games are designed for full cross-compatibility via the official app. The app manages combined wake orders for any role mix.

| Game | ONUW | Daybreak | Vampire | Alien | Super Villains | Bonus |
|------|------|----------|---------|-------|----------------|-------|
| ONUW | — | Full | Full | Full | Full | Full |
| Daybreak | Full | — | Full | Full | Full | Full |
| Vampire | Full | Full | — | Full | Full | Full |
| Alien | Full | Full | Full | — | Full | Full |
| Super Villains | Full | Full | Full | Full | — | Full |
| Bonus Roles | Full | Full | Full | Full | Full | — |

## Role Analog Mapping

Roles across games that serve the same mechanical function:

| Function | ONUW | Daybreak | Vampire | Super Villains |
|----------|------|----------|---------|----------------|
| Evil team member | Werewolf | Alpha/Mystic/Dream Wolf | Vampire | Temptress et al. |
| Peek a player | Seer | Mystic Wolf, P.I. | — | Detector, Dr. Peeker |
| Swap with player | Robber | — | Pickpocket | Role Retriever |
| Swap two others | Troublemaker | — | — | Switcheroo |
| Swap with center | Drunk | — | — | — |
| Check own card | Insomniac | — | — | Self-Awareness Girl |
| Copy a role | Doppelganger | — | Copycat | Mirror Man |
| See evil team | Minion | Squire | Renfield | — |
| Independent win-if-dead | Tanner | — | Assassin | Mad Scientist |
| Kill on death | Hunter | — | — | — |
| Confirmed pair | Mason | — | — | — |
| Flip card face-up | — | Revealer | — | Flipper |
| Protect from elimination | — | Bodyguard | — | Defender-er |
