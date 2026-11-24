# The lobby's send queue: a TLA+ model

The host's phone in the lobby: the settings lane (settings and practice in ONE queue, one
request out at a time in tap order, every tap sent), the lobby reads (`refreshLobby`, the
events held while a read is out), the socket (a read when it drops and when it is back),
"Not sent." with its "Try again", and the deal. Against an abstract server that applies a
change, answers the whole lobby and broadcasts `lobby_update` of that same lobby
(`backend/apps/core/views.py`), with a second writer beside the host: a presence change, a
join, a join to a full table that takes a practice player's seat (`practice.make_room`),
each a `lobby_update` of its own, and a new table at the same code (its numbers start
again); and the host role moving away (`host_changed`, and a 403 for this phone).

Every lobby body carries the server's revision `rev`, which rises with every change the
server tells anyone. The phone never shows a body older than the newest it has shown.

First written from `7821a42` with four KNOWN gaps (a, b, b2, c), closed on the branch
`lobby-lane-gaps`; its review (findings 1 to 6) is closed here. The lane's rules are one pure
value, `frontend/lib/features/lobby/domain/settings_lane.dart` (`SettingsLane`), and what
goes out is `lobby_taps.dart`, a part of `lobby_notifier.dart`.

## The rules the host can rely on

- **R0, nothing older is shown** (`NoFlickerBack`). A lobby body (an answer, a read, a
  `lobby_update`) whose `rev` is lower than the newest shown is not shown; equal is shown (at
  an equal number who is present may differ, and a read that crosses a write can carry newer
  members with the older number). A body with no `rev` (a server from before it) is shown as
  it comes and leaves the newest number alone. `host_changed` carries `rev` and counts as
  shown at it; one lower than the newest shown is ignored, so a late handover never puts an
  older host back (`HostNeverBack`). The newest is kept per table (its code with its
  `created_at`): a new table at a code used before starts again. This one compare replaced the guess that told lobbies apart by their values and
  the order they came in (gap a's "laid" answers and the matching of `lobby_update`s), which
  stuck when someone else wrote a key and took another player's update for the host's own.
- **R1, "Not sent." is derived** (`LostFlagged`, `NoHiddenResend`). It is
  `SettingsLane.notSent`, never a stored flag: it shows exactly while a lost change would
  still be sent by "Try again" (it has a key no newer change asked for), or the deal did not
  go. A newer tap on another key cannot take it away; a newer tap on the same key leaves the
  lost change nothing to send, so the line goes with it and that lost value is never sent
  again.
- **R2, the screen shows what will go, and that is what is dealt** (`DealAsShown`,
  `RetryCoversAll`). The screen is the server's lobby with every change still to go over it,
  the newest ask winning on each key: the pending changes, the lost changes "Try again" or
  Deal would still send (with "Not sent."), and a refused value until the next server lobby.
  So what the host sees at the tap of Deal (or of its "Try again") is what is dealt: a deal
  sends the lost changes again first and goes behind them. One deal at a time: a deal or
  "Try again" while one waits joins it. Whenever the deal does not go (a change before it lost
  or refused, a refused value on screen, a setting tapped while it waits) the lane says so,
  "Not sent.": never a silent end. A change tapped while the deal is out goes after its
  answer.
- **R3, "Try again" always does something** (`TryAgainActs`). With a refused value still on
  screen it reads the lobby (a read is what takes it off); the deal stays back, and the next
  "Try again" deals what the read shows.
- **R4, a guest's phone says nothing** (`GuestQuiet`). After a 403 (the host role moved) the
  lane forgets what it would send again, the changes waiting, and any held deal.

## Where each action is in the code

| Model | Code |
|---|---|
| `q`, `unsent`, `asked`, `askedAt` | `SettingsLane.pending`, `.unsent`, `._asked`, `._askedAt` |
| `refC`, `dealHeld`, `dq = "queued"` | `SettingsLane._refused` (`refusedShown`), `.dealHeld`, `.dealWaiting` |
| `base`, `srn` | `LobbyNotifier._base` (with what only this phone knows), `SettingsLane._shownRev` |
| `Apply`, `Show` (`Adm`: per table) | `SettingsLane.admit` (in `LobbyNotifier._admit` with `_tableOf`, `_showServer`, `_refreshOnce`, `_replayBuffered`); a `"host"` event: `_onHostChanged` (`admit(lobby: false)`) |
| `phost`, `btid` | `LobbyState.hostId`, `.code` with `.createdAt` |
| `Shown`, `Over`, `Layers` | `SettingsLane.over` (`_putBase`, `_showLane`) |
| `NotSent` | `SettingsLane.notSent` (put on `LobbyState.notSent` by `over`) |
| `Tap(ks)` | `SettingsLane.ask` (`_LobbyTaps._change`); a deal waiting is held |
| `Send`, `phase = "out"` | `SettingsLane.sendNext` (`_LobbyTaps._send`, run in turn by `_settingsQueue`) |
| `Reply`, taken | `SettingsLane.taken`, then `_showServer` of the answer |
| `Reply`, refused | `SettingsLane.refused`, then `await refreshLobby()` in `_send` (`phase = "reading"`) |
| `Reply`, forbidden | `SettingsLane.settle`, then a read |
| `Timeout` | `SettingsLane.lose`, then the read as above |
| `Retry` | `_LobbyTaps.retry`: a read with a refused value on screen; else `deal` if `dealHeld`; else `takeResend` and `ask` for each |
| `DealTap`, `DealGo` | `_LobbyTaps.deal` (`_dealing`: one deal), `takeResend`, `dealBehind`, `_dealAfterLane` (`dealGoes`) |
| `DealServe` | `startGame` (a 403: `settle`) |
| `DealLoss`, `DealTaken`, `DealRefused` | `SettingsLane.dealLost`, `.dealTaken`, `.dealRefused` |
| `ReadServe`, `ReadApply`, `ReadFail` | `_refreshOnce`, `_replayBuffered`, `_applyHeld` |
| `EvDeliver` | `_handleWebSocketEvent`: held while a read is out; else `_onLobbyUpdate` (`_showServer`) or a read |
| `SockDrop`, `SockUp` | the socket's state in `_connectWebSocket`: `readOnDrop` |
| `SOther`, `SMove`, `SApply`, `SRefuse` | the server: `views.py`, `practice.make_room`, `announce_lobby`, `host.py` |

The lane's rules are unit tested one per rule in
`frontend/test/features/lobby/domain/settings_lane_test.dart`; the notifier around it, each
gap's and each finding's trace, in
`frontend/test/features/lobby/presentation/settings_lane_order_test.dart`.

## What it models

- A key's value is the number of the tap that asked it (0: the table's own, and what
  make_room leaves on `prac`), so for the host's own keys "older" is "smaller". Three keys:
  `seats`, `deck` (a custom deck changes `deck` and `seats` in one tap, as `startCustomDeck`
  does), `prac` (practice, the other endpoint, same lane).
