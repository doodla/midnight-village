# Back, loading and speed audit (read-only), 21 November 2026

Branch `ccr-2435dc07-33z3jn` at 121c67c (= main). Nothing in the repo was changed. Evidence:
code reading, a prod-mode web build (`ENV=prod`, pointed at a local harness backend on
127.0.0.1:8741, built into this scratch folder), Playwright on the local Chromium pressing
Back / Forward / Reload and slowing or cutting the server per phone, and outside-only timing
of the live web app and API. Screenshots: shots/ beside this file (`M-*.png` are
left-to-right timelines). Scripts: `scripts/`.

Shorthand: S = scratch folder
(the session scratch folder, not kept).

## How navigation is built (the root cause of most of Part 1)

- Three routes only (`lib/core/router/routes.dart`): `/` and `/join/:code` (both `HomeGate`),
  `/game/:gameId` (`TableShell`). Every screen 01 to 11, the deck page, "My night" open, the
  held card, the vote pick are children swapped inside ONE route by `TableShell`
  (`table_shell.dart:96-199`) from server state. Nothing pushes a route; the app's own
  navigations are three `context.go('/')` calls in `join_screen.dart:58,66`.
- So the Navigator always holds exactly one page, plus a modal sheet when one is open
  (`showSkinSheet`: role sheet 03b, role sheet on 08, host's Leave confirm).
- The only back handling in the app: `PopScope(canPop: false)` on 03 Deck
  (`deck_screen.dart:101-106`) which closes the deck. No `BackButtonListener`, no other
  `PopScope`, nothing at the shell.
- Browser history, measured (`history.length` and URL after each step): a fresh visit holds
  ONE app entry for the whole session (lobby, deal, night, talk, vote, results), because
  nothing changes the URL. After any reload while a game runs, the router's async redirect
  (`app_router.dart:60-77`, `/` -> `/game/<id>` after a `GET /onuw/me/current-game/`)
  PUSHES `/#/game/<id>`, so history gets a second entry that leads back to `/`, which
  redirects forward again.
- Android: no `PopScope` at the root, so system back on the single page finishes the
  activity (Android 11 and older: the engine is destroyed, coming back is a cold start with
  a token refresh and four reads; Android 12+: the task goes to the background, state kept
  unless the OS kills it). No intent filter for `https://.../join/...` in
  `AndroidManifest.xml`: a QR scan on an APK phone opens the WEB app in the browser (a second,
  separate guest identity on that phone). Predictive back is not opted in
  (`enableOnBackInvokedCallback` absent); with Flutter 3.38 that only changes the animation.

## Part 1: BACK, what happens today

**Status, 22 November 2026: fixed (branch `fix-back-policy`).** Checked again on a prod web
build at f078d38 before the fix: Back on 02 and on 04 left the site, as below. One claim no
longer held: since c192441 the router does not redirect to `/game/<id>` after a reload, so
after a reload Back also left the site (not "nothing"); the root cause (one page, nothing
handling Back but the deck) was right. The fix is one policy for every Back
(`frontend/lib/core/router/back_policy.dart`; `frontend/lib/features/game/README.md`,
"Back"): the browser's history is held to the engine's single entry over the page the app
came from, so the browser's Back reaches the same policy as Android's, and nothing adds a
history entry (a reload, a link, a change of screen). Now: a sheet closes first; 01 leaves
(its code field open: closes it first); 02 asks with "Stay" / "Leave" (host and guest); 03
returns to 02; 08 puts My night away first; 04 to 11 do nothing; the opening waits leave;
"You're at another table." goes there. A sheet closes when its screen changes. On the web,
leaving never uses the engine's exit (in a fresh tab it took the app's history down and Back
died): the app steps back past its entry, which does nothing in a fresh tab. Not changed
here: a held card's face, 11's folded night (Back does nothing there, as on 11), the link
joiner's leftover `#/join/<code>` after Leave (rule 7). Known limit: two browser Backs fired
in the same instant (one script task) step past the app's one entry; presses 20 ms or more
apart do not.

Legend: **fine** / **closes app** / **leaves silently** (out of the table or game screen with
no question; the seat is kept on the server) / **wrong screen** / **blank** / **loses tap or
state** / **nothing** / **unknown**. "Web back (fresh)" = no reload since the page was
opened; "web back (after reload)" = a reload happened mid-game. Measured cells are marked (m).

