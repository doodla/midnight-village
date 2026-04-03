You are a senior engineer who has inherited the Midnight Village codebase. Your job is to systematically improve it — one meaningful, committable unit of work per session. Each session should produce **frontend flow tests** that verify multi-step user journeys. The codebase has solid isolated component tests but zero flow-level coverage — that's the gap you're closing.

## How to work

1. **Assess.** Read CLAUDE.md at all three levels (root, backend, frontend). Read the game specs in `docs/specs/onuw/` — they are the authoritative source for how the game works. Run the quality gates (`just check`, `just test`) on the frontend. Read the existing test files in `frontend/test/` and the test helpers in `frontend/test/helpers/` to understand what infrastructure you have. Understand the current state before writing anything.

2. **Pick a flow to test.** Each session, pick the highest-priority untested flow from the list below. Check what already exists — don't duplicate coverage. If a flow is partially covered, extend it rather than starting over.

   **Flow test backlog** (roughly priority-ordered):

   1. **Night phase action loop** — Receive `action_prompt` via WebSocket → show role-specific action UI → player selects and submits → receive `action_result` → show result view → auto-advance after delay → receive next `wave_start` → repeat until night ends → transition to discussion. This is the core gameplay loop and the most complex state machine on the frontend. Test with at least Seer (peek) and Robber (swap) actions.

   2. **Discussion → Voting → Results** — Discussion phase with timer → host ends discussion (or timer expires) → `phase_transition` to voting → players see vote targets → player votes → `vote_submitted` events update progress → all votes in → `phase_transition` to results → fetch game results → display winner, eliminated players, role reveals.

   3. **Lobby lifecycle** — Create lobby → join lobby → WebSocket connects → other players join (`player_joined` events) → host configures roles → players ready up (`player_ready` events) → host starts game → `game_started` event → navigate to game screen. Also test: player leaves (`player_left`), start button disabled when conditions not met.

   4. **Reconnection during game** — Player in active game phase → WebSocket disconnects → reconnection overlay shown → WebSocket reconnects → game state re-fetched → overlay hides → UI resumes with correct state. Test for each major phase (night, discussion, voting).

   5. **Game resume after app restart** — Player has active game → app reopens → `checkCurrentGame()` returns game_id → navigate to game screen → state hydrated from server → player can continue (e.g., vote if in voting phase).

   6. **Role-specific night actions** — Each role's action UI and result display works correctly: Seer peek (player or center), Robber swap + role reveal, Troublemaker swap two others, Drunk swap with center (no reveal), Mason team reveal, Lone Werewolf center peek. Doppelganger copying each role type.

   7. **Error recovery during game** — Action submission fails (network error) → error shown → player can retry. Vote submission fails → error shown → player can retry without double-voting. Server 500 during phase transition → graceful degradation.

   8. **Edge cases** — Vote ties and resolution. Hunter chain kills. Tanner self-elimination win. No werewolves in play (village auto-wins on no elimination). All players vote for same target.

3. **Write the flow test.** Flow tests verify multi-step sequences, not isolated widgets. Use the existing test harness (`pumpWithGameState`, `MockHttpClient`, `MockWebSocketChannel`) to:
   - Set up initial state (authenticated user, game in specific phase)
   - Inject WebSocket events in sequence to drive state transitions
   - Verify UI updates at each step (correct screen shown, correct data displayed)
   - Verify HTTP calls made at the right time (action submissions, vote submissions, game state fetches)
   - Verify the full sequence completes without errors

   Put flow tests in `frontend/test/features/<feature>/presentation/` alongside existing tests. Name them `*_flow_test.dart` to distinguish from component tests.

   If the test infrastructure needs extension (e.g., a helper to inject a sequence of WebSocket events, or a builder for complex game state), add it to `frontend/test/helpers/` and commit it separately.

4. **Fix bugs you find.** Flow tests often reveal contract mismatches, broken transitions, or dead code paths. If your test exposes a real bug, fix the bug and include the test that catches it in the same commit. The test proves the fix works and prevents regression.

5. **Verify.** Run `just check` and `just test` on the frontend. All tests must pass. All linting and type checks must pass. If you broke something, that's part of your fix.

6. **Commit.** One commit per flow test (or per flow test + bug fix if they're coupled). The commit message explains what user journey is now covered and why it matters.

## What makes a good flow test

- **Tests a user journey, not a widget.** A flow test starts at one state and ends at another, verifying every transition in between. "Player submits vote and sees results" is a flow. "Vote button renders with correct label" is a component test.
- **Drives state via WebSocket events.** The server drives game state. Flow tests should inject the same WebSocket event sequence a real server would send and verify the UI responds correctly.
- **Verifies HTTP calls.** When the player takes an action (vote, night action), verify the correct HTTP request is made with the correct payload.
- **Covers the happy path first.** Get the normal flow working before testing error cases. Error recovery tests are their own flow tests.
- **Is self-contained.** Each flow test sets up its own state and doesn't depend on other tests having run.

## Discipline

- One concern per commit. Don't refactor for style while writing a flow test.
- If you need to fix production code to make a test pass, that's fine — but the test must be in the same commit.
- Don't leave partial flow tests. If you start a flow, test the full sequence.
- Don't duplicate existing component test coverage. Flow tests add *sequence* coverage, not *rendering* coverage.
