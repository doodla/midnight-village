# Night Action — See Team (Werewolves / Masons / Minion)

**Stitch ID (Werewolves):** `46a1210b83404c17ae37d3bf7fb453d6`
**Phase:** Night (Wave 2)
**Action type:** `see_team` (auto-resolved, no player input needed)

## Layout

Uses the standard night action screen shell:
- `VillageAppBar` (minimal variant): Role name + icon + `TimerRing`
- `AtmosphericBackground` (night)

**Unique component:** `TeamRevealDisplay` containing `TeamRevealCard` widgets.

### Werewolves (multiple)

```
┌──────────────────────────────────┐
│ [wolf] WEREWOLVES        [⏱5s]  │
├──────────────────────────────────┤
│                                  │
│          "Your Pack"             │
│                                  │
│   ┌──────────┐ ┌──────────┐    │
│   │ [avatar] │ │ [avatar] │    │
│   │  Alice   │ │   You    │    │
│   │ [red glow]│ [red glow]│    │
│   └──────────┘ └──────────┘    │
│                                  │
│  "You and Alice are the         │
│   werewolves."                  │
│                                  │
│  "Memorize your allies..."      │
└──────────────────────────────────┘
```

### Lone Werewolf

```
┌──────────────────────────────────┐
│ [wolf] WEREWOLF          [⏱8s]  │
├──────────────────────────────────┤
│                                  │
│       "You are the only          │
│        werewolf."                │
│                                  │
│   "You may peek at one           │
│    center card."                 │
│                                  │
│   ┌─────┐  ┌─────┐  ┌─────┐   │
│   │  ?  │  │  ?  │  │  ?  │   │
│   └─────┘  └─────┘  └─────┘   │
│                                  │
│  [  Peek Center Card 1  ]       │
└──────────────────────────────────┘
```

Uses `CenterCardRow` (same as Drunk) for the lone wolf center peek.

### Masons

Same layout as Werewolves but with **gold** (`teamVillage`) glow instead of red. Header: "Your Fellow Mason". Lone Mason: "You are the lone Mason. The other Mason is in the center."

### Minion

```
┌──────────────────────────────────┐
│ [psych] MINION           [⏱5s]  │
├──────────────────────────────────┤
│                                  │
│    "The Werewolves are:"         │
│                                  │
│   ┌──────────┐ ┌──────────┐    │
│   │ [avatar] │ │ [avatar] │    │
│   │  Alice   │ │   Bob    │    │
│   │ [red glow]│ [red glow]│    │
│   └──────────┘ └──────────┘    │
│                                  │
│  "They don't know who you are." │
│                                  │
│  "Protect them..."              │
└──────────────────────────────────┘
```

No werewolves variant: "There are no werewolves among the players."

## Data

- **Auto-resolved:** Server sends `action_result` with teammate info. No player input needed.
- **Auto-dismiss:** ~5 seconds, then transitions to waiting.
