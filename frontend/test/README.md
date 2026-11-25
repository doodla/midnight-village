# Frontend tests

`just test` runs `flutter test --dart-define=ENV=dev --exclude-tags e2e` (everything under `test/`). Two suites live
outside `test/` on purpose and are not part of `just test`: `test_e2e/` (the live-backend
harness, `just test-harness`) and `test_screens/` (the screen gallery and the cold-read pack,
`just screens`, `just playtest-pack`). Server payloads in tests: `helpers/contract/README.md`.

`--dart-define=SCREENS_HEIGHT=640` (default 844) draws the gallery on a shorter phone, a look at the small phone the sweep holds (`test_screens/screen_gallery.dart`).

## The e2e harness (`test_e2e/`)

- `just test-harness` runs the deterministic e2e harness in `test_e2e/` and boots (and stops) its own harness backend:
  on `HARNESS_PORT`, or a free port it picks, passed to the tests as `--dart-define=HARNESS_PORT` (`HarnessConfig.port`);
  it stops only the processes it started (their process group, a hard kill after 5 s), so runs in other worktrees go side by side.
  It clears `integration_test/screenshots/` first.
  The API runner replays all 29 reference games from `backend/tests/onuw/data/reference_games.json` through the choose API
  (every phone looks, then each phone with a choose left answers its prompt by `kind`, the day through `stagedAs` with locked votes) and asserts the debug-state
  oracle, including that no phone with nothing to choose sent a choose (the oracle's per-window `chosen`) and that every window closed by itself once the phones
  with a choice had chosen (no timer fired).
  `ui_roles_test.dart` deals reference games 1, 4, 5, 8 and 21 again and plays one phone
  (the Seer looking at a player, the Doppelganger copying the Robber and robbing on her follow-up, the Hunter keeping his card, the Insomniac, the Seer doing nothing)
  through the table's shell while the others make the game's choices through the API;
  it checks the cards at dawn, My night (the night's picture story, read while the note is held) and the outcome against the game.
  Per-phone PNG filmstrips go to `integration_test/screenshots/<scenario>/`;
  the phone helper is `harness/phone.dart`.
  `api_lifecycle_test.dart` (helpers `harness/live_table.dart`, `PlayerWire.connectLobby`) runs the table lifecycle through real sockets:
  play again, dropped phones (night and vote grace, `night_results`) and host handover;
  the oracle's `pending_timers` shows which timers are armed.
  Rules for harness tests: `DebugTableController.stagedAs` is strict (a refusal throws; `lenient: true` is for the toolbar), wall-clock checks use `TimeBox`,
  waits take explicit timeouts, and nothing is slept on.
  It is intentionally NOT under `test/` and NOT part of `just test`.
  Where a harness test asserts words, it reads them from the app's own copy (`NightCopy` templates, `board.prompt.kind.go`/`.pass`), never a typed copy of them;
  a literal stays only where the test means to pin that wording.
  GitHub runs the harness (the "End-to-end Harness" job in `.github/workflows/flutter-tests.yml`, the same `just test-harness`);
  the commit gate does not. Full docs: `docs/dev/debug-harness/`.
- The night is two windows (window 1 only with a Doppelganger in the deck):
  every phone with a choice sends one `choose` per window with the stage (doing nothing is picking "You" alone);
  a phone whose prompt is `none` sends nothing (`Phone.choose` sends only while `chooses_left` is above 0) and its board sleeps;
  the Doppelganger's look is read at once and her follow-up turn arms the same board.
- Shared test helper `MockHttpClient` lives in `integration_test/helpers/` (the web integration build cannot import out of its root); `test/helpers/mock_http_client.dart` re-exports it.
- Through the real widget tree against the harness backend:
  test_e2e/ui_game_test.dart: two games from the look stage through the night, the talk (My night held, ready on, off and on) and the vote (pick, lock), then 10
  and 11 as the oracle says the game went (`test_e2e/harness/end_of_game.dart`, shared with the end-of-game runner), each tap checked against the oracle
  (`ready`, `votes`, `vote_locked`). The end of the game, apart:
  test_e2e/ui_end_test.dart plays whole games through the API (the Hunter's chain, a tie, nobody dies with a card moved, the Tanner) and opens one phone at the
  results, checking what 10 and 11 say against the oracle (who was eliminated and why, the winning teams, that phone's outcome);
  after the host's Play again every phone opens at 02.
- The whole way on one phone: test_e2e/ui_journey_test.dart starts at 01 signed out ("Start a table"), follows 02 as three guests join through the API
  (the lobby's socket is live, `UiHarness.readLobby`), picks Classic on 03 and checks its cards against the server's `deck_preview`, deals from 02, lets every
  player play the game through the API (nothing forced) while the phone follows, checks 10 and 11 against the oracle and plays again back to 02.
  `UiHarness.followTable` and `readLobby` read `/me/table/` and the lobby again in the real zone
  (a read a pump started runs in the fake zone and never completes);
  `openShell` drops a game read a pump started.
- `/debug` route (dev-only, gated by const `Env.isDev` so it tree-shakes out of prod) — the debug toolbar:
  spin up a table, switch player perspectives, god panel, auto-drive everyone but the phone shown
  (ready, keep their card, vote someone, through `DebugTableController.stagedAs`; fire the pending timer), reset learned cues.
  Core lives in `lib/core/debug/`.

## The web integration test (`integration_test/auth_flow_test.dart`)

`just test-integration-ci` drives it in headless Chrome through `flutter drive`, with a
chromedriver of Chrome's own version on port 4444; CI installs both. Running it in the cloud
container: `docs/dev/environment.md`.

In a real browser some of the app's work answers in later tasks with no frame scheduled
(this device's token store is WebCrypto and browser storage), so `pumpAndSettle` can return
halfway through a tap's requests: after a tap, wait for what the step ends on with
`tester.pumpUntilFound(finder)` (`integration_test/helpers/navigation_helpers.dart`).

## The built web page (`just web-smoke`)

`tool/web_smoke/run.sh` builds the web app for release (no backend: it opens on 01) and `smoke.cjs` opens the built page in Chromium through Playwright, served
as Vercel serves it
(the routing and headers are `frontend/vercel.json` compiled by Vercel's own `@vercel/routing-utils` and walked in its order, `routes.cjs`: redirects, then files, then the rewrite, else a 404; `routes.test.cjs` judges that walk first, `node --test`, so the tests judge what Vercel will do, not a hand-read pattern; the package is installed in this job only, `just web-smoke-setup`; every file revalidated by default; the build is made with `BUILD_COMMIT=<40 a>` and each deploy gets its own commit file):
a first visit paints without waiting for the service worker and then registers it;
a return is served by it; a second copy of the build, told apart by a line at the end of `main.dart.js` and listed under a new worker version, served in the
first one's place (a deploy) runs on its first open and after;
a table's link (`/join/<code>`) opens the app, from the worker on a return, and on a first visit registers the whole site's worker (scope `/`);
a made-up picture and a made-up file with an extension are a 404, `/commit.txt` is the commit built and never kept, `/app` still redirects and app routes still
get the page; a tab left open on the old build (its worker registered) reloads itself for the new one when it is resumed, with one page load, and a deploy whose
shell is still the old build (a new commit file, old code) is reloaded for once and then left alone (no loop).
About a minute plus the build. Playwright comes from a node_modules folder beside `tool/web_smoke/smoke.cjs`
(`just web-smoke-setup` installs it there, as CI does) or from `NODE_PATH` (the cloud container's node tools).
CI job: "Web page smoke".

## Fonts in tests

`test/flutter_test_config.dart` also makes a picture that is not a file of the app, or whose bytes do not decode, fail the test that draws it
(`ArtPicture.debugBeforeDraw`, `debugOnError`; a test that feeds bad bytes on purpose clears them; `test/helpers/art_decoded.dart` loads the pictures on screen and says which painted a decoded image: `deck_art_test.dart` does it for 02 and 03 with no game).
It loads every family in the build's FontManifest (Gloock, Figtree and MaterialIcons) via `test/helpers/test_fonts.dart`, so widget tests, goldens and the
screen gallery draw real glyphs for those.
`Roboto` (Material's default, the debug toolbar's) is drawn in a Figtree stand-in, its four weights;
the app declares `Roboto` as Figtree's regular face too (`pubspec.yaml`), so the web build never fetches Roboto from fonts.gstatic.com, and no screen is drawn
in it. The e2e UI runners load the same fonts (`HarnessConfig.loadFonts`);
nothing is fetched.

## Goldens

One baseline set, in `test/design_system/goldens/`, made on Linux.
Golden-tagged tests are skipped on other OSes (`dart_test.yaml`):
font rasterisation differs per OS, and CI (Linux) is the source of truth.
Regenerate with `just flutter-golden-update` on Linux, or from the CI workflow (see `.github/workflows/flutter-tests.yml`).
Failure diffs go to `test/design_system/failures/` (gitignored).

## Screen gallery (`test_screens/`)

`just screens [width] [report|strict]` (also from the root) renders every screen in the catalogue from the real widgets, in the app's theme, with images
precached, to `build/screens/<id>.png` at 390x844 (2x), puts each next to its mock in `build/screens/compare/`, and prints a summary
(also in `build/screens/summary.txt`; the catalogue is rendered in four parts side by side, `test_screens/screens_run.dart`, one table per part, and `SCREENS_JOBS=1` renders one part at a time on a busy machine)
of the layout overflows and exceptions caught per screen, and on a player screen (`ScreenEntry.playerScreen`) every run of text drawn below the reading floor
(14 px to act, 12 px labels, as drawn after any shrinking to fit) or set as an uppercase tracked micro-label (`test_screens/reading_floor.dart`), and on every
screen any text drawn cut short (`test/helpers/truncated_text.dart`, the fit sweep's check: a name or label is set smaller or wraps, never ends in "...").
`just screens 360` renders 360 wide into `build/screens/w360/`;
`just screens 390 strict` exits non-zero on findings.
A screen whose builder throws is reported as BUILD FAILED and always fails the run, with no PNG.
It needs no backend and lives in `test_screens/`, outside `test/`, so `just test` never runs it (the same structural exclusion as `test_e2e/`);
`test_screens/flutter_test_config.dart` reuses the test config and pins the Werewolf's portrait to the lunge
(`ShellSetup.pinnedWerewolf`; so no portrait hides behind the pin, `03b-deck-role-werewolf-no-game` draws the sheet before any game and `06-night-board-lone-werewolf-<lunge|stare|snarl>` draws a game with each of the three)
and the card back to the moon
(`ShellSetup.pinnedCardBack`: a game's own back comes from its id, so the gallery would otherwise show whichever its fixtures' ids give; `--dart-define=SCREENS_CARD_BACK=eye`, a `CardBack` name, draws another),
and `screen_gallery_test.dart` there proves the detector on every run.
Every screen and state is one entry in `test_screens/screen_catalogue.dart`;
`table_fixtures.dart` (01 to 03b through the app's routes), `shell_fixtures.dart` and `end_fixtures.dart` (04 to 11 through the table's shell) reaches each
state through the server's own payloads and events (no state the server cannot produce).
A mock screen the app lacks, or cannot reach, is a `ScreenEntry.notBuilt` with the reason.
The catalogue ends with the component sheet (`c-<page>-<ground>`, from `test/helpers/component_sheet.dart`):
each mock rebuilt from the primitives next to its mock (08 and 09 are the app's own `TalkView` and `VoteView` on recorded `/me/` bodies), and the state pages
(buttons, players, gates, faces) on night, day and paper.
The sweeps test the look players get: the test pages (`BoardPage`, `TablePage`) take their dress from the screen's own view
(`NightBoard.defaultDress`, `AtTableView.defaultDress`), a variant asks for `Dress.plain` by name, and `test/helpers/sweep_dress_test.dart` fails a sweep that
renders in another dress.

**The screen sweep** (`test/screen_cases/`, `test/helpers/screen_sweep.dart`) holds every state of the catalogue (`test_screens/screen_catalogue.dart`) at three
phones and three text sizes, on one pumped tree.
Writing nothing gets every rule: nothing overflows, throws or is cut;
every player's name is whole and no piece of the kit drawn after it lies on its words
(`test/helpers/name_pieces.dart`: names from the samples and the kit's pieces, pieces by the kit's own types);
the phone's text size reaches the tree; the main action (the amber `PrimaryButton`, or the `SecondaryButton`s where a screen has none) is built, on the screen
without scrolling, under nothing, labelled, 48 to touch, and a finger's held press still reaches the detector it went down on.
The one opt-out is `SweepPlan.noMainAction(why)` for a state with no main action (a wait, a lock, a guest, a sheet).
A page that is a state at a larger text size (`textScale`) is drawn, not swept again;
rules about how a state opens are `SweepPlan.whenOpened`.
Every state is also held to the stage clock (`test/helpers/stage_clock.dart`, added by `sweep_run.dart`):
a game screen whose `/me/` carries a `deadline` draws a clock with its number (`WorldTimer`, `SquareSky` or `TimerBand`) on the screen, a night candle on no
card and no main button; `stage_clock_test.dart` places every timer the table sets (`Length`) as a stage clock or on the no-clock list, each with why
(the owner, 24 November 2026: 04 had a deadline and no clock).
Every state is held to what a frame costs too (`test/helpers/frame_cost.dart`, a guard file, added by `sweep_run.dart`):
painted once into a recording canvas (a `Still`'s inside is one picture there, as on a frame), it may fill no layer of its own (a `saveLayer`, an opacity,
a `ShaderMask`, a `BackdropFilter`, an image or colour filter) outside the named parts of `layerAllowed`, each with why, and no picture may be decoded more
than two eighths of its width larger than it is drawn, or drawn without `ArtImage.decodedFor` (`undecodedAllowed`: the nine-slice frames).
`test/screen_cases/not_yet_swept.dart` lists the states that fail today, each with its fault in one line (`--dart-define=SWEEP_ALL=true` prints them);
it only shrinks. A test presses with `pressLikeAFinger` (`test/helpers/finger.dart`):
down, six frames of 16 ms, up. A plain `tester.tap` on anything that takes a tap fails the test
(a gesture detector with a tap recogniser under the finger: a button, a card, a scrap, a row, the layer that takes a tap anywhere, a part made tomorrow; no list of names. A drag, a press written out with time on the glass, and a tap on what takes none are not held. The rule watches the pointer; nothing is hooked in `lib/`. `notYetHeld` in `finger.dart` is empty: every test file presses like a finger);
`plainTap(why:)` is the named to-do (a test or picture that counts frames from the tap).
The press lasts as long as a real one, so the test's own clocks run while the finger is down (the table's slow poll is 50 ms here, 15 s on a phone):
a fixture says what the server holds AFTER an action when that action reaches it (`http.answerEach`, `TableSetup.offTheTableOnceLeft`), never before the press,
and a test that counts the requests a tap makes counts from the lift (`pressLikeAFinger(beforeLift:)`).
`raw_values_test.dart` compares screen code with the merge base with origin/main, all files together (a moved value is not new);
with no merge base it fails on GitHub and skips, saying so, on a machine.

### Loading and error states (issue 10)

Every place the app waits and every request that can fail has a picture in the catalogue:
the opening (first frame with no sign yet, the lanterns, "Still on its way.", "One moment" with "Try again", the seat not yet known), 01's Start and Join busy
and failing (`01-join-starting`, `-joining`, `-join-not-sent`, `-start-not-sent`, `-no-table`, `-full`, `-playing`), and in an Android browser
(`01-join-android-web`, `-android-web-fresh`, `-android-web-keyboard`, `-android-web-x2`: the quiet "Get the app" on the "at tables" row; `TableSetup.pump(androidWeb: true)`, the one seam `appDownloadProvider`),
02 waiting, offline, dealing, deal and leave failing, leaving, 04, 08 and 09 waiting (and 04's and 08's wait failing), 10 and 11 loading, the game offline over
06, 08 and 09, "Not sent." on 04 and 09, and 11's Play again busy, Leave busy, failing and refused.
An entry's `frames` is how many 100 ms frames are drawn before the picture (1 for a first frame).
02's and 03's waiting pictures show what the held files draw today.

`just loading-clips [folder]` (`test_screens/loading_clips_test.dart`, `tool/loading_clips.py`) draws four scenes of the real app frame by frame on the test's
clock and makes a looping WebP of each, 390 wide and under 1.2 MB (it lowers the quality until it is):
a tap going busy then done (Start a table), a join that takes seven seconds, a failed send and its retry (Play again), a reconnect in a game.

The scanner (`01b-scan`, `-found`, `-refused`) is drawn with `FakeCodeScanner` (`test/helpers/fake_code_scanner.dart`):
a camera a test drives (`see(text)`), that remembers whether it was started, stopped and ended, with `FakeCameraFrame`, a picture of a table with a code on it,
for the picture. `TableSetup.pump(scanner:)` gives the app one;
the default is a fake, so no test reaches the camera plugin.
It has no mock beside it: the mocks have no scanner.

## The type scale guard (`test/design_system/skin/`)

The scale is the owner's choice of 23 November 2026 (`docs/design/type-audit.md`).
`skin_contract_test.dart` holds every role to its cap
(names at most 16, questions 24, headings 20, body 14 to 15, buttons 15, labels 12, timers and your role as they were: a mock's bigger number is converted at the cap),
and `type_guard_test.dart` fails any `fontSize:`, `fontWeight:`, `fontFamily:`, `fontStyle:` or `TextStyle(` in `lib/` outside `design_system/skin/` and
`features/debug/`, except the named fits in its allow-list (a role made smaller to fit its room).
A new size is a role in `shadow_paper.dart` with a cap, never a number in a widget.

## Scenes in motion (`test_screens/scene_frames_test.dart`)

`just scene-frames [folder] [label]`
(add `--dart-define=SCENE_FRAMES_STEP_MS=17` to the `flutter test` line for one frame every 17 ms, as real speed for an animation; no strip then) pumps the
table shell through the dusk (the deal to the night) and the dawn (the night to the talk) at 390x844 (2x), eight frames evenly from the first frame to
`Motion.scene`, one PNG each and a strip of them side by side, into `<folder>/dusk` and `<folder>/dawn` (default `build/scene_frames`), named
`<label>-NN-<ms>ms.png` (default label `after`).
The clock is the test's, so the frames are the same every run;
the pictures are loaded for real before the first frame is drawn.
Run it on a shell that crossfades (any earlier commit) with another label for the "before".
Unit tests: `test/design_system/primitives/scene_switcher_test.dart`
(the switcher: runs and finishes, no fade over a screen, no frame a blend of the two screens or with a pixel no widget painted (read from the drawn frame, `test/helpers/frame_pixels.dart`), a touch mid-scene lands on the new screen, a scene cutting a crossfade short pops nothing, reduce motion cuts, every other change crossfades)
and `test/features/game/presentation/scene_shell_test.dart`
(the same through the real shell: no gap in any frame, the primary button on show by 60% of the scene, and the table answering before `/me/` for both scenes).
The layered headers (04's village, 08's dawn; `docs/design/art/layers/`) are held by `test/design_system/skin/layered_scene_test.dart`
(the description is consistent, no layer shows its own edge where a scene starts it, 04 travels no further than its art was cut for, and drawn at rest the layers are the flat picture they were cut from, `flat.jpg`, compared in blocks of 4 x 4 pixels, 08's baked sun left out; a layer comes in from its `from` and rests where it belongs),
the dusk's moon in `scene_shell_test.dart` (lowered after the sheet is down: still moving against the plate when the sheet is within 2 px of rest) and the
talk's own frame having no sun, then the one sun (same file), and the picture-size check in `skin_contract_test.dart`
(every layer in the bundle at its declared size, none undeclared).
Mid-scene goldens are not kept: a golden needs the art loaded, and the test clock never waits for image I/O;
the frames above are the record.

`just night-frames [folder] [label]` (`test_screens/night_frames_test.dart`) films the night board's small moments at 390x844 (2x), one PNG per 17 ms step into
`<folder>/<label>/pick` (a finger on Cleo for 170 ms, the pick lifting with its glow while the button rises, a hold, then a tap taking it back) and
`<folder>/<label>/candle` (a 30 s window, one frame per second, from whole to a stub);
defaults `build/night_frames` and `run`.
The test binding paints a blurred shadow as a solid block, so the gallery (`screen_gallery.dart`) and this film switch `debugDisableShadows` off while they
draw: the pictures show the real glow.

`just vote-frames [folder] [label] [width]` (`test_screens/vote_frames_test.dart`) films the vote at six players, one with a long name
(360 wide by default, 2x), one PNG per 17 ms step into `<folder>/<label>/vote`:
the frame it opens, a finger on Cleo for 85 ms, the pick, then the lock tap and the seal landing (`lock-down`, `lock`, then `choosing` and `locked`);
defaults `build/vote_frames`, `run`. `just vote-pictures [folder] [width]` (`test_screens/vote_pictures_test.dart`) saves the locked vote, the moment of the
lock as four frames, and the vote at 3, 4, 6 and 10 players, a long name and large text (`just contact-sheet <folder>` for one sheet).
`test/features/game/presentation/vote_feel_test.dart` holds the same moments as assertions
(the press, the pick, the lock and the words' contrast of 4.5:1 on every frame of it, the seal staying inside its token at rest and clear of the name on every frame at each row size, a refused lock giving the rows back, the rows' growth cap, the names measured once per width and text size, reduce motion, ten long names, the vibrations and none for a declined tap);
`test/design_system/feel/haptics_only_here_test.dart` fails any `HapticFeedback` call outside `Haptics`.

`just end-pictures [folder]` (`test_screens/end_pictures_test.dart`) saves the end board at 360 x 780, 2x, the mocks' size:
every outcome (1a to 1h, ten players at the top and opened where the hanged are, a tie, the Doppelganger), then a 360 x 640 phone and text at 1.3 and 1.6, two
outcomes each. `just contact-sheet <folder>` makes one sheet.

`just end-reveal-frames [folder] [width]` (`test_screens/end_reveal_frames_test.dart`) saves the end board's reveal at its moments
(start, the hanged big, the stamp, the banner, a second death's stamp, the winners risen when nobody hangs, the rows turning, settled; each PNG named with its time)
for one hanged, nobody hanged, the Hunter, ten players and a tie, and films the one-hanged reveal a frame every 33 ms and the Hunter's and nobody-hanged ones
too, into `<folder>/film/<case>/`; the same moments are pages of `just screens` (`test_screens/end_reveal_pages.dart`, `12-end-reveal-*`).
Defaults `build/end_reveal` and 390.

`just end-link-pictures [folder]` (`test_screens/end_link_pictures_test.dart`) draws every step of a few recorded nights, done, at 360, 390 and 412 wide
(`END_LINKS_GAME`, `END_LINKS_SCALE`, `END_LINKS_SHORT` pick one game, a text size, the 640-high phone), one PNG a step, to look at every link at full size.

`just end-night-frames [folder] [width]` (`test_screens/end_night_frames_test.dart`) films What happened on the six-player game (`results`), stepped through at
a player's pace (each step played and read 1.5 s before the next tap, then back to the result), a frame every 66 ms into `<folder>/film/`;
its moments are pages of `just screens`
(`test_screens/end_night_pages.dart`, `12-end-night-*`: the deal, each kind of step, a swap mid-move, back to the result, the Doppelganger's game, ten players, text 1.6).
Defaults `build/end_night` and 360.

`just card-frames [folder] [label]` (`test_screens/card_turn_frames_test.dart`) films your card (04) at 390x844 (2x), one PNG per 17 ms step into
`<folder>/<label>`: the finger landing, the hold's 120 ms, the turn to the face, the face, the turn back and rest;
running the test with `--dart-define=CARD_FRAMES_STILL=true` films it under reduce motion;
defaults `build/card_frames` and `run`.

`tool/scene_web_check.sh [outdir]` is the browser check:
it builds `test_screens/scene_demo_main.dart` (a standalone web entry hosting the two scenes on the real primitives and art; keys d, n, w, r), serves it twice
(the card's hold ring still, and breathing as in a first game, `--dart-define=RING=true`; both scenes are the layered headers, since the demo is built from the real primitives),
and drives it in headless Chrome with Playwright at 1x and 4x CPU throttle, printing the `requestAnimationFrame` deltas of each scene beside the crossfade, the
slow frames of each of the six runs (the browser's run-to-run spread is about 1.5 slow frames, so compare with a run of an earlier commit made the same day),
and the card at rest with the hold ring breathing over its layered village (`tool/scene_web_measure.js`).
The demo warms the layers up as the shell does (`SceneSwitcher.precacheHeader`).
Headless Chrome in the cloud container has no GPU, so the numbers compare the scenes with the crossfade and are not a phone's frame rate.


## An open app renewing itself (`lib/core/update/`)

`test/core/update/new_build_test.dart` (fake clock, fake fetch and reload, no sleeps) holds the rule table `mayReloadNow`, when a newer build is acted on
(first screen at once; at the table and in a game never at a screen or phase change or on the timer, only when the tab comes back after more than 5 s hidden; never with a request out, an unsent tap or typed text; a worker that cannot be updated leaves the app running and the next look retries),
the loop guard, how often it looks, and what smells of a stale build (`StalePageInterceptor`).
`test/core/update/worker_renewal_test.dart`
(a fake registration that can only update and wait: a failed or never-finishing update gives up with nothing let go of) and
`test/features/new_build_holds_test.dart`
(01's typed name or code and the open scanner hold the reload, 01's draft survives it in the tab's storage, the loop guard is per tab) hold the rest.
`test/features/new_build_restore_test.dart` opens the whole app with a seat at a waiting table, in the night, the talk, the vote and the count, learns of a
newer build, sees the reload at its moment and opens the app again cold:
the same seat, the same screen, no second reload;
a shell that stays old is not reloaded again.
`test/design_system/asset_release_test.dart` fails when a file of the last release
(the bundle at the main branch (origin/main) when git has it, else `tool/release_assets.json`; `just record-assets` refuses while one is uncovered, tested in `.claude/guardrails/tests/test_release_assets.py`)
is gone from the bundle and is neither an `ArtSet.retired` copy nor listed in `removedOnPurpose` with a date.

- **Paper rules** (`test/design_system/primitives/`):
  `paper_rules_test.dart` (one light, separation, locked, material, and every sheet a paper screen opens), `paper_components_test.dart`
  (no stroke on any paper screen or sheet, the registry on built widgets, the README table row by row, tap targets measured on the screens),
  `paper_consistency_test.dart` (red by hue, one locked form, chips, name tags) and `paint_cache_test.dart` (what repaints while the night board animates).
