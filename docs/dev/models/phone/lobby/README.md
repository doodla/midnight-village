# The lobby's send queue: a TLA+ model

The host's phone in the lobby, as the code is at `7821a42`: the settings lane
(`frontend/lib/features/lobby/presentation/lobby_notifier.dart`: settings and practice in ONE queue,
one request out at a time in tap order, every tap sent), the lobby reads (`refreshLobby`, the
events held while a read is out), the socket (a read when it drops and when it is back), and the
one "Try again" slot it shares with the deal. Against an abstract server that applies a change,
answers the whole lobby and broadcasts `lobby_update` (`backend/apps/core/views.py`).
Step 1 of the plan for splitting `lobby_notifier.dart`: the model of today, before any change.

## What it models

- A key's value is the number of the tap that asked it (0: the table's own), so "older" is
  "smaller". Three keys: `seats`, `deck` (a custom deck changes `deck` and `seats` in one tap,
  as `startCustomDeck` does), `prac` (practice, the other endpoint, same lane).
- `q` is `_pending` and the queue at once: the change out is always its head (`_send` removes
  it on every outcome). The screen is `Over(base, q)`: the base lobby with every pending change
  over it (`_withPending`). What the base is follows the code: the answer, the read (with the
  events held meanwhile over it), a `lobby_update`, or, after a refusal or a loss, what was
  already shown (the refused or lost value stays until the read lands).
- After a refusal or a loss the queue waits for the read (`await refreshLobby()` in `_send`).
- "Try again" is one slot: the unsent changes (`_resendUnsent`: each trimmed to the keys no
  newer change asked for, renumbered, at the back of the queue) or the deal.
