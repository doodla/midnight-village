# Where the phone sits: a TLA+ slice (`PhoneSeat.tla`)

One guest phone from 02 through a game, play again and the next deal, written from branch
`start-lands-fast` (on `e48d802`). It models what moves the screen between tables and
games: the events (`game_started` on the lobby socket, `game_results` and `play_again` on
the game's); `/me/table/` reads, all asked through `askWhere` (a plain ask replaces the
read out, in a game and at the end board; a judged ask, the lobby's, waits for the read
out or judges the answer held, and asks again only if it still says "waiting"; coming
back to the app joins a read out); the lobby's reads and the phone's own player list (a
read can fail, leaving the list behind, and is read again after a backoff, main's #187); the game's `/me/`, refused to a phone that is not
a player; the phone leaving; a socket that opens (not listened to until it is up; a game's
never opens for a phone that is not a player), drops and comes back; the phone asleep; the
app coming back. The slow poll is left out: every heal must come from the phone's own reads.
The table is a version: 0 waiting, 1 game 1, 2 its results, 3 waiting again, 4 game 2;
`NoTable` once the phone has left.

Left out: the stages inside a game (the day model's, `../day/`: here a game behind the
server heals by its deadline, `GameHeals`, whose guard is the server's own state, so
convergence inside a running game holds by construction; the rules that matter here, at
02 and the end board, do not lean on it), the lobby asking only once per change of
status (`_askedWhereAt`: the model asks on every such lobby read; the code asks less,
and a resume or a socket coming back still asks), the host's taps (the answers seat the phone as
the events do), a cold open from the seat kept on the device (`LastSeat`; its one-read rule
is pinned by `app_open_test.dart`), a second table, joining again after leaving.

## Rules

- `NeverBack`: the screen never goes back to a table older than one it showed.
- `Converges`: the screen ends where the server is (`NoTable` for a phone that left).

## Bounds, and why they keep the rules meaningful

- Two games (versions 0 to 4): the fewest that hold a deal, the results, play again and a
  second deal, so a late or missed event of the first game can meet the second.
- At most two socket drops, two app resumes or sleeps, one failed lobby read and one leave
  in a run (`MaxDrops`, `MaxResumes`, `MaxFails`): every finding below needs at most one of
  each, and two drops and two resumes let a miss happen before and after play again.
- Reads are not numbered. A `/me/table/` read is either the newest asked for or not
  (`cur`); with `DROP_STALE` an older read can change nothing, so it is let go at once. The
  first version numbered every read, which made the state space unbounded in practice (the
  `seat` run passed 9 million states without ending). Only "newest or not" decides what the
  app does with an answer (Riverpod applies the newest build's alone), so nothing the rules
  can see is lost; with `DROP_STALE` off the older reads are kept, marked, and still break
  `NeverBack` (`stale`).
- The event channel holds at most the three events a run can send; the lobby and `/me/`
  reads are one slot each, as in the app (a read asked for while one is out shares it).

`runseat.sh` runs all six in about half a minute on this machine (`seat`: 211,762 distinct
states, none left on the queue).

Cost, accepted: a game screen's socket opening reads `/me/` once more (and `/me/table/`
when the table names the game), on every phone, at every new game: the first `/me/`
always goes out before the socket listens.

## Branch `ask-less` (27 November 2026): `FIX_ASKLESS`

The phone is told, not asked (contract, sections 1, 4 and 8). In this slice: the end of a
game reaches the phone with its own view (`me`, then `game_results`, one batch) and moves
the table it holds to "finished" with no read (`MyTable.inGameAt`); a `/me/` ahead of the
table does the same; past a deadline the phone reads its `/me/`, not the table. With a
table read already out, the table is asked again instead (`_compareTable`).

- **`seat_drop`** (`SEED_OVER_READ`, the first try; fixed). The app comes back and asks
  where it sits; the host plays again while the phone sleeps (the event is lost); the old
  game's `/me/` then lands at its results, and the seat put from it drops the read that
  would have said "waiting". The phone stays on the end board, its socket up, and nothing
  is left to heal it (the slow poll now runs only while the socket is down). Now a seat
  read out is asked again rather than dropped. Test: `live_game_test.dart`, "a read of the
  seat out when /me/ moves past the table is asked again".
- `seat` (this branch) holds both rules (210,114 distinct states); `seat_before` is main's
  phone (211,762).