| Screen / overlay | Android system back | Web back (fresh) | Web back (after reload) | Web forward | Web reload | Deep link `#/join/CODE` mid-game |
|---|---|---|---|---|---|---|
| 01 Join, empty | closes app (fine) | leaves site (fine) (m) | n/a | full reload of 01 | fine | stranger: name + amber Join; tap -> "That table is playing now." and Join stays amber (m) |
| 01 code field open | closes app (should close the field first) | leaves site; typed code lost | n/a | full reload, code lost | code lost | same |
| 01 arrived by link | closes app | leaves site (m) | n/a | full reload | fine (m) | n/a |
| 01 "Working" (Start/Join in flight) | closes app; the request completes on the server, seat taken while the phone is gone | leaves site, same | n/a | full reload, shows the table (fine) | same | n/a |
| 02 Table, guest | **closes app** | **leaves site** (about:blank in the test) (m) shots/02guest-back.png | n/a | returns via a full reload, then fine (m) | fine (m) | seated player: the table (fine) |
| 02 Table, host | **closes app** | **leaves site** (m) shots/02host-back.png | n/a | full reload (m) | fine | fine |
| 02 host's Leave confirm (sheet) | closes the sheet (fine) | **leaves site, sheet and all** (m) shots/02leavesheet-back.png | n/a | full reload, sheet gone | sheet gone (fine) | n/a |
| 03 Deck | closes the deck, back to 02 (fine, the one `PopScope`) | **leaves site** (m) shots/03deck-back.png | n/a | full reload lands on **02** | lands on 02; an unsaved grid edit is lost (by design) (m) | n/a |
| 03b role sheet | closes sheet (fine) | leaves site | n/a | full reload | sheet gone | n/a |
| 04 Your card | **closes app** | **leaves site** (m) shots/04B-back.png | **nothing** (back -> `/` -> redirect -> same screen; forward also nothing) (m) | full reload | **wrong screen first**: "The village sleeps" for a moment, then 04 (m) shots/04B-reload-1500ms.png | seated: the game (m) |
| 04 card held (finger down) | closes app (rare) | leaves site | nothing | - | card hidden again (fine) | - |
| Night board 06 (and 05) | **closes app** | **leaves site** | nothing (m) | full reload | fine; local picks lost (spec accepts) (m) shots/g06B-reload-1500ms.png | seated: the game |
| Night board, a card held | closes app | leaves site | nothing | - | hidden (fine) | - |
| 08 Talk | **closes app** | **leaves site** | nothing (m) | full reload | fine (m) | seated: the game (m) |
| 08 My night open (first frame after night) | **closes app** (should put it away) | leaves site | nothing | - | opens closed (ack already sent; fine by spec) | - |
| 08 role sheet | closes sheet (fine) | leaves site | **unknown**: probably the sheet stays (the redirect rebuilds nothing) | - | sheet gone | - |
| 09 Vote, picked | **closes app** | **leaves site** | nothing | full reload | pick kept (server) (m) shots/g09B-picked-reload-1500ms.png; 0.3 s blank day ground shots/g09B-picked-reload-300ms.png | seated: the game |
| 09 Vote, locked | closes app | leaves site | nothing (m) | - | locked kept (fine) | - |
| 10 The count | closes app | leaves site | back -> `/`; the redirect finds no current game in results, URL stays `/`, same screen (m) | back to `/game/<id>` (m) | fine (m) | seated: the count (m) |
| 11 Results (night open/folded) | closes app; fold state lost on return if killed | leaves site | as 10 (m) | as 10 | lands on 11 (kept on the device, fine) | seated: 11 |
| "One moment" banner (any screen) | closes app | leaves site | nothing | - | restarts the wait | - |
| 01 "Not sent." after a failed restore | closes app | leaves site | - | - | tries again (the only way it heals) | - |
| After Leave, a player who joined by LINK | - | - | - | - | URL is still `#/join/CODE`: 01 shows only an amber "Join" for the table just left, plus a stale "Not sent." + "Try again" that would re-join it; no Start, no other code (m) shots/r5-link-guest-after-leave.png | - |

Notes on cells:
- "leaves site" in the test lands on `about:blank`; on a phone it is the previous site, the
  camera app (QR scan), or the browser closes the tab. Coming back by Forward or the link is a
  full restart of the app (white page, then four reads, see Part 3). The seat is kept on the
  server, so the player is not out of the game, but nothing told them and getting back costs
  seconds of blank screen.
- Android "closes app": the player is still seated; on Android 12+ coming back is usually
  instant, on 11 and older or after the OS reclaims memory it is a cold start (blank night
  ground for every request, Part 2).
- Two different web behaviours for the same screen depending on whether a reload happened
  is itself a bug: history must not depend on the past.

### What SHOULD happen (rules a non-engineer would agree with)

1. Back closes whatever is open on top first: a sheet, the deck page, the code field,
   My night open, a held card's page, the night on 11 if it is unfolded.
