# Before the game: 01 Join, 02 Table, 03 Deck (`features/lobby`)

The screens before the deal, rebuilt to `docs/specs/frontend/first-time-play.md` (sections 7
and 8 win) from the primitives. Keep this file true when you change what it describes.

- **Where they show.** Home (`/`) is `HomeGate`: signed out, 01; signed in, the table's shell
  (`TableShell`), which shows the screen `/me/table/` names: 01 at no table, 02 at a waiting
  table (03 for a host who opened it, a step of this phone's only: a restart lands on 02), the
  game's screens in a game. So a player who comes back to a table they sit at is there with no
  tap. `/join/<code>` (a table's link and QR code) is 01 with the name and "Join", or the table
  itself for a player already at it; `/game/<id>` is the same gate. Back is the gate's one
  policy (`BackPolicy`, `features/game/README.md`): 01 leaves the app (its code field open,
  Back closes it first), "You're at another table." goes there, 02 asks first with the
  host's "Stay" / "Leave" (a guest too; not while a deal or a leave is on its way; the
  question closes when the screen changes), 03 returns to 02, the opening waits leave the app
  (the seat is kept).
- **The saved account** (`AuthNotifier`, `AuthRepository.tryRestoreSession`). Read back at
  start from storage alone while its access token works (its own `exp`; no request), else
  renewed once. A try the server does not answer (no network, a timeout, a 5xx, an answer
  that is not the server's) is made again by itself with the healing backoff and the same
  refresh token (the server no longer blacklists a used one, so a renewal whose answer was
  lost still works); meanwhile home is the game opening (`OpeningWait`: 01's village and
  title, "One moment" once a try got no answer), never 01's form. Only a 401 (the account is
  gone: refused, deleted or inactive, on the renewal or on any read) clears it, and the seat
  kept for it, and shows a fresh 01. `AuthRepository.createGuest` refuses
  (`SavedAccountExists`, nothing sent) while a saved account is kept, unless the player is
  signed in with it and asks for another name (`replacing`, from 01 at no table, where the
  server has said they have no seat), so 01 can never cost a seat; a tap that sent nothing
  says nothing (no "Not sent.").
- **Opening the app** reads the seat this device last had for this account (`LastSeat`,
  `mv.seat.v1.<user>:<seat>`, kept from every `/me/table/` answer, cleared with the account)
  beside `/me/table/`: its game's `/me/`, or its waiting table's lobby, goes out at the same
  moment; `/me/table/` decides and a seat it does not name is let go. The read beside it is
  quiet: it closes nothing, says nothing ("This table has closed." comes only from a game
  `/me/table/` names) and never asks for the table again (`LiveGameNotifier` acts only for a
  game `/me/table/` names). Seated with a working token: two requests, one round trip, then
  the screen (`test/features/app_open_test.dart` pins it); a renewal first makes it three.
- **01** (`join_screen.dart`): the name is this device's own guest account's or empty and
  focused; "Join a table" first, then "Start a table", locked until a name is typed; Enter in
  the name opens the code (with a code, or from a link, it joins; never a table of one's own
  by accident); the online count and the last game under them. The village takes all the
  height the form leaves, the whole scene and never more (`TopArtLayout.fill`), so the form
  sits low and a tall phone shows no empty lower half; with the keyboard up the form stays in
  view above it. A game that closed (404) lands here with "This table has closed."
  (`JoinFlow.tableClosed`). **The scan action** (a glyph beside "Join a table" and the code
  field, `GlyphButton` with `ScanGlyph`; not on a table's link) opens **01b**, the scanner
  (`presentation/scan/scan_view.dart`: a `Viewfinder` window, a Back glyph, the light where the camera has
  one), as a place of 01 with Back for its rule (`BackHandler`: Back closes it to 01 as it
  was). The camera is behind `CodeScanner` (`presentation/scan/code_scanner.dart`; `MobileCodeScanner` on
  `mobile_scanner`: QR only, the back camera, stopped with the app in the background); it is
  made when the scanner opens and disposed when it goes, so the camera is never touched
  before the tap and stops the moment the screen leaves. What it reads goes through
  `tableCodeFrom` (`domain/table_link.dart`: a link of any origin with `/join/<code>`, or a
  bare code; anything else is ignored silently). A code read stops the camera, closes the
  corners in on the code and joins by `JoinFlow.join`, the same path as typing (with no name
  yet: back to 01 with the code in and the name asking). The scanner's place (open, and the
  code once read) is `ScanSession` (`presentation/scan/scan_session.dart`), outside 01's widgets, because
  `HomeGate` swaps one 01 for another when a join starts; it closes when the join ends or is
  refused. The camera refused, none, or an insecure page: `ScanProblem`, a `ShutteredWindow`, one line and "Type
  the code". A scanner left open when 01 goes away ends (`ScanSession.left`), so only a tap starts the camera; a table's link shows none. A join keeps its code in `JoinFlowState.code`, so 01, made again while it runs or when it is refused, has the code in its field. In browsers with no built-in detector the scanner decodes with the app's own `web/zxing/` (`own_decoder_web.dart`). The ways in are `JoinFlow`
  (`join_flow.dart`), outside any widget: the account (this device's when it has that name,
  else a new guest: the server has no rename), then `createTable` (always `defaults: "v2"`)
  or a join by code (`already_in_lobby` is no refusal: the player is there), then
  `/me/table/`. The start's or the join's answer is the table's lobby (`LobbySeed`): 02 shows
  it without reading it again; a joined table is read once more when its socket is first up
  (a join said before it listened), a started one never (only its host knows the code). Refusals are the spec's banners; no answer is "Not sent." with "Try again". A
  link to another table while seated at one, and the server's 409 `already_at_table`, say
  "You're at another table." with "Go there" (it reads `/me/table/` again): never a silent
  second seat.
- **02** (`at_table_screen.dart`): the table's paper (`_JoinCard`) is two blocks: the QR code
  of the join link (`joinLink`: `<origin>/join/<code>`, a path; `appOrigin` is the page's origin on
  the web, else `--dart-define=PUBLIC_ORIGIN`, else no QR code) with "Scan to join" on it (its
  label alone: under a large QR code, at the edge of a small one), never under
  `Sizes.qrScannable`; and, past a hairline, the code with its own label "Code" (01's word)
  and Share. Nearly empty (`Sizes.nearlyEmptyTable`) and open, the table's picture and the QR
  code large and centred; past that, or at a table set for a number, the QR code at its least
  beside the code (over it where the code would have under `Sizes.joinCodeBeside`: at 320).
  From `Sizes.twoUpPlayers` the rows go two to a line where each half keeps
  `Sizes.playerColumn`; the rows, the deck and Deal are in view for six at 390 x 844 and five
  at 360 x 640, and alone at a table set for eight the deck and Leave too, at 320, 360 and
  390, text x1 and x1.3 (`table_fit_test.dart`). A row per player: their own outlined and
  never dimmed, names never cut, another's dropped phone (`connected: false`) dimmed with no
  words, a practice player's (`players[].practice`, a seat the server plays) with its own
  token (the thing it is named for, `TokenId.practice`) and "Practice" (`PracticeTag`, the
  word alone, quieter than "You") on the name's line, never dimmed, for host and guests. Share is the system share sheet (`share_plus`); only where there is none the link is
  copied and the screen says "Copied". At a table set for a number (`settings.seats`): "{d} of
  {n}" with an empty circle for each place not taken (`SeatsLine`, `SeatDots.empty`, the
  same words 03 shows, for host and guests alike), above the rows; the wait is said this one
  way, never as card arithmetic. Everyone sees the game as set up (`_SetupPanel`): the chip
  (an automatic deck), the talk's length ("Talk 5 min") and every role in the deck face up
  with its count, in `deckOrder` (`LobbyState.tableCards`; the same for every viewer,
  following every `lobby_update`), in balanced lines (`_DeckStrip`: the thumbnails shrink to
  `Sizes.thumbLeast` before a second line, and no card sits alone on one); a tap or a hold on
  a role reads it (03b). The host's panel opens 03 ("Edit") and, at a number, shows a deck
  that does not hold the cards the deal needs (`DeckCount`; a guest never sees it). Fewer
  came than the number (3 or more here): "Play with {n}" sets the number to who is here in one
  tap; an automatic deck follows, a deck of the host's own is never changed: the tap opens 03
  with its count showing. The deal button is the server's `deal` (`DealState`): "Deal to
  {n}", {n} the number as this phone shows it (a change on its way included), live only when
  `ok` and nothing is on its way, else the same words locked; "Need 3 players" at an open
  table of fewer than three, or "Can't deal yet.". Nobody is asked to be ready. A deal
  refused all the same says why when the refusal gives a reason worth saying
  (`LobbyNotifier.dealRefusal`), never a bare "Not sent.". A quiet labelled "Leave" asks
  first ("Stay" / "Leave"); a guest's is a quiet underlined word at the foot (`TextAction`).
  Either shows it is on its way at once (`busy`: a `BusyMark` beside the word). Leaving
  (`LobbyNotifier.leave`): `not_in_lobby` (400) and a table gone (404) count as left (an
  earlier leave got there); another refusal says why ("That table is playing now.", else
  "Can't leave now."); no answer (no connection, the client's 10 s wait run out, a 5xx):
  `/me/table/` decides, and only a phone the server still seats sees "Not sent." with "Try
  again". Off the table, `/me/table/` puts the phone at 01 (the last one out closes the
  table). A guest: "{host} deals" at the hero title size over the same card. A deal, a
  handover or a host change reads `/me/table/` again; a deal names its game (the deal's
  answer for the host, `game_started` for a guest), and that game's `/me/` is read at the
  same moment, not after `/me/table/`. A table that is gone says so with "Go home".
- **03 Tonight's game** (`deck_screen.dart`): the set-up page, the host's, editable before
  anyone comes and until the deal; every change is saved as it is made (shown at once, a
  merged PATCH, one at a time), so a restart finds it at the server. Top to bottom:
  - **Players**: a `ValueStepper` within the server's `seats_range` (never below who is here,
    never above what the table holds); below 3, "Any" (an open table, dealt to whoever is
    there), offered only with an automatic deck, so a deck of the host's own is never quietly
    dropped. At a number, `SeatsLine` "3 of 8" with every seat drawn.
  - **The deck, face up**: the chips make it automatic; every role in a grid in `deckOrder`,
    lit with its count; a tap puts one in (up to the role's most, Masons in pairs), a lit
    card's minus (`RoleCard.onRemove`) takes one out, a hold opens 03b (`showRoleSheet`). The
    first card changed on an automatic deck makes it the host's own from those cards
    (`startCustomDeck`), for the number (an open table takes the least of `seats_range`). At
    a number, `DeckCount`: the cards picked over the cards needed ("7 / 11", `cardsNeeded`,
    `pickedCards`) and a slot each, the players' then the centre's three, in the danger ink
    while it is not the need. No words say which way the deck is off.
  - **Every length the server has**, in `Length` order (Talk, Vote, Night, Doppelganger,
    Look, Night minimum, Dropped phone, Host away), each a `LabelledStepper`: its value with
    its unit ("30 s", "5 min", "2:30 min"; 0 is "No clock" for the talk and the vote, "Off"
    for the rest) from the server's `lengths` (a new table shows the server's defaults),
    moved by a step (`Length.up`/`down`: 5 s under a minute, 15 s under five, then whole
    minutes) within `length_ranges` (the server's rule table, so a step is never refused for
    a range reason). The Doppelganger's row is there only while the deck holds one. Each
    stepper is as wide as its own widest value; the rows stay even (every name beside its
    stepper, or every name over it). There are no pace presets.
  - **Practice players, hidden** (the owner: "hidden enable so it's not visible to
    everyone"): a hold on the word "Players" itself (`LabelledStepper.onLabelLongPress`,
    the words only, never the room before the stepper) switches them on for this table; a
    tap does nothing and nothing on screen offers it. While on (`LobbyState.practiceOn`), a
    "Practice" stepper under Players sets how many sit, 0 to the server's `practice.most`.
    A hold switches them off only at 0 (the row goes); with some seated it does nothing, so
    a thumb resting on the word never removes everyone. `LobbyNotifier.togglePractice` /
    `setPracticeCount` send `POST /lobbies/<code>/practice/` as changes on the settings'
    lane (below). What to tell the owner: "On the set-up page, press and hold the word
    Players."
  - "Done" back to 02, always live (a host who changed only a timer is never stuck).
