# The phone under protocol 2: two TLA+ models

> These models predate the protocol-1 cleanup (20 November 2026):
> they speak of "protocol 2", the contract's "Third amendment" (now `docs/specs/onuw/api-contract-v2.md`, sections 5 and 9), `ProtocolTwoGameNotifier`
> (now `LiveGameNotifier`), the server module night2 (now `apps/onuw/choose_night.py`) and sample names ending in `_v2` (now plain names);
> the one flow they model is the only one left.

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

| `day_late` | `TapOrder` | KNOWN until the phone sends `asked` (#16): two taps on "Ready to vote" (on, then off); the first gets no answer, the second goes out and is stored, then the first arrives late and is stored over it: the server has "ready" for a player who last said "not ready". 6 states. The same for a changed vote. |

F3 (Riverpod rebuilding the notifier and dropping taps in flight) is in the same test file
and commit; whether TLC or the modelling found it is not recorded.

With the fixes: `v_villager`, `v_actor` and `v_sleeper` hold every rule; `v_robber_fix`
(`FIX_RETRY`) and `v_minion_fix` (`FIX_RETRY`, `FIX_TURN`) hold every rule once the model was
refined (`rerun.sh`; 684,228 distinct states each; their first runs still broke a temporal
property); `day_fix` (`FIX_HEAL`) holds `OutcomeLoads` and `ScreenConverges` (1,087,725
distinct states) and does not check `TapOrder`.

**#16, the server's half.** `FIX_ASKED` models what the server does once a request carries the
time of its tap (`asked`): a ready or a vote older than the newest it applied for that lane is
answered `409 stale_request` and stored nowhere. `day_asked` (`FIX_ASKED`, the same faults as
`day_late`) holds `TapOrder` (1,002,993 distinct states). The phone does not send `asked` yet,
so `day_late` is the phone of today; it becomes a holding run when the phone sends it.
Run one: `java -cp tla2tools.jar tlc2.TLC -config day_asked.cfg PhoneDay.tla` in `day/`.
`day/runday.sh` runs every `day_*` run and fails when one ends otherwise than recorded here
(`TLA2TOOLS=/path/to/tla2tools.jar day/runday.sh`).

**Told, not asked (branch `ask-less`, 27 November 2026).** `FIX_ASKLESS` in `day/` models the
phone of that branch: a stage change carries this phone's own view (`me`, before the
table's event; the results with it at the end), applied when its stage is later, and the
event then reads nothing; a taken ready or lock's answer (the stored value and the count)
is put on the held `/me/`; an event is lost only with its socket, which comes back and reads
`/me/` and `/me/table/`; the slow table poll runs only while the socket is down; a failed
`/me/table/` read is read again (`retryForever`: the poll had stood in for it before).
`day_askless` (every fix, `OutcomeLoads` and `ScreenConverges`: 5,083,702 distinct states) and `day_askless_order`
(`TapOrder` with `asked`) hold; every earlier run sets it FALSE. Its first run broke
`ScreenConverges` only because the model had no retry of a failed table read: the code has
one, so the model now says so (the finding was the model's, not the app's).
Both reviews of `ask-less` found the socket that dies open (it looks up and delivers
nothing, so nothing reads and the poll stays off): `ZOMBIE` makes it an action. Without the
fix, `day_zombie` breaks `ScreenConverges` (the screen stays behind for good; it is in
`BREAKS`). `FIX_BEAT` is the fix: the server sends every socket a `beat` frame each heartbeat
and the phone drops one silent for 2.5 beats, so it comes back and reads. `day_beat` (every
fix, the zombie, two faults and two taps) holds `OutcomeLoads` and `ScreenConverges`
(9,322,705 distinct states). The seat model has the same pair (`seat/README.md`). Not
modelled: one frame lost on a socket that stays alive (TCP does not lose frames; a full
channel-layer queue could); the next event or tap of the table, a deadline or a resume
heals it, and the beat does not.

**A result at the choose (branch `night-result-now`, 25 November 2026).** `ANSWER_CARRIES`
models the phone of that branch: a taken choose's answer carries the caller's results and its
prompt's `chooses_left` (the server's count right after the request), and the phone fetches
`/me/` after it only when that is above 0 (her follow-up turn) or the answer is a 409; a taken
answer with 0 left keeps the tap confirming (its results shown) until a later fetch. The
results themselves are not modelled (the phone shows them from the answer; nothing waits on
them). Every earlier run sets it FALSE (the phone before it). With it: `v_actor_now` (the
Seer) holds every rule (236,521 distinct states), `v_robber_now` (`FIX_RETRY`, a Doppelganger
who copies the Robber) holds every rule including `FollowUpArmed` (782,417), `v_minion_now`
(`FIX_RETRY`, `FIX_TURN`, the Minion) holds every rule (782,417). The runs are `v_*_now.cfg` in `night/`.