2. With nothing open, back never drops you out of a table or a game by accident. In a game:
   nothing happens (or one quiet hint the first time). At a waiting table: it asks, like the
   host's Leave ("Stay" / "Leave"), or does nothing.
3. Back from 01 with nothing open leaves the app (it is the start).
4. Reload, a killed app, or opening the table's link always returns you to exactly where
   the game is, never to 01 while you still have a seat, and never through a screen that
   says something untrue ("The village sleeps" before your card).
5. Browser history never fills with game steps, and behaves the same with or without a
   reload: one entry for the app.
6. A link opened mid-game shows the right thing: your own table if you sit at it; for a
   stranger, the table's name and "Playing now", Join only when it can work.
7. Leaving puts you on a clean 01 (both ways in), with no leftover banner.

### Every place that breaks them

| Rule | Where | What |
|---|---|---|
| 1 | `talk_screen.dart:53-55` (`_open`), `results_screen.dart:192` (`_open`), `join_screen.dart:186` (`_codeOpen`), `hold_to_reveal.dart` (OverlayPortal, not a route) | in-screen "open" states have no back handler: Android back closes the app |
| 1 | web, every sheet (`sheet_scaffold.dart:12`) | browser back does not close a sheet: it leaves the page |
| 2 | no root `PopScope` (`table_shell.dart`, `app.dart`) | Android back on 02 and 04 to 11 closes the app |
| 2 | web: no history entry to absorb back (`routes.dart`, no URL change) | browser back on any screen leaves the site |
| 4 | `table_shell.dart:181-185` + `screen_table.dart:149-153` | reload or cold start during 04 shows 05 "The village sleeps" until `/me/` answers (seconds on a cold server) |
| 4 | `auth_notifier.dart:57-79`, `join_screen.dart:69-79` | restore failure (no network, server cold past 10 s, 5xx) shows 01 with "Not sent." and never heals by itself (m shots/M-s6-reload-down.png); typing the name and tapping Join/Start then makes a NEW account (`join_flow.dart:134-141`) and the seat is lost for good |
| 4 | spec "Storage was wiped mid-game": "You left this game." + "Go home" | `BannerCopy.leftGame` exists, never used |
| 5 | `app_router.dart:60-77` | the redirect pushes `/game/<id>` after a reload: history differs, back becomes "nothing" |
| 6 | `join_screen.dart:254-261` | stranger mid-game: amber Join that can only be refused; after refusal Join stays amber beside the banner |
| 6 | `AndroidManifest.xml` | no app link: APK players scanning the QR land in the browser as a new guest |
| 7 | `join_screen.dart:58` (`context.go('/')` skipped when the screen is already unmounted) and `home_gate.dart:38-46` | a link-joined player keeps `#/join/CODE`; after Leave only "Join" of that table is offered (m) |
| 7 | `join_flow.dart` (keepAlive banner state) | a stale "Not sent." + "Try again" (re-join!) shows after Leave (m); cause not proven, likely `_run` failing on `await ref.read(myTableProvider.future)` while the shell invalidates it |

## Part 2: LOADING, what a player sees

Measured with every API request delayed (Playwright route) by 4 to 6 s ("cold server"),
14 s (past the 10 s HTTP timeout) or refused ("down"). WebSockets were not slowed. HTTP
timeouts: `connectTimeout` 10 s and `receiveTimeout` 10 s on both clients
(`api_client.dart:15-16`, `authenticated_client.dart:20-21`); no overall request deadline,
no retry inside a tap.

