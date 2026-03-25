# Screen Inventory — Midnight Village

Every screen in the app, organized by game phase. For each: route, data source, states, user actions, and transitions.

---

## Phase: Pre-Game

### S01 — Welcome

| Field | Value |
|-------|-------|
| Route | `/welcome` |
| Data | None (unauthenticated) |
| API | `POST /api/auth/guest/` |
| Entry | App launch (no stored tokens) |
| Exit | → S02 Home (on auth success) |

**States:**
| State | Description | Mock |
|-------|-------------|------|
| Default | Title, name input, CTA button | `bf680519...` |
| Loading | Button shows spinner, input disabled | **Needs mock** |
| Error — Network | SnackBar "Check your connection and try again" | **Needs mock** |
| Error — Server | SnackBar "Server temporarily unavailable" | **Needs mock** |

---

### S02 — Home (Create/Join)

| Field | Value |
|-------|-------|
| Route | `/home` |
| Data | Stored user (display_name) |
| API | `POST /api/lobbies/`, `POST /api/lobbies/<code>/join/`, `GET /api/onuw/me/current-game/` |
| Entry | ← S01 (auth), ← S03 (leave lobby), ← S15 (leave game) |
| Exit | → S03 Lobby (create/join success) |

**States:**
| State | Description | Mock |
|-------|-------------|------|
| Default | Greeting, Create/Join cards | `2edeb079...` |
| Join expanded | Code input visible | `2edeb079...` (shown) |
| Active game banner | "You have an active game" + Rejoin button | **Needs mock** |
| Error — Lobby not found | "No lobby with that code" under input | **Needs mock** |
| Error — Lobby full | "This lobby is full" | **Needs mock** |
| Error — Game in progress | "Game already in progress" | **Needs mock** |

---

## Phase: Lobby

### S03 — Lobby Waiting Room

| Field | Value |
|-------|-------|
| Route | `/lobby/:code` |
| Data | Lobby (code, host, players, settings) |
| API | `GET /api/lobbies/<code>/`, `POST .../ready/`, `POST .../leave/` |
| WebSocket | `ws/lobby/<code>/` — player_joined, player_left, player_ready, game.started |
| Entry | ← S02 Home (create/join) |
| Exit | → S05 Role Reveal (game.started), → S02 Home (leave) |

**States:**
| State | Description | Mock |
|-------|-------------|------|
| Default (host) | Player list, ready toggle, Start Game button | `9697d1c7...` |
| Default (non-host) | Same but no Start button, no role edit | **Needs mock** |
| All ready | Start Game button enabled (green) | **Needs mock** |
| Not enough players | Start disabled, "Need at least 3 players" | **Needs mock** |
| Invalid roles | Start disabled, validation error on role bar | **Needs mock** |
| Reconnecting | Subtle "Reconnecting..." banner | **Needs mock** |
| Lobby disbanded | "Host left the lobby" → navigate to Home | **Needs mock** |
| Leave confirmation | Dialog "Leave this lobby?" | **Needs mock** |

### S04 — Role Selection (Host Only)

| Field | Value |
|-------|-------|
| Route | `/lobby/:code/roles` or modal |
| Data | Role config, player count |
| API | None (local state, validated at start) |
| Entry | ← S03 (host taps edit) |
| Exit | → S03 (save/close) |

**States:**
| State | Description | Mock |
|-------|-------------|------|
| Default (valid) | Roles selected, count shows green | `4dfd4d3b...` |
| Invalid — wrong count | "Need N roles, have M" error banner | **Needs mock** |
| Invalid — Mason count | "Masons must be 0 or 2" error | **Needs mock** |
| Preset selection | Dropdown/sheet of recommended setups | **Needs mock** |

---

## Phase: Night

### S05 — Role Reveal

| Field | Value |
|-------|-------|
| Route | `/game/:gameId` (night sub-state) |
| Data | `your_role.original_role` from `GET .../me/` |
| Entry | ← S03 Lobby (game started) |
| Exit | → S06-S09 (first wave action/waiting) |

**States:**
| State | Description | Mock |
|-------|-------------|------|
| Seer reveal | Village team, gold accent | `9e6725f9...` |
| Werewolf reveal | Werewolf team, red accent | **Needs mock** |
| Villager reveal | Village team, no night action note | **Needs mock** |
| Tanner reveal | Independent team, grey accent | **Needs mock** |
| Doppelganger reveal | "Your role will change tonight" | **Needs mock** |

### S06 — Night Action: Seer

