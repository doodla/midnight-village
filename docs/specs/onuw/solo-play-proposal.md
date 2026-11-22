# Proposal: trying the game alone (A built)

21 November 2026. The owner, alone at a live table, could not get past the lobby: a game needs
three phones. Two ways one person could try it, with rough cost. Recommended: **A**.

**Built (22 November 2026), with the owner's hidden switch** ("hidden enable so it's not
visible to everyone"). How it works now: `backend/apps/core/README.md` and
`backend/apps/onuw/README.md` ("Practice players"), the API in
`docs/specs/onuw/api-contract-v2.md`, the screens in `docs/specs/frontend/first-time-play.md`
(02, 03, 09). Where the build differs from the plan below, and why:

- **The mark is the account, not `settings.practice_ids`.** A practice player's username
  starts with `practice-` (guest sign-up never makes one). A list in the settings could be
  PATCHed by the host to name a real guest, and the server would then play for them; the
  game would also need it copied. The settings keep only the switch (`practice: true`).
- **`{"on": bool}` and `{"count": n}`, not `{"add": 1}` / `{"remove": 1}`.** A count is a
  target, so a resend leaves the table as once; "on" is the hidden switch.
- **Hidden.** No visible stepper by default: a hold on 03's "Players" switches them on,
  then a "Practice" stepper appears under it. The tag is on 02 and 09 (the night board and
  the count are not touched).
- **One choose each per window, even with nothing to choose** (taken alike, read as
  nothing), so the work after a window opens does not depend on their cards.
- **The backstop is `GET /me/`, not the stage timers** (a timer fires at the deadline, too
  late to act in the stage). Presence needed no change: a player with no socket is never
  stamped disconnected, so they are never "gone"; only the players list says `connected`.
- **Names are village things** ("Scarecrow", "Teapot", ...): "Moth" is a seat token.
- **A person joining a full table takes a practice seat**, and the owner leaving with only
  practice players left closes the table and deletes their accounts.
- No migration.

## A. Practice players (recommended)

Seats filled by simple computer players. They do what a person does, at once and at random,
and never host.

**Server** (additive, no migration; every field in the lobby's settings JSON):

- `POST /lobbies/<code>/practice/` (host only, waiting table) with `{"add": 1}` or
  `{"remove": 1}`. Add makes a guest user (display name from a fixed list: "Owl", "Fox",
  "Moth", ...) and seats it with `lobbies.add_member` (so `seats` and `max_players` hold, and a
  full table refuses with `lobby_full`); its id goes in `settings.practice_ids`. Remove
  deletes the last one added. The lobby body gains `players[].practice: true`.
- A driver, run from the same after-commit points that open each stage (and from the stage
  timers as a backstop), acts for every practice player still to act, through the same
  service functions a phone's request calls: look stage, ready; night, if it has a choose,
  one pick chosen uniformly among the prompt's valid picks (or none, where none is valid),
  then choose; talk, ready; vote, a random player other than itself, locked. Randomness is
  seeded from the game's seed and the player's id and logged, like every other draw.
- Never host: `host.transfer_ownership` and the acting-host handover skip practice ids.
  Always present: presence counts them connected, so no grace period waits on them.
- Hidden information is unchanged: a practice player's role is as secret as anyone's; the
  results show it like any player's.

**App:** on 03, under Players, a "Practice" stepper (0 to the empty seats); on 02 and in the
game a practice player's row carries a "Practice" tag (`TagChip`) and is never dimmed. One
word of copy. Nothing else changes: the night, talk and vote screens already wait for others.

**Size:** server about 350 lines with tests (endpoint, driver, the host and presence filters,
a seeded multi-player test per stage, contract samples); app about 150 lines with tests.
Two to three days of agent work. Risk: low; the driver uses the existing service calls.

## B. Every seat on one phone (pass and play)

One phone joins as three or more guests and is handed round: before each secret step a cover
says whose turn it is ("Pass to Fox"), then that seat's screen shows.

**Server:** unchanged. **App:** an identity switcher (several token sets in storage, one
lobby socket and one game socket per seat, or polling), a hand-off cover before every secret
screen, and the night's windows walked seat by seat, so the host must set long lengths.

**Size:** app about 600 lines plus tests, and a second way through every screen. Risk: high
(timers expire while the phone is being passed, several sockets on one device, secrets shown
to whoever holds the phone). It teaches the screens, but not how a table plays.