| Wait | 0 s | 0.3 s | 2 s | 10 s | On failure | Class |
|---|---|---|---|---|---|---|
| Web first paint (no Flutter yet) | white page | white | white (local), ~1.5 to 3 s on the live site | - | white forever if JS fails | blank, undesigned (`web/index.html` has no splash; manifest background `#0175C2` blue; title "midnight_village", description "A new Flutter project.") shots/00-firstpaint-300ms.png |
| Android launch | white (`launch_background.xml`, light theme) | white | Flutter | - | - | blank, undesigned |
| App start, signed in (token refresh, `auth_notifier.dart:57`) | night ground, nothing | same | same | same until 10 s timeout | 01 with "Not sent." + "Try again", never heals (m) | blank, then wrong screen |
| Router redirect (`/onuw/me/current-game/`, awaited in `redirect`) | keeps previous frame (blank) | blank | blank | blank | stays on `/` (harmless) | blank |
| `/me/table/` (first, `where_am_i_provider.dart:20`) | night ground, nothing (`table_shell.dart:203`) | same | same | "One moment" after the first failure (10 s) | retried forever | blank, then "One moment" |
| 01 art (street door) | form on empty night ground | same | art pops in (2 to 4 s locally) shots/00-firstpaint-2000ms.png | - | - | pop-in |
| Guest account + start table ("Start a table") | all three buttons dim: looks exactly like "no name typed" (m) shots/01-start-150ms.png | same | same | same (3 requests in a row: 14 s at 6 s each) shots/s1-start-14000ms.png | "Not sent." + "Try again" | nothing visibly happens (Start is a `SecondaryButton`: no busy state) |
| Join by code / link | "Join" with a spinner (m) | spinner | spinner | spinner 20 s at 5 s per request shots/M-s2-joinlink.png | "Not sent." / the refusal | spinner with no words (acceptable for 2 s, not for 20) |
| After sitting down: 02 lobby read | night ground, nothing (`at_table_screen.dart:154-168`) | same | same | "One moment" only once the read fails | retried | blank (m shots/s1-start-20000ms.png, `-26000ms`) |
| 02 portraits | rows with empty circles, portraits pop in (m) shots/03deck-reload-1500ms.png | | | | | pop-in |
| Settings change (chip, pace, custom deck) | chip selected at once (good) | deck preview turns into face-down cards until the answer (m) shots/M-s3-chip.png | same | - | taken back + "Not sent." + "Try again" | instant feedback, placeholder designed-ish |
| Deal | amber button with a small spinner (good) (m) | same | same | after the answer the button is idle and tappable again until `/me/table/` lands (m shots/s4-deal-6000ms.png), then 05 "The village sleeps" until `/me/` (m) shots/M-s4-deal.png | "Not sent." / refusal words | busy then re-tappable gap, then wrong screen |
| Entering the game: first `/me/` | 05 "The village sleeps" + empty candle (`night_screen.dart:24-29`) | same | same | same; no "One moment" unless the socket is ALSO down (`table_shell.dart:107-110`) | retried with backoff, still no banner | wrong screen (it is the card look) |
| `/me/` on every stage change | old screen stays, clock running, buttons live (m) `s9-to-count-slow` 0 to 4 s | same | then day/night ground, nothing (`table_shell.dart:191-193`, m 8 s) | count at 12 s | HTTP down + socket up: the OLD stage stays for 20 s+ with no banner (m) shots/s8-to-vote-httpdown-10000ms.png | stale, then blank |
| Choose (night) | "Chosen" on the tap (outbox) | | | | "Not sent." + "Try again" on the board | good |
| Ready (04), Ready to vote (08) | "Ready ✓", count +1 at once (m) shots/M-s7-ready-slow.png | | | at 10 s the tap is taken back and "Not sent." + "Try again" (m) | | good, but a 10 s timeout silently undoes a tap the server may have taken |
| Vote pick / lock | lift + outline / "Locked" at once (m) | | | | "Not sent." + "Try again" | good |
| Results read (10/11) | 10: day ground, nothing; 11: night ground, nothing (`count_screen.dart:66-78`) | | | | "One moment" while failing | blank |
| Play again / Edit deck (host, 11) | spinner on "Play again" (also when Edit deck was tapped) | | | buttons idle again before 02 arrives (gap: `results_screen.dart:85-87`) | "Not sent." + "Try again" | busy, then re-tappable gap |
| Leave (guest 02, guest 11) | the word dims, no spinner | | | idle again before 01 arrives (`at_table_screen.dart:148-150`) | "Not sent." + "Try again" | nothing visibly happens |
| Live channel reconnect | nothing (by design) | | | | "One moment" only if fetches fail too | ok, but HTTP failures with the socket up show nothing |
| Server cold start | nothing anywhere says the server is waking; the 10 s timeout turns a slow wake into "Not sent." or the 01 restore failure | | | | | missing |

### Gallery: loading and error states that exist vs missing

Exist (`test_screens/screen_catalogue.dart`): `05-night-loading`, `08-talk-not-sent`,
`10-count-waiting`, `01-join-closed`, `01-join-link-elsewhere`, `02-table-handover`.
(Rendered: `frontend/build/screens/` after `just screens 390 report` in this audit: 136 rendered, 0 findings.) Looked at: `10-count-waiting.png` is a bare lavender page with "One moment" in a box at the foot, nothing else: the one designed waiting state reads as a blank page, not as the game; `05-night-loading.png` is the sleeping village and candle, deliberate-looking but it is the night's words, used today for non-night waits (04).

NO gallery entry (nobody has looked at them): web first paint / Android launch; app start
blank (`AuthInitial`); the shell's `_Nothing` on night and on day ground; the "One moment"
banner over any screen (`_OfflineBanner`); 01 Start "working"; 01 Join "working"; 01
restore failed ("Not sent." with an empty name); 01 "No table with that code." / full /
playing now; 02 waiting (`_Waiting`) and its offline form; 02 dealing; 02 not sent; 02
leaving; 02 table closed + "Go home"; 03 waiting / offline / not sent; 06 "Not sent." on the
board; 09 not sent; 11 waiting; 11 busy; 11 failed; reload into 04 via 05.

