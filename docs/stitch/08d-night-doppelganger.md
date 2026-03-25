# Night Action — Doppelganger

**Stitch ID:** (not yet mocked — uses night action screen shell)
**Phase:** Night (Wave 1, always first)
**Action type:** Two-step — peek then follow-up

## Layout

Two sequential screens using the standard night action shell.

### Step 1: Choose a player to copy

Same layout as Robber, but with different copy.

```
┌──────────────────────────────────┐
│ [copy] DOPPELGANGER      [⏱10s] │
├──────────────────────────────────┤
│                                  │
│  "Choose a player to copy.       │
│   You will become their role."   │
│                                  │
│  ┌────────┐  ┌────────┐        │
│  │ Alice  │  │  Bob   │        │
│  └────────┘  └────────┘        │
│  ┌────────┐  ┌────────┐        │
│  │ Carol  │  │  Dave  │        │
│  └────────┘  └────────┘        │
│       ┌────────┐                │
│       │  Eve   │                │
│       └────────┘                │
│                                  │
│  [       Copy Carol       ]     │
└──────────────────────────────────┘
```

Uses `PlayerGrid` with `maxSelections: 1`. **Mandatory** — must select.

### Step 2a: Result + follow-up (if copied role has night action)

Shows `RoleCard` reveal: "You are now a SEER!" then immediately transitions to the appropriate action screen (Seer, Robber, Troublemaker, or Drunk layout).

### Step 2b: Result only (if copied role has no action)

Shows `RoleCard` reveal: "You are now a VILLAGER!" with auto-dismiss. No follow-up.

### Step 2c: Deferred action (if copied role is Wave 2)

Shows `RoleCard` reveal: "You are now a WEREWOLF! You will join them in Wave 2." Auto-dismiss, then acts during Wave 2 with the appropriate See Team screen.

## Data

- **Step 1 submit:** `{action_type: "peek_player", targets: {player_id: X}}`
- **Step 1 result:** `action_result` with `revealed_role`
- **Step 2:** Varies by copied role. Server sends follow-up `action_prompt` if applicable.
- **Extra time:** Doppelganger needs ~10s for step 1 + the copied role's action time.
