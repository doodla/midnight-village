# Night Action — Drunk

**Stitch ID:** `ad43d58e5dba4358ac8e3a73a3bdc5c4`
**Phase:** Night (Wave 3, last in wave)
**Action type:** `swap_with_center`

## Layout

Uses the standard night action screen shell:
- `VillageAppBar` (minimal variant): "THE DRUNK" + wine glass icon (`Symbols.wine_bar`) + `TimerRing`
- `AtmosphericBackground` (night)

**Unique component:** `CenterCardRow` — 3 face-down `CenterCardSlot` widgets in a horizontal row.

```
┌──────────────────────────────────┐
│ [wine] THE DRUNK         [⏱7s]  │
├──────────────────────────────────┤
│                                  │
│  "Exchange your card with one    │
│   from the center. You won't    │
│   see what you get."            │
│                                  │
│   ┌─────┐  ┌─────┐  ┌─────┐   │
│   │  ?  │  │  ?  │  │  ?  │   │
│   │Card1│  │Card2│  │Card3│   │
│   └─────┘  └─────┘  └─────┘   │
│              [glow]             │
│                                  │
│  "(This action is mandatory)"   │
│                                  │
│  [  Swap with Center Card 2  ]  │
└──────────────────────────────────┘
```

## Data & Interactions

- **Action prompt:** `action_types: [swap_with_center]`, `valid_targets: {center_indices: [0, 1, 2]}`
- **Submit:** `{action_type: "swap_with_center", targets: {center_indices: [X]}}`
- **Mandatory:** Must select a card. Timer expiry = forced skip (graceful degradation)
- **Result:** No result shown (blind swap — Drunk doesn't see new role)