### Rules (proposed)

1. Every tap answers within 100 ms on the thing tapped (pressed look, then busy or done).
2. A tapped button is busy and cannot be tapped again until the screen it leads to is up
   (not just until the HTTP answer).
3. After about 1 s of waiting, a calm designed waiting state appears that says what is
   happening in two or three words ("Finding your table", "Dealing", "Waking the village");
   before 1 s, the screen you are leaving stays.
4. Nothing is ever a bare ground with nothing on it, and never a screen that says something
   untrue (05 for a card look).
5. A slow server is named once, plainly, after ~3 s ("The village is waking up"); no
   10 s timeout turns slowness into failure: reads keep waiting and heal, taps keep their
   look until the server says otherwise.
6. Every wait can be left (Leave or back), and every failure heals by itself; a banner
   button is a shortcut, never the only way out.
7. The first screen paints in the look within 300 ms on the web and Android (designed
   splash in `index.html` and the launch theme), and the art for the current screen loads
   before the secrets' art.

Breaks: every row classed blank / nothing / wrong / re-tappable gap above; specifically
`table_shell.dart:203` (`_Nothing`), `at_table_screen.dart:154`, `deck_screen.dart:88-97`,
`count_screen.dart:66` (`EndWaiting`), `home_gate.dart:35-38,47-50`, `night_screen.dart:24`
(05 while loading), `join_screen.dart:295-301` (Start without busy), `results_screen.dart:85`,
`at_table_screen.dart:131-150`, `auth_notifier.dart:57-79` (restore does not heal),
`table_shell.dart:107-110` (offline only with the socket down), the 10 s timeouts, `web/index.html`,
`android/app/src/main/res/drawable*/launch_background.xml`, `main.dart:24` (art precache
unprioritised).

## Part 3: SPEED (measured from outside only; no account tools used)

Live app: `https://midnight-village-app-anthelion.vercel.app` (static, Vercel CDN).
API it calls (from the shipped `main.dart.js`): `https://midnight-village-anthelion.vercel.app/api`.
Every API answer carries `x-vercel-id: iad1::iad1::...`: edge AND function in Washington
(iad1). My vantage point egresses close to iad1, so these are best-case network numbers; a
player in Europe adds ~0.1 s per request, in South Asia ~0.25 s per request.
Throwaway data created: 2 guest accounts ("Perf probe") and 3 tables, each table left at once.

### Web download (what comes before the first paint)

