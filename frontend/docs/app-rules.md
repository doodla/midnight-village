# The app's rules, in full

The long form of the rules that `frontend/CLAUDE.md` states in a line each, one sentence per
line so two branches that add to different rules do not collide. `CLAUDE.md` is what every
session reads; this page is for when you are about to touch the thing a rule is about.
Each rule is in bold, whole: `just brief` quotes every bold phrase here to the screen and
design-system builders, so a rule that is not bold is not quoted.

## Requests: every tap's request goes through `playerRequest`

- **Every request a player's tap makes goes through `playerRequest`** (`frontend/lib/core/requests/player_request.dart`), and the control that was tapped shows it:
  `Pending` (`frontend/lib/design_system/primitives/pending.dart`) is busy in the frame of the tap, cannot be sent twice, stays busy until the screen it leads to is up
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
  (`frontend/lib/core/api/in_this_task.dart`: Dio's own steps of no length run as microtasks, not as browser tasks the app's frames can come between).
  `tap_leaves_now_test.dart` presses 08's "Ready to vote" with a storage that never answers after start and fails unless the request has reached the
  HTTP client before any time passes or any frame is drawn. A second tab shares the saved session as before: its writes are read back (`storage` event).

## Waits: every place the app waits is `Waiting`

- **Every place the app waits is `Waiting`** (`frontend/lib/design_system/primitives/waiting_sign.dart`) in the frame of the screen it waits for
  (`OpeningWait`, `frontend/lib/features/game/presentation/shell/waits.dart`, `EndWaiting`):
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
  `main_button_rule_test.dart` scans `frontend/lib` for a bare disabled main button.
- A new main button brings its state and its test.

## The dress: one look, two dresses

- **One look, two dresses: a screen is plain unless it asks `ScreenFrame(dress: Dress.paper)`; sizes, angles and colours are the skin's, never a number in a screen.**
  Plain is today's look, exactly; shared parts read `context.dress`/`context.skin` and draw the paper, torn edges, pins, banners, the amber piece and mood only there;
  a paper component takes its look from the one table `frontend/lib/design_system/skin/dress_style.dart` (`PaperPiece`),
  **a paper component draws no stroke, outline or border** (paper_components_test.dart fails one),
  and is listed in the inventory with both dresses (`frontend/lib/design_system/skin/dress_inventory.dart`);
  **a screen never builds a raw Material button, chip, divider or border**;
  the skin's values are `skin.parts` and `skin.mood` (`frontend/lib/design_system/README.md`, "The dress").

## An app left open

- **The app renews itself for a new build** (`frontend/lib/core/update`, the rule `mayReloadNow` in
  `frontend/lib/features/game/domain/reload_rule.dart`, `docs/dev/deploy-vercel.md`): it knows its commit
  (`BUILD_COMMIT`), reads `/commit.txt`, and reloads at a safe moment through the cold opening, so
  a seated player lands in their seat. Only on 01 at once; at the table and in a running game it
  never reloads on a screen change, a phase change or the timer, only when the tab comes back after
  a while away (owner, 24 November 2026: "Reload only when nobody waits"). It updates the service worker and waits
  for it to take over before reloading; it never deletes the worker or its caches. Nothing is
  shown. A build with no commit (local, tests, the
  installed app) never looks. A new place that shows a screen or starts a request must not break
  the rule: a screen is an `AppScreen` or one of `HomeGate`'s names, a write goes through
  `playerRequest`.
- **A file removed or renamed in `frontend/assets` needs a retired copy or a dated reason**: it fails `asset_release_test.dart` (compared with the
  bundle at the main branch (origin/main), else `frontend/tool/release_assets.json`) until it is an `ArtSet.retired` copy or
  a dated `removedOnPurpose` line in `frontend/tool/release_assets.json`; `just record-assets` refuses
  while one is uncovered, so regenerating cannot hide a removal.
- **A tool that needs the built web app asks for it**: `out=$(tool/web_build_cached.sh <flutter build web arguments>)`,
  never its own `flutter build web`: the build is made again only when what goes into it changed (a minute, else a blink).
- **vercel.json is judged as Vercel compiles it**: `frontend/tool/web_smoke/routes.test.cjs` (run by
  `just web-smoke`, which needs `@vercel/routing-utils` from `just web-smoke-setup`), never by
  reading a `source` as a plain pattern.

## The other rules in full

The rules `frontend/CLAUDE.md` gives in one line, whole.

- **Taps change what others can see at once, never on the response.** All taps go
  through the one `Outbox`; a choose is never sent twice for a turn; a taken choose's answer
  carries the results (the board opens one by itself, once), and `/me/` is re-read only when a turn follows. A phone with nothing to
  choose sends no choose at all; its board has no button.
- **Words: every player-facing string is in `frontend/lib/design_system/copy`, none in widgets; a spec names a copy class or key, never the words.**
  The library is `copy.dart`, one part file per screen's words (`vote_copy.dart`, `table_copy.dart`, ...);
  read them all on one page with `just copy-page` at the repo root; `just check` fails a key name that does not exist;
  `copy_budget_test.dart` holds them to the spec's copy rules.
  **A change that adds words says why in its pull request** (`tool/words_added.py`: no screen has a pinned number of words).
- **Reading floor: body and names 14 px, small labels 12 px, 7:1 contrast on player screens, full ink for anything that says something true.**
  **No uppercase micro-labels.**
  **One amber fill per screen; a selection is lift plus outline, never amber.**
  The owner's type choice, 23 November 2026 (`docs/design/type-audit.md`); 08's "Ready to vote" is its one amber fill, the owner's choice of the same day.
- One look, two dresses, in full: "The dress" above, and `frontend/lib/design_system/README.md`.
- **Values from the skin: build screens from `frontend/lib/design_system/primitives`, read `context.skin`, `context.ground`, `Space`, `Motion`; no literals.**
  **A text size, weight or face is a type role, never a number in a widget** (`type_guard_test.dart` fails it);
  **no `SkinId` checks in layout code**. One look, Shadow paper; a new look is a whole design, not a recolour.
- **Secrets are held, not tapped (`HoldToReveal`, `HeldFace`); nothing vibrates on a card** (owner, 23 November 2026).
  Art for secrets is precached at start so a reveal fetches nothing.
  "My night" on 08 is held too, and shows on the board, from its top, only while held.
- **Information a player asks for opens as a sheet from the bottom edge** (`showSkinSheet`),
  the same place whatever was tapped, closed by its button, the scrim or Back; never a popover
  at the touch point, and opened from a context under the screen's `ScreenFrame` (asserted), so it is dressed and lit as its screen is
  (`frontend/lib/design_system/README.md`, "Where information a player asks for appears").
