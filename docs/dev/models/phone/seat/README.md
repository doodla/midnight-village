# Where the phone sits: a TLA+ slice (`PhoneSeat.tla`)

One guest phone from 02 through a game, play again and the next deal, written from branch
`start-lands-fast` (on `e48d802`). It models what moves the screen between tables and
games: the events (`game_started` on the lobby socket, `game_results` and `play_again` on
the game's); `/me/table/` reads, all asked through `askWhere` (a plain ask replaces the
read out; a judged ask, the lobby's, waits for the read out and asks again only if its
answer is still "waiting"); the lobby's reads and the phone's own player list (a read
again can fail, leaving the list behind); the game's `/me/`, refused to a phone that is not
a player; the phone leaving; a socket that opens (not listened to until it is up; a game's
never opens for a phone that is not a player), drops and comes back; the phone asleep; the
app coming back. The slow poll is left out: every heal must come from the phone's own reads.
The table is a version: 0 waiting, 1 game 1, 2 its results, 3 waiting again, 4 game 2;
`NoTable` once the phone has left.

Left out: the stages inside a game (the day model's, `../day/`: here a game behind the
server heals by its deadline, `GameHeals`), the host's taps (the answers seat the phone as
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

`runseat.sh` runs all six in about half a minute on this machine (`seat`: 207,781 distinct
states, none left on the queue).

## Runs (`TLA2TOOLS=/path/to/tla2tools.jar ./runseat.sh`)

| Run | Constants | Ends |
|---|---|---|
| `seat` | the phone of this branch | holds both rules |
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