- Faults (at most `MaxFaults`): a change with no answer in time, a refusal, a failed read, a
  socket drop, a lost or refused deal. `LATE`: a request with no answer may still reach the
  server after a newer one (issue #16).

Left out: the host role moving (403), the notifier going away, a deal that reached the server
though its answer was lost, the deck rules, how practice asks fold (`PracticeAsk.then`, unit
tested). Bound: 3 taps, 1 player joining, 1 deal tap, 2 faults.

## Files

| File | What it is |
|---|---|
| `PhoneLobby.tla` | The model; its header names the code it was read from. |
| `lobby.cfg` | The rule that holds (`NeverOlder`), 2 faults. |
| `heal.cfg` | `FlickerHeals` and `Converges` with 1 fault: both hold. |
| `known_*.cfg` | One KNOWN gap each: the run must still break its rule. |
| `runlobby.sh` | Runs them all and fails when any ends otherwise (a gap closed, or a new break). |

`TLA2TOOLS=/path/to/tla2tools.jar ./runlobby.sh` (TLC is not in the repository). Last run:
TLC 2026.11.19 (`tla2tools.jar` of the tlaplus v1.8.0 release), 24 November 2026.

## Rules

| Rule | Says | Run | Result |
|---|---|---|---|
| `NeverOlder` | The server never writes a key's older ask over a newer one (lane order; "Try again" never undoes a newer change) | `lobby` | holds (6,774,314 distinct states) |
| `FlickerHeals`, `Converges` | A key shown older than its answer is put right with nobody tapping; the screen ends where the server is or says "Not sent." | `heal` (1 fault) | hold (616,617 distinct states) |
| `NoFlickerBack` | (a) Once a change's answer is shown, its keys never show an older value | `known_a` (no fault at all) | KNOWN gap |
| `LostFlagged` | (b) A lost change that "Try again" would still send is said so on the screen | `known_b` | KNOWN gap |
| `NoHiddenResend` | (b) "Try again" never sends a change whose "Not sent." a later tap took away | `known_b2` | KNOWN gap |
| `RetryCoversAll` | (c) "Try again" sends every change that did not get through | `known_c` | KNOWN gap |
| `NeverOlder` | With `LATE`: a lost request may reach the server after a newer one | `known_late` | KNOWN gap (#16) |
| `FlickerHeals` | With 2 faults: a socket drop and a failed read | `known_heal` | KNOWN gap |
| `Converges` | With 2 faults: a refusal and a failed read | `known_converge` | KNOWN gap |

## Known gaps (shortest traces)

The traces are TLC's with one worker (`runlobby.sh` runs the known gaps that way, so they come
out the same every time). TLC writes `Next` for the step `SJoin` (someone sits down) and for
`SRefuse` (the server refuses a change).

**(a) A read that crosses an answer shows the old value: real, with no fault at all**
(`known_a`, `MaxFaults = 0`, 9 states). The host taps a seat count; it goes out. Someone sits
down: `player_joined`, and the phone starts a read, which the server serves BEFORE it applies the
seat count. The server applies it, answers, and queues `lobby_update`. The answer lands: the new
count shows. The read lands: the OLD count shows (the `lobby_update` was not in yet, so nothing
was held to replay over the read). The `lobby_update` then arrives and puts it right. At the
table: the number the host just set jumps back for a moment, then forward again. Any read that
crosses an answer does it (a player joining or leaving, a refusal or loss of an earlier change,
the socket coming back). The socket can do it alone, too (a run with four workers found it, 10
states): two quick seat taps, and the first one's `lobby_update` arrives after the second one's
answer, so the first count shows until the second `lobby_update` comes. It heals whenever the
socket works (`heal` holds), but not always: with the socket down and the read after it failing,
the old value stays until something else reads (`known_heal`, 15 states: the socket drops and
starts a read, two seat taps both answered while that read was served before them, the read
lands old, the socket is back and its read fails).

**(b) A new tap hides "Not sent." while the lost change still waits: real** (`known_b`, 5
states). The host taps a seat count; no answer: "Not sent." with "Try again". The host turns
practice on: the line goes (`_change` sets `notSent: false`), but the seat count stays in
`_unsent` and `_retry` still points at it. At the table: the lost count is still shown, with no
word, until the read lands and it flips back, still with no word and no "Try again". Worse
(`known_b2`, 10 states): then practice is lost too, "Not sent." comes back, and "Try again"
sends practice AND the old seat count (nothing newer asked for seats), so the count changes long
after the host saw it undone. (A new tap on the SAME key is harmless: "Try again" would trim the
lost change to nothing, so the rule counts only a lost change that would still be sent.)

**(c) A lost deal after a lost change: "Try again" redoes only the deal: real** (`known_c`, 7
states). The host taps a seat count; no answer: "Not sent.". Nothing is pending any more, so
Deal is live; the host deals; no answer: "Not sent." again, and the one slot now holds the deal
(`_retry = deal`). "Try again" sends the deal; the seat count stays in `_unsent`, unsaid. At the
table: the game is dealt for the old count. A REFUSED deal empties the slot too (`_retry =
null`, `notSent: false`): the lost change is then unsaid with no "Try again" at all.

**Also found.** `known_late` (9 states, two faults): two seat taps; the first gets no answer but
reaches the server after the second, and overwrites it (the hole #16 names for the game is in
the lobby too). `known_converge` (7 states, two faults): a custom deck is tapped, the server
refuses it, the read after the refusal fails: the refused deck stays on screen, with no word,
until something else reads (`_send`'s refusal branch shows nothing itself, and `_applyHeld`
keeps what is shown).

## #16, the server's half (`FIX_ASKED`)

`FIX_ASKED` models what the server does once a change carries the time of its tap (`asked`):
per key, a change older than the newest it applied for that key is dropped; when every key of
a change is dropped it answers `409 stale_request`, stores nothing and broadcasts nothing (the
phone reads again, as after any refusal). `late.cfg` (`LATE` and `FIX_ASKED`, 2 faults) holds
`NeverOlder` (17,572,777 distinct states); `known_late` (`LATE` alone) still breaks it, and is
the phone of today, which sends no `asked` yet. When the phone sends it, `known_late` goes and
`late.cfg` is the run. `runlobby.sh` runs both.

