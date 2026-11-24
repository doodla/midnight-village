# The lobby's send queue: a TLA+ model

The host's phone in the lobby: the settings lane (settings and practice in ONE queue, one
request out at a time in tap order, every tap sent), the lobby reads (`refreshLobby`, the
events held while a read is out), the socket (a read when it drops and when it is back),
"Not sent." with its "Try again", and the deal. Against an abstract server that applies a
change, answers the whole lobby and broadcasts `lobby_update` of that same lobby
(`backend/apps/core/views.py`).

First written from `7821a42` as the code was, with four KNOWN gaps (a, b, b2, c). The model
is now the fixed design, and the code follows it: the lane's rules are one pure value,
`frontend/lib/features/lobby/domain/settings_lane.dart` (`SettingsLane`), and what goes out
is `lobby_taps.dart`, a part of `lobby_notifier.dart`.

## The rules the host can rely on

- **R1, "Not sent." is derived** (gaps b, b2). It is `SettingsLane.notSent`, never a stored
  flag: it shows exactly while a lost change would still be sent by "Try again" (it has a
  key no newer change asked for), or the deal did not go. A newer tap on another key cannot
  take it away; a newer tap on the same key leaves the lost change nothing to send, so the
  line goes with it and that lost value is never sent again (the trimming rule).
- **R2, what is dealt is what was shown** (gap c). A deal goes behind the lane: every lost
  change is sent again first (shown at once, as "Try again" would), then the deal. A change
  before it lost or refused keeps it back ("Not sent."), and so does a refused value still on
  screen. "Try again" redoes every lost change, oldest first, then the deal if it did not go:
  nothing is forgotten.
