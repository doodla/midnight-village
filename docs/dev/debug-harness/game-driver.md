# Single-Agent Game Driver

A capability for **one** agent (Claude or a human) to drive an entire ONUW
multiplayer game — every player — against the real backend, and verify the
emergent state against the rules. It's a smart, omniscient exploratory tester:
it sees the whole board, deliberately steers into edge cases, and checks each
game's outcome via the DEBUG oracle.

It is **not** the deterministic API runner (scripted, asserts fixed scenarios)
and **not** N independent player-agents (concurrency + hidden-info-in-play). Use
this one for **exploratory testing of in-game logic and flow** — broad coverage,
edge-case hunting, "does this make sense," many games fast.

## What it is

`backend/tools/game_driver.py` — a dependency-free (stdlib) CLI exposing clean
verbs over the real player API + the DEBUG oracle. Each command prints JSON;
non-2xx responses are printed, not raised (seeing *how* the server rejects a bad
move — 400 vs 500 vs leak — is the point).

## Prerequisites

The harness backend must be up (DEBUG, throwaway DB, `127.0.0.1:8001`):

```bash
cd backend && just harness-serve     # leave running in another shell
```

Override the target with `DRIVER_API_BASE` if needed.

## Verbs

```bash
cd backend
python3 tools/game_driver.py setup --spec tools/specs/<spec>.json   # → game_id + player ids
python3 tools/game_driver.py me            --game <id> --player Alice
python3 tools/game_driver.py act           --game <id> --player Alice --action peek_player --targets '{"player_id": 1061}'
python3 tools/game_driver.py advance-wave   --game <id>
python3 tools/game_driver.py vote          --game <id> --player Alice --target 1062
python3 tools/game_driver.py end-discussion --game <id>
python3 tools/game_driver.py reveal-votes   --game <id>
python3 tools/game_driver.py results        --game <id>
python3 tools/game_driver.py oracle         --game <id>   # referee-only ground truth
python3 tools/game_driver.py fire-timer     --game <id> --key voting
```

`setup` writes a session file (`backend/.driver/session-<id>.json`, gitignored)
mapping player name → token, so later commands resolve a player by name. The
**first player in the spec is the host** and holds the host-only endpoints
(advance-wave, end-discussion, reveal-votes, oracle, fire-timer).

### Spec format

```jsonc
{
  "players": ["Alice", "Bob", "Carol", "Dave", "Eve"],
  "roles":   {"Alice": "Werewolf", "Bob": "Seer", "Carol": "Robber",
              "Dave": "Villager", "Eve": "Villager"},
  "center":  ["Werewolf", "Troublemaker", "Minion"],
  "timers":  { }   // optional; see below
}
```

Role names are canonical TitleCase. The lobby role-config is derived from
`roles` + `center` (must be a valid ONUW setup for the player count).

### Action-target encoding (the `--targets` JSON)

| action | targets |
|---|---|
| `peek_player` | `{"player_id": <id>}` |
| `peek_center` | `{"center_indices": [i, j]}` (exactly 2) |
| `swap_with_player` | `{"player_id": <id>}` |
| `swap_others` | `{"player_ids": [a, b]}` |
| `swap_with_center` | `{"center_index": i}` |
| lone-Werewolf center peek | `see_team` with `{"center_index": i}` |
| decline an optional action | the action's type with `{}` (empty targets) |

## Operational truths (learned by driving real games)

- **Timers are disabled by default.** A slow LLM agent loses the night to the
  30s-per-wave timeout before it can act. `setup` therefore sets
  `night_wave_seconds / discussion_seconds / voting_seconds = 0`, which makes the
  backend skip scheduling those timers — so **nothing auto-advances on wall-clock
  and the driver controls every transition.** To test timeout paths deliberately,
  set a short timer in `spec.timers` (e.g. `{"night_wave_seconds": 5}`) and/or
  use the `fire-timer` verb.
- **Phases auto-advance when complete.** A wave advances the instant all its
  actors submit; voting reveals the instant everyone votes. So `advance-wave` /
  `reveal-votes` are only needed for *partial* states (some players didn't act /
  vote) — calling them after a phase already completed returns a clean 4xx, not an
  error. Check phase (via `me`/`oracle`) before forcing.
- **Verify against the oracle, then `results`.** Drive the game, then read
  `oracle` (post-swap `current_role`, team, votes) and `results` (winners,
  eliminations, reasons) and compare to what the rules say should have happened.
  The oracle is host-token + DEBUG-only — never hand it to a player being driven
  if you're testing hidden-info behavior.
- **Hidden-info checks must be STRUCTURAL, not text-matching.** A player's `me`
  view legitimately contains role *names* in `roles_in_game` (the public role
  list) and in their own `your_role`. A leak is a role attached to *another
  specific player* — assert that `players[]` carries only `{player_id,
  display_name}` and that no field maps another player to a role. Grepping for
  role names false-positives on the public list.

## Charter for a driver agent

> You are an exploratory tester driving whole ONUW games via
> `backend/tools/game_driver.py` against the booted harness backend. Your job is
> to find logic/flow bugs, not to play well.
>
> For each game: pick a setup (vary roles/counts; deliberately include
> Doppelganger chains, ties, Hunter, no-werewolf, Drunk-into-werewolf, timeout
> paths). Drive every phase to results. **Between moves, probe edge cases** —
> double-submit, act out of turn, invalid/foreign targets, vote for self, act in
> the wrong phase — and record how the server responds (expect clean 4xx, never
> 500, never a role leak). After results, read `oracle` + `results` and **assert
> the emergent state matches the rules**; log any discrepancy, 500, stuck phase,
> or hidden-info leak as a finding with the exact request and response.
>
> Run many short games rather than one long one. Coverage over depth.
