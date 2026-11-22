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

- The owner, live app: "After I back after viewing a card's details. Can't see another cards
  details till I remove/add a card from the deck." Then a recording (web, Chrome on Android,
  gesture navigation, 22 November), read frame by frame with Android's touch trace. Fixed,
  not yet tried on a real phone:
  - One back swipe closed the card's sheet and also left 03 for 02. The swipe starts as a
    touch on the page; it dragged the sheet down fast enough to close it before Android took
    the touch, so the Back that followed did 03's Back too. Sheets are no longer dragged
    (`showSkinSheet`): the same in 02's leave question and 08's role sheet.
  - The holds that "opened nothing" lasted 0.40 and 0.43 s; a card opened its sheet only at
    0.5 s (the holds that worked were 0.57 to 0.73 s; taps under 0.1 s). Nothing was stuck: a
    longer hold worked straight after. A card's hold is now 0.3 s (`RoleCard.holdDelay`).
  - Owner, 22 Nov, on that reading: "Wrong. I held it a long time." The clip shows only the two
    short presses, so a long hold that opens nothing after backing out of a card's details is
    NOT ruled out: not reproduced, not fixed. Open until a new recording or a hunt settles it.
  Both shown before and after in a real Chromium with touches, against a release build.

- Back, loading and speed: the audit is done, `docs/dev/audits/back-loading-speed-audit.md` (worst ten,
  the rules, the mechanisms, where the seconds go). Fixes start after the set-up page lands
  (same files), as small pull requests: back, then loading, then speed. Back is built (branch
  `fix-back-policy`, not merged yet): one policy for the phone's and the browser's Back. Keeping the server
  warm and moving the database are proposals for the deployment session only.

- Loading, failing and busy states (issue 10), built on branch `worktree-agent-accfac18dd0dae241`, not yet merged: every
  player request goes through one door and the tapped control shows busy until the next screen is up;
  one waiting body (three paper lanterns, "Still on its way." after 5 s, "One moment" with
  "Try again") in the frame of every screen that waits; a picture for every loading and error state
  (`just screens`) and four looping clips (`just loading-clips`). Still open: 02's and 03's own waiting
  and busy lines (held with the practice-players session), the first paint before Flutter (white page,
  Android launch), the 10 s request timeout.

## Done

- Practice players (issue 26): on the set-up page, press and hold the word "Players". A
  "Practice" stepper then seats village things (Scarecrow, Teapot, ...) with their own tokens
  and the word "Practice"; the server plays them. Set it to 0 and hold again to hide it. A
  person has practice players at one table at a time; closing the table removes them.
- Back (issue 9): one policy for the phone's Back and the browser's. 01 leaves the app; a
  waiting table asks Stay / Leave; the set-up page returns to the table; in a game Back does
  nothing, only Leave exits; whatever is open on top closes first, and any sheet closes when
  the screen under it changes. Not tested on a real Android phone or a real phone browser.
- A seated player is never stranded, and the app opens with fewer requests (audit items 4
  and 6): the saved account is restored by itself until the server answers, no new account
  is made over a saved one, a deleted account gets a clean fresh start, a lost renewal answer
  no longer costs the seat (the old refresh token is no longer cancelled on renewal), and
  opening in a game is 2 requests at once where it was 4 in a row.
- Set-up page (issue 7): the host picks the number of players, every timer has its own
  stepper (the Doppelganger's only while the card is in the deck), the deck is face up for
  everyone, a "picked / needed" counter, "Scan to join" only on a QR code, and leaving no
  longer says "Not sent." Practice-players proposal: `docs/specs/onuw/solo-play-proposal.md`.
  Still weak: "Play with 3" shows as soon as three are here.
- Android and web first impression (icon, name, launch screen): pull request 6, merged
  (06d0468). The deployment session was asked for a fresh Android install file.

## Relayed by the coordinating session, 22 November 2026 (not heard directly; confirm with the owner)

- Practice players: yes, "but hidden enable so it's not visible to everyone. I'm thinking long
  press on an element or something". Switched on by a hidden gesture on an existing element;
  nothing visible to ordinary players. Built (see "In flight").
- "Polish puzzles" was a typo for "polish passes".
- Six sample looks (https://claude.ai/artifact/7rsphhNPs5Uypyqbj4QiH2): "Skip till our default
  is good". Parked: no other looks until Shadow paper is good.
- Polish passes: "include design improvements as well. Make the game look prettier and feel
  better, without costing usability". Screen by screen, after that screen's fixes land; before
  and after pictures to the owner; no added waits.
- "Include vibration." (The coordinating session's reading: light, on day screens such as
  locking a vote, the card flip and Ready; never at night.)
- "The bar is a game that can win awards. Micro interactions matter." Every touch answers at
  once; the small moments (press, lock, join, error, empty) are designed, not default.
- New art is fine: "Use the image gen" (said directly, 22 November). A piece may make the
  Shadow paper art it needs without asking first; the owner sees it in the pictures before merge.
- From the owner's board, 22 November (relayed): the Doppelganger timer shows only "when it's
  in the game"; renaming yourself at a table: yes; back during a game does nothing, only Leave
  exits; polish passes 1 to 8: "Do it"; "See 1 or 2 cards is ambiguous" (the night wording is
  being reworked by the coordinating session); sounds: none for now; "The text sizes on the
  main screen feel a bit too big" (first screen and table; options going to the board).
- Haiku workers: "Use haiku where you can trust it. It's much faster and cheaper." (said
  directly, 22 November). What it can be trusted with: `docs/dev/haiku-trial.md`.