- **State.** Everything shown is `lobbyProvider(code)`, read until it answers (`retryForever`;
  "One moment" meanwhile): the lobby body, its socket (`lobby_update` is the whole lobby), and
  this phone's changes on the settings' lane over it: settings PATCHes (merged as the server
  merges them, shallow) and practice changes (`PracticeAsk.then`, folded as the server
  applies them; key `practice`), ALL in one pending list, shown at once, sent one at a time
  in the order tapped. What the host sees while a change is on its way is ONE value: the
  server's state with only the pending keys (`LobbyState.pendingKeys`) taken from this phone
  (`TableCards`: `secondsOf` a length, `tableCards`, `cardsNeeded`, `pickedCards`;
  `PracticeSeats`: `practiceOn`, `practiceCount`, `seatedCount` for the seats line,
  `practiceLimit`; and `DealState`, which waits, "Deal to {n}" locked, while any change is
  on its way), so nothing pairs a new value with an old one and nothing goes around one. A
  change the server refuses (`serverAnswered`, `core/api/api_exception.dart`: the one
  classifier every host action uses) is dropped and the lobby read again, never "Not
  sent." nor sent again; a change that never got an answer says "Not sent." with "Try
  again", which sends each such change again with only the keys no newer change has asked
  for since (`_askedAt`), so it never undoes a newer value on the same key, answered or on
  its way. A host role that moved says nothing. `TableSettings` reads the deck, the chip, the look and the number of players.
