# Before the game: 01 Join, 02 Table, 03 Deck (`features/lobby`)

The screens before the deal, rebuilt to `docs/specs/frontend/first-time-play.md` (sections 7
and 8 win) from the primitives. Keep this file true when you change what it describes.

- **Where they show.** Home (`/`) is `HomeGate`: signed out, 01; signed in, the table's shell
  (`TableShell`), which shows the screen `/me/table/` names: 01 at no table, 02 at a waiting
  table (03 for a host who opened it, a step of this phone's only: a restart lands on 02), the
  game's screens in a game. So a player who comes back to a table they sit at is there with no
  tap. `/join/<code>` (a table's link and QR code) is 01 with the name and "Join", or the table
  itself for a player already at it.
- **01** (`join_screen.dart`): the name is this device's own guest account's or empty and
  focused; "Join a table" first, then "Start a table", locked until a name is typed; Enter in
  the name opens the code (with a code, or from a link, it joins; never a table of one's own
  by accident); the online count and the last game under them. The village takes all the
  height the form leaves, the whole scene and never more (`TopArtLayout.fill`), so the form
  sits low and a tall phone shows no empty lower half; with the keyboard up the form stays in
  view above it. A game that closed (404) lands here with "This table has closed."
  (`JoinFlow.tableClosed`). The ways in are `JoinFlow`
  (`join_flow.dart`), outside any widget: the account (this device's when it has that name,
  else a new guest: the server has no rename), then `createTable` (always `defaults: "v2"`)
  or a join by code (`already_in_lobby` is no refusal: the player is there), then
  `/me/table/`. Refusals are the spec's banners; no answer is "Not sent." with "Try again". A
  link to another table while seated at one, and the server's 409 `already_at_table`, say
  "You're at another table." with "Go there" (it reads `/me/table/` again): never a silent
  second seat.
- **02** (`at_table_screen.dart`): for everyone, "Scan to join" (the QR code's label only:
  with no link there is no QR code and no "Scan to join") with Share beside it, the QR
  code of the join link (`joinLink`: `<origin>/#/join/<code>`; `appOrigin` is the page's
  address on the web, else `--dart-define=PUBLIC_ORIGIN`, else the code alone), never under
  `Sizes.qrScannable`, and the code after its label "Code" (`_CodeLine`, 01's word). Nearly empty (`Sizes.nearlyEmptyTable`: alone or two)
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
  with "Edit"; the deal button is the server's `deal` (`DealState`): "Deal to {n}", live only when
  `ok`, else the same words locked (at a table set for a number, `deal.seats`, {n} is that
  number; never card arithmetic), "Need 3 players" at an open table of fewer than three, or
  "Can't deal yet.". Nobody is asked to be ready:
  the server deals in everyone at the table. A deal refused all the same (the table changed
  under the tap) says why when the server's refusal gives a reason worth saying
  (`LobbyNotifier.dealRefusal`: the table playing, too few, the deck), else nothing extra,
  never a bare "Not sent." nor a notice that repeats the button; the button stays busy until
  the lobby is read again and its new verdict sets it. A quiet labelled "Leave" asks first
  ("Stay" / "Leave"). Leaving (`LobbyNotifier.leave`) waits as long as a waking server takes
  (`LobbyService.leaveWait`, not the client's 10 s); "not at this table" (400) and a table
  gone (404) count as left (an earlier tap got there); with no answer at all `/me/table/`
  decides, and only a phone the server still seats sees "Not sent." with "Try again"; a
  refusal says why ("That table is playing now.", else "Can't leave now."). Off the table,
  `/me/table/` puts the phone at 01 (the last one out closes the table). With a pace chosen, its talk length ("5:00") sits beside the chip,
  selected, so 02 shows what 03 chose. A guest: "{host} deals" at the hero title size over the
  same card, the rows, and "Leave" a quiet underlined word at the foot (`TextAction` in the
  actions, no outlined button): waiting said by the shape, not a sentence. A deal, a handover or a host change reads `/me/table/` again; the layout follows
  the lobby's host with no words; a table that is gone says so with "Go home".
- **03 Tonight's game** (`deck_screen.dart`): the set-up page, the host's, editable before
  anyone comes and until the deal; every change is saved as it is made (shown at once, a
  merged PATCH, one at a time), so a restart finds it at the server. Top to bottom:
  - **Players**: a `ValueStepper` from 3 to 10 (`settings.seats`); below 3, "Any" (an open
    table: dealt to whoever is there, the automatic deck for who is here); never below the
    players here (the server refuses it). At a number, `SeatsLine` "3 of 8" (shared with 02).
  - **The deck, face up**: the chips make it automatic; every role in a grid, lit with its
    count (`LobbyState.tableCards`: the server's `deck_cards`, or the host's own deck with this
    phone's taps); a tap puts one in (up to the role's most, Masons in pairs; at its most a
    tap does nothing), a lit card's minus (`RoleCard.onRemove`) takes one out, a hold opens
    03b (`showRoleSheet`). The first card changed on an automatic deck makes it the host's own
    from those cards (`startCustomDeck`), for the number (an open table takes the players
    here, at least 3). At a number, `DeckCount`: the cards picked over `deal.need` ("7 / 11")
    and a slot each, the players' slots then the centre's three, in the danger ink while it
    is not the need. No words say which way the deck is off.
  - **Every length the server has** (`Length`: Look, Night, Night minimum, Doppelganger,
    Talk, Vote, Dropped phone, Host away), each a `LabelledStepper`: its value with its unit
    ("30 s", "5 min", "2:30 min", "Off" for 0) from the server's `lengths` (a new table shows
    the server's defaults), moved by a step (`Length.up`/`down`: 5 s under a minute, 15 s
    under five, 30 s under fifteen, then minutes) within `length_ranges`. The Doppelganger's
    is drawn quiet while the deck holds no Doppelganger. There are no pace presets.
  - "Use this deck" back to 02: one label, live while the deck holds the cards the deal needs
    (always for an automatic deck), locked otherwise.
- **State.** Everything shown is `lobbyProvider(code)`, read until it answers (`retryForever`;
  "One moment" meanwhile): the lobby body, its socket (`lobby_update` is the whole lobby), and
  this phone's settings changes merged over it as the server merges a PATCH (shallow), shown
  at once, sent one at a time; a refusal or no answer takes the change back and says "Not
  sent." (`notSent`, `retry`); a host role that moved says nothing. `TableSettings` reads the
  deck, the chip, the look and the number of players; the lengths are the server's
  `lengths` (`LobbyState.secondsOf`, this phone's change while it is on its way).
- **Tests.** `test/features/lobby/` (`table_screens_test.dart` drives the screens through the
  routes on recorded lobby bodies, `test/helpers/table_setup.dart`: each chip's cards, a deck
  one card short, a player joining, a phone dropping and coming back, the 409; the deal's
  verdicts in `lobby_state_test.dart`); the gallery's 01 to 03b states are
  `test_screens/table_fixtures.dart`; the whole way from 01 to 11 and back to 02 against a
  real server is `test_e2e/ui_journey_test.dart`.
