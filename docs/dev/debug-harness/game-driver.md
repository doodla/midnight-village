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

The harness backend must be up (DEBUG, throwaway DB). It binds `HARNESS_PORT`, or a free
port it picks and prints:

```bash
cd backend && HARNESS_PORT=8001 just harness-serve     # leave running in another shell
```

The driver targets `127.0.0.1:8001` unless `DRIVER_API_BASE` says otherwise
(`DRIVER_API_BASE=http://127.0.0.1:<port>/api` for another port).

## Verbs

```bash
cd backend
python3 tools/game_driver.py setup --spec tools/specs/<spec>.json   # → game_id + player ids
python3 tools/game_driver.py me            --game <id> --player Alice
python3 tools/game_driver.py ready         --game <id> --player Alice        # the look (or ready to vote); --not un-readies in the talk
python3 tools/game_driver.py choose        --game <id> --player Alice --picks '[{"player_id": 1061}]'
python3 tools/game_driver.py advance-wave   --game <id>
python3 tools/game_driver.py vote          --game <id> --player Alice --target 1062   # locks; --pick only picks
python3 tools/game_driver.py end-discussion --game <id>
python3 tools/game_driver.py reveal-votes   --game <id>
python3 tools/game_driver.py results        --game <id>
python3 tools/game_driver.py oracle         --game <id>   # referee-only ground truth
python3 tools/game_driver.py fire-timer     --game <id> --key voting
```

`setup` writes a session file (`backend/.driver/session-<id>.json`, gitignored)
mapping player name → token, so later commands resolve a player by name. The
**first player in the spec is the host** and holds the host-only endpoints
(advance-wave, end-discussion, reveal-votes, oracle, fire-timer). It opens the table as
the app does (`defaults: "v2"`), with a custom deck from the spec. Every stage-scoped
command (`ready`, `choose`, `vote`, `advance-wave`, `end-discussion`, `reveal-votes`)
reads that player's `me` first and sends the `stage` it carries (a `choose` also its
prompt's `chosen`), as the app does.

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

### Picks (the `--picks` JSON)

Every player with a choice (`me`'s `action_prompt.chooses_left` above 0) sends a
`choose` in the window; one with nothing to choose (`kind` `none`) need send nothing,
and the window never waits for it. A choose is 0 to 2 picks, each
`{"player_id": <id>}`, `{"center_index": i}` or `{"self": true}`. The server reads them for
the role (`me`'s `action_prompt.kind` and `shapes` say which picks would do something):

| `kind` | picks that act |
|---|---|
| `seer` | one other player, or two centre cards |
| `robber` | one other player |
| `troublemaker` | two other players |
| `drunk` | one centre card |
| `lone_werewolf` | one centre card |
| `doppelganger_look` | one other player (then, if she copied a role that acts in window 1, a second choose as that role) |
| `none` | nothing: send `[]` |

Picks that mean nothing (or `[]`) take the role's default: the Drunk is swapped by the
server, the Seer, Robber, Troublemaker and the look skip.

## Operational truths (learned by driving real games)

- **Timers are disabled by default.** A slow LLM agent loses the night to the
  window timeouts before it can act. `setup` therefore sets
  `night_wave_seconds / night_min_window_seconds /
  night_doppelganger_window_seconds / discussion_seconds / voting_seconds = 0`,
  which makes the backend skip scheduling those timers — so **nothing
  auto-advances on wall-clock and the driver controls every transition.** To test
  timing deliberately, put real values in `spec.timers` (e.g.
  `{"night_doppelganger_window_seconds": 10, "night_min_window_seconds": 8}` for the
  shipped lengths, `{"night_wave_seconds": 5}` for a timeout, `{"card_look_seconds": 30}`
  for the look stage, where every player taps `ready` first) and/or use the `fire-timer`
  verb (`wave:1`, `wave:2`, `look`, `current`: closes that stage now).
- **The night is two windows** (1 = Doppelganger, 2 = everyone else; `me` shows
  `current_wave` 1 or 2). Every player has a prompt in every window; a player with a
  choice chooses once, one with nothing to choose sends nothing;
  results are resolved when the window closes; read what happened from `oracle`
  (`night_actions_log`), which is the referee, or each player's `me` (`night_results`).
  A Doppelganger's look resolves in her first choose (listed in her `me` at once); her
  follow-up is a second choose in the same window if she copied Seer/Robber/
  Troublemaker/Drunk/Minion (`chooses_left` says so).
- **Phases auto-advance when complete.** Window 2 closes the instant every player with
  a choice has chosen (no sooner than `night_min_window_seconds`); the talk ends when everyone is ready;
  voting reveals the instant everyone has locked. So `advance-wave` / `end-discussion` /
  `reveal-votes` are only needed for *partial* states — calling them after a stage ended
  returns a clean 409 `wrong_stage`, not an error. Check the stage (via `me`/`oracle`)
  before forcing.
- **Verify against the oracle, then `results`.** Drive the game, then read
  `oracle` (post-swap `current_role`, team, votes) and `results` (winners,
  eliminations, reasons) and compare to what the rules say should have happened.
  The oracle is host-token + DEBUG-only — never hand it to a player being driven
  if you're testing hidden-info behavior.
- **Hidden-info checks must be STRUCTURAL, not text-matching.** A player's `me`
  view legitimately contains role *names* in `roles_in_game` (the public role
  list) and in their own `your_role`. A leak is a role attached to *another
  specific player* — assert that `players[]` carries only `{player_id,
  display_name, token, seat}` and that no field maps another player to a role. Grepping for
  role names false-positives on the public list.

## Charter for a driver agent

> You are an exploratory tester driving whole ONUW games via
> `backend/tools/game_driver.py` against the booted harness backend. Your job is
> to find logic/flow bugs, not to play well.
>
> For each game: pick a setup (vary roles/counts; deliberately include
> Doppelganger chains, ties, Hunter, no-werewolf, Drunk-into-werewolf, timeout
> paths). Drive every phase to results. **Between moves, probe edge cases** —
> double-submit, a stale `stage`, invalid/foreign picks, vote for self, a vote
> without `lock` — and record how the server responds (expect clean 4xx, never
> 500, never a role leak). After results, read `oracle` + `results` and **assert
> the emergent state matches the rules**; log any discrepancy, 500, stuck phase,
> or hidden-info leak as a finding with the exact request and response.
>
> Run many short games rather than one long one. Coverage over depth.
