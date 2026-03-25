# Night Action — Insomniac

**Stitch ID:** (not yet mocked — uses night result screen shell)
**Phase:** Night (Wave 4)
**Action type:** `peek_player` (self-target, auto-resolved)

## Layout

Uses the Night Action Result screen layout (same as S10), not the action selection layout. The Insomniac has no choice — they automatically see their own card.

### Card unchanged

```
┌──────────────────────────────────┐
│ [bed] INSOMNIAC          [⏱5s]  │
├──────────────────────────────────┤
│                                  │
│        [RoleCard: face up]       │
│        ┌──────────────┐         │
│        │ ▓▓ gold bar ▓│         │
│        │              │         │
│        │  [eye icon]  │         │
│        │  INSOMNIAC   │         │
│        │ Village Team │         │
│        └──────────────┘         │
│                                  │
│  "Your card is still:            │
│   Insomniac"                    │
│                                  │
│  "Nothing changed..."           │
└──────────────────────────────────┘
```

### Card changed (swapped by Robber or Troublemaker)

```
┌──────────────────────────────────┐
│ [bed] INSOMNIAC          [⏱5s]  │
├──────────────────────────────────┤
│                                  │
│        [RoleCard: face up]       │
│        ┌──────────────┐         │
│        │ ▓▓ RED bar ▓▓│         │
│        │              │         │
│        │ [wolf icon]  │         │
│        │  WEREWOLF    │         │
│        │ Werewolf Team│         │
│        └──────────────┘         │
│                                  │
│  "Your card is now:              │
│   Werewolf!"                    │
│  (alert styling, red text)      │
│                                  │
│  "Someone swapped your card..." │
└──────────────────────────────────┘
```

## Data

- **Auto-resolved:** Server sends `action_result` with `revealed_role` (own current card)
- **No player input** — peek is automatic
- **Auto-dismiss:** ~5 seconds
- **Key UX note:** If the card changed, this is a dramatic moment — the player discovers they are no longer who they thought. Use danger styling (red glow) for werewolf-team reveals.