| File | Raw | On the wire | Cache |
|---|---|---|---|
| `index.html` | 1.2 KB | br | `max-age=0, must-revalidate` (x-vercel-cache HIT) |
| `flutter_bootstrap.js` | 4 KB | br | same |
| `main.dart.js` | 3.02 MB | 0.91 MB br | same (no hashed names; the Flutter service worker serves repeats) |
| `canvaskit.js` + `chromium/canvaskit.wasm` (www.gstatic.com, a second origin) | ~ | 0.02 + 1.63 MB br | `max-age=31536000` |
| fonts: Gloock + 4 Figtree weights + MaterialIcons (subset) | 264 KB | br | via service worker |
| Roboto from fonts.gstatic.com (a THIRD origin; Material's default, something still asks for it) | 64 KB | woff2 | long |
| `AssetManifest.bin.json`, `FontManifest.json` | 5 KB | | |
| art: 30 webp, all precached at start (`main.dart:24`), 768x1024 scenes, 576x768 portraits | 1.36 MB | webp | via service worker |

Renderer: CanvasKit (dart2js, `flutter build web --release`, no `--wasm`, default PWA
service worker; `frontend/tool/vercel_build.sh:18`).

### Time to a usable Join screen (Playwright, fresh browser each "first")

| Profile | First visit | Repeat visit (reload) |
|---|---|---|
| Desktop-fast link near iad1 | Flutter view ~1.5 s, Join usable 3.05 s | 0.47 s |
| Phone profile: 9 Mbit/s, 150 ms RTT, CPU x4 slower (2 runs) | Flutter view 3.8 / 4.2 s, Join usable 5.45 / 5.81 s | 1.82 / 1.75 s |

Waterfall of the fast first visit (ms): HTML 17-456; bootstrap 451-526; **gap 526-1460
(the loader waits for the service worker to install before loading the app, up to 4 s:
`prepareServiceWorker`)**; main.dart.js and canvaskit in parallel 1460-1991; fonts
1745-1880, Roboto 1748-2118; AssetManifest 2226-3050 (probably CPU, not network); then the
first API call (`/api/stats/online/`, 3049-3701) and the 30 art files (3080-3398), each art
file shows twice in the log (service worker plus page; unconfirmed). Until ~1.5 s the page is
WHITE (no splash in `index.html`); then the empty night ground; the 01 picture pops in last.

### API (curl from outside, seconds, ttfb = total here)

| Request | Warm (3 runs) | Cold (first after 9 min idle) | Cold (after 15 min) |
|---|---|---|---|
| first request of a burst (token refresh / stats) | 0.20 to 0.58 | **1.59** (token refresh) | **1.22** (token refresh) |
| `GET stats/online/` | 0.17 to 0.42 (cached 15 s at the edge) | 0.25 | |
| `POST auth/guest/` | 0.23 to 0.47 | not measured (no third account) | |
| `GET onuw/me/current-game/` | 0.18 to 0.23 | 0.25 | |
| `GET me/table/` | 0.20 to 0.44 | 0.44 | |
| `POST lobbies/` (start a table) | 0.25 | 0.25 | |
| `GET lobbies/<code>/` | 0.20 | 0.48 | |
| `PATCH lobbies/<code>/` (settings) | 0.25 to 0.27 | 0.25 | |
| `POST lobbies/<code>/leave/` | 0.24 | 0.24 | |

So: a warm request costs ~0.2 to 0.45 s even from next door; the hosting's wake-up adds
~1.0 to 1.4 s to the first request after idle (function cold start plus the database waking;
which of the two cannot be told from outside). Headers show no cold-start marker; only
`x-vercel-cache` (MISS on the API, HIT on `stats` within 15 s).

### Requests in a row, from the code

| Moment | In sequence today | Could be |
|---|---|---|
| Open, signed in, mid-game | token refresh (`auth_repository.dart:43`, ALWAYS, even with a valid access token) -> `current-game` (awaited inside the router redirect, `app_router.dart:62`) -> `me/table/` -> `games/<id>/me/` (-> `results/` on 10/11) = **4 to 5 round trips** after the app has booted | 1: use the stored access token (the interceptor already refreshes on 401); drop the redirect's `current-game` (`me/table/` names the game); fetch `/me/` for the last known game in parallel with `me/table/` = **1 to 2** |
| Open, signed in, waiting table | refresh -> current-game -> me/table -> lobby (+ socket) = 4 | 1 to 2 |
| Start a table | guest -> (auth change re-runs the redirect: current-game, in parallel) -> `POST lobbies/` -> `me/table/` -> `lobbies/<code>/` = 4 | guest -> `POST lobbies/` (its answer IS the lobby) = 2 |
| Join | guest -> join -> me/table -> lobby = 4 | 2 |
| Deal | start -> (event) -> me/table -> `/me/` = 3 | start -> `/me/` of the returned game id = 2 |
| Stage change | event -> `/me/` (sometimes also me/table) = 1 to 2 | 1 |

What blocks first paint in `main()` (`main.dart:16-24`): `restoreLearned()` and
`restoreLocalSteps()` (local storage, a few ms); art precache is NOT awaited (good) but runs
at the same time as the 01 picture, so the picture can come late. The network waits come
after the first frame as blank grounds (Part 2).

Server work that is slow by design (from the code and docs, not measured inside):
- `DB_CONN_MAX_AGE` default 0 (`config/settings/vercel.py`): every request opens a new TLS
  connection to Postgres (pooled endpoint): typically 20 to 100 ms in-region, more if the
  database is not in iad1 (region not visible from outside).
- `GET /me/` runs `ensure_timers` and a timer `sweep` on every call (`apps/onuw/views.py:291-294`).
- A `choose` is 14 queries (21 for a Doppelganger's first) (`apps/onuw/README.md:47`).
- **CORS preflights (web only, measured).** The app (`midnight-village-app-...`) and the API
  (`midnight-village-...`) are different origins, and every API call carries
  `Authorization`/JSON, so the browser first sends an `OPTIONS` request to each new URL and
  waits for it (live: 0.42 s, it runs Django too). `access-control-max-age: 86400` caches it
  per URL only (Chrome caps it at 2 h), so `/games/<new id>/me/`, `/lobbies/<new code>/` and
  everything in a fresh browser pay it again: in the local runs, 136 OPTIONS for 572 real
  requests. A first open is therefore up to 8 to 10 round trips, not 4 to 5.
- Presence: a DB write per socket every 15 s plus a timer row per 40 s (`deploy-vercel.md`).

### Where the owner's 3 to 4 seconds go (repeat visit, phone, warm server)

| Part | Time | Whose |
|---|---|---|
| Boot the app from cache (service worker, compile 3 MB of JS, CanvasKit) | ~1.0 s to the first frame, ~1.8 s to a usable Join | ours (build choices) |
| 4 requests in a row before the game screen (refresh, current-game, me/table, me) at ~0.3 s server + phone RTT each, plus a CORS preflight before each one the browser has not cached | ~1.5 to 2.5 s (up to ~4 s with preflights) | ours (sequence) + hosting (per-request cost) |
| Hosting asleep (first request after a few minutes) | +1.3 s (measured), more on a bad day | hosting |
| First visit only: download ~2.6 MB compressed + service-worker wait | +3.5 to 4 s (5.5 s total measured on the phone profile) | ours |

All of it shows as a white page, then an empty night ground: nothing says what is happening.

### Fixes, ranked (expected gain, who)

**Status, 22 November 2026: 3, 5 and 6 done (branch `speed-requests-sw-fonts`).** Measured
on one machine, a release web build served locally as Vercel serves it (revalidated, no
long cache) against a local backend, Playwright, 5 runs, medians; "phone" = 9 Mbit/s,
150 ms, CPU x4. Fix 3: an answer that says where the player sits is `/me/table/`'s next
value (`SeatSeed`): Start 4 requests in a row to 2 (phone: tap to 02 3.1 s to 2.4 s), Join
4 to 2 (4.7 s to 2.8 s), the Deal start + `/me/table/` + `/me/` to start + `/me/`, for the host and a guest: the
game's `/me/` leaves while 02 is still up and the seat is taken from it when it lands (a
first version changed the screen at once: its frame came 0.9 s sooner on the phone, but
the heavy first frames of 04 ran before `/me/` left and the card's data came 0.4 s later;
taken out). The card's data now arrives as before (phone 1.37 s both; fast 0.56 s against
0.54 s), the card screen at 2.40 s against 2.53 s. Play again 1 request (it was 3). Fix 5: the worker is never waited for on a first visit (registered
once the start is in); the bootstrap is inlined in `index.html`, so after a deploy a
returning phone runs the new build at its first open. Usable 01, first visit: fast 1.9 s
to 1.1 s, phone 5.8 s to 5.4-5.8 s (within noise); the first return 0.2 to 0.3 s slower
(the worker caches from that visit on), the third visit equal (phone 3.31 s to 3.34 s).
Dropping the worker instead was measured too: first visits like this, every return 0.7 s
slower on the phone without long cache headers (`vercel.json`). Fix 6: 01's picture is
asked for first (phone, first visit: in at 6.5 s to 6.0 s), each picture is one request
(28 to 15), Roboto is never fetched. Not done: a guest's Play again still reads
`/me/table/` and the lobby (its event names only the code).