- **`zombie`** (`ZOMBIE` without `FIX_BEAT`: the review's finding, fixed). A socket
  can die without closing (a phone that slept, a network changed under it): the phone still
  counts it up, so it neither reads on its return nor runs the slow poll. Shortest trace: at
  02 the host deals, the dead lobby socket loses `game_started`, and the phone stays at 02
  while the server plays on. With `FIX_BEAT` (the server's `beat` frame each heartbeat; a
  socket silent for 2.5 beats is dropped, so `Back` reads as for any drop), `seat_beat`
  holds both rules with the zombie, drops, resumes and failures (227,182 distinct states).
  Test: `test/core/websocket/socket_beat_test.dart`.
- **`lost`** (`LOSE` without `FIX_TOKEN`: the second reviews' finding, fixed). An event lost
  on a socket that stays alive: the beat keeps it "up", so nothing reads. Shortest trace: the
  deal's `game_started` is lost on a live lobby socket and the phone stays at 02. With
  `FIX_TOKEN` (the beat carries the table's token, the lobby's `rev` or the game's stage and
  `moved_on`, and a phone showing less reads once: 02 its lobby, judged; elsewhere where it
  sits), `seat_token` holds both rules with the zombie, a lost event, drops, resumes and
  failures (234,901 distinct states). Tests: `test/features/resume_and_beat_test.dart`,
  `live_game_told_test.dart`.

## Runs (`TLA2TOOLS=/path/to/tla2tools.jar ./runseat.sh`)

| Run | Constants | Ends |
|---|---|---|
| `seat` | the phone of this branch (`FIX_ASKLESS`) | holds both rules |
| `seat_before` | main's phone before `ask-less` | holds both rules |
| `seat_beat` | this branch, with `ZOMBIE` and `FIX_BEAT` | holds both rules |
| `seat_token` | this branch, with `ZOMBIE`, `LOSE`, `FIX_BEAT` and `FIX_TOKEN` | holds both rules |
| `seat_drop` | `FIX_ASKLESS` with `SEED_OVER_READ` | breaks `Converges` (finding, fixed) |
| `zombie` | `ZOMBIE` without `FIX_BEAT` | breaks `Converges` (finding, fixed) |
| `lost` | `LOSE` without `FIX_TOKEN` | breaks `Converges` (finding, fixed) |
| `late` | without `FIX_LATE` | breaks `NeverBack` (finding, fixed) |
| `stale` | without `DROP_STALE` | breaks `NeverBack` (why the seed relies on it) |
| `noup` | without `FIX_UP` | breaks `Converges` (finding, fixed) |
| `leave` | without `FIX_403` | breaks `Converges` (finding, fixed) |
| `today` | `e48d802`: no fix | breaks `Converges` (the owner's slow start) |

## What it found

- **`today`**: on `e48d802` a `game_started` lost while the lobby socket was down is healed
  only by the poll: the reconnect read only the lobby, which said "in a game", and nothing
  looked further. Fixed by `FIX_HEAL` (`_askWhereIfMoved`, the reconnect and the resume
  asking `/me/table/`). Tests: `table_moves_on_test.dart`.
- **`late`** (fixed: `_alreadyIn`, the code's guard, modelled as the code states it: the
  table the phone holds already names that game). A `game_started` that reaches the phone
  after a read took it past that game put it back in the old game's night. Test: "a late
  game_started".
- **`stale`**: a seat from an event must drop a read already out, or a read served before
  the deal ("waiting") answers after the event and takes the phone back to 02. Riverpod
  does it; `myTable` also arms nothing from a dropped read. Tests: "a read of where it sits
  that was out when the event came".
- **`noup`** (fixed). A screen reached by a read whose socket starts listening after the
  server moved on missed the event (a read answers "the results", the host plays again
  before the game's socket is open). A socket's first opening now reads what its screen
  depends on, as a socket coming back does: `/me/table/`, and at 02 the lobby too. This is
  also what checks a seat taken from an event (the seat always opens a new socket).
  Tests: "an event said before a new screen's socket listened".
- **`leave`** (the review of `77968bc`, finding 2; fixed). Ben leaves at 02 (answered); the
  lobby's read again fails, so his own list still has him; the host deals and
  `game_started` seats him from that list, dropping the read that would have said "no
  table". The game refuses his `/me/` (403) and never opens its socket to him, and nothing
  asked `/me/table/` again. Now a refused `/me/` asks it (`FIX_403`). Tests:
  `where_asked_test.dart`, "a seat from an event is checked by the server".
- One request per heal (the review's finding 1) is not a rule here (the rules are about
  where the screen ends); `where_asked_test.dart` and `app_open_test.dart` pin it.
