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
  focused; "Join a table" first, then "Start a table", locked until a name is typed; the
  online count and the last game under them. The ways in are `JoinFlow` (`join_flow.dart`),
  outside any widget: the account (this device's when it has that name, else a new guest:
  the server has no rename), then `createTable` (always `defaults: "v2"`) or a join by code
  (`already_in_lobby` is no refusal: the player is there), then `/me/table/`. Refusals are the
  spec's banners; no answer is "Not sent." with "Try again".
- **02** (`at_table_screen.dart`): the host's QR code of the join link (`joinLink`:
  `<origin>/#/join/<code>`; `appOrigin` is the page's address on the web, else
  `--dart-define=PUBLIC_ORIGIN`, else the code alone), the code, Share (a glyph: the system
  share sheet, `share_plus`, or the clipboard), a row per player (their own outlined, names
  never cut), the deck as its chip or the custom deck's cards with "Edit", and "Deal to {n}"
  by the server's own deal rules (`DealState`: 3 or more, a custom deck of players + 3). A
  guest: "{host} deals", the code, "Leave". Each phone sets its own ready flag as it sits down
  (`LobbyNotifier.sitDown`; the server's deal wants every member ready, and there is no ready
  button). A deal, a handover or a host change reads `/me/table/` again; the layout follows
  the lobby's host with no words; a table that is gone says so with "Go home".
- **03** (`deck_screen.dart`): the chips choose (the server builds the deck at the deal);
  "Edit" opens the role grid (a tap adds a card up to the role's most, then none; a hold opens
  03b, `showRoleSheet`: the role text and a quiet "Close", nothing that changes the deck); an
  edited deck is sent with "Use this deck", amber only at players + 3 (the server refuses any
  other). The pace chips write the contract's presets (talk, vote, a night window; never the
  Doppelganger's window) and the lengths show once the settings carry them.
- **State.** Everything shown is `lobbyProvider(code)`: the lobby body, its socket
  (`lobby_update` is the whole lobby), and this phone's settings changes merged over it as the
  server merges a PATCH (shallow), shown at once, sent one at a time; a refusal or no answer
  takes the change back and says "Not sent." (`notSent`, `retry`); a host role that moved says
  nothing. `TableSettings` reads the deck, the chip, the pace and the lengths.
- **Not known to the phone (server gaps).** Whose phone has dropped (the lobby body has no
  presence, so 02's dimmed row shows only on the component sheet); the timer lengths before a
  pace is chosen; a chip's cards before the deal.
- **Tests.** `test/features/lobby/` (`table_screens_test.dart` drives the screens through the
  routes on recorded lobby bodies, `test/helpers/table_setup.dart`); the gallery's 01 to 03b
  states are `test_screens/table_fixtures.dart`.
