# Midnight Village — ONUW server contract v2 (lock-in voting, night taps, card look, results timeline, tokens, home, pace)

Status: design, not built. Base: the code as of 2026-11-19 (`backend/apps/onuw`, `backend/apps/core`), `docs/dev/debug-harness/contract.md` §0, `backend/CLAUDE.md`. All paths below are under `/api/` (core) or `/api/onuw/` (game), the same prefixes the app uses today. All new error bodies keep today's `{"detail": ...}` and add a machine `code` (additive). Lock order stays **Game → PlayerRole → Lobby → LobbyMember**. Every socket send and timer change goes through the after-commit helpers.

Every change is **additive and off by default** except the items in the "Breaking (last slice)" list. The current app keeps working until each screen is rebuilt.

---

## 0. Summary of the surface

| # | New or changed | Kind |
|---|---|---|
| 1 | `POST /onuw/games/<id>/vote/` gains `"lock"` (default `true` = today) | additive |
| 1, 3 | `POST /onuw/games/<id>/ready/`: "I've looked at my card" (night, window 0) / "ready to vote" (talk) | new |
| 1, 3 | socket `progress` `{stage, done, needed}` | new event |
| 2 | `action_type: "sleep"` on `POST .../action/`; `sleep_prompt` in `/me/` and in `wave_waiting` | additive |
| 2 | game setting `night_all_players_tap` (bool, default false): a window closes early only when **every** present player has submitted | new setting |
| 3 | game setting `card_look_seconds` (0–120, default 0 = off): the look stage before the night | new setting + timer job `card_look` |
| 4 | `GET .../results/` gains `night_timeline`, plus `token`/`seat` per player | additive |
| 5 | `LobbyMember.token`, `PlayerRole.token`, `PlayerRole.seat` | migrations |
| 6 | `GET /stats/online/` (core), `GET /onuw/me/recent-games/` | new |
| 7 | none (client presets); optional `pace` label validated | client |
| 8a | `GET /me/table/` (core, "where am I") | new |
| 8b | `PlayerRole.night_results_seen`; `/me/` field; `POST .../night-results/seen/` | new |

New `/me/` fields (all additive): `players[].token`, `players[].seat`, `my_vote`, `ready`, `progress`, `sleep_prompt`, `night_results_seen`.

---

## 1. Lock-in voting and "ready to vote"

### Decision
A vote has two states on the server: **picked** (`PlayerRole.vote_target` set, `has_acted = False`) and **locked** (`has_acted = True`). A player may change a pick freely. Locking is final: there is no unlock (409). The early reveal waits on **locked** votes and keeps today's rule (`_votes_ready`): reveal once every player not gone past the grace period has locked. **At any reveal (early, deadline or host), every stored pick counts, locked or not.** That covers your ruling: a picked-but-unlocked vote counts at the deadline, and no pick means a non-voter. It also covers a gone player who had picked; one rule is simpler than two.

While voting, others see only `progress {stage: "vote", done, needed}`: never a target, never who has picked, never who has picked-but-not-locked. A pick sends **no event at all**.

"Ready to vote" during the talk is the same pattern: each player taps ready (and may un-tap). When every present (not gone) player is ready, the server calls `end_discussion`, the same function the host uses. This does not conflict with the host's end-discussion: both run under the Game lock with a phase check, and whichever comes second gets today's 400 "not in the discussion phase". The talk still never *waits* for anyone. Readiness can only end it early.

**Conflict with the mocks (you decide):** `09-vote.png` ("3 of 5 locked in") and `08-talk.png` ("2 of 5 ready to vote") light *specific* players' tokens, which shows **who** has locked or is ready. Your ruling says count only. This contract sends counts only. Who has locked is not role information, so adding `done_player_ids` later is a one-line additive change if you overrule. Until then the client should light the first `done` token slots, not specific players.

