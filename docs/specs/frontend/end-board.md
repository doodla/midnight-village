# The end board: final design and build spec (23 Nov 2026)

This is the design round's spec, kept in the repo and updated to what is built (piece 2, the static board, and its
fixing pass). Where the build and the round's mocks differ on purpose, it says so. The mocks themselves stayed with
the design round; the build's pictures come from `just end-pictures` (in `frontend/`).

For Flutter builders who have not seen the rounds before this one. Everything here is decided; where something is
still open it says "open" and who decides.

## 0. What this is, and what it replaces

At the end of a game every phone shows one screen: **the end board**. It is a notice board in the village square at
dawn, lit by one lantern. A banner says who was hanged and whether you won. Every player's card is pinned on the
board. The winners are bigger and sit in the lantern's light, and the hanged carry a black ribbon. The votes hang
as name tags under the card they chose. At the foot are "What happened" (the night, replayed on the board),
"Edit deck" and the one amber control, "Play again".

The owner's decision (23 Nov 2026): round four's board and light, with round three's bottom. That means the
smaller "What happened" and "Edit deck" scraps, and more air between the scraps, the middle cards and the plaque.

**It replaces two screens and one tap. All three go away:**

| Today | File (under `frontend/lib/`) | Goes |
|---|---|---|
| 10 The count | `features/game/presentation/shell/count_screen.dart` (`CountScreen`, `CountView`; `EndWaiting` moves to the new screen) | deleted |
| 11 Results | `features/game/presentation/shell/results_screen.dart` (`ResultsScreen`, `ResultsView`, `ResultsAct`) | deleted; its Play again / Edit deck / Leave logic (`Pending`, host or guest) moves to the new screen |
| "See who won" | `features/game/presentation/table_screen.dart` (`StepRecord.wonPrefix`, `LocalStepsNotifier.seeWhoWon`), `features/game/domain/screen_table.dart` (`AppScreen.count`, `AppScreen.results`), `features/game/presentation/shell/table_shell.dart` (lines 274 to 279), `design_system/copy/copy.dart` (`CountCopy.seeWhoWon` and the rest of `CountCopy` and `ResultsCopy` that is no longer used) | removed; one `AppScreen.end` |

The tests and harness words that go with them are in TICKETS.md, piece 5.

Pictures: the design round's `sheet-final.png`, `sheet-motion.png`, `compare-final.png` and single phones in
`png/` (not in the repo). The build's own: `just end-pictures` (every outcome at 360 x 780, a 360 x 640 phone, text at
1.3 and 1.6) and `just screens`.

## 1. Rules that hold everywhere

- **Four text sizes:** 40, 24, 16 and 12. This screen uses only three of them:
  - 24 (Gloock): the banner.
  - 16 (Gloock): names, tags, scraps, slips and the plaque.
  - 12 (Figtree Bold): role strips, and HANGED on the stamp, in capitals.
- **Names are 16 Gloock and are never cut.** A card is always as wide as its name needs (section 3). The audit
  checks this.
- **Contrast:** at least 4.5:1, measured on what is really behind the letters. The lowest on any final phone is
  4.71 (`audit.txt`). The one flag is in 1d: there, the labels of the cards that have scrolled under the bottom band
  are measured although they are hidden.
- **One amber control: Play again.** It shows only on the host's phone. A guest's phone has none.
- **Touch targets:** each is at least 48 pt tall, even where the scrap looks 40 pt. The extra is invisible padding
  (the dashed boxes in `0-anatomy.png`).
- **One light: the lantern.** Every shadow falls away from it. Cards further from it are a little darker. While What
  happened plays, the moon is the light and the lantern is out.
- **One death mark: the black ribbon.** HANGED is a stamp seen only during the reveal (beats 3 and 4b), then it lifts off.
- **Vote tags** hang on one length of twine from the pin at the bottom-left of the card they voted for.
- **The dealt card** is a small, older card tucked behind its own card's top-left corner. It shows only when the
  dealt role differs from the final one.
- **Hidden information:** everything on this board is public once the game has ended. Only two things differ from
  phone to phone: the wax seal ("you"), and the banner's second line.
- **No added waits:** the reveal uses existing motion tokens. One tap finishes it. Every control works from the
  first frame.

## 2. Anatomy

The numbers match `png/0-anatomy.png`. Positions are in pt on a 360 x 780 phone. Data comes from
`GET /onuw/games/<id>/results/` (fields in `code`), plus `GET .../me/` for who you are and who hosts.