1. Stop the 2 needless requests on open (start-up token refresh; the redirect's
   `current-game`), and run `/me/` beside `me/table/`: **-0.6 to -1.2 s on every open**; app (us).
2. Serve the API from the app's own origin (a rewrite `/api/(.*)` -> the API in
   `frontend/vercel.json`, sockets stay direct): no preflights, **-0.2 to -0.45 s on every
   first request to a URL, about half the round trips of a first open and of every new
   game's first read**; repo file (us), check with the deployment owner (one more edge hop,
   the `Date` header must pass).
3. Use the answers we already get (create/join/deal return the lobby or the game id):
   **-0.5 to -1 s per start/join/deal**; app (us).
4. Designed first paint: a night-ground splash with the title in `index.html` and the
   Android launch theme; a calm waiting line after ~1 s: **perceived, large**; app (us).
5. Do not wait for the service worker before loading (or drop the Flutter SW and set long
   cache headers on hashed copies): **-0.5 to -0.9 s first visit**; app/build (us).
6. Load 01's picture before the 30 secret art files; stop asking for Roboto: **01 complete
   ~0.3 to 1 s sooner on a phone**; app (us).
7. Keep the server warm during the hours people play (a ping every few minutes, Vercel
   "fluid compute"/min instances, database autosuspend off or longer): **-1.3 s on the
   first request after idle**; deployment owner (propose only).
8. Put the database in the same region as the functions (iad1) and allow connection reuse
   (`DB_CONN_MAX_AGE` > 0 with the pooled URL, or a pooler such as PgBouncer that keeps TLS
   warm): **-50 to -150 ms per request**; deployment owner (propose only).
9. Consider `--wasm` (skwasm) for Chrome/Android: faster start on supported browsers, falls
   back by itself; needs testing; app/build (us).

## Worst problems, ranked by how likely a real table hits them

1. Browser back (and Android back) on any screen leaves the app; coming back is a full
   restart through white and blank screens. Every web player, every game. `routes.dart`, no root `PopScope`.
