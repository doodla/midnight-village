# What the owner has said (newest first)

The owner plays the live app (web and an Android install) and reports what they hit. Their
words are the brief; do not soften them. Add to the top; move an item to "Done" with the
commit when it has shipped. In-flight state is here too, so a new session can pick up.

## 24 November 2026, playing the live app on an Android phone (412 points wide) and a friend's Pixel, in Chrome (verbatim)

> The game was very choppy.

> it felt like I was watching a ppt. Every tap was delayed and took a second to respond. I felt pretty bad watching it on my friends phone, which was a pixel. High end enough

> There was a lot of lag

They played in the browser (Chrome) and say it was everywhere.

> Explore all directions and improve systematically. Surface hard trade-offs if any. But in general, use your judgement

> let's add some atmosphere to the game as well. Use 11labs for the audio. The earlier sounds were just bad. I want something nice, eery and it should be loopable for the main theme. Think how classic balatro is. That feeling ( with an appropriate vibe ). Proper sfx as well.

> let's also work on visual atmosphere. The game should come alive now

> I'm looking for micro joy moments as well. It should feel like a labour of love 💞

OPEN. Measured (branch `perf-frames`): `just phone-frames` plays a whole game on a phone profile (the release web build, Chrome, CPU slowed 4x, or 1x and 2x for a fast phone) and reports, for every screen, transition and tap, the frames over 16 and 50 ms, the worst frame, the long tasks, the time to content, and for a tap the time to the first changed pixel, to its final state and to the server's answer; it fails when a budget is broken. The causes, ranked, are the next pieces.

Measured on the phone itself (branch `perf-field`): our lab Chrome has no graphics chip, so it cannot say what a Pixel does; the app now measures itself.
Open the game's address with `?perf=1` at the end (`https://midnight-village-app-anthelion.vercel.app/?perf=1`, or a table's link with `?perf=1`); the tab remembers it (`?perf=0` switches it off).
A thin strip at the bottom shows the last tap: "finger → screen 84 ms · request left 12 ms · answer 163 ms · worst 22 ms".
Play a round, tap the strip, tap "Copy report" and paste it to us (or "Copy everything" for the whole record).
It records the time of each tap from the finger to the first frame, the request it made leaving and its answer, the answer applied and the frame after; every frame per screen; every request, socket event and screen change; and the phone (browser, screen, graphics chip).
Nothing leaves the phone unless you copy it, and it holds no names, roles, cards or votes.
In the lab, `just phone-frames --perf <dir>` plays the same game with it on and puts the app's numbers beside phone-frames' own.

## 24 November 2026, playing the live app with friends: the start and play again (written, verbatim)

> updates are really slow. Someone starts the game and it takes forever for my screen to update. Same with restarts as well

> 5-7 seconds ish. But that feels like forever.

HANDLED (branch `start-lands-fast`): the socket and the server were fast; the phone was not.
A phone that missed `game_started` or `play_again` (its socket down at that moment, the phone
asleep) waited at 02 for the 15 s poll; now any lobby that says the table is in a game, the
socket coming back and the app coming back read where the phone sits at once. And the event
itself moves the screen (the dusk on `game_started`, 02 on `play_again`), the reads filling in
behind. `just phone-timing` measures tap to guest screen on a slowed phone against a budget.

## 24 November 2026, when an open app reloads itself to a new version (the owner's board: a button, not their words)

> Reload only when nobody waits

HANDLED (branch `reload-when-quiet`): the app reloads to a new version only at the first screen (01), or when the app comes back after a while away (the tab visible again after more than 5 seconds hidden, the notion the resume already had; no new timer). Never at the table (02, 03), never during a game, never right after "play again" (reaching 02 had reloaded at once and stalled some restarts on a full reload while friends waited). Known and accepted cost: a phone left open at the table across several games keeps the old version until then. The rule: `mayReloadNow` (`frontend/lib/features/game/domain/reload_rule.dart`); it replaces the 23 November rule (at once at a table before the deal).

## 24 November 2026, timers in the live game (verbatim)

> there's no timer in some stages, even though there's one under the hood