- **Tests.** `test/features/lobby/` (`table_screens_test.dart` drives the screens through the
  routes on recorded lobby bodies, `test/helpers/table_setup.dart`: each chip's cards, a deck
  one card short, a player joining, a phone dropping and coming back, the 409; the deal's
  verdicts in `lobby_state_test.dart`; `setup_page_test.dart` drives 03 tap by tap for 3, 5,
  8 and 10 players with 1, 2 and 5 here against a stand-in server, and holds answers to check
  what shows while changes are on their way; `table_leave_test.dart` every way a leave ends); the gallery's 01 to 03b states are
  `test_screens/table_fixtures.dart`; the whole way from 01 to 11 and back to 02 against a
  real server is `test_e2e/ui_journey_test.dart`, and a table set for eight, filled one by
  one, lowered to seven and dealt is `test_e2e/ui_setup_test.dart`. Practice players:
  `practice_players_test.dart` (the hidden hold on the word only, the stepper to the most,
  off only at 0, the tags on the name's line, Deal waiting for a change on its way, + + −
  with every answer held, the three recorded refusals, "Not sent." and "Try again", a stale
  "Try again" never undoing a newer practice count or setting, a guest),
  `practice_seats_test.dart` (what the app reads, the fold); one person alone holding
  "Players", seating three and playing a whole game while the server plays them is
  `test_e2e/ui_practice_test.dart` (run by `just test-harness`).
