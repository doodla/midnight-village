# The phone under protocol 2: two TLA+ models

> These models predate the protocol-1 cleanup (20 November 2026): they speak of "protocol 2", the contract's "Third amendment" (now `docs/specs/onuw/api-contract-v2.md`, sections 5 and 9), `ProtocolTwoGameNotifier` (now `LiveGameNotifier`), the server module night2 (now `apps/onuw/choose_night.py`) and sample names ending in `_v2` (now plain names); the one flow they model is the only one left.

Two models of ONE phone against an abstract server that keeps the rules of
`docs/specs/onuw/api-contract-v2.md` ("Third amendment"), written from the app code at
`a1eb6dd` (the data layer of `526909f`). Every finding is replayed against the real notifier
in `frontend/test/features/game/presentation/protocol_two_findings_test.dart` and fixed in
`303f1df` (`fix(frontend): protocol 2 phones heal every fetch and trust the server's turn`).

## Files

| File | What it is |
|---|---|
| `night/PhoneNight.tla` | The night: look stage, window 1 (the Doppelganger's look and follow-up), window 2, the talk. Header names the Dart files modelled. |
| `night/*.cfg` | One configuration per run (`ROLE`, `COPY`, which fixes are on). `runall.sh` and `rerun.sh` write them and run TLC. |
| `night/view.mjs` | The reader's words for the chart: a name for each state and arrow. |
| `night/chart/`, `night/chart-robber/` | Chart (`chart.mmd`) and report of the `FollowUpArmed` counterexample, for a Doppelganger who copied the Minion and the Robber. |
| `day/PhoneDay.tla` | From the talk to the next game: the ready and vote lanes of the `Outbox`, `/me/`, `/me/table/`, the results, play again. |
| `day/*.cfg`, `day/runday.sh` | Its runs. |
| `lobby/` | A third model: the host's settings lane in the lobby (`SettingsLane` in `features/lobby/domain/settings_lane.dart`, sent by `lobby_taps.dart`), first of `7821a42`, now the fixed design (gaps a, b, b2, c closed), with its own README, runs and known gaps. |

The scripts look for TLC at `$TLA2TOOLS` (default: a path in the session that made them;
set the variable). TLC logs are not kept.

## Rules checked

Night: `StoredAsIntended` (the server stores what the player meant), `OnePerTurn`,
`NoChosenForUnusedTurn`, `FollowUpArmed` (her follow-up board arms while window 1 is open),
`ChosenNotForever`, `Converges`. Day: `TapOrder` (a lane's taps are stored in tap order),
`ScreenConverges` (the screen ends where the server is), `OutcomeLoads`.

## What it found (before the fix)

| Run | Broke | Finding |
|---|---|---|
| `chart`, `chart_robber` | `FollowUpArmed` | F1: a failed `/me/` after the first load was never fetched again; her follow-up never armed. |
| `v_minion` | `NoChosenForUnusedTurn` | F2: the turn was read from the prompt's `kind`, so a Doppelganger-Minion's follow-up turn was wrong. |
| `v_oldserver` | `StoredAsIntended` | F4: without `chosen` in the request a resent look is stored as the follow-up (the server side was fixed in `fb229fb`). |
| `day_outcome` | `OutcomeLoads` | F5: a failed `GET results/` was never fetched again. |
| `day_screen` | `ScreenConverges` | F6: a lost play-again or deal event left the phone on the results. |
| `day` | `TapOrder` | Accepted: a request processed late can overtake a newer tap of the same lane (needs a per-phone sequence number on the server; open item in `docs/dev/status.md`). |

F3 (Riverpod rebuilding the notifier and dropping taps in flight) is in the same test file
and commit; whether TLC or the modelling found it is not recorded.

With the fixes: `v_villager`, `v_actor` and `v_sleeper` hold every rule; `v_robber_fix`
(`FIX_RETRY`) and `v_minion_fix` (`FIX_RETRY`, `FIX_TURN`) hold every rule once the model was
refined (`rerun.sh`; 684,228 distinct states each; their first runs still broke a temporal
property); `day_fix` (`FIX_HEAL`) holds `OutcomeLoads` and `ScreenConverges` (1,087,725
distinct states) and does not check `TapOrder`.