| Field | Value |
|-------|-------|
| Route | `/game/:gameId` (night sub-state) |
| Data | `action_prompt` with `action_types: [peek_player, peek_center]` |
| API | `POST .../action/` |
| Entry | ← S05 or S09 (wave transition) |
| Exit | → S10 Result (action submitted), → S09 Waiting (timer expired) |

**States:**
| State | Description | Mock |
|-------|-------------|------|
| Choice mode | Two option cards (Peek Player / Peek Center) | `3cc5d237...` |
| Peek Player selected | Player grid shown, select 1 | `3cc5d237...` |
| Peek Center selected | 3 center card slots, select 2 | **Needs mock** |
| Submitting | Button shows loading | **Needs mock** |
| Timer expired | Auto-skip, transition to waiting | (no mock needed — transitions) |

### S07 — Night Action: Robber

| Field | Value |
|-------|-------|
| Data | `action_types: [swap_with_player]` |
| API | `POST .../action/` |

**States:**
| State | Description | Mock |
|-------|-------------|------|
| Default | Player grid, select 1 | `2efa48a9...` |
| Target selected | "Swap with [Name]" button enabled | `2efa48a9...` |
| No selection | Skip option visible | `2efa48a9...` |

### S08 — Night Action: Troublemaker

| Field | Value |
|-------|-------|
| Data | `action_types: [swap_others]` |
| API | `POST .../action/` |

**States:**
| State | Description | Mock |
|-------|-------------|------|
| Default | Player grid, select 2 | `05c311eb...` |
| One selected | First player has "1" badge | **Needs mock** |
| Both selected | "Swap [A] and [B]" button enabled | `05c311eb...` |

### S08b — Night Action: Drunk

| Field | Value |
|-------|-------|
| Data | `action_types: [swap_with_center]` |
| API | `POST .../action/` |

**States:**
| State | Description | Mock |
|-------|-------------|------|
| Default | 3 center card slots (face down), select 1 | **Needs mock** |
| Selected | "Swap with Center Card [N]" button | **Needs mock** |

### S08c — Night Action: See Team (Werewolves/Masons/Minion)

| Field | Value |
|-------|-------|
| Data | `action_types: [see_team]`, auto-resolved |

**States:**
| State | Description | Mock |
|-------|-------------|------|
| Werewolves (multiple) | "Your pack: [names]" | **Needs mock** |
| Lone Werewolf | "You are alone" + optional center peek | **Needs mock** |
| Masons (pair) | "Your fellow Mason: [name]" | **Needs mock** |
| Lone Mason | "You are the lone Mason" | **Needs mock** |
| Minion | "Werewolves: [names]" or "No werewolves among players" | **Needs mock** |

### S08d — Night Action: Doppelganger

| Field | Value |
|-------|-------|
| Data | Two-step: peek then follow-up |

**States:**
| State | Description | Mock |
|-------|-------------|------|
| Step 1 — Peek | Player grid, select 1 to copy | **Needs mock** |
| Step 1 — Result | "You are now a [Role]" reveal | **Needs mock** |
| Step 2 — Follow-up | Role-specific action (if applicable) | **Needs mock** |

### S08e — Night Action: Insomniac

| Field | Value |
|-------|-------|
| Data | Auto-peek own card |

**States:**
| State | Description | Mock |
|-------|-------------|------|
| Unchanged | "Your card is still: Insomniac" | **Needs mock** |
| Changed | "Your card is now: [Role]!" with alert styling | **Needs mock** |

### S09 — Night Waiting

| Field | Value |
|-------|-------|
| Route | `/game/:gameId` (night sub-state) |
| Data | `current_wave` |
| WebSocket | `wave_waiting`, `wave_complete`, `action_prompt` |

**States:**
| State | Description | Mock |
|-------|-------------|------|
| Default | Moon, "The village sleeps...", wave dots | `036587c8...` |
| (varies by wave) | Dot progress updates | Same structure |

### S10 — Night Action Result

| Field | Value |
|-------|-------|
| Data | `action_result` WebSocket event |

**States:**
| State | Description | Mock |
|-------|-------------|------|
| Peek result (enemy) | Card revealed in red (Werewolf) | `76d3795d...` |
| Peek result (village) | Card revealed in gold (Seer, Villager, etc.) | **Needs mock** |
| Swap result | "You are now a [Role]" (Robber) | **Needs mock** |
| Team result | "Your pack: [names]" (Werewolf/Mason) | **Needs mock** |
| No result | "You swapped cards" (Troublemaker/Drunk) | **Needs mock** |