- Bodies are `[v, rev, host, tid]` (`tid`: the table); the server's `rev` rises with each change it tells anyone (a host
  change applied, a presence change, a join, a make_room, the host role moving).
- After a refusal or a loss the queue waits for the read (`await refreshLobby()` in `_send`).
- Faults (at most `MaxFaults`): a change with no answer in time (applied or not), a refusal,
  a failed read, a socket drop, a lost or refused deal, the host role moving. `LATE`: a
  request with no answer may still reach the server after a newer one (issue #16).
- `MaxJoins` bounds the second writer: one presence change, join, or make_room.

Left out: the notifier going away, a deal that reached the server though its answer was lost,
the host role coming back to this phone, the deck rules, how practice asks fold
(`PracticeAsk.then`, unit tested), a server that answers a value other than the one asked.
Bound: 3 taps, 1 second-writer event, 1 deal tap, 2 faults.

## Files

| File | What it is |
|---|---|
| `PhoneLobby.tla` | The model; its header names the code it was read from. |
| `lobby.cfg` | `NeverOlder`, 2 faults. |
| `late.cfg` | `NeverOlder` with `LATE` and `FIX_ASKED` (the server's half of #16), without the second writer (`MaxJoins = 0`: it never writes a host's ask, with it the run had 36 million states and 6 million still queued at its twelfth minute, well on course past the script's hour). |
| `rule_a.cfg`, `rule_b.cfg`, `rule_b2.cfg`, `rule_c.cfg`, `rule_d.cfg` | R0, R1, R1, R2, R4: their rules hold, 2 faults. |
| `try.cfg` | R3, `TryAgainActs` (liveness), 1 tap, 2 faults. |
| `heal.cfg` | `Converges` with 1 fault. |
| `known_*.cfg` | One KNOWN gap each: the run must still break its rule. |
| `runlobby.sh` | Runs them all and fails when any ends otherwise (a gap closed, or a new break). |

`TLA2TOOLS=/path/to/tla2tools.jar ./runlobby.sh` (TLC is not in the repository). Last run,
the whole script: TLC 2026.11.19 (`tla2tools.jar` of the tlaplus v1.8.0 release),
24 November 2026.

## Rules

| Rule | Says | Run | Result |
|---|---|---|---|
| `NeverOlder` | The server never writes a key's older ask over a newer one (lane order; "Try again" never undoes a newer change) | `lobby` | holds (36,495,738 distinct states, 15 min) |
| `NoFlickerBack`, `HostNeverBack` | (R0) No lobby shown takes a host value back, nothing laid over the lobby is older than it, and no older host comes back | `rule_a` | holds (36,495,738 distinct states, 17 min) |
| `LostFlagged` | (R1) A lost change that "Try again" would still send is said so on the screen | `rule_b` | holds (36,495,738 distinct states, 15 min) |
| `NoHiddenResend` | (R1) "Try again" never sends a lost value after "Not sent." stopped showing for it | `rule_b2` | holds (36,495,738 distinct states, 15 min2) |
| `RetryCoversAll`, `DealAsShown` | (R2) "Try again" leaves nothing behind; what is dealt is what the screen showed at the tap, but a key another writer changed where the phone could not show it (`Unseen`: see below) | `rule_c` | holds (36,495,738 distinct states, 15 min) |
| `GuestQuiet` | (R4) A phone that met a 403 shows no "Not sent." | `rule_d` | holds (36,495,738 distinct states, 15 min) |
| `TryAgainActs` | (R3) After "Try again" a request goes out or "Not sent." goes | `try` | holds (191,320 distinct states, 0 min) |
| `Converges` | The screen ends where the server is or says "Not sent." | `heal` (1 fault) | holds (2,416,919 distinct states, 3 min) |
| `NeverOlder` | With `LATE` and `FIX_ASKED`: the server drops a change older than the one it stored | `late` | holds (3,218,025 distinct states, 1 min) |
| `NeverOlder` | With `LATE` alone: a lost request may reach the server after a newer one | `known_late` | KNOWN gap (#16) |
| `Converges` | With 2 faults: a refusal and a failed read | `known_converge` | KNOWN gap |

## How the review's findings showed in the model

Each was first seen breaking the model as it was at `de8b710` (TLC, one worker), then fixed
in the model and the code:

1. **A deal that never went, and nothing said.** The model had `dq = "none"` guards on a tap
   and on "Try again" that the code does not have. Without them `rule_c` breaks
   (`DealAsShown`: a setting tapped while the deal was out reached the server before it, and
   was dealt though the screen at the tap did not show it). Now a change tapped while the
   deal is out waits for its answer, a tap while the deal waits keeps it back ("Not sent."),
   and there is one deal at a time: a deal or "Try again" while one waits joins it.
2. **"Try again" that did nothing.** A refused value on screen after a failed read: Deal says
   "Not sent.", and "Try again" sent nothing and read nothing. `TryAgainActs` breaks on it
   (`try.cfg`). Now it reads the lobby.
3. and 4. **The hold that stuck, and another player's update taken for the host's own.** With
   a presence `lobby_update` beside the host's own, `rule_a` breaks: an update carrying the
   old seats, sent before the host's change was applied, arrives after its answer and shows
   the old count. The value-and-order matching is gone; the `rev` compare is the rule.
5. **"Not sent." on a guest's phone.** After a 403 the lane kept what it would resend;
   `GuestQuiet` breaks with the 403 kept that way. Now `settle` forgets it.
6. **`DealAsShown` was weaker than its name** (it compared with the screen after the lost
   values were shown again). With the screen at the tap, `rule_c` breaks: the read put 4
   back, "Not sent." showed, the host dealt and 5 was dealt. Now a lost value lies over the
   screen while it would still be sent, so the screen at the tap is what goes.

**Added with the server's `rev` (its contract: `docs/specs/onuw/api-contract-v2.md`,
sections 2 and 8).** With two host moves, a `host_changed` applied whatever its number
breaks `HostNeverBack` (a read showed the newest host, then the first move's late event put
the older one back). With a new table at the same code and the newest kept for the whole
code, `Converges` breaks (two taps, then the new table's first `lobby_update`, numbered 1,
is never shown). Both hold with the rules above.

**What `DealAsShown` leaves out, and why (the honest nearest rule).** With the second writer
in, the deal can only promise the screen for the keys the phone could know. Two traces broke
the plain rule, neither a fault of the phone's: (1) a new table opened at the same code and
the host dealt before its first `lobby_update` came; (2) the host changed the practice count
and, before its answer, someone sat down at the full table: make_room took a practice seat
AFTER the host's change was applied, the phone showed the host's change on its way over that
newer lobby, and the answer (older) was rightly not shown; the deal dealt the server's order,
which is the table as it is. So `Unseen` (the keys left out) is: make_room's `prac` after the
lobby on screen or while the host's own practice change is on its way, and every key of a
new table not heard of yet. Every other key is dealt as shown.

**A slip in the model, found on the way.** `Next` read `\E r \in reqs : SRefuse(r) \/ SJoin`:
the quantifier ran to the end of the line, so someone sat down only while a request of the
host's was in flight. Each quantifier is in parentheses now.

## How the gaps closed (the first four, `7821a42`)

**(a) A read that crosses an answer showed the old value**; now the `rev` compare. **(b) A
new tap hid "Not sent." while the lost change still waited**, and **(b2)** "Try again" then
sent a value the host saw undone; now "Not sent." is derived. **(c) A lost deal after a lost
change: "Try again" redid only the deal**; now a deal sends the lost changes first and "Try
again" redoes both, the change first.

**Still open.** `known_late` (two faults): two seat taps; the first gets no answer but
reaches the server after the second, and overwrites it (#16, the server's). `known_converge`
(two faults): a custom deck is tapped, the server refuses it, the read after the refusal
fails: the refused deck stays on screen, with no word, until something else reads (a Deal
then says "Not sent.", and its "Try again" reads).

## #16, the server's half (`FIX_ASKED`)

`FIX_ASKED` models what the server does once a change carries the time of its tap (`asked`):
per key, a change older than the newest it applied for that key is dropped; when every key of
a change is dropped it answers `409 stale_request`, stores nothing and broadcasts nothing (the
phone reads again, as after any refusal). `late.cfg` (`LATE` and `FIX_ASKED`, 2 faults) holds
`NeverOlder`; `known_late` (`LATE` alone) still breaks it, and is the phone of today, which
sends no `asked` yet. When the phone sends it, `known_late` goes and `late.cfg` is the run.
`runlobby.sh` runs both.