HANDLED (branch `your-card-clock`): the one stage the server timed with no clock on the phone was 04 Your card (the look stage, `card_look_seconds`); it jumped to the night when time ran out. Now 04 shows the time left in every state (before Ready, the card held open, after Ready, a restart): the night's candle and number, quiet, on the headline's banner, where the night board's clock stands. So it cannot happen again, every screen state the gallery draws is checked: a game screen whose `/me/` carries a deadline must draw a clock (`test/helpers/stage_clock.dart`, run by the screen sweep), and every timer the table can set is either a stage clock or on a short list of timers no phone counts down, each with why (the night's minimum window, a dropped phone's grace, the host's handover).

## 24 November 2026, 04 Your card in the live game (a screenshot of the Werewolf, verbatim)

> can we scale the image so the whole thing sits and showed in the frame?

HANDLED (branch `role-card-readable`): a role's art is never cropped. Every portrait is 3 by 4; the held card's window was as wide as the card and as tall as the words left, and the art covered it (the wolf's ears, hood and claw cut off). Now the window takes the art's own shape, as large as the room allows, the paper showing beside it (`HeldFace`); the sheet's portrait was already 3 by 4.

> There's a double label as well.

HANDLED: a team's tag beside a role's name never repeats the name (`RoleText.teamLabel`): the Werewolf team's reads "Werewolf team" (the Werewolf and the Minion, red), the others "Village", "Alone", "Copies"; the count's tag (10) is the same rule.

> I'd like the copy updated with different formatting so it's easier to parse

HANDLED: every role fills one structure (`RoleRules`): a small label ("Night", the Hunter's "Vote", "Wins") in a column beside short lines, one line per case; then "You are your last card." set apart under them. No role has more words than before (spec section 3, "Role text").

## 23 November 2026, a play-through with practice players (spoken, verbatim)

Handled by the deck-count piece (set-up page leave rule, the table's primary button, timer
names): the first "disabled button" item and the timers. Everything else is OPEN.

> Okay I'm finally seeing the game again after getting access to the practice players. There's a distinct lack of animations everywhere, which is okay.

OPEN (said "which is okay"; the polish passes cover motion).

> Also the stepper or card picker allows you to go over the limit so you can essentially go 10 or 8 or 12 or 8. It tells you that, yeah, you're over the limit but it allows you to leave the page. Now you're sitting on the main page with a disabled button that says "Deal to 5", which is not good. Just say "Start the game" or whatever. I guess most people would be confused, like, "What, what do I do?" Rather there should be some sort of nice text or error message or something that says, "Hey you can't go back to the game unless you correct the count."

HANDLED by this piece: the set-up page cannot be left with a wrong count (it says how many too many or too few, and its leave control says so); the table's primary button is never silently disabled and its label is plain. Reviewed and reworked (23 November 2026): 03's "Done" is always "Done" and its count line says what to do ("14 of 12 · Remove 2 cards"), the first "Done" or Back with a wrong count stays and nudges it, the second leaves; 02's one button says "Add 1 card" / "Remove 2 cards", "Need 3 players" / "Need {n} more" (players before deck) or "Start the game"; 01's "Start a table" and "Join a table" with no name take the cursor to the name field and nudge it; `PrimaryButton` and `SecondaryButton` cannot be built disabled without a reason.

> (Seen in the live app, 23 November 2026: a tab left open showed a blank red box where the Werewolf should be.)

HANDLED: an app left open now notices a newer build (`/commit.txt`) and reloads itself at a safe moment (23 November rule: at once at a table before the deal, in a game only when the tab comes back after a while away, never on a phase change; replaced 24 November, see the top of this file) and lands in the same seat on the same screen (nothing shown, nothing said; the rule is in `docs/dev/deploy-vercel.md`, "What an open app does when a new build goes live"); a file that is not there is a real 404 and never the app's page; and a file removed from the bundle without a retired copy fails a test (`asset_release_test.dart`).

> The timers aren't really explained as such but I guess that's a pretty minor thing.

HANDLED by this piece (a one-line caption under each timer's name, set once).

> Okay I've done that and now let's say I'm in the game. The vibration on the card after I press to reveal it, I don't like it so maybe get rid of it. The "My Night" thing seems like it floats: depending on where I tap it, it shows up in a different spot. The card, "What happened?" is kind of dumb. It should be like a pop-up or something.

DONE: no vibration anywhere on a card (`feel.md` section 3; `Haptics` has no call for it, and keeps only the day's pick tick, lock knock and count knocks). DONE: "My night" shows in one place, not above the touch point (first as a sheet from the bottom edge; decided on 23 Nov 2026, when the discussion screen became the square: press and hold the note on the discussion screen, and the night shows on the board from its top only while it is held; the count of who is ready is on the "Ready to vote" button). NOT done: "What happened?" as a pop-up. No text "What happened?" exists in the app; the only card of that kind is the night's story on 11 Results (the red line and steps in the page). To do: open it as the same sheet (`showSkinSheet`) from the existing night control (`_NightHead`), closed by default; update the spec's 11 lines with the date.

> I feel like instead of just the texts there, maybe we could have the images for the roles in the game, then results pages. It's just that things are too big, the texts, and you're kind of just trying to figure out what is important to read. The images are nice: "What, I was dealt this card and this is what they are now," but I feel like the name shouldn't be on the right side. The name maybe should be like the header of the card and then I can go to the "See who won" page.

DONE by the end board (pieces 1 to 5a; live with 5a): every player is a card with the role's image, the name as the card's header, and only three text sizes (`docs/specs/frontend/end-board.md`). The type tokens' change was the type-scale piece.

> What was the screen just before this? I feel a little redundant so maybe we merge those two to show a singular results screen.

DONE by the end board (piece 5a): the count, "See who won" and the results are one screen; "What happened" is part of it, replayed on the board itself. The old two screens' code goes in piece 5b.

## 24 November 2026, the end board's "What happened" on the live game (written, with a screenshot of "Robber Teapot takes Sridhar's card.")

> The links are not at all polished there are breaks.

DONE (branch `end-links`): a step's thread was tied between the corners of the box a tilted card fills, so on a turned card it began and ended in mid-air, and a pair side by side got a diagonal from one card's top to the other's bottom, with no heads. Now every link is one part, `CardLink` (`design_system/primitives/card_link.dart`): tied on the real card edges that face each other, a head at both ends of a take or a swap, a dot at the card seen (a look) or at both ends (a team), bent gently round every other card, seal and the lantern; a middle card is lifted onto the board beside the one who acted for its step (no thread down to the foot), and a card no clean thread can reach is lifted beside the other end the same way. `end_night_sweep_test.dart` holds the rule on every recorded night, at 360, 390 and 412 wide and text 1.0, 1.3 and 1.6.

> I think, yes, our design is still a bit weak. I'd like to see a few more mocks or a few more designs to see if we can show up all these issues.

OPEN: more mocks and designs.

> Give me your critique as well and let's also figure out which personas' review we need. Maybe not five people or whatever but if we have a good persona who's giving good critique, that would be nice. We can test it.

OPEN: critique and a persona test.

> You could blind test against my feedback to see if there's a persona that kind of gives feedback similar to ours (or at least would catch similar things that I do). Because I feel like this is not a game nearly ready to be Game of the Year, and I think the upcoming changes will help but I don't think they address everything I've mentioned.

OPEN: blind-test personas against this feedback.

Earlier the same day, on text sizes (OPEN, the type tokens):

> I realized why the text sizes still feel off. It's built from the mocks and what I think happened is the mocks have this. I didn't worry about it at the mock stage and they translated directly I guess. I guess that's why it feels still very odd to me that the text sizes are so huge. [...] the text sizes are much smaller, especially around the names.

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

## 22 November 2026, a card's details after Back, on 03 (live app; open)

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
  directly, 22 November).
- 22 Nov, same-address API trial (#66): it BROKE the live web app for about 30 minutes (23:15 to
  23:49 UTC) and was reverted (#68). Cause: Vercel's rewrite `/api/:path*` does not match a path
  ending in a slash, and every API path does, so calls got `index.html`. No local check can see
  Vercel's own forwarding. Not retried: a retry needs (1) `/api/(.*)` -> `.../api/$1`, (2) proof
  on a Vercel deployment's own address BEFORE it serves players (a slash path and a POST both
  answer JSON), and (3) the owner's yes. Live baseline to beat: Start 1.41 s fast, 2.78 s slow
  phone; Join 1.33 s, 2.60 s.

## 23 November 2026: the type scale (heard directly)

- "The text sizes ... are so huge ... especially around the names." Two scales were rendered; the
  owner chose: "Tight sizes, but keep the serif names." Names 16 in the serif, screen questions 24, body
  14, buttons 15, labels 12; the timers and the role on your own card stay as big as they were. The
  reading floor is now body 14, labels 12. Built: `docs/design/type-audit.md`. A design round follows
  for the room it freed.
