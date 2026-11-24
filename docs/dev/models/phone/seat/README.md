# Where the phone sits: a TLA+ slice (`PhoneSeat.tla`)

One guest phone from 02 through a game, play again and the next deal, written from branch
`start-lands-fast` (on `e48d802`). It models what moves the screen between tables and
games: the events (`game_started` on the lobby socket, `game_results` and `play_again` on
the game's), `/me/table/` reads (a read still out when a newer one is asked for is
dropped: Riverpod keeps only the newest build's answer), the lobby's reads, the game's
`/me/`, a socket that opens (not listened to until it is up), drops and comes back, the
phone asleep, the app coming back, and the slow poll. The table is a version: 0 waiting,
1 game 1, 2 its results, 3 waiting again, 4 game 2.

Left out: the stages inside a game (the day model's, `../day/`: here a game behind the
server heals by its deadline, `GameHeals`), the host's taps (the answers seat the phone as
the events do), a second table.

## Rules

- `NeverBack`: the screen never goes back to a table older than one it showed.
- `Converges`: the screen ends where the server is. Every run here has the slow poll
  off (`POLL = FALSE`): a miss must heal by the phone's own reads, never by waiting 15 s.

## Bounds, and why they keep the rules meaningful

- Two games (versions 0 to 4): the fewest that hold a deal, the results, play again and a
  second deal, so a late or missed event of the first game can meet the second.
- At most two socket drops and two app resumes or sleeps in a run (`MaxDrops`,
  `MaxResumes`): a miss before and after play again. Every finding below needs one.
- Reads are not counted. A `/me/table/` read is either the newest asked for or not
  (`cur`); with `DROP_STALE` an older read can change nothing, so it is let go at once.
  The first version numbered every read, and the number made the state space unbounded
  in practice (the `seat` run passed 9 million states without ending). Only "newest or
  not" decides what the app does with an answer (Riverpod applies the newest build's
  alone), so nothing the rules can see is lost; with `DROP_STALE` off the older reads are
  kept, marked, and still break `NeverBack` (`stale`).
- The event channel holds at most the three events a run can send; the lobby and `/me/`
  reads are one slot each, as in the app (a read asked for while one is out shares it).

`runseat.sh` runs all five in about 20 seconds on this machine (`seat`: 79,896 distinct
states, no state left on the queue).

## Runs (`TLA2TOOLS=/path/to/tla2tools.jar ./runseat.sh`)

| Run | Constants | Ends |
|---|---|---|
| `seat` | the phone of this branch | holds both rules |
| `late` | without `FIX_LATE` | breaks `NeverBack` (finding, fixed) |
| `stale` | without `DROP_STALE` | breaks `NeverBack` (why the seed relies on it) |
| `noup` | without `FIX_UP` | breaks `Converges` (finding, fixed) |
| `today` | `e48d802`: no fix | breaks `Converges` (the owner's slow start) |

## What it found

- **`today`**: on `e48d802` a `game_started` lost while the lobby socket was down is never
  healed but by the poll: the reconnect read only the lobby, which said "in a game", and
  nothing looked further. Fixed by `FIX_HEAL` (`LobbyNotifier._askWhereIfMoved`, the
  reconnect and the resume reading `/me/table/`). Tests: `table_moves_on_test.dart`, the
  socket down across the deal, the phone asleep across it, a lobby update.
- **`late`** (fixed: `LobbyNotifier._applyStartedGame` does nothing when the table the
  phone holds already names that game). A `game_started` that reaches the phone after a
  read has taken it past that game (it woke at 02 after play again, the event still in its
  socket) put it back in the old game's night. Test: "a late game_started".
- **`stale`**: a seat from an event must drop a read already out. Without it, a read served
  before the deal ("waiting") answers after the event and takes the phone back to 02. The
  app gets this from Riverpod; `myTable` also arms nothing from a dropped read (one used to
  arm a 15 s poll nobody cancelled). Tests: "a read of where it sits that was out when the
  event came", for the deal and for play again.
- **`noup`** (fixed: `FIX_UP`). A screen reached by a read whose socket starts listening
  after the server has moved on missed the event: a read answers "the results", the host
  plays again before this phone's game socket is open (about 0.6 s on the live server), and
  `play_again` goes to nobody. The same at 02 with a deal. A socket opening now reads what
  the screen depends on, as a socket coming back does: the game's first "connected" heals
  like a reconnect (`LiveGameNotifier._wasDisconnected` starts true), and 02 reads its
  lobby once more when its socket is first up (`_readWhenUp`, now for every lobby but a
  table its host just opened), whose rule reads `/me/table/` if the table moved on. Tests:
  "a deal while 02's socket is still opening", "play again before the end board's socket
  is open".