| # | Element | Role | Size, type token | Data |
|---|---|---|---|---|
| 1 | Sky: the square at dawn (sky plate under a purple dusk, gallows on the hill, far and near roofs, two crows): the banner is the bright thing in it | the place and the hour | full width, 0 to the board's top. The dusk is the skin's (`PaperParts.duskTint`), laid over the sky plate only | the gallows carries a small disc showing the **first hanged player's `token`**. With nobody hanged it shows none |
| 15 | Banner | the result in one sentence, in two lines | three-piece slice, 128 tall for two lines at 24, and as much taller as its words measure past that (a third line, a larger text size): the paper round the words stays as drawn and the middle stretches, so it never clips (`BannerSlice.heightOf`). Top 36 on a phone 780 tall, 10 on one 640 tall, in between by the height (`EndMetrics.bannerTopFor`); the board starts 4 under it. Tilted -1.2°. Its width is the text plus both ends, and it may run past the screen's edges. Text 24 Gloock, centred: ink `#14172f` on bone, or `#f6ecd6` on the red banner | line 1 from `eliminated_players` (in death order, below); line 2 from `winning_teams` and the caller's own `outcome` and `team`. Red when the Werewolf team wins, or the Tanner (and not the village too); bone otherwise, whoever you are (the build's rule: the round's 1h mock shows red for a guest who lost to the village, and is wrong there). Copy: section 4 |
| — | Roof | the board's top | `roof4` three-piece, x 120 to 509 stretches, 30 tall above the board | — |
| 16 | Board: frame and felt | where everything is pinned | x 2 to 358, top 168, bottom 632. `frame4` nine-slice; the frame is about 19 pt. Felt `#20234a` (night `#191b3a`) with grain, and three dim torn notices behind the cards | — |
| — | Posts | the board stands on the cobbles | `post4-l/-r`, 15 wide, 18 showing | — |
| 2 | Lantern | the one light | `lantern` 88 wide (152 tall), flipped, hung from the board's top-right at x 272, y 162. Light point = the centre of its panes. Warm glow: radial, 180 across, screen blend | lit, except while What happened plays |
| 6 | Pool of light | warmth on the winners | radial amber `255,184,96` at 25%, screen blend, over the living winners' cards, pulled 25% toward the lantern | the cards with `outcome == "win"` and `is_eliminated == false` |
| — | Vignette | one light, falling off | two radial darkenings: 60% around the lantern, 32% at the edges | — |
| 4 | Player card | one per player | name header 22 tall (16 Gloock; taller with larger text), portrait window 4:3 cut at the face with headroom (focus 22% down), 10 of paper under it, and the role on a tab 17 tall (12 Figtree Bold), as wide as the role and 5 each side, glued over the portrait's foot 1 above the card's. Width = the largest of: portrait + 8; name + 20; role + 18, using the wider of the dealt and final roles (+ 28 when it carries tags, to clear the pin). Portrait: winners 90 wide, losers 64 (section 3). Paper: winner `#f4e8cb`; loser `#c9c0aa`, portrait desaturated (0.55) and darkened (0.78); werewolf team red (`#9a2c25` won, `#7b231e` lost); night `#cfd2e2`. Tilt ±2°, seeded (section 3) | `display_name`, `final_role` (portrait and label), `team` (red paper when `werewolf`), `outcome` (lit or lost), `seat` (order). **Doppelganger:** the face shows the copied role from `night_timeline` (the `copy` step's `copied_role`), and the strip reads "Doppelganger". With no timeline it shows "Doppelganger" (section 7) |
| 3 | Dealt card | where this card started | a small card 34 to 40 wide (0.38 x portrait), 1.3 tall, tucked at (-30% w, -50% h) behind the top-left corner, turned -13°, sepia portrait, no words | `original_role`, only when it differs from `final_role` |
| 4 | Wax seal: "you" | which card is yours | `marks-1` 30 pt, pressed with **your own sigil** (`token`, greyscale, screen-blended). On the card's right edge, 44% down, 14 pt over the edge, so tags, ribbon and dealt card never cover it | the caller's `player_id` from `GET .../me/`. **The results body does not say who "you" are** |
| 7 | A hanged card | who died | same card, raised higher (bigger shadow), turned ±3° | `is_eliminated` |
| 9 | Ribbon | the one death mark | `marks-4`, 30 to 38 (0.38 x portrait), so it reads at arm's length, pinned on the top-right corner and turned 14°, with a bone edge so it reads on red. 92% of it hangs outside the card, clear of the name | `is_eliminated` (by vote and by the Hunter alike) |
| 10 | Pin and twine | ties the tags to the card | a paper disc of 10 at the card's bottom-left (x + 8, bottom - 6). The twine is a sagging quadratic curve with a soft shadow away from the light | — |
| 8 | Vote tags | who voted for this card | a tag of bone paper, its left end cut to a point, at least 26 tall and as tall as its name at the phone's text size: punched hole, the voter's sigil in an 18 circle, their name in 16. Each tag stands apart: the first 4 under the card's lowest corner, then 4 between tags. More than three hang in columns, as many as fit (two in the card's own slot, up to three when the strand has the row: a card alone on its row, or beside one with no tags that is not the Hunter's pick; then the strand hangs under the lower of the two cards). They are pushed sideways to stay inside their room and never lie on a card | every player's `vote_target_id`, grouped by target, in the voters' seat order. **Shown under the hanged cards only. When nobody is hanged, they are shown under every card** (each has at most one). Players who did not vote (`null`) have no tag |
| — | The Hunter's pick | why a second card died | bone twine between the two cards (red twine is the Werewolves' alone; the Hunter is the village's), with a slip, "Dev's pick" (16), hung between them where it covers no name, role, tag, seal or ribbon, and as little of either card as it can. One per Hunter the vote took who took someone | the player with `elimination_reason == "hunter_chain"`, and the eliminated Hunter (final role Hunter, or a Doppelganger who copied the Hunter) whose `vote_target_id` is that player |
| 11 | What happened | replays the night on this board | torn bone scrap as wide as its words, 40 tall, at the foot's left, turned -3°, flat iron pin, 16 Gloock. Touch target 48 tall. Where one line leaves the middle cards no room beside it, its words go on two lines ("What / happened", 48 tall); where two lines do not either, the middle cards take a row of their own above it. While the night plays it reads "The result" (same place, as wide) | shown when `night_timeline` is not null; hidden otherwise |
| 12 | The middle cards | the three cards nobody held | no name; portrait 44 x 33; role tab 12. Width = role + 12 (at least 52). Face up, level, side by side, right-aligned, 3 apart; past the width they have they wrap to a second row (large text). Never a pile. In the fixed band | `center_cards` (final). At night: `night_timeline.dealt.center` and then each step's `positions_after.center` |
| 13 | Edit deck | host: back to the table with the deck open | scrap as wide as its words and the busy mark's room at its end (it sends a request), 40 tall, at the foot's left under What happened, turned 2°. Touch target 48. Busy (`Pending`), the mark turns in that room and the words stay in place, whole, in full ink, as on Play again | host only (`is_host`) |
| 14 | Play again | host: the one action | amber paper `#e0a03e` with a deckled edge on a darker backing `#4a2a12`, in the type scale's large button label. From Edit deck's right (12 apart) to the foot's right, 50 tall (taller with larger text) | host only. Busy and failed states as on today's 11 (`Pending`: "Not sent." / "Try again"). Busy, the mark turns in its own end padding and the words stay |
| — | Guest's foot | a guest waits for the host | "Leave": a scrap, touch target 48, busy as Edit deck is (the round's dark `#252849` scrap is not built yet: the build's is bone). "{host} deals next.": plain words beside it, wrapping, not a control and not a slip. No amber | `is_host == false`; `host_id` gives the name, and it shows only while the host is at the table (as today) |
| — | Cobbles | the ground | `cobbles` under the board's foot | — |

Things this screen no longer shows:
- the words "Won", "Died", "Village", "Alone" and "Werewolf team": light, size, ribbon and red paper carry them;
- the count rows and "No vote: {names}": the tags carry the votes;
- the server's `reason` text.

## 3. The layout rule, 3 to 10 players

The layout is pure Dart and does not depend on what is showing at the moment. Night faces, hidden tags and the
reveal never move a card. It is computed once from the results.

1. **Order.** Living winners in seat order, then living losers in seat order, then the dead, in the order they died:
   - killed by the vote first, in seat order;
   - then the Hunter's pick.
The foot (11 to 14) is laid out by measurement: two rows as tall as what is in them, at the phone's text size, with
18 of air above, 12 between and 18 below on a phone 780 tall, 8 each on one 640 tall. The board's window is what is
left between the banner and the foot.

2. **Rows of two.** If the living players end on a single card and somebody died, that card joins the dead in the
   last row, with the dead on the left (`1a`: Cleo hanged with Ben beside her). A single card left on a row is centred.
3. **Slots.** Each row has two equal slots across the board's inside (about 311 pt). The first row stops at the
   lantern (x 276), so its slots are about 125. A card is centred in its slot and keeps at least 6 pt clear on each
   side.
   - A name that does not fit its slot takes a row on its own. A 20-character one-word name, about 170 pt at 16, is
     always on its own row.
   - If a first-row name does not fit beside the lantern, swap it with the next row's narrower card.
4. **Sizes are fixed.** Winners' portraits are 90 pt wide and losers' 64 (1.4x).
   - With 5 players or fewer, each row grows up to 1.3x as far as its own room lets it while it keeps its cards (the
     first row stops at the lantern; the rows below have the width), then all of them less until the board fits
     (`1c`).
   - Cards are never made smaller to fit.
5. **Vertical.** Each card keeps 12 under whatever stands above it (a card, a strand of tags, the lantern); its
   dealt card and its ribbon keep 8 under whatever stands above them, not under the whole row. A tilted card is
   measured by its turned corners. Below a row: room for the longest strand of tags in it. Spare height is shared
   between the rows, at most 40 to a gap; the rest goes above and below, so a small group stands centred.
6. **Tilt.** ±2°, seeded from the player's `player_id`, so the same card tilts the same way on every phone and every
   screen. Plus a ±2 pt vertical jitter from the same seed. Cosmetic, not game randomness.
7. **Ties.** Every hanged card sits in the dead row(s), each with its own strand of tags (`1d`, `1e`).
8. **Nobody hanged.** No dead row and no ribbon. Every card carries the one tag of the player who voted for it
   (`1b`). The gallows hangs empty.
9. **When it does not fit: the board scrolls.** **This is the 10-player rule.**
   - The rows never shrink. The board grows downward and scrolls between two fixed parts:
     - the sky, the banner and the roof, which becomes a fixed eave the board slides under;
     - the bottom band, whose torn cobble lip, with a soft shadow, overlaps the board's foot.
   - The lantern, the pool and the shadows belong to the board and scroll with it. Shadows are computed in board
     coordinates, so nothing is recomputed while scrolling.
   - **Six or fewer fit one screen, as far as the hard rule lets them** (the owner's wish: up to six players fit a
     360 x 780 phone with no scrolling; cards never shrink; bigger tables scroll). A board of six or fewer that would
     scroll closes up in steps (`EndFit`, `features/game/domain/end_board_metrics.dart`), loosest first:
     - *loose*: the board as rules 1 to 8 lay it;
     - *close*: a long strand of tags may take the row beside the Hunter's pick too (the slip hangs between the two
       cards), strands of two or more hang side by side where they fit, and a hanged card slides along its slot so
       its ribbon clears the card above;
     - *closest*: the air between rows down to its least (8 under a card, 6 above what a card holds up).
     It takes the first step that fits. **The hard rule never bends**: what hangs on a card (tags, the Hunter's slip,
     a seal, a ribbon) covers no other card and no name (`coversNothing`). A step that would make a piece cover one is
     not taken; a board that still does not fit stands at the tightest clean step and scrolls. The rule as tested
     (`end_board_rules.dart`, in the domain tests and in the sweep on the real fonts alike): for six or fewer, IF the
     board scrolls THEN every step tighter than its own would cover something. Every recorded game of six fits a
     360 x 780 phone at text size 1 at some step, for every viewer; a three-and-three tie or names too long to share
     a row may scroll. The Hunter's slip looks for its place anywhere between the two cards (and 40 round them),
     against the ribbon as drawn (turned).
   - **Where it opens** (`openingOf`, `features/game/domain/end_board_open.dart`). Opened down the board at all, the
     eave cuts a card, at least 14 pt of it showing, as the lip cuts one below: it is plain there is more above.
     Within that, it shows whole above the lip the most of: the hanged with all that hangs on them and your own card;
     else the hanged with all that hangs on them; else the hanged's cards (their tags go under the lip); else the
     vote's dead (the Hunter's pick further down). The test states it the same way: whatever some opening that keeps
     the cut could show, this one shows. When that is the top, the first view shows the banner and the winners
     under the lantern, and the next row is cut by the lip, which says "more below" without words. The round's 1d
     (ten players at the top, the hanged out of view) is the board scrolled back up.
   - From 7 players it scrolls. A 360 x 640 phone, or larger text, scrolls sooner.
   - Why: the owner found round three "too busy" and asked for calm. The one-screen version needs 48 pt portraits,
     winners at only 1.25x and five cramped rows (round four's `1f`). Scrolling keeps every card, name and tag
     exactly as it is at 6 players, and the rule stays the same at every count.
   - Use a `SingleChildScrollView` with clamping physics inside a `ClipRect`. No scroll bar and no hint words.

## 4. Copy

Two lines, at most, at 24. They come from the payload, and every phone builds its own second line.

- **Line 1, who died:**
  - "{a} hanged." / "{a} and {b} hanged." / "{a}, {b} and {c} hanged."
  - With the Hunter: "{a} hanged, {b} too."
  - "No one hanged."
- **Line 2, you:**
  - When you won: "You and the village win." / "You and the Werewolves win." / "You win alone." (the Tanner).
  - When you lost: "You lose to the village." / "You lose to the Werewolves." / "The Tanner wins. You lose."
  - When nobody won: "Nobody wins."
  - With two winning teams, name the one you are with; if you are with neither, name the first in `winning_teams`.
- If a line is wider than about 320 pt (long names), the banner takes a third line: its middle band stretches in
  height (`centerSlice` `Rect.fromLTRB(300, 140, 1130, 330)`). It never goes smaller than 24.
- **Steps of What happened:** in the banner, one line a step, each leading with the role (section 8, "The lines").
- **Controls:** "What happened", "The result" (at night), "Edit deck", "Play again", "Leave" and "{host} deals next.";
  the first time only, the cue "Go on".
- This changes first-time-play section 3: 10 and 11 become one screen. The headlines there say "{name} dies." The
  owner has seen and kept "hanged" since round two, so **update the spec in the same change** (TICKETS, piece 5).

## 5. Assets

**Already in the repo (`frontend/assets/`), used as they are:**
- `skins/shadow_paper/roles/*.webp`: portraits for every role, the dealt cards and the middle cards.
- `skins/shadow_paper/tokens/*.webp`: sigils, on tags, the seal and the gallows.
- `skins/shadow_paper/layers/dawn_gallows/`: `sky_plate`, `gallows`, `roofs_mid` and `roofs_near`, through
  `LayeredArt` / `SceneLayer`.
- `skins/shadow_paper/layers/night_village/moon.webp`: the night of What happened.
- The table's card back, through `CardBackScope`. The mocks show `card_back_moon`.
- Fonts: Gloock and Figtree Bold.

**Mock ornaments, generated in rounds 3 and 4.** They are in `final-end/assets/` (PNG with alpha). Each must be
accepted by the owner as final art, or redrawn.

| File | Made | Used as | Displayed | Proposed in-app file (webp, @3x max) |
|---|---|---|---|---|
| `banner.png` 1460 x 477 | round 3, generated (cut-paper swallowtail with laurels) | banner, three-piece | 128 tall | `end/banner.webp` |
| `banner-red.png` 1460 x 477 | **generated 23 Nov 2026 with the owner's yes**: `banner.png`'s original edited into dried-blood red paper (one image, first try; same silhouette, folds and laurels; `PROVENANCE.md`) | banner when you lost | 128 tall | `end/banner_red.webp` |
| `frame4.png` 666 x 863 | round 4, generated | board frame, nine-slice `Rect.fromLTRB(99, 102, 570, 761)` at scale 0.19 | about 19 pt frame | `end/frame.webp` |
| `roof4.png` 629 x 140 | same image as the frame | roof, three-piece x 120 to 509 | 30 tall | `end/roof.webp` |
| `post4-l.png` 79 x 147, `post4-r.png` 81 x 148 | same image as the frame | the posts | 15 wide | `end/post_l.webp`, `end/post_r.webp` |
| `lantern.png` 677 x 1170 | round 3, generated | the lantern | 88 x 152 | `end/lantern.webp` (264 x 456) |
| `crow4-1.png` to `crow4-6.png` | round 4, generated (flat single-layer crows) | crows in the sky; five lift in reveal beat 4 | 22 to 104 wide | `end/crow_1.webp` to `end/crow_6.webp` |
| `cobbles.png` 1467 x 816 | round 3, generated | the ground | full width | `end/cobbles.webp` |
| `marks-1.png` 430 x 430 | round 3, generated (blank wax seal) | "you" seal | 30 | `end/seal.webp` (90 x 90) |
| `marks-4.png` 382 x 482 | round 3, generated (mourning ribbon) | death mark | 24 to 34 | `end/ribbon.webp` |

**Drawn in code (no art):**
- felt, grain and notices;
- pins, twine, tags, scraps, slips, the plaque, the stamp and its ink burst;
- glow, pool and vignettes.

The paper grain should be one small tileable texture made in code (a noise PNG), not generated.

**The owner's rule: "ask before generating large batches of art."** The smallest set is **no new generation at
all**: accept the nine kinds above as final art, shown to the owner on `sheet-final.png`. The one honest exception is
`banner-red.png`. It was a recolour, and "a look is never a recolour or filter", so it became one new generated
image: the same ribbon cut from dried-blood red paper. **Done: generated 23 Nov 2026 with the owner's yes, one
image** (`PROVENANCE.md`); the old recolour is kept only for the record as `gen/banner-red-round4-recolour.png`. Folder
`frontend/assets/skins/shadow_paper/end/`, listed in `pubspec.yaml`. The art contract test checks the sizes.

## 6. How each piece maps to a widget

New code lives in `features/game/presentation/end/` (the screen), `features/game/domain/end_board.dart`
(layout, pure Dart, no Flutter), `end_banner.dart` (copy) and `end_story.dart` (What happened, from `NightTimeline`).
Reuse the existing domain where it already does the job: `GameOutcome`, `outcome_view.dart` (`EndSeat`,
`Winners`, `NightLine`) and `night_timeline.dart`.

| Piece | Widget |
|---|---|
| Sky (dawn and night) | `LayeredArt` with `LayeredSceneId.dawnGallows`. At night, cross-fade a night tint and lay `night_village/moon` over it (`SceneLayer`) |
| Banner | `OverflowBox` + `Image.asset(centerSlice: …)` (a three-piece slice is a nine-slice whose middle runs the full height) + `Text` 24 |
| Board frame, roof | `Image.asset(centerSlice: …)` over a felt `DecoratedBox` (colour + tiled grain `ImageShader`) |
| Lantern, glow, pool, vignette | `Image` + `DecoratedBox(RadialGradient)`. The pool is a `CustomPaint` with `BlendMode.screen` |
| One light | a new `OneLight` `InheritedWidget` (the light point, in board coordinates) and one function `paperShadows(rect, elevation)` that returns `BoxShadow`s thrown away from it. Every card, tag, scrap and pin uses it. Brightness fall-off: a `ColorFiltered` matrix per card |
| Card | a new `BoardCard`: a paper `Container`, name `Text`, `ArtPicture` portrait in a 4:3 `ClipRRect`, role strip. `Transform.rotate` for the tilt. A `Stack(clipBehavior: Clip.none)` for the dealt card (behind), ribbon and seal (over) |
| Turning a card | the existing `PaperFlip` (its own `turn` 160 ms) |
| Wax seal | **`PaperSeal` does not exist yet: build it.** `seal.webp` with the player's token (`PlayerToken` art) at 52%, greyscale, screen-blended |
| Vote tags | a new `VoteTag`: `ClipPath` (notched) + punched hole + `PlayerToken` art + `Text` 16 |
| Twine | `CustomPainter`: quadratic segments, a 2.2 stroke, a blurred offset shadow path, dashed for a look |
| Scrap, slip | a new `PaperScrap` / `PaperSlip`: `ClipPath` with a seeded torn polygon + grain + pin + `Text` 16. The touch target is an outer `SizedBox(height: 48)` with `HitTestBehavior.opaque`, wider than the paper where needed |
| Plaque | the existing `PrimaryButton` (the amber control), given Shadow paper's plaque shape: deckled `ClipPath` twice, backing and face. It keeps busy and pending exactly as today |
| Stamp and ink burst | a bordered `Container` + `Text` 12 caps, and a `CustomPainter` for the burst (beat 3 only) |
| Crows | `Image` + `Transform` |
| Scroll | `ClipRect` + `SingleChildScrollView`, between the fixed eave and the fixed band (section 3, rule 9) |
| Waiting for results | today's `EndWaiting` (the dawn ground, the lanterns after 300 ms, "One moment") |

## 7. What the payload does not carry, said plainly

1. **Who "you" are.** It is `player_id` from `GET .../me/`, not from the results body. The seal and banner line 2
   need it.
2. **The host's name for a guest.** It comes from `GET .../me/` (`host_id`, `players`), and presence from the table,
   as today.
3. **The Doppelganger's copied role** is only in `night_timeline` (the `copy` step). If the timeline is null, the
   card shows "Doppelganger" and its own portrait.
4. **The tilt seed.** Derived on the phone from `player_id`. It is cosmetic.
5. **Who is a practice player.** That is in `/me/`'s `players`, not in the results, and nothing on this board needs
   it.

Everything else on the board comes from the results body. That covers dealt and final roles, teams, outcomes,
deaths and why, every vote, the middle cards, the night and every sigil. No server change is needed.

## 8. Motion

Tokens are from `docs/design/feel.md` section 2 (`Motion` in `design_system/layout/space.dart`). No literal
durations.

### The reveal, in place (`png/2-reveal-1` to `-5`)

It plays once, when the results arrive while this phone is in the game (the phase change to `results`). A phone that
opens or restarts in the results phase shows the settled board at once. Nothing is kept on the device: this replaces
`StepRecord.wonPrefix`.

As built (piece 3 and its fixing pass): the timeline is `revealOf` in `features/game/domain/end_reveal.dart`, pure and
tested on every recorded sample; the widgets read it off one clock.

| Beat | What moves | Tokens |
|---|---|---|
| 0 | The board shows every card face down in the seat it keeps, every back with one portrait size (the least on the board, so no back says who won or who hangs) and a bone edge round it and round the game's card back. The board already stands where the settled board opens (scrolled to the dead on a tall board): nothing scrolls and no seat moves. The banner lies furled on the roof (`FurledScroll`). The middle cards face down. The bottom band is whole and live | — |
| 1 | The held beat: nothing moves | `reveal` 400 ms (the owner's no-added-waits rule: shorter than the round's `beat`) |
| 2 | The first death lifts out of its seat to the middle of the window, its art filling the card, a set share of the board wide (`RevealMetrics.bigWidthShare`), turned 3° and in the lantern's warm light, turning face up on the way (the back grows into the face's size edge on, so nothing is ever drawn smaller than it is). The board dims, still seen | lift `settle`; turn `quick` landing at the lift's end; dim `quick` |
| 3 | The face is seen whole for a moment, then HANGED slams onto the card's lower edge, under the role's tab (a narrow plate in a double bone rule with bone lines bursting out, `InkStamp`), at its own size. **A knock** (below). The banner is taken up off the roof and unrolls down, once | seen `quick`; stamp `press` (`Motion.land`, stopped at its own size); banner `scene` |
| 4 | It holds, then drops back to its seat; the stamp lifts off and the ribbon is pinned on | hold `reveal`; drop `settle`; ribbon `press` |
| 4b | **Each further death** (the Hunter's pick, a tie's other) gets its own beat once the one before is back in its seat: a shorter lift, stamp and knock, held less. The Hunter's pick lands smaller (`pickShare`) and turned the other way; its twine and slip come on as it lands back | lift `settle`; seen `press`; stamp `press`; hold `settle`; drop `settle` |
| 5 | As the last death drops, every other card turns where it sits, row by row (a winner's card grows to its size as it turns); the middle cards with the last row. Then the dealt cards and seals come out, the pool comes on and the tags drop in on their twine | turns `PaperFlip` (`quick`), rows `stagger` 150 ms apart (closed up past five rows); then `settle`; tags `Motion.land` |

- **Lengths** (at six players; more rows add 150 ms each, closed up past five): one hanged **2.03 s**; two hanged (a
  tie) **2.88 s**; the Hunter and his pick **2.88 s**; nobody hanged **1.39 s**. Ten players with one hanged: 2.33 s.
  Each further death adds about 0.96 s.
- **Nobody hanged:** its own beat, shorter than a hanging: after the hold the winners rise together where they lie,
  turning face up as the lantern's pool comes on (`rise` `settle`), are held a moment (`quick`), then settle as the
  banner unrolls (the light knock) and the others turn row by row. (The round's idea of the empty noose swinging
  needs the noose as its own layer; the gallows is one picture today.)
- **Skip:** one touch anywhere jumps to the settled board, and the control under it still takes the touch (the board
  keeps the same layers settled, so nothing above a control is built again). "What happened", "Edit deck" and "Play
  again" work from frame one. A tap on What happened finishes the reveal and starts the night.
- **Reduce motion** (`Motion.within`), or a screen reader on (`MediaQuery.accessibleNavigation`): the settled board
  at once, faded in.
- **At 7+ players:** the reveal plays where the board opens (the dead in view, `initialScroll`); the big card is in the
  middle of that window.
- **Not built (differs from the round's mock):** the crows lifting; the gallows' disc. Cards keep their seats from the
  first frame (the owner's ruling), where the mock moved them to their rows at the end.


### What happened, on the board (`png/3-what-1` to `-5`)

As built (piece 4 and its fixing pass): the steps are `endStoryOf` in `features/game/domain/end_story.dart`, pure and
tested on every recorded sample; `EndNight` steps through them. Calm, one thing at a time. Where the build differs from
the round's mock, on purpose (the owner rejected busier designs; the fixing pass's decisions win):

- **The step's line is in the banner.** No caption slip floats over the board: the banner, which by day says the result,
  says the step. It keeps the room its tallest words need (the result's, or any line of this night's, up to three lines
  by the result's rule, set smaller only where three will not take it, never under 24): the board never moves when the
  words change. Back at the result, the banner says the result again. Bone at night (red is the result's).
- **One step at a time.** Only the step shown has a thread. No number chips anywhere. Earlier steps leave nothing behind
  but the cards' faces: you watch the cards change.
- **The deal is the first step.** "What happened" turns every card to the face it was dealt and the banner says "The
  cards as dealt."; each tap then plays one step. A night where nobody acted is the deal alone, then the result: the
  scrap is still offered (the deal against the result shows who ended up with what).
- **Every card the step is about is whole on screen before it plays** (name included), on every board, phone and text
  size. On a board that scrolls the step's cards are centred in the window (`nightViewOf`,
  `features/game/domain/end_night_view.dart`, pure); the deal brings the board to its top with "you" in view. Where
  the step's cards cannot all be in the window together (a tall board, large text), the one who acted is, and each
  other card is lifted from its seat to the window's nearest edge, in front, for that step. At night the board may
  scroll a little further, so its lowest card stands above the foot's lip. `end_night_sweep_test.dart` fails when any
  card of the step shown is clipped, covered or off screen, for every recorded night, ten players and a night where
  nobody acted, at 360 x 640, 360 x 780, 390 x 844 and 412 x 915, text 1.0, 1.3 and 1.6.
- **A middle card is lifted onto the board for its step** (owner, 24 Nov 2026: a thread down to the foot "sweeps a long
  way"): beside the card of the one who acted, clear of every card, seal and the lantern where the window has room,
  else in front of cards the step is not about, as the fit pass lifts a card (`nightMiddleAt`); its place in the foot
  stands empty for the step. Never a bare "Left", "Right" or "Middle". Lifting is the preferred form, and it never
  covers a name, card, seal or tag (coordinator's rule, 24 Nov 2026; `nightLiftedOf`): the step's middle cards side by
  side where they fit clear; else two of them fanned, the second over the first's far third and raised by its strip,
  so each shows its strip and at least two thirds of its face; else none is lifted. Then they stay in the foot, raised
  there (the selection's lift), and the thread runs from the one who acted down over the lip to each, the shortest way
  that crosses no card or name (`end_night_foot.dart`); the board stands with the one who acted as the lowest card in
  view where the window allows (`nightStandOf`). The step's banner line is the same in every form.
- **Links** (owner, 24 Nov 2026: "The links are not at all polished there are breaks."): one part, `CardLink`
  (`design_system/primitives/card_link.dart`), given the two cards as they lie (turned, lifted). It is tied ON each
  card's edge where the two face each other, never under a seal, and bends gently, more only as needed to clear every
  other card, seal and the lantern, inside the board's window. A take and a swap are solid with a head at both ends
  (each card received the other's); a look (a copy too) is gapped with a dot at the card seen; a team is gapped with a
  dot at each end. A move's link too short for its two heads bows out. Where no clean link exists, the far card is
  lifted beside the near one for the step (`nightStepOf`). It draws in on the step's clock (a tap finishes it). The
  sweep (`end_night_sweep_test.dart`, `test/helpers/end_links.dart`) holds it on every recorded night and ten players
  at 360 x 640, 360 x 780, 390 x 844 and 412 x 915, text 1.0, 1.3, 1.6: both ends on the right cards' edges (within a
  point), the path in the window (down over the foot to a middle card kept there), off its own cards, across no other card or seal (a card the step lifted a card over
  is under the step; where the step's cards cannot lie apart at all, only the ends are judged), the ends right for
  the kind. The `12-end-night-*` pages' sweep plan carries the same rule.
- **The way back reads "The result"** (two words); after the last step one more tap is the result. **No auto-advance**:
  a step plays on a tap (or a swipe left; a swipe right goes back), its motion short (`settle` + `quick`; the deal
  `scene`), and a tap while it plays finishes it: the owner's no-added-waits rule.
- **The first time only, "Go on"** on a small bone scrap on the board's lower edge (over the foot's lip, covering no
  card), gone at the first tap and never shown again on that device (`EndBoardView.stepTaught` and `onStepTaught`;
  piece 5 keeps it as the learned cue `end_step`, `Cue.endStep`). The project's rule: teach a gesture once, by doing it.
- **The way back is exact.** The settled board is hidden as it is, not rebuilt, and comes back pixel for pixel,
  scrolled where it stood.
- **Team twines are gapped** (a look), red for the Werewolves and the Minion, bone for the Masons. The mock drew the
  Werewolves' solid.
- **Card widths count the night.** Each card is as wide as every role it shows in the night (Ben, robbed of the
  Troublemaker's card in `results`, is as wide as "Troublemaker"), so nothing moves when faces change; this can move
  a card to the next row beside the lantern (rule 3). Each middle card likewise.
- **The moon** is the night village's moon, at the skin's size (`PaperParts.nightMoonWidth`), up at the left, between
  the sky plate and the hills and roofs (the dawn sky's slot), over the night's ground; a lighter veil lies over the
  whole sky; the felt takes the moon's cool wash (`PaperParts.nightFeltReach`); the lantern goes dark.

**The lines** (one function, `StoryCopy.line` in `design_system/copy/end_copy.dart`, a part of `copy.dart`; every form
tested in `story_copy_test.dart`): each leads with the role and ends with what came of it.

- "The cards as dealt."
- "Werewolves Cleo and Esme meet." (three or more: "Cleo, Esme and Fin"); "Werewolf Cleo is alone."
- "Lone Werewolf Cleo peeks at a middle card."
- "Minion Dev sees the Werewolves." / "Minion Dev sees no Werewolves."
- "Masons Esme and Fin meet." / "Mason Esme is alone."
- "Seer Ana sees Cleo: Werewolf." / "Seer Ana peeks at two middle cards."
- "Robber Ben takes Dev's card." / "Troublemaker Dev swaps Ana and Ben." / "Drunk Ida swaps with a middle card."
- "Insomniac Hana wakes: still Insomniac." / "Insomniac Hana wakes: now the Seer."
- "Doppelganger Ana copies Ben: now a Seer." (an Insomniac: "now an Insomniac"), then the copied act as "Doppelganger
  Ana ..." in the same forms.

| Moment | What moves | Tokens |
|---|---|---|
| Tap "What happened" | The sky turns to night; the moon comes up behind the roofs and becomes the light; the lantern goes out. Every card turns to the face it was dealt, on cool night paper. Tags, ribbons and dealt cards fade out; the seal stays. The banner: "The cards as dealt." The scrap becomes "The result" | sky `scene`; turns `PaperFlip` |
| Each step, one a tap | The board brings the step's cards whole into view. Its link is tied between the cards' facing edges, never across another card, to a middle card lifted beside the one who acted. Cards whose card moved turn to their new face. The banner says the step. Red twine for the Werewolf team, gapped for a look | scroll `settle`; twine and turns `settle` + `quick` |
| After the last step | It stays until a tap or "The result" | — |
| "The result" | Dawn returns. The cards turn to their final faces, and tags, ribbon and the pool come back; the banner says the result | `scene` |

- **Reduce motion:** every change is a cut, and the steps still go one a tap.
- **Screen reader:** the banner is a live region: each step's line is read as it comes, and the banner is a button
  that plays the next step.
- **No timeline (null):** no scrap.

## 9. Haptics

- **No vibration when cards turn,** by the owner's word: not on the reveal and not in What happened.
- **The knock belongs to the stamp.** `Haptics.thud` (`mediumImpact`) fires as each HANGED lands, through the
  `Haptics` seam, on every phone. Two deaths (a tie, the Hunter's pick) are two stamps a beat apart, so **two
  knocks**: each death is its own moment, and the second knock says "and another". Three deaths, three.
- **Nobody hanged:** `Haptics.light` once, as the banner unrolls.
- **A skipped or reduce-motion reveal** fires one vibration as the board settles, if none had come yet; the knocks
  not yet come are not played.
- **Never:** What happened, a scroll, What happened's steps, Edit deck or Leave.
- **Play again:** as today.

This one vibration replaces feel.md's two (the count's `thud` and 11's `light`). Update the rows in feel.md
section 4 in the same change.

## 10. Accessibility

Screen-reader order:
1. **The banner first,** as one sentence: "Cleo hanged. You and the village win."
2. The board, row by row, in the visual order. Each card is one node, 8 words or fewer:
   - "Ana, you. Villager, was Seer. Won."
   - "Cleo. Werewolf. Hanged. Votes: Ana, Dev, Maximilian."
   - "Cleo, Dev's pick. Werewolf. Died."
3. The middle: "Middle cards: Insomniac, Villager, Drunk."
4. "What happened", button.
5. "Edit deck", button.
6. "Play again", button (host); or "Ana deals next." and "Leave", button (guest).

Tags, twine, ribbon, seal, crows and the lantern are excluded from semantics: the card nodes say it all. While What
happened plays, the banner reads out each step and plays the next on a tap, and "The result" leads back. Text scales with the system
up to the point where a name would no longer fit a slot; past it, rows of one card.

## 11. Proof in this folder

- Phones, 360 x 780 at 2x:
  - `1a` village wins;
  - `1b` Werewolves win, nobody hanged;
  - `1c` 3 players;
  - `1d` and `1e`: 10 players, a tie, long names, scrolled to the top and to the end;
  - `1f` the Hunter;
  - `1g` a Tanner win;
  - `1h` a guest's phone (Ben: the hare seal, the red banner, Leave);
  - `2-reveal-1` to `-5`;
  - `3-what-1` to `-5`;
  - `0-anatomy`.
- `audit.txt`, per phone:
  - only sizes 12, 16 and 24;
  - one amber control on the host's phones and none on the guest's;
  - lowest contrast 4.71 on what is really behind the text;
  - no name cut.
