# Models of ordering and concurrency

> These models predate the protocol-1 cleanup (20 November 2026):
> they speak of "protocol 2", the contract's "Third amendment" (now `docs/specs/onuw/api-contract-v2.md`, sections 5 and 9), `ProtocolTwoGameNotifier`
> (now `LiveGameNotifier`), the server module night2 (now `backend/apps/onuw/choose_night.py`) and sample names ending in `_v2` (now plain names);
> the one flow they model is the only one left.

Logic whose bugs live in the order of events (the server's stage handling, the phone's
outbox and fetch loop) is checked with small TLA+ models, one focused slice at a time.
Tests check the paths someone thought of; a model checker walks every interleaving of
requests, answers, lost messages, timers and restarts inside a small bound.

## When

- A change to how the server orders, locks, retries or closes a stage (`backend/apps/onuw/choose_night.py`,
  `protocol.py`, `services` timer and presence paths, `backend/apps/core/timers.py`).
- A change to how the phone sends taps or re-reads state (`Outbox`, the protocol-2 game
  notifier, `frontend/lib/core/healing`).
- A review finds an ordering bug: model the slice to find its siblings before fixing it.

## How

1. Write the model from the code, not from the spec: one module per slice, its header
   naming the files and commit it was modelled from. Every `await` or transaction boundary
   is a point where any other step may happen.
2. Check it with TLC (`tla2tools.jar`, not in the repository) through the statechart skill
   (pstack), which also turns TLC's counterexamples into a chart and a plain-words report
   (`view.mjs` names the states and arrows).
3. Keep the bound small (two faults, one restart, two or three taps) and add a `FIX_*`
   constant per proposed fix, so the same model shows the bug and the fix.
4. Every finding becomes a real test that replays the path against the real code (backend:
   a pytest; phone: a widget/notifier test from recorded samples). The model is the search;
   the test is the guard.
5. Keep the model here with a README: what it models, what it leaves out, what it found and
   the commit that fixed it.
6. A rule the code breaks today and that nobody is fixing yet is a KNOWN gap: its run is a
   `known_<name>.cfg` that the run script expects to break (so a clean run means nothing
   changed), and the README gives its shortest trace in plain words.

## Models

| Folder | Slice | Found | Fixed in |
|---|---|---|---|
| `night2/` | Server: a whole protocol-2 game, three phones | A resent Doppelganger look read as her follow-up | `fb229fb` |
| `phone/` | One phone: the night board and the talk-to-next-game lanes | F1-F6 (stuck fetches, turn read from `kind`, results never loaded, lost play again) | `303f1df` |
| `docs/dev/models/phone/seat` | One phone between tables and games: events that seat it, `/me/table/` reads, the lobby's player list, leaving, sockets opening, drops, sleep, resume | A deal missed while the socket was down healed only on the poll; a late `game_started` put the phone back in a game it was past; an event sent before a new screen's socket listened was missed; a seat built from a stale player list stranded a phone that had left | `start-lands-fast` |
| `docs/dev/models/phone/seat`, `docs/dev/models/phone/day` (`FIX_ASKLESS`) | The phone told its own view as a stage opens: no read at a stage change, the seat moved from `/me/`, the poll only while the socket is down | A seat put from `/me/` dropped a seat read out that knew of play again, stranding the phone on the end board (`seat_drop`); a socket that dies open (it looks up, hears nothing) strands the screen for good (`zombie`, `day_zombie`; fixed by the server's beat, `FIX_BEAT`); a frame lost on a socket that stays alive does too (`lost`, `day_lost`; fixed by the table's token on the beat, `FIX_TOKEN`) | `ask-less` |
| `docs/dev/models/phone/lobby` | The host's phone in the lobby: the settings lane, reads, socket, "Not sent." and "Try again", the deal | A read crossing an answer flicks a setting back; a new tap hides "Not sent."; a lost deal takes the one "Try again"; still open: a late request overtakes (#16), a refused value kept by a failed read | gaps a, b, b2, c: branch `lobby-lane-gaps` |
