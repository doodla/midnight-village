# Models of ordering and concurrency

> These models predate the protocol-1 cleanup (20 November 2026): they speak of "protocol 2", the contract's "Third amendment" (now `docs/specs/onuw/api-contract-v2.md`, sections 5 and 9), `ProtocolTwoGameNotifier` (now `LiveGameNotifier`), the server module night2 (now `apps/onuw/choose_night.py`) and sample names ending in `_v2` (now plain names); the one flow they model is the only one left.

Logic whose bugs live in the order of events (the server's stage handling, the phone's
outbox and fetch loop) is checked with small TLA+ models, one focused slice at a time.
Tests check the paths someone thought of; a model checker walks every interleaving of
requests, answers, lost messages, timers and restarts inside a small bound.

## When

- A change to how the server orders, locks, retries or closes a stage (`apps/onuw/choose_night.py`,
  `protocol.py`, `services` timer and presence paths, `apps/core/timers.py`).
- A change to how the phone sends taps or re-reads state (`Outbox`, the protocol-2 game
  notifier, `core/healing/`).
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

## Models

| Folder | Slice | Found | Fixed in |
|---|---|---|---|
| `night2/` | Server: a whole protocol-2 game, three phones | A resent Doppelganger look read as her follow-up | `fb229fb` |
| `phone/` | One phone: the night board and the talk-to-next-game lanes | F1-F6 (stuck fetches, turn read from `kind`, results never loaded, lost play again) | `303f1df` |
