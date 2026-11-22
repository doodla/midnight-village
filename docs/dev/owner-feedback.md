# What the owner has said (newest first)

The owner plays the live app (web and an Android install) and reports what they hit. Their
words are the brief; do not soften them. Add to the top; move an item to "Done" with the
commit when it has shipped. In-flight state is here too, so a new session can pick up.

## 21 November 2026, from the live lobby (the owner was alone, so stuck there)

- "I need the number of players to be configurable and I need the settings page to be really
  configurable. I need to be able to edit everything and then wait for the number of people to
  appear. If I, as the host, say I want to set up a game for 8 people, then I should be able
  to do that." The host chooses the player count; the deck is for that count, not for whoever
  is at the table.
- "It makes no sense to see the deck face down in the setup... everybody should see what
  characters have been selected." The deck is always face up, for host and guests.
- "I can't edit any of the timers. I don't really need quick, long, normal timers. I just need
  the things to be editable." No pace chips; every timer is its own editable value.
- "I don't see the doppelganger timer configuration here."
- "The page says 'Scan to join' but it's a code so that's dumb." (Check the QR draws on web.)
- "If I leave the game it says 'Not sent, try again.' I don't know why it says that."
- The deck editor's only feedback was a greyed button flipping between "Add N cards" and
  "Remove N cards"; they read "Add 2 cards" as "add players".
- Back (the phone's back button, the browser's) and loading states are "not at all handled".
- "It took 3 or 4 seconds for things to load and I have no idea what's happening." "It takes
  so long to open the app."
- The Android install looked like "a generic Flutter thing" (icon, name, launch screen). Keep
  the application id `com.midnightvillage.midnight_village`.
- One person alone cannot try the game (needs 3). Workaround to suggest: the join link in two
  private browser windows. Proposed next: practice players (computer-filled seats).
- Unclear, asked back: "Start making polish puzzles" (read as: start polish passes).

## How they want the work run

`docs/dev/running-the-work.md`.

## In flight (22 November 2026)

- Set-up page: host-chosen player count (`seats`), every timer editable, deck always face up,
  the "Scan to join" wording, the leave bug. Worktree `agent-a6a63f89cd81af037`, being built;
  then one review, pictures for the owner, its own pull request.
- Back, loading and speed: the audit is done, `docs/dev/audits/back-loading-speed-audit.md` (worst ten,
  the rules, the mechanisms, where the seconds go). Fixes start after the set-up page lands
  (same files), as small pull requests: back, then loading, then speed. Keeping the server
  warm and moving the database are proposals for the deployment session only.

## Done

- Android and web first impression (icon, name, launch screen): pull request 6, merged
  (06d0468). The deployment session was asked for a fresh Android install file.

## Relayed by the coordinating session, 22 November 2026 (not heard directly; confirm with the owner)

- Practice players: yes, "but hidden enable so it's not visible to everyone. I'm thinking long
  press on an element or something". Switched on by a hidden gesture on an existing element;
  nothing visible to ordinary players. Not started; after the set-up page.
- "Polish puzzles" was a typo for "polish passes".
- Six sample looks: "Dunno what you mean by sample looks." They do not recall seeing them, so
  show them again properly: https://claude.ai/artifact/7rsphhNPs5Uypyqbj4QiH2

## Waiting on the owner

- A reaction to the six sample looks (link above). No more look work until then.