- **R3, nothing older lands over an answer** (gap a). An answered change stays laid over the
  screen, with the answer's values, until nothing older can land: no lobby read is out (one
  asked before the answer may be older) and its own `lobby_update` has been heard (or the
  socket dropped since, losing whatever it had not delivered). A `lobby_update` is told
  apart by order: it is the update of the oldest change still waiting for one whose values
  it carries, so that one and every one before it have had theirs (the socket keeps the
  server's order). A lost change waits for its update too, unlaid: it may have got through.

**Changed from the rules as first asked.** R2 asked that lost changes the screen no longer
shows (the read put the server's values back) not be part of the deal. Modelled, that breaks:
a lost change can get through all the same (its answer lost, not its request), and the phone
cannot know, so a deal past it can deal a value the screen did not show. The rule built:
a deal always sends the lost changes first, and they show again at once before it goes.
`DealAsShown` still leaves out a key whose lost change got through without the phone hearing
of it, until a later answer on that key: "Not sent." said so when it was lost.

## Where each action is in the code

| Model | Code |
|---|---|
| `q`, `unsent`, `asked`, `askedAt` | `SettingsLane.pending`, `.unsent`, `._asked`, `._askedAt` |
| `conf`, `outSeen` | `SettingsLane._answered` (`_Answered`: `laid`, `due`), `._outHeard` |
| `refShown`, `dealHeld`, `dq = "queued"` | `SettingsLane.refusedShown`, `.dealHeld`, `.dealWaiting` |
| `NotSent` | `SettingsLane.notSent` (put on `LobbyState.notSent` by `over`, every `_show`) |
| `Over(base, conf \o q)` | `SettingsLane.over` (every `LobbyNotifier._show`; `pendingKeys` makes `settling`) |
| `Tap(ks)` | `SettingsLane.ask` (`_LobbyTaps._change`) |
| `Send`, `phase = "out"` | `SettingsLane.sendNext` (`_LobbyTaps._send`, run in turn by `_settingsQueue`); `.out` is the one out |
| `Reply`, taken | `SettingsLane.taken(answer)`, then `over` of the answer |
| `Reply`, refused | `SettingsLane.refused`, then `await refreshLobby()` in `_send` (`phase = "reading"`) |
| (left out) the host role moved, 403 | `SettingsLane.settle`, then a read; each later change is still sent and meets its own 403 |
| `Timeout` | `SettingsLane.lose`, then the read as above |
| `Retry` | `_LobbyTaps.retry`: `SettingsLane.takeResend` (trimmed, oldest first) and `ask` for each, then `deal` if `dealHeld` |
| `DealTap`, `DealGo` | `_LobbyTaps.deal`: `takeResend`, `dealBehind`, `await _settingsQueue`, `dealGoes` |
| `DealServe`, `DealRefuse` | `startGame` (no lane transition) |
| `DealLoss`, `DealTaken`, `DealRefused` | `SettingsLane.dealLost`, `.dealTaken`, `.dealRefused` |
| `ReadServe`, `ReadApply`, `ReadFail` | `_refreshOnce` (`readAsked`, `serverShown`, `readEnded`), `_applyHeld` |
| `EvDeliver` | `_handleWebSocketEvent`: `SettingsLane.heard` as it arrives, then held or `_onLobbyUpdate` (`serverShown`) |
| `SockDrop`, `SockUp` | the socket's state in `_connectWebSocket`: `SettingsLane.socketDropped`, `readOnDrop` |

The lane's rules are unit tested one per rule in
`frontend/test/features/lobby/domain/settings_lane_test.dart`; the notifier around it, each
gap's trace included, in `frontend/test/features/lobby/presentation/settings_lane_order_test.dart`.

## What it models

- A key's value is the number of the tap that asked it (0: the table's own), so "older" is
  "smaller". Three keys: `seats`, `deck` (a custom deck changes `deck` and `seats` in one tap,
  as `startCustomDeck` does), `prac` (practice, the other endpoint, same lane). The phone
  sees values, not tap numbers: with `COLLIDE` two taps can carry the same value (seats 5,
  6, 5), and the phone tells `lobby_update`s apart by value and order only.
- The screen is `Over(base, conf \o q)`: the base lobby with every answered change still laid
  and every pending one over it. What the base is follows the code: the answer, the read
  (with the events held meanwhile over it), a `lobby_update`, or, after a refusal or a loss,
  what was already shown (the refused or lost value stays until a lobby of the server's).
- After a refusal or a loss the queue waits for the read (`await refreshLobby()` in `_send`).
- Faults (at most `MaxFaults`): a change with no answer in time (applied or not), a refusal,
  a failed read, a socket drop, a lost or refused deal. `LATE`: a request with no answer may
  still reach the server after a newer one (issue #16).

Left out: the host role moving (403), the notifier going away, a deal that reached the server
though its answer was lost, the deck rules, how practice asks fold (`PracticeAsk.then`, unit
tested), a server that answers a value other than the one asked. Bound: 3 taps, 1 player
joining, 1 deal tap, 2 faults.

## Files

| File | What it is |
|---|---|
| `PhoneLobby.tla` | The model; its header names the code it was read from. |
| `lobby.cfg` | `NeverOlder`, 2 faults. |
| `late.cfg` | `NeverOlder` with `LATE` and `FIX_ASKED` (the server's half of #16). |
| `rule_a.cfg`, `rule_b.cfg`, `rule_b2.cfg`, `rule_c.cfg` | Gaps a, b, b2, c: their rules hold, 2 faults. |
| `heal.cfg` | `FlickerHeals` and `Converges` with 1 fault. (`FlickerHeals` with 2 faults, once `known_heal`, needs no run of its own now: `NoFlickerBack` holds with 2 faults, so no key is ever shown older than its answer.) |
| `known_*.cfg` | One KNOWN gap each: the run must still break its rule. |
| `runlobby.sh` | Runs them all and fails when any ends otherwise (a gap closed, or a new break). |

`TLA2TOOLS=/path/to/tla2tools.jar ./runlobby.sh` (TLC is not in the repository). Last run,
the whole script: TLC 2026.11.19 (`tla2tools.jar` of the tlaplus v1.8.0 release),
24 November 2026.

## Rules

| Rule | Says | Run | Result |
|---|---|---|---|
| `NeverOlder` | The server never writes a key's older ask over a newer one (lane order; "Try again" never undoes a newer change) | `lobby` | holds (8,897,725 distinct states) |
| `NoFlickerBack` | (a, R3) Once a change's answer is shown, its keys never show an older value | `rule_a` | holds (8,897,725) |
| `LostFlagged` | (b, R1) A lost change that "Try again" would still send is said so on the screen | `rule_b` | holds (8,897,725) |
| `NoHiddenResend` | (b2, R1) "Try again" never sends a lost value after "Not sent." stopped showing for it | `rule_b2` | holds (8,897,725) |
| `RetryCoversAll`, `DealAsShown` | (c, R2) "Try again" leaves nothing behind; what is dealt is what the screen showed at the tap | `rule_c` | holds (8,897,725) |
| `FlickerHeals`, `Converges` | A key shown older than its answer is put right with nobody tapping; the screen ends where the server is or says "Not sent." | `heal` (1 fault) | hold (720,207) |
| `NeverOlder` | With `LATE` and `FIX_ASKED`: the server drops a change older than the one it stored | `late` | holds (23,561,865) |
| `NeverOlder` | With `LATE` alone: a lost request may reach the server after a newer one | `known_late` | KNOWN gap (#16) |
| `Converges` | With 2 faults: a refusal and a failed read | `known_converge` | KNOWN gap |

## How the gaps closed (the traces that showed them)

The traces are TLC's with one worker on the model as it was at `7821a42`; each is now a test
in `settings_lane_order_test.dart` that asserts the fixed behaviour.

**(a) A read that crosses an answer showed the old value.** The host taps a seat count; it
goes out. Someone sits down and the phone starts a read, served BEFORE the server applies the
count. The answer lands: the new count shows. The read lands: the OLD count showed, until the
`lobby_update` put it right. The socket did it alone too: two quick seat taps, the first's
`lobby_update` after the second's answer. Now the answered change stays laid until nothing
older can land: the count never jumps back.

**(b) A new tap hid "Not sent." while the lost change still waited.** The host taps a seat
count; no answer: "Not sent.". The host turns practice on: the line went, though "Try again"
would still send the count. (b2) Then practice was lost too, "Not sent." came back, and "Try
again" sent the old count AND practice: the count changed long after the host saw it undone,
unsaid. Now the line stays through the practice tap, so "Try again" sends only what it said.

**(c) A lost deal after a lost change: "Try again" redid only the deal.** The host taps a seat
count; no answer. Nothing pending, so Deal is live; the host deals; no answer; the one "Try
again" slot held only the deal, and the game was dealt for the old count. Now a deal sends the
lost count first; if it is lost again the deal does not go, and "Try again" redoes both, the
count first.

**Still open.** `known_late` (two faults): two seat taps; the first gets no answer but
reaches the server after the second, and overwrites it (#16, the server's). `known_converge`
(two faults): a custom deck is tapped, the server refuses it, the read after the refusal fails:
the refused deck stays on screen, with no word, until something else reads. An answered change
whose own `lobby_update` never comes (applied while the socket was down, and the socket back
before its answer) stays laid until the next of the host's changes is heard or the socket
drops: the screen shows the answer's value, which is the server's unless something else
changed that key meanwhile.

## #16, the server's half (`FIX_ASKED`)

`FIX_ASKED` models what the server does once a change carries the time of its tap (`asked`):
per key, a change older than the newest it applied for that key is dropped; when every key of
a change is dropped it answers `409 stale_request`, stores nothing and broadcasts nothing (the
phone reads again, as after any refusal). `late.cfg` (`LATE` and `FIX_ASKED`, 2 faults) holds
`NeverOlder`; `known_late` (`LATE` alone) still breaks it, and is the phone of today, which
sends no `asked` yet. When the phone sends it, `known_late` goes and `late.cfg` is the run.
`runlobby.sh` runs both.