### API
`POST /api/onuw/games/<id>/vote/`
```json
{"target_player_id": 14, "lock": false}
```
- `lock` is absent or `true`: pick and lock in one call (today's behaviour, so the old app is unchanged). Response `{"status": "submitted"}`.
- `lock: false`: pick or re-pick. Response `{"status": "picked"}`.
- Locking always carries the target (no "lock whatever I picked"), so a lost pick request cannot lock the wrong name.
- Errors:
  - 400 `{"detail": "Game is not in the voting phase.", "code": "wrong_phase"}`
  - 400 `{"detail": "You cannot vote for yourself.", "code": "invalid_target"}`
  - 400 `{"detail": "Invalid vote target.", "code": "invalid_target"}`
  - 400 `"lock must be true or false"` (`code: "bad_request"`)
  - 403 not a player
  - 409 `{"detail": "You have already locked in your vote.", "code": "vote_locked"}` (for a re-pick or a re-lock after locking)

`POST /api/onuw/games/<id>/ready/`
```json
{"ready": true}
```
- Talk: `ready` is `true` or `false` (toggle). Response `{"status": "ok", "ready": true}`.
- Night, window 0 (item 3): only `true` is allowed (looking is one-way). `false` is a 400 `bad_request`.
- Any other phase or window: 400 `wrong_phase`. Not a player: 403.

Socket, game group (new consumer handler `progress`):
```json
{"type": "progress", "stage": "vote", "done": 3, "needed": 5}
```
- `stage` is `"look"`, `"talk"` or `"vote"`.
- `needed` = players not gone past grace. `done` = how many of them are ready/locked.
- Sent: when the stage opens (`done: 0`), on every lock or ready change, and when a grace period expires during the stage (`needed` changes).
- Legacy `vote_submitted {player_id}` keeps being sent on **lock** only, until the breaking slice.

`GET .../me/` additions:
```json
"my_vote": {"target_player_id": 14, "locked": false},
"ready": true,
"progress": {"stage": "vote", "done": 3, "needed": 5}
```
- `my_vote` is present in voting only and is the caller's own; otherwise `null`.
- `ready` is the caller's own flag at the look and talk stages.
- `progress` is `null` outside the look, talk and vote stages.
- `players[].has_voted` keeps meaning "locked" until the breaking slice.

### Server changes
- `models.PlayerRole.phase_ready = BooleanField(default=False)`. One flag reused for "looked at card" (night, window 0) and "ready to vote" (talk). It is reset by the existing `player_roles.update(...)` calls in `_open_window` (first window) and `transition_to_discussion`.
- `services.submit_vote(game, voter_id, target, *, lock=True)`, rewritten as **one** `transaction.atomic()`:
  1. Lock the Game row (`select_for_update`), then re-check the phase.
  2. Lock the voter's PlayerRole.
  3. Validate, then store.
  4. If `lock`: `_send_after_commit` the legacy `vote.submitted` and `progress`; then `if _votes_ready(game): reveal_votes(game)`.

  This also fixes the current TOCTOU (see "poor code" #1).
- `services.set_ready(game, user_id, ready)`: Game lock, then PlayerRole; compute `done/needed` (`needed` = not `_is_gone`); send `progress`. Talk: if `done == needed >= 1`, call `end_discussion(game)`. Look stage: see item 3.
- `services.vote_progress(game)` / `ready_progress(game)` helpers, used by `/me/`, the events and `_evaluate_presence`. `_evaluate_presence` also handles DISCUSSION: re-evaluate readiness when a grace timer fires. No grace timers are started in the talk, so a gone talker is only re-counted on the next tap. The talk has its own deadline as backstop.
- `views.VoteView` parses `lock` (strict bool). `views.ReadyView` is new; the URL is `games/<id>/ready/`.
- `consumers.GameConsumer.progress` handler.
- `reveal_votes` is unchanged: it already reads `vote_target` for everyone.

### Leak analysis
- A pick produces no broadcast and returns the same body every time. The only thing the table sees is your own screen.
- `progress` is a count of a table action (pointing, locking), not role information.
- Errors name only the caller's own state.
- Timing: the reveal moment depends only on locks and presence, never on roles.
- Gone players: `needed` shrinking when a grace period expires reveals only presence, which is already public (`player_presence`).

### Tests that must exist (multi-player, seeded)
- `test_pick_can_change_until_locked`
- `test_lock_is_final_repick_returns_409`
- `test_vote_without_lock_field_locks_like_before` (legacy)
- `test_votes_revealed_when_all_present_players_locked_even_if_deadline_far`
- `test_unlocked_pick_counts_at_voting_deadline`
- `test_unlocked_pick_counts_at_host_reveal`
- `test_player_with_no_pick_is_non_voter_at_deadline`
- `test_gone_player_pick_counts_when_others_lock_early` (5 players, one dropped past grace)
- `test_pick_sends_no_socket_event` (captures the group and every player channel)
- `test_progress_event_carries_only_counts` (asserts the key set is `{type, stage, done, needed}`)
- `test_vote_after_reveal_is_rejected_and_does_not_change_results` (race: reveal commits, then a vote arrives)
- `test_concurrent_last_two_locks_reveal_once` (`transaction=True`, two threads)
- `test_all_ready_ends_discussion_once`
- `test_unready_toggle_counts_down`
- `test_host_end_discussion_and_last_ready_race_one_transition`
- `test_dropped_player_inside_grace_still_needed_for_ready`
- `test_me_my_vote_is_own_only` (another player's `/me/` never shows it)

### Staging
1. Ship the server (`lock` defaults to true, `progress` added, legacy event kept).
2. Rebuild screens 8 and 9 on `lock:false` + `progress`.
3. In the breaking slice, drop `players[].has_voted` and `vote_submitted.player_id` (or the whole event).

---

## 2. Something to tap at night for every player

### Decision
Every player sees face-down cards in **both** windows and taps.

- A player with a real prompt submits their action exactly as today.
- A player with no prompt submits `{"action_type": "sleep", "targets": {}}`. The tapped card is **not** sent; it means nothing.
- The server stores only `has_acted = True` for a sleep. There is no log entry, nothing in `night_action_data`, and nothing goes to the engine, so the engine stays deterministic and untouched.

**The window-close rule must change: a window may close early only when *every* player not gone past grace has submitted (real or sleep), and still no sooner than `night_min_window_seconds`.**

Why: under today's rule ("all *actors* done") two leaks appear as soon as non-actors have something to tap.
- (a) If the actors finish first, the window closes at the minimum while a sleeper is still visibly "choosing". Their screen jumping away shows they had nothing.
- (b) If the last person to tap is followed at once by the close, that person was an actor.

When everyone must tap, the close is keyed to the last tap of *anyone*, so it carries no role information. Grace and gone rules are unchanged: a player inside grace already holds the window whatever their role. The minimum window stays. It still hides "the table was fast", and it still stops a lone fast tapper from correlating with the close.

Window 1 (Doppelganger), when fixed at `night_doppelganger_window_seconds > 0`: taps are theatre. Sleeps are accepted and ignored, because only its timer closes it. When that fixed length is 0, the same all-tap rule applies.

The rule is behind the game setting `night_all_players_tap` (default `false`). The current app never sends `sleep`, so turning it on with old clients would make every window run to its deadline. The new night screen sets it; the breaking slice flips the default.

Client guidance, so phones look the same (not server):
- Every phone offers the same tap budget: up to 3 taps in window 1 (look + 2 for a Doppelganger-as-Seer center peek) and up to 2 in window 2 (Troublemaker or Seer center).
- Each phone sends exactly one submission per prompt.
- No sound or vibration differs.
- After the window closes every phone shows the same "dawn" screen.

### API
`POST /api/onuw/games/<id>/action/` with `{"action_type": "sleep", "targets": {}}`:
- Accepted from a player with no acting role in the current window who has not acted yet. Response `{"status": "submitted"}`, identical to a real action.
- From a player who *has* a prompt: 400 `{"detail": ["Invalid action."], "code": "invalid_action"}`. The message is generic, as required.
- Repeat: 409 as today.
- Window 0 or not night: 400 as today.
- `targets` must be `{}` or absent; anything else is a 400 "Invalid action.".

`GET .../me/` new field (night, window 1 or 2, caller has no acting role and has not acted):
```json
"sleep_prompt": {"wave": 2, "action_types": ["sleep"],
                 "valid_targets": {"player_ids": [11, 13, 14], "center_indices": [0, 1, 2]}}
```
It is `null` otherwise. `action_prompt` stays exactly as today (`null` for sleepers), so the old app is unaffected.

Socket `wave_waiting` gains the same object:
```json
{"type": "wave_waiting", "wave": 2, "sleep_prompt": {...}}
```

The shape of `sleep_prompt.valid_targets` equals a Seer's prompt (other players + center), so the client can draw the same board from either prompt.

### Server changes
- `engine/roles.py`: add `ActionType.SLEEP = "sleep"`. It is never in any role's `prompt_action_types`; the engine never sees it.
- `views.NightActionView`: before `get_player_acting_role_for_wave`, branch on `action_type == "sleep"`.
  - If `acting_role is None`: set `has_acted = True` (keep `night_action_data` untouched) and fall through to `check_and_maybe_advance`.
  - If `acting_role` is not None: generic 400.
  - Same locks as today (Game, then PlayerRole).
- `services._night_ready_to_close`: when `get_timer_seconds`-style bool `night_all_players_tap` is true, require `pr.has_acted or _is_gone(pr)` for **all** `prs`. Otherwise use today's actor-only rule. `_night_timer_plan` and `ensure_timers` use the same function, so recovery follows automatically.
- `services.send_wave_prompts`: build `sleep_prompt` for non-actors and add it to `wave.waiting`.
- `serializers.GameMeSerializer.get_sleep_prompt`.
- `engine/validation.py`: validate `night_all_players_tap` is a bool if present.
- `_open_window` already resets `has_acted` for everyone.

### Leak analysis
- To an onlooker at the table: same board, same tap budget, one submission each. The close moment is a function of everyone's last tap, the minimum and presence, none of which depends on roles.
- Residual: human tells (thinking time), which no server can hide. Brief rule 3 says to keep sound and haptics identical.
- To a network observer (out of scope): request paths and bodies differ only in `action_type`; responses are identical.
- `sleep` errors say "Invalid action." only.
- Sleeps are not logged, so results and the oracle are unchanged.
- The Doppelganger's fixed window is unaffected.
- A Doppelganger with a follow-up gets `has_acted` reset (as today), so under the all-tap rule window 1 (fixed off) waits for her second submission exactly as for any other unfinished player.

### Tests that must exist
- `test_sleep_accepted_for_player_without_action_in_window_2`
- `test_sleep_rejected_generically_for_actor` (asserts the message has no role name)
- `test_sleep_response_identical_to_real_action_response`
- `test_all_tap_window_waits_for_sleeper` (Seer + Werewolf act at once; a Villager untapped keeps it open until the deadline)
- `test_all_tap_window_closes_at_min_when_everyone_tapped_fast`
- `test_all_tap_close_time_independent_of_who_tapped_last` (two seeded games, same tap times, different roles: same close time)
- `test_actor_only_rule_unchanged_when_setting_off`
- `test_sleep_not_in_night_log_or_results`
- `test_sleep_in_fixed_doppelganger_window_does_not_close_it`
- `test_all_tap_with_doppelganger_window_fixed_off_waits_for_followup`
- `test_wave_waiting_carries_sleep_prompt_only_to_non_actors`
- `test_me_sleep_prompt_null_after_sleep`
- `test_recovery_rebuilds_deferred_close_under_all_tap_rule`
- `test_player_in_grace_holds_all_tap_window`

### Staging
1. Server (setting off) first.
2. The new night screen sends `sleep` always and sets `night_all_players_tap: true` in the lobby settings it writes.
3. The breaking slice flips the default to true.

---

## 3. Press and hold to see secrets; "everyone has looked, then the night starts"

### Decision
Press-and-hold is client-only: your card is `your_role.original_role`, what you saw and the "My night" box use `night_results`. One server change is needed: an optional **look stage** before the first night window, so "night starts when everyone has looked" is real.

The look stage uses the existing transient state *phase `night`, `current_wave = 0`*. No new phase, so the state machine and old clients are untouched. It is enabled by the game setting `card_look_seconds` (0–120, default 0 = off = today: the window opens at deal).

When it is on, the deal does **not** open a window. It sets `phase_deadline = now + card_look_seconds` and schedules timer `<game>:look` (job `card_look`). Each player calls `POST .../ready/` (first release of the hold). When every player not gone has looked, or the backstop fires, or the host taps advance-wave, the server calls `start_night_phase` (idempotent under the Game lock).

The look stage reveals nothing: every player has the same thing to do, and its end depends only on taps, presence and the clock.

### API
- `POST /api/onuw/games/<id>/ready/` with `{"ready": true}` during night with `current_wave == 0`. Responses and errors are as in item 1.
- `progress` event and `/me/` `progress` with `stage: "look"`.
- `/me/` `deadline` = the look deadline.
- `advance-wave` during window 0: host opens the night now (today it would call `advance_wave` at window 0, see "poor code" #6).

### Server changes
- `views.GameStartView._deal`: if `card_look_seconds > 0`, set the deadline and schedule `card_look` after commit instead of `start_night_phase(game)`.
- `services.set_ready` (look stage): when `done == needed >= 1`, call `start_night_phase`.
- `@timers.job("card_look")` → lock the Game; if `phase == night and current_wave == 0`, call `start_night_phase`.
- `ensure_timers` / `_phase_timer_plan`: in window 0 with `phase_deadline` set, ensure `<id>:look` (with the reconnect allowance).
- `_night_start_is_stuck`: applies only when `phase_deadline is None` (look stage off).
- `WaveAdvanceView`: in window 0, call `start_night_phase` instead of `advance_wave`.
- `debug_views` `current`: include the `:look` key.
- Validation: add `card_look_seconds` to `TIMER_SETTING_KEYS` with max 120.

### Leak analysis
The stage is identical for every role; only presence and taps end it. `night_results` is player-scoped already, and the "My night" box is identical for everyone until held (client).

### Tests that must exist
- `test_look_stage_off_opens_window_at_deal_as_before`
- `test_look_stage_waits_until_all_players_ready`
- `test_look_stage_backstop_opens_night`
- `test_look_ready_false_rejected`
- `test_look_stage_ignores_player_gone_past_grace`
- `test_look_timer_rebuilt_by_me_fetch_after_restart`
- `test_stuck_rule_does_not_open_night_during_look_stage`
- `test_host_advance_during_look_opens_window_once`
- `test_ready_and_backstop_race_open_window_once` (`transaction=True`)

### Staging
1. Server (default 0).
2. The new card screen ships, and the deck screen writes `card_look_seconds` (suggest 30).
3. Optionally flip the default in the breaking slice.

---

## 4. Results that show the night in order and how cards moved

### Decision
`GET .../results/` (already results-phase only, already all players) gains a `night_timeline` computed by a **pure engine function** that replays the night log over the dealt cards. Every physical card gets a stable id, so duplicate roles (2 Werewolves, 2 Masons) still have distinct paths. Each step lists actors, the action, what was looked at (as card ids), the moves, and **all card positions after the step**, so the client only draws (principle 1).

Rows are log entries in resolution order, with ONE correction: the engine resolves the team views of order group 2 in SEAT order (a Minion can sit between two Werewolves in the log), so the timeline puts group 2 in the order of the rules, with a stable sort: Werewolves, then Minion, then Masons (a Doppelganger who copied Werewolf or Mason is one of that role's actors, after the dealt ones). Team views move no cards, so no position changes. The `see_team` rows of one role in one order group then merge into ONE step with all its actors ("Werewolves wake"); `doppelganger_actors` names the Doppelganger among them, so the screen can mark her without a rule. A Doppelganger who copied Minion acts in window 1 (a different order group) and keeps a step of her own.

The timeline is built FORWARDS from the dealt cards: `PlayerRole.original_role` by seat and `Game.dealt_center_cards` (`Game.center_cards` is overwritten during the night). A game dealt before that column existed recovers its centre by undoing the logged swaps from the final table; that is accepted only if the players' cards it arrives at equal their dealt roles (nothing else is verified: the centre it returns is what the log implies). `night_timeline` is `null` (logged: WARNING for such an old game, ERROR otherwise) whenever it cannot be built, for ANY reason, and the rest of the results still show. There is no runtime "replay equals final" check, because it could never fail; it is tested instead, for the 29 reference games and for seeded random nights, with the actions collected the way the server collects them.

### API (additions to the existing body)
```json
{
  "players": [{"player_id": 11, "display_name": "Ana", "token": "crow", "seat": 0, "...": "existing fields"}],
  "night_timeline": {
    "seats": [11, 12, 13, 14, 15],
    "cards": [
      {"card_id": "k0", "role": "Seer",         "werewolf": false},
      {"card_id": "k2", "role": "Werewolf",     "werewolf": true},
      {"card_id": "k5", "role": "Werewolf",     "werewolf": true}
    ],
    "dealt": {"players": {"11": "k0", "12": "k1", "13": "k2", "14": "k3", "15": "k4"},
              "center": ["k5", "k6", "k7"]},
    "steps": [
      {"step": 1, "window": 2, "order_group": 2, "role": "Werewolf", "actors": [13],
       "doppelganger_actors": [], "action": "peek_center", "made_by_server": false,
       "looked_at": [{"center_index": 1, "card_id": "k6"}],
       "team": [], "copied_role": null, "moves": [],
       "positions_after": {"players": {"11": "k0", "12": "k1", "13": "k2", "14": "k3", "15": "k4"}, "center": ["k5", "k6", "k7"]}},
      {"step": 3, "window": 2, "order_group": 3, "role": "Robber", "actors": [12],
       "doppelganger_actors": [], "action": "swap_with_player", "made_by_server": false,
       "looked_at": [{"player_id": 13, "card_id": "k2"}],
       "moves": [{"card_id": "k1", "from": {"player_id": 12}, "to": {"player_id": 13}},
                 {"card_id": "k2", "from": {"player_id": 13}, "to": {"player_id": 12}}],
       "positions_after": {"players": {"11": "k0", "12": "k2", "13": "k1", "14": "k3", "15": "k4"}, "center": ["k5", "k6", "k7"]}}
    ],
    "final": {"players": {"...": "..."}, "center": ["k5", "k6", "k7"]},
    "center_moved": [false, false, false]
  }
}
```
- `cards` lists one entry per card; the example shows three of the eight.
- `action` is one of `copy` (Doppelganger look), `see_team`, `peek_player`, `peek_center`, `swap_with_player`, `swap_others`, `swap_with_center`, `look_own` (Insomniac), `skip`.
- `role` is `role_acting_as`. `doppelganger_actors` lists which of `actors` is the Doppelganger (her look, her follow-up as another role, her place among the Werewolves or Masons); it is empty otherwise. `team` (see_team rows) is everyone shown together: the actors of a Werewolf or Mason row plus whoever the result listed (a Minion's row lists the Werewolves).
- `looked_at[].card_id` comes from the replay, not from the stored result text. The client looks up `role` in `cards`.
- `werewolf: true` marks the werewolf cards (the red path): a Werewolf card, AND a Doppelganger card whose holder copied Werewolf, which is a werewolf card for whoever ends the night holding it (`docs/specs/onuw/doppelganger.md`, Team Resolution Rule). The server decides this from the copy step; the client only colours. The card's `role` still says "Doppelganger".
- `center_moved` drives "Center cards, untouched: …".
- Card ids: `k0..k(n-1)` by seat order, then `k(n)..k(n+2)` for center 0–2. No randomness.

### Server changes
- New `engine/timeline.py` (pure, no Django):
  - `undo_to_dealt(final_players, final_center, log) -> (dealt_players_roles, dealt_center)`
  - `build_night_timeline(seats, original_roles, dealt_center, log) -> dict`
  - `recover_dealt_center(original_roles, final_players, final_center, log)` (legacy games)
- `views.ResultsView` builds `seats` from the seat-ordered PlayerRoles (fallback `user_id` order for legacy rows), adds `night_timeline` (via `services.night_timeline_for`), `token` and `seat`.
- Keep `night_actions_log` and the other existing fields.

### Leak analysis
The endpoint is already results-phase only (403 before). After results everything is public by the rules. Sleeps are not logged, so they do not appear. `made_by_server` was already in the raw log.

### Tests that must exist
- `test_timeline_matches_reference_games` (all 29 reference games: final positions == stored final roles and center; steps in wake order)
- `test_timeline_duplicate_werewolves_have_distinct_paths`
- `test_timeline_robber_then_troublemaker_same_player_order`
- `test_timeline_drunk_timeout_swap_marked_made_by_server`
- `test_timeline_doppelganger_copy_then_followup_rows_before_real_role`
- `test_timeline_merges_werewolf_team_view_row`
- `test_timeline_undo_then_replay_roundtrip_property` (seeded random nights, 3–10 players, all roles)
- `test_results_timeline_not_available_before_results_phase`
- `test_timeline_null_and_logged_on_inconsistent_log`

### Staging
Additive. The new results screen reads it; the old one ignores it.

---

## 5. Player tokens

### Decision
Ten tokens:
- `crow`, `key`, `moth`, `bell`, `thorn`
- **`antler`, `hare`, `lantern`, `spindle`, `scythe`** (folk-horror objects, no religious or national symbols)

`LobbyMember.token` is assigned on create and join, **under the Lobby row lock**: the first free token in a permutation seeded by the lobby code (`random.Random(f"{code}:tokens").sample(TOKENS, 10)`). It is logged at INFO (`lobby, user, token`). That makes it deterministic and replayable. The token stays with the member across play again (the membership persists) and is freed on leave (the row is deleted).

The deal **snapshots** the token and seat order (join order) into `PlayerRole.token` / `PlayerRole.seat`. A game's tokens never change, even if someone leaves mid-game (a non-host can, see "poor code" #4), and recent games and results stay stable.

`max_players` must be capped at 10 (today it is unbounded at create); a full set means no free token, and the join is refused 400 "Lobby is full." (`code: "lobby_full"`).

### API
- Lobby detail and every lobby response: `players[].token` (`"crow"`).
- Game `/me/` `players[]` and `GET .../players/`: `token`, `seat`.
- Results `players[]`: `token`, `seat`.
- `lobby_update` already carries the lobby serializer, so tokens arrive with it.

### Server changes
- core migration `0010_lobbymember_token`: `token = CharField(max_length=16, blank=True, default="")` plus `UniqueConstraint(fields=["lobby", "token"], condition=~Q(token=""), name="unique_lobby_token")`, and a **data migration** backfilling existing members in join order with the same algorithm.
- `core/tokens.py`: `TOKENS`, `assign_token(lobby)`.
- `LobbyJoinView` becomes atomic with `select_for_update` on the Lobby: capacity check, create, token (this also fixes the race in "poor code" #3).
- `LobbyCreateView`: the host member gets a token too.
- `LobbyCreateSerializer`: `max_players` between 3 and 10.
- onuw migration `0010_playerrole_v2_fields` (one migration for all PlayerRole fields in this contract): `token CharField(16, default="")`, `seat PositiveSmallIntegerField(null=True)`, `phase_ready BooleanField(default=False)`, `night_results_seen PositiveSmallIntegerField(default=0)`, plus `Meta.ordering = ("seat", "user_id")`.
- `_deal` fills `token` and `seat` from the locked lobby's members.

### Leak analysis
Tokens are public table identity, assigned from the code and join order. No role link.

### Tests that must exist
- `test_each_member_gets_distinct_token`
- `test_token_assignment_deterministic_for_same_code_and_join_order`
- `test_token_freed_on_leave_and_reused`
- `test_tokens_stable_across_play_again`
- `test_concurrent_joins_get_distinct_tokens_and_respect_capacity` (`transaction=True`)
- `test_game_snapshot_tokens_survive_member_leaving`
- `test_backfill_migration_assigns_tokens`
- `test_max_players_over_10_rejected`

### Staging
Additive. Run the migration before the code that reads it.

---

## 6. Home extras

### Decision: online count
`GET /api/stats/online/` (core, `AllowAny`, anon-throttled), as in the mock: "23 players at 5 tables tonight".
- Players = distinct users with a **fresh socket row** (`last_seen >= Now() - stale`) in `LobbySocket` ∪ any registered game socket table.
- Tables = distinct lobbies among those rows.

It is computed per request from rows on the database clock; there is no per-process state. Core must not import onuw, so a game app registers a source: `presence.register_online_source(lambda: QuerySet[values("user_id", "lobby_id")])` (onuw: `SocketPresence` → `game__lobby_id`). Socket tables hold one row per open socket, so the cost is two tiny scans. Responses carry `Cache-Control: public, max-age=15`, so Vercel's CDN absorbs home-screen traffic.

Caveat: someone sitting on the home screen (no socket) is not counted. The honest label is "players at tables".

```json
{"players": 23, "tables": 5}
```

### Decision: recent games
`GET /api/onuw/me/recent-games/?limit=5` (default 5, max 10):
- Only games in `results` where the caller has a PlayerRole, newest first.
- Unfinished or abandoned games are never listed: they hold live hidden information, and "where am I" covers them.
- Fields are minimal: nothing about other players' roles. The full detail stays behind `results/`, which already checks membership.
- `ended_at` = `Game.updated_at`. Nothing writes a results-phase game afterwards; add `finished_at` later only if that changes.

```json
{"games": [{"game_id": "9b…", "ended_at": "2026-11-18T21:04:11Z", "player_count": 6,
            "winning_teams": ["village"], "you_won": true}]}
```

### Leak analysis
- The online count is an aggregate of public presence.
- Recent games only contain finished games of the caller, and only facts announced to that whole table at results.
- No lobby code is exposed (it would let anyone read the lobby detail).

### Tests that must exist
- `test_online_counts_distinct_users_across_lobby_and_game_sockets`
- `test_online_ignores_stale_rows`
- `test_online_has_cache_header_and_no_user_data`
- `test_core_online_view_imports_no_game_app` (the existing scan covers this)
- `test_recent_games_only_finished_games_of_caller`
- `test_recent_games_excludes_running_game`
- `test_recent_games_limit_clamped`
- `test_recent_games_other_user_sees_nothing`

### Staging
Additive.

---

## 7. Pace presets

### Decision
The presets are client-side sugar over the existing settings: the server already validates every key. The minimum window (`night_min_window_seconds`, 8) is **not** a pace knob: it is a hidden-information guard. Keep it fixed at 8 in every preset, and make sure `night_wave_seconds >= 8`.

| preset | `discussion_seconds` | `voting_seconds` | `night_wave_seconds` | `night_doppelganger_window_seconds` |
|---|---|---|---|---|
| quick | 180 | 45 | 20 | 10 |
| normal | 300 | 90 | 30 | 10 |
| long | 480 | 120 | 45 | 15 |
| custom | 60–900 | 20–300 | 10–120 | 8–30 (client slider bounds) |

The deck screen writes the chosen numbers with the deck via the existing `PATCH /lobbies/<code>/`. Optionally it also writes `"pace": "quick" | "normal" | "long" | "custom"` so the screen re-selects the preset. In that case the server should validate it as one of those four strings (one line in `validate_onuw_settings`) so junk is not stored. The server never reads it.

Note: the code's default `voting_seconds` is 120 (`services.transition_to_voting`). With lock-in, the timer is only a backstop.

### Tests that must exist
- `test_pace_label_validated_if_present`
- `test_preset_values_pass_validation` (one parametrised test per preset)

---

## 8. Two bugs

### (a) Reopening the app between games lands on home

**Root cause.**
- `frontend/lib/core/router/app_router.dart:63-79`: on `/`, the router asks `GET /onuw/me/current-game/` and redirects only when `game_id` is present.
- `backend/apps/onuw/views.py:621-655` `CurrentGameView` returns only games with `phase != results` (`.exclude(game__phase=Phase.RESULTS)`, line 639) and never looks at lobby membership.

Between games the newest game is in `results` (lobby `finished`, waiting for "Play again"), or the lobby is `waiting` with no new game yet. Both return `{"game": null}`, so the app stays on home although the player is still seated.

**Fix:** a core "where am I" endpoint that starts from **membership**, and asks the game app (hook) about the newest game.

`GET /api/me/table/`:
```json
{"table": {"lobby_code": "QX7KDM", "game_type": "onuw", "status": "waiting", "is_host": false, "token": "moth",
           "game": {"game_id": "9b…", "phase": "results"}}}
```
or `{"table": null}`.

- Membership: the caller's newest-joined `LobbyMember` whose lobby is `in_game`, or was updated within `CORE_TABLE_RESUME_HOURS` (default 12, so stale tables from last week do not hijack home).
- `game` is the lobby's newest game if the caller plays in it (via the new `GameHooks.member_game(lobby, user_id) -> dict | None`); otherwise `null`.

Routing for the client:
- `game.phase != "results"` → the game screen.
- `status == "waiting"` → the lobby.
- `status == "finished"` → that game's results screen (with Play again / Leave).

A waiting-lobby member therefore gets `status: "waiting"` and is sent to the table.

`CurrentGameView` stays as is for the old app. Optionally add `"lobby_code"` next to `"game": null` additively.

Tests:
- `test_where_am_i_waiting_lobby_member_gets_table`
- `test_where_am_i_after_results_before_play_again_gets_results_game`
- `test_where_am_i_after_play_again_gets_waiting_lobby`
- `test_where_am_i_running_game`
- `test_where_am_i_after_leave_is_null`
- `test_where_am_i_ignores_stale_table`
- `test_where_am_i_picks_newest_membership`
- `test_core_view_uses_hooks_not_game_app`

### (b) A full restart shows the night result again

**Root cause.** `frontend/lib/features/game/presentation/game_notifier.dart:263-286` (`_surfaceMissedNightResults`) decides "already shown" against `state.shownNightResults`, which lives only in memory. After a cold start it is empty, so every closed-window entry of `/me/` `night_results` is "unseen" and is shown again (night, talk and vote phases).

**Recommendation: a server-side ack** rather than device storage.
- It survives a browser that clears storage (phone browsers, private tabs), which is the v1 platform.
- It is player-scoped, cheap, and one source of truth.
- The prefix of `night_results` is stable (window order, append-only), so a count is enough.

API:
- `/me/` gains `"night_results_seen": 1`.
- `POST /api/onuw/games/<id>/night-results/seen/` with `{"seen": 2}` (integer 0–10) → `{"night_results_seen": 2}`. It is monotonic: `UPDATE … SET night_results_seen = GREATEST(night_results_seen, n)` in one statement (no Game lock needed; it takes no other lock).
- The value is **not** clamped to the visible list length. The Doppelganger's look arrives by socket while window 1 is open, but `/me/` lists it only after the window closes. Clamping would lose that ack.
- The client shows `night_results[night_results_seen:]` and acks after the result screen hides.
- For uniformity, **every** phone acks once after each window's dawn screen, sleepers with their unchanged count, so the request pattern does not mark actors.

Tests:
- `test_seen_count_is_monotonic`
- `test_seen_count_is_player_scoped`
- `test_doppelganger_ack_before_window_close_survives`
- `test_me_reports_seen_count`
- `test_seen_rejects_non_integer_and_out_of_range`

---

## Hidden information — cross-cutting checks
- No new field reveals another player's pick, readiness identity, action, or result before results.
- Every new group event is a count or public identity.
- Error strings for night submissions stay generic ("Invalid action.").
- Timing: the look stage, the all-tap close and lock-in reveals depend only on taps by everyone, presence and the clock.
- Add a parametrised "no-leak sweep" test: for every new endpoint and event, in each phase, assert that no role name appears in any non-results payload sent to a player other than its owner (`test_v2_payloads_contain_no_foreign_role_names`).

## Atomicity and locking
- `vote/`, `ready/`, sleep: one transaction, Game then PlayerRole. Transitions (`reveal_votes`, `end_discussion`, `start_night_phase`) are called inside it. Side effects go after commit.
- Join and create: Lobby, then LobbyMember. Deal: Lobby (already locked), then a read of members, then create Game and PlayerRoles.
- `night-results/seen/`: a single conditional UPDATE on PlayerRole only.
- `card_look` job: Game lock plus the phase/window check (idempotent via the `start_night_phase` guard).

## Seeded randomness
- Tokens: `Random(f"{code}:tokens")`, logged.
- Card ids: deterministic by seat.
- Sleep: no randomness.
- The Drunk timeout is unchanged.
- No other new randomness.

---

## Deployment session must know
1. **Migrations:** core `0010_lobbymember_token` (schema + data backfill + conditional unique constraint) and onuw `0010_playerrole_v2_fields` (4 columns with defaults, PlayerRole `ordering`).
   - Both are additive. Run `migrate` **before** the new code takes traffic: new code reads the columns; old code ignores them.
   - The deploy doc still has migration running on Vercel as an open note (`docs/dev/deploy-vercel.md:145`). Settle that first.
2. **New timer job `card_look`** (key `<game id>:look`, under the game prefix, so the sweep and `cancel_all_for_game` cover it).
   - Only scheduled when `card_look_seconds > 0`. Keep it 0 on every table until the deployment is fully promoted, so an old deployment's queue subscriber never receives a job name it does not know.
   - `debug-fire-timer current` must include it.
3. **New game settings (lobby JSON):**
   - `card_look_seconds` (int 0–120, default 0)
   - `night_all_players_tap` (bool, default false)
   - `pace` (label, optional)
   - New Django setting `CORE_TABLE_RESUME_HOURS` (default 12).
   - No environment-variable changes.
4. **Presence:** the online count reads the existing socket rows with the existing stale window (`ONUW_PRESENCE_STALE_SECONDS`); nothing new to run. `Cache-Control: public, max-age=15` on `/api/stats/online/`: confirm Vercel caches API responses by that header and does not vary on `Authorization` (the view takes no auth).
5. **Behaviour flips (breaking slice only):**
   - Defaults of `night_all_players_tap` (and optionally `card_look_seconds`).
   - Removal of `vote_submitted.player_id` and `players[].has_voted`.
   - Ship only when no old client is in the wild (PWA cache: bump the app version).

---

## Implementation order (independently mergeable backend slices)
1. **S1 — schema + tokens + seat order.** Both migrations (all four PlayerRole columns at once), `core/tokens.py`, locked join/create, `max_players` cap, token/seat in the serializers, `PlayerRole` ordering. Fixes "poor code" #2 and #3.
2. **S2 — where am I** (`/me/table/` + `GameHooks.member_game`). Fixes 8a.
3. **S3 — night results ack.** Fixes 8b.
4. **S4 — lock-in voting** (`lock`, `progress` event, `my_vote`, single-transaction `submit_vote`). Fixes "poor code" #1.
5. **S5 — ready to vote** (`ready/` in the talk, `progress` talk).
6. **S6 — look stage** (`card_look_seconds`, `card_look` job, recovery and stuck-rule changes, advance-wave at window 0).
7. **S7 — sleep + all-tap close rule** (setting off by default).
8. **S8 — results timeline** (pure `engine/timeline.py` first, with the property test, then the view).
9. **S9 — home** (`stats/online/` with `register_online_source`, `me/recent-games/`).
10. **S10 — breaking cleanup.** Flip the defaults, drop the legacy vote fields, update `docs/dev/debug-harness/contract.md` §0 and `backend/CLAUDE.md`. The harness keeps passing `night_all_players_tap: false` or makes its runner send sleeps.

S2, S3, S8 and S9 depend only on S1 (S8 and S9 only for tokens/seat). S4–S7 share `progress` and `phase_ready`: land S4 before S5 and S6.

## Open risks
- **Mock vs ruling** on who-has-locked / who-is-ready (tokens lit per player). Decide before building screens 8 and 9.
- **Mixed clients at one table** with `night_all_players_tap` on: an old phone never sleeps, so every window runs to its deadline. Correct but slow. Ship the setting only from the new deck screen.
- **Hosts can set `night_min_window_seconds` to 0** (allowed for the harness), which removes the timing guard. Consider a floor of 5 outside DEBUG.
- **Doppelganger window at 8–10 s** is tight for look plus a Seer center follow-up. Watch playtests.
- **Online count misses people on the home screen.** If the number must include them, it needs a write per authenticated request (a `last_seen` on User), which is not cheap on Vercel. Not recommended.
- **Ack uniformity** (every phone acks) is a client discipline. A future client that acks only on results would mark actors to a network observer (out of scope, but cheap to keep).
- **The timeline undo-replay** assumes every card move is logged. Any future role that moves cards outside the log (Daybreak) must log moves, or `night_timeline` becomes `null`.

## Poor or wrong in the current code
1. `backend/apps/onuw/services.py:1346-1365`: `submit_vote` checks `game.phase` on an **unlocked** Game, then locks only the PlayerRole. A vote can commit after `reveal_votes` has computed results, so `ResultsView` (`vote_target_id`) disagrees with `game.results`. The reveal check at 1390-1397 runs in a separate transaction. Fix in S4 with a single Game → PlayerRole transaction.
2. `backend/apps/onuw/models.py:129-130`: `PlayerRole` has no ordering and a UUID pk. Every players list (`views.py:574`, `GameMeSerializer.get_players`, `ResultsView`) comes back in arbitrary order, so seats and columns can shuffle between calls. S1 adds `seat` and ordering.
3. `backend/apps/core/views.py:180-193`: join is not atomic. A concurrent join can exceed `max_players`. `max_players` itself is unbounded at create (`serializers.py:68-71`), while the game allows 10 at most.
4. `backend/apps/core/views.py:279-299` (non-host leave): allowed during `in_game`. The PlayerRole stays while membership and (soon) the token disappear. Acceptable, but it is why the deal must snapshot tokens.
5. `backend/apps/core/views.py:309`: `is_ready = request.data.get("is_ready", …)` is not validated as a bool (the string `"false"` is truthy). Ready can also be toggled while `in_game`.
6. `backend/apps/onuw/views.py` `WaveAdvanceView`: at `current_wave == 0` (a night not yet opened) it calls `advance_wave` on window 0. That cancels `<id>:wave:0`, resolves "window 0" and opens window 1 even when the Doppelganger is not in the deck. It should call `start_night_phase` (S6 fixes this; it matters as soon as the look stage exists).
7. `backend/apps/onuw/views.py:666` and `:756`: the `ResultsView` docstring promises "Center cards (original and final)", but only the final `game.center_cards` is returned (it is overwritten in `persist_wave_results`, `services.py:~867`). The timeline in S8 provides the dealt center.
8. `backend/apps/onuw/views.py:621-655`: `CurrentGameView` answers in two shapes (`{"game": null}` vs a flat object), which forced a three-shape parser in `game_resume_service.dart:74-101`. It also ignores lobbies (bug 8a).
9. `frontend/lib/features/game/data/game_resume_service.dart:26,34`: it reads `your_role` with `.toString()` (it is an object) and a top-level `has_acted` (it lives in `your_role.has_acted`). Both are always wrong. Frontend, noted for the agent editing it.
10. `backend/apps/onuw/views.py` `ResultsView` answers **403** for "results not available yet". 409 would match the other state conflicts; harmless but inconsistent.
11. `backend/apps/core/views.py` `LobbyDetailView.patch`: no lock and no status check. Settings can change mid-game (the running game copied its settings, so it is only confusing), and two host taps can interleave.

## Rulings by the session owner (19 November 2026)

- **Who has locked / who is ready:** counts only, as the brief says. The app lights the first `done` slots, never specific players.
- **`card_look_seconds`** is written as 30 by the new deck screen.
- **Label for the Doppelganger window on the deck screen:** "Copy".
- **Hold-to-read a role** works on every role card, large or small.
- **Pace:** three presets plus custom, exactly the table in section 7.

## Amendments after independent review (19 November 2026)

These override the text above wherever they disagree. The review's root causes were three
assumptions, so the fixes are rules, not patches.

### Rule A: there is no old app to protect, so there is no legacy staging

The Flutter app is not deployed anywhere (`docs/dev/deploy-vercel.md`). The app in this
repository is the only client and changes in the same pull request as the server slice it
depends on. Therefore:

- No `night_all_players_tap` setting. The all-tap close rule is THE rule for window 2.
- No legacy vote fields: S4 removes `vote_submitted.player_id`, `/me/ players[].has_voted`
  and `has_voted` in the player list. Only `progress` counts exist ("counts only" ruling).
- `lock` is required on `POST .../vote/` (no default).
- Slice S10 ("breaking cleanup") is deleted.
- `PATCH /lobbies/<code>/` merges the given settings keys into the stored settings instead
  of replacing the whole object, so one screen cannot silently drop another screen's key.

### Rule B: every phone sends the same thing at night

- Every player submits exactly once per window. A player whose prompt offers a choice
  (Seer, Robber, Troublemaker, Drunk, lone Werewolf, the Doppelganger's look and her
  choosing follow-ups) submits that action. EVERY other player, including actors with
  nothing to choose (Werewolves in a pack, Masons, Minion, Insomniac, a Doppelganger who
  copied one of them) submits `sleep`; the server still gives them their automatic
  `see_team` / `none` result when the window closes. `sleep` from a player who has a choice
  is the generic 400.
- `sleep_prompt` is sent to every player who has no choice; `/me/` carries it too.
- The all-tap rule applies to window 2 only. Window 1 is always the fixed Doppelganger
  window. `night_doppelganger_window_seconds = 0` and `night_wave_seconds = 0` are refused
  unless the Django setting `ONUW_ALLOW_UNTIMED_NIGHT` is true (true only in the test,
  development and harness settings; false in base, so production refuses them). With no
  deadline one idle player could stall the night, and an open-ended window 1 singles out
  the Doppelganger.
- `night_min_window_seconds` has a floor of 5 under the same switch.
- `advance-wave` takes `{"from_window": n}` and answers 409 if the current window differs,
  so a stale host tap cannot close the window after the one it was aimed at.

### Rule C: a change must be safe while the previous code is still serving

Vercel runs `migrate` at build time, before the new code takes traffic, and the channel
layer is shared between old and new instances.

- Every new NOT NULL column has a database default (`db_default`). Tested by a raw insert
  that omits the column.
- Tokens are assigned lazily as well as on join: at the deal for any member whose token is
  blank; serializers accept a blank token. The backfill leaves members beyond the tenth
  blank.
- Consumers drop unknown event types instead of closing the socket.
- A new timer job name is only scheduled by code that can also run it; `card_look` is
  scheduled only when `card_look_seconds > 0`.

### Single corrections

- **Look stage (section 3):** `_evaluate_presence`, `ensure_timers` and `recover_timers`
  must each handle "night, window 0, look deadline set": re-check look readiness when a
  grace timer fires or a player reconnects, rebuild the `:look` timer, and never open the
  night at start-up while a look deadline is pending. `start_night_phase` cancels
  `<id>:look`. Implement this as one `stage readiness` function used by all three, not
  three special cases.
- **Votes (section 1):** `docs/specs/onuw/voting-and-resolution.md` is updated in S4: a
  pick counts at any reveal whether or not it was locked, including the pick of a player
  who dropped, and an unlocked Hunter pick triggers the Hunter chain. The pick response
  echoes the stored target (`{"status": "picked", "target_player_id": 14}`).
  `target_player_id` must be a JSON integer.
- **Talk readiness (section 1):** no grace timers in the talk. `needed` is computed when a
  player taps and when a player's presence changes; `progress` is sent on both.
- **Night results ack (section 8b):** phones ack only after a window's dawn screen; the
  value is clamped to the number of results the caller can see. The "not clamped" sentence
  is withdrawn.
- **Results timeline (section 4):** the deal stores the center as dealt in
  `Game.dealt_center_cards` (S1 migration). The timeline is built forwards from it. The
  undo is used only for games dealt before that column existed, is verified against each
  player's `original_role`, and yields `night_timeline: null` if they differ. The
  "forward replay must reproduce the final table" check is dropped: it could never fail.
- **Online count (section 6):** `authentication_classes = []`; the app calls it without an
  `Authorization` header.
- **"Poor code" #6** is wrong as written: `advance_wave` at window 0 raises and returns a
  500 (unreachable today). The fix stands.

### Slice order after the amendments

S1 schema, tokens, seat, dealt center, tolerant consumers · S2 where am I · S3 results ack ·
S4 lock-in voting (with the app's vote screen) · S5 ready to vote · S6 look stage ·
S7 sleep and the all-tap rule (with the app's night screens) · S8 results timeline ·
S9 home extras and merged settings PATCH.

## Second amendment: the night is one `choose` (20 November 2026)

`docs/specs/frontend/first-time-play.md` section 4(b) replaces this contract's `sleep`
action, `sleep_prompt` and the wording of Rule B. In short: every phone sends
`action_type: "choose"` with 0 to 2 ordered picks; the server alone decides what the picks
mean for the role and answers every phone identically; window 1 accepts up to two `choose`
from any phone; window 2 closes when every present phone has chosen once (never before the
minimum); a window opening is one group event and each phone reads its own prompt from
`/me/`; prompts no longer carry teammates (teams are shown with the results of the window);
the deck may be `deck: "auto"` with a chip and is then built by the server at the deal.

**Staging.** The app in this repository still wears its old night screens, and the harness
drives them. Until screens 04 to 09 are rebuilt the server keeps today's behaviour for games
whose settings do not say `night_protocol: 2`, and `lock` on a vote defaults to true. The new
screens' lobby defaults write `night_protocol: 2`. When the last old screen is gone, protocol 1,
the legacy vote fields (`vote_submitted.player_id`, `has_voted`), the per-role prompt events
and this paragraph are deleted in one cleanup slice (tracked in `docs/dev/status.md`).

**Stages (20 November 2026, `docs/specs/frontend/first-time-play.md` sections 7 and 8).** Under `night_protocol: 2` every stage-scoped request (`choose`, `ready`, `vote`, and the host's `advance-wave`, `end-discussion`, `reveal-votes`) carries the `stage` string that `GET /me/` returns, and a request for a stage that has passed is `409 {"code":"wrong_stage"}` and does nothing; this replaces `from_window` for protocol 2. A phone chooses once per window (only the Doppelganger sends a second in window 1; the server takes a second from anyone, and every choose names the prompt it answers so a resend is never taken for a second: see "Third amendment" below), the prompt carries `shapes` (which picks would do something, as data), and `vote_submitted {player_id}` is not sent: votes announce counts only. `defaults: "v2"` writes only `card_look_seconds`, `night_protocol` and the automatic deck (no timer length). See `backend/CLAUDE.md`, "Night protocol 2".

## Third amendment: a lost answer and a resend (20 November 2026)

A phone whose answer is lost sends the same request again, with the same `stage`. A model
of the protocol-2 game (`docs/dev/models/night2/`) found that this was not safe for
`choose`: the Doppelganger's resent look was counted as her second choose and read as the
copied role's action (as Robber she robbed the player she had looked at), and her real
follow-up was refused `409 already_chosen`. Taking "a harmless second choose from anyone"
was only harmless for phones whose second choose is never read. The rule now, for every
protocol-2 request: **sending it twice leaves the game as sending it once did.**

**`choose` names the prompt it answers.** The body carries `chosen`: the `chosen` of the
`action_prompt` the phone is answering (`GET /me/`; after a `200` the phone's own count is
one higher, so the Doppelganger's follow-up sends `1`). Under the Game lock, after the stage
check:

- `chosen` LOWER than the server's count for the window: a resend of a choose already
  taken. `200 {"status": "submitted"}`, the same bytes as the original, for every role;
  nothing is stored, read or sent (the picks of the resend are not looked at).
- equal: a new choose, read as before.
- higher: a prompt the server never showed: `400 bad_request`.
- missing, not a plain JSON integer, or negative: `400 bad_request`. Required, because no
  client spoke protocol 2 yet when this was added (the app in this repository has the
  night board but no protocol-2 request yet; the harness and the samples send it).

**After ANY choose answered 200 the phone re-reads `GET /me/` and trusts its `chosen` and
`chooses_left`, never the 200.** The 200 says only that the server holds a choose for the
prompt the request named. A choose built from a STALE prompt (its `chosen` already passed)
is answered the same 200 and is stored nowhere: if the phone meant it as a new choose,
only `/me/` shows that it was not taken (`chosen` did not move, `chooses_left` is still 1).

`409 already_chosen` stays for exactly one case: a choose that answers a prompt that is
used up (`chosen` == `max_chooses`): a second phone of the same player, or a client that
ignores its prompt. A resend never gets it. A resend that arrives after its stage ended
(the copy of the last choose that closed window 2) names a stage that is over: `409
wrong_stage`, nothing stored, as for any late tap; the phone reads `/me/`.

**The other requests**, each checked by a test that sends it twice
(`backend/tests/onuw/test_resend.py`):

| Request | A resend while its stage is open | A resend after its first copy ended the stage |
|---|---|---|
| `ready` (look, talk) | sets the flag to the same value: same answer | `409 wrong_stage` |
| `vote` pick | stores the same pick: same answer; resent after its own lock: `409 vote_locked` (nothing changes) | n/a (a pick ends nothing) |
| `vote` lock | **same lock again: `200 {"status":"submitted"}`, nothing stored or sent** (was `409 vote_locked`); any other pick or lock after locking is still `409 vote_locked`; protocol 1 unchanged | `409 wrong_stage` (the last lock revealed) |
| `night-results/seen` | `GREATEST`: same answer | no stage |
| `advance-wave`, `end-discussion`, `reveal-votes` | always end their stage | `409 wrong_stage` |
| lobby `start` | n/a | `400` "Lobby is not in waiting state." (Lobby row lock: one game) |
| lobby `play-again` | `200`, the same lobby body | `409` once the next game is dealt |
| lobby `join` | state unchanged; the answer differs: `400 already_in_lobby` | n/a |
| lobby `leave` | state unchanged; the answer differs: `400` "You are not in this lobby." (`404` if the leaver was the last member and the lobby is gone) | n/a |
| lobby settings `PATCH`, lobby `ready` | merges / sets the same values: same answer | n/a |

For the lobby requests whose second answer differs (`join`, `leave`, `start`), the client
treats that answer to its own resend as success and reads the lobby (`GET /lobbies/<code>/`
or `GET /api/me/table/`). There is no kick and no token-change endpoint today; when one is
added it needs a row here and a test in `test_resend.py`.

A stale resend that overtakes a NEWER request of the same phone (a pick resent after a
different pick) is a client ordering matter: the app sends a phone's requests one at a
time and retries only the latest.

**Two additions to the viewer's own `night_results` (protocol 2 only).** Nothing of anyone
else's; protocol 1 is unchanged.

- `peek_center`: `revealed_info` gains `center_indices` (`[i, j]`, the centre cards in the
  order of `roles`: "Left: X, Right: Y"). The viewer chose them.
- `"nothing_chosen": true` in `revealed_info` when the result is the role's default because
  nothing the player picked meant anything for the role (or they did not choose): an entry
  `{"action_type": "skip", "revealed_info": {"nothing_chosen": true}}` for a Seer, Robber,
  Troublemaker or the Doppelganger's look (protocol 1 omits skips; protocol 2 lists the
  viewer's own), the Drunk's swap made by the server (`{"card_index": n,
  "nothing_chosen": true}`), and a lone Werewolf who looked at no centre card
  (`see_team` without `center_card`). Absent on a result the player's picks made.
  `night_results_seen` counts these entries like any other.

**Two additions to `GET /me/` (protocol 2 only, additive).**

- `player_id` at the top level: the caller's own id (the app no longer has to take it from
  the login).
- `action_prompt.chooses_left` (0 or 1): how many `choose` this phone should still send in
  the open window. 1 per window for every phone; after her look, 1 again for the
  Doppelganger when the copied role acts in window 1 (Seer, Robber, Troublemaker, Drunk,
  Minion). It says nothing her own prompt's `kind` does not already say to her, it is the
  same width for every phone, and it is only in her own `/me/`. `max_chooses` stays what
  the server accepts (two in window 1 from anyone). **An accepted tell:** phones send one
  choose per window, so an armed Doppelganger's phone is the only one that sends a SECOND
  `POST .../action/` in window 1. Someone watching the table's network traffic can see
  that extra request (not its content). The answer is the same bytes as anyone's, and the
  server would take a second choose from any phone; the extra request itself is visible
  and accepted, as is her look's extra work in her first request (`backend/apps/onuw/README.md`). The legacy
  `has_voted` and `your_role.has_acted` are still sent; they go with the cleanup slice.

## Fourth amendment: the stage clock, the vote list, the server's `Date` (20 November 2026)

Three additions for the rebuilt phone screens; all additive, no migration, protocol 1 unchanged.

- **`GET /me/` `stage_started_at`** (protocol 2): when the timed stage that is open now (the
  look, window 1, window 2, the talk, the vote) opened, in `deadline`'s format (ISO 8601 with
  offset). It is null whenever `deadline` is null (an untimed stage, the results) and for a
  stage opened by code from before it existed. The same on every phone; it depends only on
  when the stage opened, never on a role. A restart's reconnect allowance moves `deadline`,
  never `stage_started_at`, so a phone draws the stage as it really ran. Stored in the
  existing `Game.night_window_opened_at`, which every stage now sets when it opens (the
  night's minimum-length rule still reads it only in a night window).
- **`GET /me/` `vote_targets`** (protocol 2): while voting, the player ids the caller may vote
  for, in seat order: every player in the game but the caller (no self-votes,
  `voting-and-resolution.md`), the same list `POST .../vote/` accepts, whoever has picked,
  locked or dropped. Null outside the vote. The phone lists exactly these and holds no rule.
- **CORS exposes `Date`** (`CORS_EXPOSE_HEADERS = ["Date"]` in the base settings, so every
  environment): a web app on an allowed origin can read the server's clock from the
  response `Date` header to draw `deadline` and `stage_started_at` against it instead of
  the phone's clock. Origins are unchanged (`CORS_ALLOWED_ORIGINS` per environment).

**The table before the deal (same amendment, protocol-2 tables only unless said).** A table
whose settings say `night_protocol: 2` gets more in its lobby body (`GET /lobbies/<code>/`,
every lobby answer, every `lobby_update`); any other table is answered as before.

- **No ready check at the deal.** Everyone at the table is dealt in; a guest who joins and
  closes the app cannot block it. (The original night keeps "everyone ready".)
- **`players[].connected`** (bool): the member's phone is at the table (a lobby socket or
  a socket on the newest game). A phone that drops stays `true` for the table's
  `disconnect_grace_seconds`; then the table gets a `lobby_update` with `false`. Coming
  back sends a `lobby_update` at once. A member never seen with a socket is `false`.
  `lobby_update` is also sent when a member joins or leaves. Not secret at a table.
- **`deck_preview`**: the automatic deck the deal would build for the players at the
  table now and `deck_chip`, `{role: count}` (the shape of `settings.roles`), from the
  deal's own function; null for a custom deck or a player count with no automatic deck.
- **`deal`**: `{"ok": bool, "need": int, "have": int}`: `ok` is exactly whether the deal
  would be accepted now (waiting, 3 to 10 players, a legal deck of the right size, valid
  settings; only the host check is left out); `need` = players + 3; `have` = cards in the
  deck the deal would use (0 if none). The phone holds no deck-size rule.
- **One table at a time (every table):** `POST /lobbies/<code>/join/` by a member of
  another table that is still going (waiting or in a game, active within the resume
  window) is `409 {"detail": "You are already at another table.", "code":
  "already_at_table", "lobby_code": "<that table>"}`. A finished table traps nobody; after
  play again a member leaves that table to sit elsewhere.
