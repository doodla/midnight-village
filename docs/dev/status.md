# Status: where the work stands

Current state only, and short: links, not copies. History is `git log` on main. The tracker is
GitHub Issues (`docs/dev/running-the-work.md`); what needs the owner is on the owner's board
(`docs/dev/owner-board.md`). Last gone through: 24 November 2026.

## Branch and deployment

- Work lands on main by pull request, squash-merged when every GitHub check is green
  (`docs/dev/running-the-work.md`). Each session works on its own branch, started from main.
- The server is LIVE on Vercel; every merge builds and migrates the shared database
  (`docs/dev/deploy-vercel.md`, "Deploy-safe changes"). After every merge the "Deployed Check"
  workflow proves the live server and app work together (`docs/dev/deploy-vercel.md`, "The
  check after each merge"). A red run on main opens an issue titled "main is red": look now.
- Never roll back to a build from before core migration 0011 (commit e8f50b5, #81): it can
  neither read nor write the lobby's members.

## What is built

The whole game, on the one look (Shadow paper): 01 Join, 02 Table, 03 Deck, 04 Your card, the
night board, 08 Talk, 09 Vote, the end board, practice players, scanning and table links. The
server runs one game flow on Vercel. What each part is and how it is held: `backend/CLAUDE.md`,
`frontend/CLAUDE.md` and the READMEs they name; start a piece with `just brief`.

## Next, in order

1. The lobby's send queue: the gaps the model found (branch `lobby-lane-gaps`, in review).
2. [#44](https://github.com/doodla/midnight-village/issues/44) the notes' giant lines: reflow them and switch the check on (the tool is merged, #181).
3. [#16](https://github.com/doodla/midnight-village/issues/16) a late, lost request must not overwrite a newer tap: the phone sends `asked` (the server's half is live, #172).
4. A notice's and a text action's words can only be a line of copy (the buttons are done, #165 and #167).
5. [#33](https://github.com/doodla/midnight-village/issues/33) a few small sounds: on hold until the owner says why the four takes missed.

## Waiting on the owner

On the owner's board, not here. Today: how the hold on "My night", the reveal and the four
screens changed on 23 and 24 November feel on a real phone; and why the four sound takes missed.

## Open issues

- [#8](https://github.com/doodla/midnight-village/issues/8) deck editor: make it obvious what a change to the deck does.
- [#11](https://github.com/doodla/midnight-village/issues/11) the app takes too long to open.
- [#12](https://github.com/doodla/midnight-village/issues/12) rerun the cold-read playtest on the real screens.
- [#13](https://github.com/doodla/midnight-village/issues/13) small phones: night board and Minion card text too small to read.
- [#24](https://github.com/doodla/midnight-village/issues/24) questions for the owner.
- [#28](https://github.com/doodla/midnight-village/issues/28) polish passes, screen by screen.
- [#34](https://github.com/doodla/midnight-village/issues/34) rename yourself while at a table.
- [#41](https://github.com/doodla/midnight-village/issues/41) the first screens as a place: the village.

## Known limits with no issue yet

- The live app measures itself (`docs/dev/deploy-vercel.md`, "Seeing the live app"): Vercel
  Speed Insights (score only on Hobby), and a summary at each game's end on our own server,
  read with `just field-report` once the server has a `FIELD_REPORT_KEY` (not set: the report
  is closed to everyone, the summaries are kept). Web Analytics needs the owner's Enable click; the vitals' numbers,
  function latency and longer logs need Pro.

- Countdowns follow the server's clock (`server_clock_countdown_test.dart`), from a time in
  whole seconds that arrives after the network trip: two phones can show numbers about a
  second apart. Closing it needs the server's time in the `/me/` body.
- Scanning and table links are built and not yet checked on a real phone; a native release
  build needs `PUBLIC_ORIGIN`, and the committed Android signing key is public on purpose
  (sideloaded installs only: `frontend/android/release-key/README.md`).
- A lobby answer's number (`rev`, #179) and a request's tap time (`asked`, #172) are sent or
  accepted by the server; the phone does not use them yet (items 1 and 3 above).
- Other looks are parked by the owner until Shadow paper is good.