---

## Phase: Discussion

### S11 — Discussion

| Field | Value |
|-------|-------|
| Route | `/game/:gameId/discussion` |
| Data | Timer, your_role, night_action_data, roles in play, players |
| API | `POST .../end-discussion/` (host) |
| WebSocket | `phase_change` → voting |
| Entry | ← Night phase (phase_change) |
| Exit | → S12 Voting (timer/host action) |

**States:**
| State | Description | Mock |
|-------|-------------|------|
| Default (host) | Timer, info card, end discussion button | `f5c95559...` |
| Default (non-host) | Same without end button | **Needs mock** |
| Timer warning (60s) | Timer turns amber | (CSS state) |
| Timer critical (15s) | Timer turns red, pulses | (CSS state) |
| End confirmation | Dialog "End discussion and start voting?" | **Needs mock** |

---

## Phase: Voting

### S12 — Voting

| Field | Value |
|-------|-------|
| Route | `/game/:gameId/voting` |
| Data | Players with has_voted, timer |
| API | `POST .../vote/` |
| WebSocket | `vote_submitted`, `vote_reveal` |
| Entry | ← S11 Discussion |
| Exit | → S13 Vote Reveal |

**States:**
| State | Description | Mock |
|-------|-------------|------|
| Selecting | Player grid, no selection yet | **Needs mock** |
| Target selected | Confirm panel visible | `790a6b17...` |
| Vote submitted | Grid locked, "Vote locked in", waiting | **Needs mock** |
| All votes in | Brief flash, auto-transition | (transition) |

### S13 — Vote Reveal

| Field | Value |
|-------|-------|
| Route | `/game/:gameId/reveal` |
| Data | Full vote list from `vote_reveal` event |
| Entry | ← S12 Voting |
| Exit | → S14 Elimination (auto, 3s after tally) |

**States:**
| State | Description | Mock |
|-------|-------------|------|
| Revealing | Vote arrows appearing one by one | `ae0a67d7...` |
| Tally shown | Bar chart with max highlighted | `ae0a67d7...` |
| Tie | Multiple red bars, "Tied" text | **Needs mock** |
| No majority | All bars grey, "No player received 2+ votes" | **Needs mock** |

### S14 — Elimination Announcement

| Field | Value |
|-------|-------|
| Route | `/game/:gameId/elimination` |
| Data | Derived from vote tally + game_results |
| Entry | ← S13 Vote Reveal |
| Exit | → S15 Results (auto, 3s) |

**States:**
| State | Description | Mock |
|-------|-------------|------|
| Single elimination | "[Name] has been eliminated" + role reveal | `9f9ec58f...` |
| Tie elimination | "[Name1] and [Name2] eliminated" | **Needs mock** |
| No elimination | "NO ONE DIES" in muted blue | **Needs mock** |
| Hunter chain | Second name appears after 2s delay | **Needs mock** |

---

## Phase: Results

### S15 — Results

| Field | Value |
|-------|-------|
| Route | `/game/:gameId/results` |
| Data | Full results from `GET .../results/` |
| Entry | ← S14 Elimination |
| Exit | → S03 Lobby (Play Again), → S02 Home (Leave) |

**States:**
| State | Description | Mock |
|-------|-------------|------|
| Werewolf wins + you lose | Red theme, "WEREWOLVES WIN!" | (generated, check list) |
| Village wins + you win | Gold theme, "VILLAGE WINS!" | **Needs mock** |
| Tanner wins | Grey/green theme, "TANNER WINS!" | **Needs mock** |
| Nobody wins | Muted grey, "NOBODY WINS" | **Needs mock** |
| Multiple winners | Tanner + Village both win | **Needs mock** |
| Night log expanded | Chronological action history | **Needs mock** |

---

## Summary: Mock Coverage

| Category | Screens | Mocked | Needs Mock |
|----------|---------|--------|------------|
| Pre-Game | 2 | 2 | 6 error/loading states |
| Lobby | 2 | 2 | 8 states (non-host, validation, reconnect) |
| Night | 6+ | 5 | ~18 states (role variants, Drunk, Doppel, Insomniac, see-team, center peek) |
| Discussion | 1 | 1 | 3 states |
| Voting | 3 | 3 | 6 states (tie, no majority, vote locked, Hunter) |
| Results | 1 | 1 | 5 states (village wins, tanner, nobody, multi-winner) |
| **Total** | **15+** | **14** | **~46 additional states** |
