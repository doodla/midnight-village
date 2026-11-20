# Before the game: 01 Join, 02 Table, 03 Deck (`features/lobby`)

The screens before the deal, rebuilt to `docs/specs/frontend/first-time-play.md` (sections 7
and 8 win) from the primitives. Keep this file true when you change what it describes.

- **Where they show.** Home (`/`) is `HomeGate`: signed out, 01; signed in, the table's shell
  (`TableShell`), which shows the screen `/me/table/` names: 01 at no table, 02 at a waiting
  table (03 for a host who opened it, a step of this phone's only: a restart lands on 02), the
  game's screens in a game. So a player who comes back to a table they sit at is there with no
  tap. `/join/<code>` (a table's link and QR code) is 01 with the name and "Join", or the table
  itself for a player already at it; `/lobby/<code>` is home (the old game screen goes there).
- **01** (`join_screen.dart`): the name is this device's own guest account's or empty and
  focused; "Join a table" first, then "Start a table", locked until a name is typed; Enter in
  the name opens the code (with a code, or from a link, it joins; never a table of one's own
  by accident); the online count and the last game under them. The village takes all the
  height the form leaves (`TopArtLayout.fill`), so the form sits low and a tall phone shows
  no empty lower half. A game that closed (404) lands here with "This table has closed."
  (`JoinFlow.tableClosed`). The ways in are `JoinFlow`
  (`join_flow.dart`), outside any widget: the account (this device's when it has that name,
  else a new guest: the server has no rename), then `createTable` (always `defaults: "v2"`)
  or a join by code (`already_in_lobby` is no refusal: the player is there), then
  `/me/table/`. Refusals are the spec's banners; no answer is "Not sent." with "Try again". A
  link to another table while seated at one, and the server's 409 `already_at_table`, say
  "You're at another table." with "Go there" (it reads `/me/table/` again): never a silent
  second seat.
- **02** (`at_table_screen.dart`): for everyone, "Scan to join" with Share beside it, the QR
  code of the join link (`joinLink`: `<origin>/#/join/<code>`; `appOrigin` is the page's
  address on the web, else `--dart-define=PUBLIC_ORIGIN`, else the code alone), never under
  `Sizes.qrScannable`, and the code. Nearly empty (`Sizes.nearlyEmptyTable`: alone or two)
  the table's picture shows and the QR code is large and centred, the code under it. Past
  that the next thing is who is here, the deck and Deal, so the card is short: no picture, the
  QR code at its least on the left with the words, Share and the code beside it (stacked,
  still at its least, where the code would have under `Sizes.joinCodeBeside`: at 320), and
  from `Sizes.twoUpPlayers` the rows two to a line where each half keeps
  `Sizes.playerColumn`. So the rows, the deck with its cards and Deal are all in view for six
  at 390 x 844 and five at 360 x 640 (`table_fit_test.dart`); beyond that the body scrolls
  under its fade. A row per player: their own outlined and never dimmed, names never cut,
  another's dropped phone (`connected: false`; the server keeps it true through the grace
  period) the whole row dimmed, its token more, with no words. Share is the system share sheet
  (`share_plus`, no mail fallback); only where there is none, or it fails, the link is copied
  and the screen says "Copied" (the skin has no share art: the platform's glyph). The host:
  the deck as its chip with its cards face up (`deck_preview`) or the custom deck's cards,
  with "Edit"; the deal button is the server's `deal` (`DealState`): "Deal to {n}" only when
  `ok`; else "Need 3 players", "Add 1 card" / "Remove 2 cards" (a custom deck, `need` against
  `have`), "The deck does not fit." or "Can't deal yet.", locked. Nobody is asked to be ready:
  the server deals in everyone at the table. A deal refused all the same (the table changed
  under the tap) says why when the server's refusal gives a reason worth saying
  (`LobbyNotifier.dealRefusal`: the table playing, too few, the deck), else nothing extra,
  never a bare "Not sent." nor a notice that repeats the button; the button stays busy until
  the lobby is read again and its new verdict sets it. A quiet labelled "Leave" asks first
  ("Stay" / "Leave"). A guest: "{host} deals" over the same card, the rows, a quiet "Leave"
  at the end. A deal, a handover or a host change reads `/me/table/` again; the layout follows
  the lobby's host with no words; a table that is gone says so with "Go home".
- **03** (`deck_screen.dart`): the chips choose (the server builds the deck at the deal), with
  the chip's cards face up from `deck_preview` (only for the chip the body is of: a chip tapped
  and not answered yet shows the deck face down, as does a count with no automatic deck, where
  "Edit" starts empty); "Edit" opens the role grid from them (a tap
  adds a card up to the role's most, then none; a hold opens 03b, `showRoleSheet`: the role
  text and a quiet "Close", nothing that changes the deck); an edited deck is sent with "Use
  this deck", amber only at the cards the deal needs (`deal.need`), "Add 1 card" / "Remove 2
  cards" otherwise. The pace chips write the contract's presets (talk, vote, a night window;
  never the Doppelganger's window) and the lengths show once the settings carry them.
- **State.** Everything shown is `lobbyProvider(code)`, read until it answers (`retryForever`;
  "One moment" meanwhile): the lobby body, its socket (`lobby_update` is the whole lobby), and
  this phone's settings changes merged over it as the server merges a PATCH (shallow), shown
  at once, sent one at a time; a refusal or no answer takes the change back and says "Not
  sent." (`notSent`, `retry`); a host role that moved says nothing. `TableSettings` reads the
  deck, the chip, the pace and the lengths.
- **Not known to the phone**: the timer lengths before a pace is chosen.
- **Tests.** `test/features/lobby/` (`table_screens_test.dart` drives the screens through the
  routes on recorded lobby bodies, `test/helpers/table_setup.dart`: each chip's cards, a deck
  one card short, a player joining, a phone dropping and coming back, the 409; the deal's
  verdicts in `lobby_state_test.dart`); the gallery's 01 to 03b states are
  `test_screens/table_fixtures.dart`; the whole way from 01 to 11 and back to 02 against a
  real server is `test_e2e/ui_protocol2_journey_test.dart`.
