# Where the phone sits: a TLA+ slice (`PhoneSeat.tla`)

One guest phone from 02 through a game, play again and the next deal, written from branch
`start-lands-fast` (on `e48d802`). It models what moves the screen between tables and
games: the events (`game_started` on the lobby socket, `game_results` and `play_again` on
the game's), `/me/table/` reads (a read still out when a newer one is asked for is
dropped: Riverpod keeps only the newest build's answer), the lobby's reads, the game's
`/me/`, a socket that opens, drops and comes back, the phone asleep, the app coming back,
and the slow poll. The table is a version: 0 waiting, 1 game 1, 2 its results, 3 waiting
again, 4 game 2.

Left out: the stages inside a game (the day model's, `../day/`: here a game behind the
server heals by its deadline, `GameHeals`), the host's taps (the answers seat the phone as
the events do), a second table.

## Rules

- `NeverBack`: the screen never goes back to a table older than one it showed.
- `Converges`: the screen ends where the server is.

## Runs (`runseat.sh`; `TLA2TOOLS=/path/to/tla2tools.jar ./runseat.sh`)

| Run | Constants | Ends |
|---|---|---|
| `seat` | the phone of this branch (the slow poll on, sockets take time to open) | holds both |
| `late` | without `FIX_LATE` | breaks `NeverBack` (a finding, fixed) |
| `stale` | without `DROP_STALE` | breaks `NeverBack` (why the seed relies on it) |
| `known_open` | the branch, no slow poll, sockets take time to open | breaks `Converges`: KNOWN gap |

## What it found

- **`late`** (fixed in this branch: `LobbyNotifier._applyStartedGame` does nothing when the
  table the phone holds already names that game). A `game_started` that reaches the phone
  after a read has already taken it past that game (the phone woke at 02 after play again,
  the event still in its socket) would put it back in the old game's night. Shortest trace:
  deal, end, play again with the event still on its way; a resume reads "waiting again";
  then the old event lands. Test: `table_moves_on_test.dart`, "a late game_started".
- **`stale`**: a seat from an event must drop a read already out. Without it, a read served
  before the deal ("waiting") answers after the event and takes the phone back to 02. The
  app gets this from Riverpod (an invalidated provider ignores its older build's answer);
  `myTable` also arms nothing from a read that was dropped (a dropped read used to arm a
  15 s poll that was never cancelled). Tests: `table_moves_on_test.dart`, "a read of where
  it sits that was out when the event came", for the deal and for play again.
- On `e48d802` (all fixes off, no slow poll) a `game_started` missed at 02 while the socket
  was down is never healed: the reconnect read only the lobby, which said "in a game", and
  nothing looked further. The app's guard is `table_moves_on_test.dart` (the socket down
  across the deal, the phone asleep across it, a lobby update): each waited for the 15 s
  poll on `e48d802` and heals in one read now.

## KNOWN gap: `known_open`

A screen reached by a read whose socket starts listening after the server has moved on
waits for the slow poll: a read answers "the results" (or "waiting"), the host plays again
(or deals) before that answer reaches the phone and before the new screen's socket is open
(about 0.6 s on the live server), so the event goes to a socket that is not listening yet.
`FIX_UP` is the proposed fix, not built: a socket's first opening reads what was said
before it listened (02: its lobby again, whose rule reads the table if it moved on; a
game: `/me/table/` once), one more read per screen opened. The window is a fraction of a
second; the 15 s poll heals it.