2. Every open and every stage change is a bare ground for 1 to 3 s (more when the server
   sleeps), and nothing anywhere says what is happening. `table_shell.dart:203`, `at_table_screen.dart:154`, `count_screen.dart:66`, `web/index.html`.
3. 4 to 5 requests in a row on open (two needless). `auth_repository.dart:43`, `app_router.dart:62`.
4. Entering the game (deal, reload, cold start in the card look) shows "The village sleeps"
   before "Your card": an untrue instruction to close your eyes. `night_screen.dart:24`, `screen_table.dart:149-153`. shots/M-s4-deal.png, shots/M-s5-reload-cold.png.
5. "Start a table" gives no sign of life (all buttons dim, no spinner) for 1 to 15 s. `join_screen.dart:295-301`. shots/01-start-150ms.png.
6. A restore that fails (offline for a moment, server past 10 s) strands a seated player on
   01 with "Not sent." forever; typing the name then makes a new account and the seat is
   lost. `auth_notifier.dart:57-79`, `join_flow.dart:134-141`. shots/M-s6-reload-down.png, shots/s6-recovered-0ms.png.
7. After a stage change, the old screen stays live with its clock running while `/me/` is
   slow; with HTTP failing and the socket up it stays 20 s+ with no "One moment".
   `table_shell.dart:107-110`. shots/s8-to-vote-httpdown-10000ms.png.
8. After the POST answers, Deal / Play again / Leave are tappable again until the next
   screen arrives. `at_table_screen.dart:131-150`, `results_screen.dart:85`. shots/s4-deal-6000ms.png.
9. A player who joined by link and leaves sees only "Join" of that same table plus a stale
   "Not sent." / "Try again" (re-join). `join_screen.dart:58`, `home_gate.dart:38-46`, `join_flow.dart`. shots/r5-link-guest-after-leave.png.
10. Reload adds a history entry (`/game/<id>`), so back behaves differently after a reload;
    APK players who scan the QR land in the browser as someone new. `app_router.dart:60-77`, `AndroidManifest.xml`.

## Mechanisms that would enforce the rules everywhere

- **One back policy at the shell**: a root `PopScope`/`BackButtonListener` in `TableShell`
  that asks a small stack of "open things" (sheets, deck, My night, code field, folded night)
  to close first, else does nothing in a game and asks at a table; on the web, one sentinel
  history entry re-pushed on `popstate` (or `GoRouter` with `onExit`) so browser back goes
  through the same policy. A widget test per `AppScreen` value: "back with nothing open
  stays here", "back with X open closes X".
- **One "pending" primitive**: every request goes through one helper that gives the tapped
  control its busy look at once, keeps it busy until the SCREEN it leads to is up (not the
  HTTP answer), shows the calm waiting line after ~1 s and the "waking up" line after ~3 s,
  and never turns slowness into failure (no 10 s cut-off on reads; taps keep their look until
  answered or refused). Lint: no `SecondaryButton`/`TextAction` with an async `onPressed`
  outside it.
- **One waiting screen**: replace `_Nothing`, `_Waiting`, `EndWaiting`, `HomeGate`'s blanks and
  05-as-loading with one designed `Waiting(what)` built from the skin; a test that walks every
  `AsyncValue` state of `tableScreenProvider`, `liveGameProvider`, `lobbyProvider`,
  `authProvider` and fails when any maps to a bare ground or to 05 outside the night.
- **Gallery entries plus a coverage test**: every loading/error state above gets a gallery
  entry; a test lists the states each provider can be in and fails when one has no gallery
  entry.
- **Restore heals**: `authProvider` restore retried with backoff like every other fetch
  (`retryForever`), and 01 never offers a new account while a stored one is not yet read.
- **Fewer round trips by construction**: start-up does no refresh; screens use the POST's
  answer; a test counts requests on open (at most 2 before the game screen).
- **Designed first paint**: `index.html` splash and Android launch theme from the skin's
  night colour and title, checked by a screenshot in `just screens`.

## Rough size

- Back policy (shell + web sentinel + tests): 1.5 to 2 days.
- Pending primitive + one waiting screen + copy (3 to 4 new strings, within the spec's
  banned words: no "loading", "server", "connection") + gallery entries + coverage test: 3 to 4 days.
- Restore heals + new-account guard + link/leave fix: 1 day.
- Fewer requests on open/start/join/deal: 1 to 1.5 days (app only, no server change).
- Splash, art priority, service-worker wait, Roboto: 0.5 to 1 day.
- Hosting (keep-warm, DB region, connection reuse): the deployment owner; hours, not days.
Full timing log: S/live/apiseq.log
