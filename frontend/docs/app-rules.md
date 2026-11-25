# The app's rules, in full

The long form of the rules that `frontend/CLAUDE.md` states in a line each, one sentence per
line so two branches that add to different rules do not collide. `CLAUDE.md` is what every
session reads; this page is for when you are about to touch the thing a rule is about.

## Requests: every tap's request goes through `playerRequest`

- **Every request a player's tap makes goes through `playerRequest`** (`core/requests/player_request.dart`), and the control that was tapped shows it:
  `Pending` (`design_system/primitives/pending.dart`) is busy in the frame of the tap, cannot be sent twice, stays busy until the screen it leads to is up
  (`settle`), and settles to done or to its own words with its own "Try again" (the very same request).
- The door is a compile-time rule: every write (the services' write methods, `AuthenticatedClient`'s post, patch and delete, the guest account) takes a `Door`,
  and only `playerRequest((door) => ...)` makes one, so a write outside it does not build;
  a door is shut when its request is done (a kept token throws in development and tests, is logged in release).
  `player_request_test.dart` scans for a bare `ref.read(p.future)` of a provider nobody holds
  (use `whileHeld`: a read that is dropped when the screen changes failed requests that had worked).
- A control that waits for the next screen is freed when that read fails (`readAnswered`), and says "One moment" with "Try again".
- A failure is the control's: never global state that can show up later on another screen.
- Nothing here waits.
- **A tap's request leaves the phone in the tap's own task** (owner, 24 November 2026: "Every tap was delayed and took a second to respond"; measured,
  0.4 to 1.6 s from the finger to the request on a slowed phone): the session's tokens are held in memory (`TokenStorage`: storage is read once at start and
  written through on every change), so signing a request reads no storage, and `AuthenticatedClient` and `ApiClient` send through `inThisTask`
  (`core/api/in_this_task.dart`: Dio's own steps of no length run as microtasks, not as browser tasks the app's frames can come between).
  `tap_leaves_now_test.dart` presses 08's "Ready to vote" with a storage that never answers after start and fails unless the request has reached the
  HTTP client before any time passes or any frame is drawn. A second tab shares the saved session as before: its writes are read back (`storage` event).

## Waits: every place the app waits is `Waiting`

- **Every place the app waits is `Waiting`** (`design_system/primitives/waiting_sign.dart`) in the frame of the screen it waits for
  (`OpeningWait`, `lib/features/game/presentation/shell/waits.dart`, `EndWaiting`):
  never a bare ground.
- No sign for the first 300 ms (`Motion.signAfter`), then three paper lanterns hung from the header's edge and lit one after another (`PaperLantern`), "Still on
  its way." after 5 s (`Motion.slowAfter`), and, while a fetch fails, "One moment" with "Try again" alone on one line (never lanterns and a failure together);
  nothing is held back for it.
- A failure is one quiet line on the control (`Notice`), never a box; a busy control sinks into its shadow with a small lantern (`BusyMark`) in its own padding, so its words never move.

## Main buttons: a screen's main action never sits silently disabled

- **A screen's main action never sits silently disabled**
  (owner, 23 November 2026: a dimmed "Deal to 5" and no word of why; widened after the review of the fix).
  `PrimaryButton` and `SecondaryButton` take no `onPressed` of null:
  a button that cannot act yet is `.locked(onLockedTap:)`
  (a tap leads to the fix and is nudged: 01's "Start a table", "Join a table" and "Join" with no name take the cursor to the name field and shake it, `Nudge`)
  or `.waiting(reason:)` (only while a change of this phone's is on its way), or it says what to do in its own label and does it:
  the table's button reads "Add 1 card" / "Remove 2 cards" (opens 03), "Need 3 players" / "Need {n} more" (shares the table's link), else "Start the game".
- The reasons come players first, then the deck, the server's current `need`.
- A page that can be left into a state where the game cannot start is not left by accident:
  03's "Done" is always "Done", but with the wrong number of cards the first "Done" or Back stays, scrolls the count ("14 of 12 · Remove 2 cards") into view and
  nudges it, and the second leaves (never trapped: the table's code is on 02).
  `main_button_rule_test.dart` scans `lib/` for a bare disabled main button.
- A new main button brings its state and its test.

## The dress: one look, two dresses

- **One look, two dresses**: a screen is plain (today's look, exactly) unless it asks `ScreenFrame(dress: Dress.paper)`;
  shared parts read `context.dress`/`context.skin` and draw the paper, torn edges, pins, banners, the amber piece and mood only there;
  a paper component takes its look from the one table `skin/dress_style.dart` (`PaperPiece`), draws NO stroke, outline or border
  (`paper_components_test.dart` fails one), and is listed in the inventory with both dresses (`skin/dress_inventory.dart`);
  a screen never builds a raw Material button, chip, divider or border;
  sizes, angles and colours are the skin's (`skin.parts`, `skin.mood`), never a number in a screen (`lib/design_system/README.md`, "The dress").
