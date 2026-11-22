# Type audit and two smaller scales (23 November 2026)

The owner: text across the game still feels "so huge", "especially around the names". Their
reference (a generic phone mock at 390): headline 38-40, names 16 in chips with 28 avatars,
small labels 12, body 15, room code 32, button label 14 bold. An options round: nothing is
merged and the shipped scale is unchanged. This file is the audit, the two candidate scales
(`today` is what ships), what was moved to which face, and a guard for after the choice.

How to see them: `frontend/test_screens/type_scale_options_test.dart` renders six screens at
360 wide for the scale it is built with (`--dart-define=TYPE_SCALE=today|compact|tight`, the one
private switch, `lib/design_system/skin/type_scale.dart`); `tool/type_scale_sheet.py` joins
the three. The switch is for rendering only: with no define the scale is `today`.

## 1. Every text style token (today), from `skins/shadow_paper.dart`

Family G = Gloock (the display serif), F = Figtree (the text face). Size / weight / line height.
"Mock" is the value the token was first taken from (`mock-to-skin.md`); where the code already
differs from the mock, the mock's number is in brackets.

| Token | Family | Size | Weight | Line h | Used for | Mock (S = screen) |
|---|---|---|---|---|---|---|
| heroTitle | G | 46 (Join sets 42 by hand) | 400 | 1.0 | "Midnight Village" on 01 and its opening | S01 46 (owner cut to 42, 22 Nov) |
| heroCode | G | 46 | 400 | 1.0 | the table code under the QR (02), the scanner's found code | S02 46 |
| heroVerdict | G | 44 | 400 | 0.95 | "Dev dies." (10) | S10 44 |
| heroWinner | G | 40 | 400 | 0.95 | "The village wins" (11) | S11 40 |
| heroRole | G | 46 | 400 | 0.9 | your role's name on a held face (04, 08) | S04 58 |
| display | G | 36 | 400 | 0.95 | the dead player's role (10); "My night" large on the talk (08) | S07, S10 36 |
| screenTitle | G | 34 | 400 | 1.05 | screen question: "Who dies today?" (09), "Look at cards"/"The village sleeps" (06, 05), "Your card" (04), the waits | S05, S09 34 |
| headline | G | 32 | 400 | 1.0 | "Tonight's deck" (03), role name on the role sheet (03b), the table's headline (02) | S03, S03b 32 |
| title | G | 26 | 400 | 1.15 | a player's name in the vote rows (09, `PlayerRowSize.large`); the name field on 01 (set to 20 by hand); results section lines (11); seats line (02); deck lines (03); dialogs | S06, S09 26 |
| tally | G | 28 | 400 | 1.0 | votes at the end of a count row (10) | S10 28 |
| heading | G | 24 | 400 | 1.0 | names in the count rows (10); "My night" (08); stepper values (03); deck headings; app bar | S03 pace, S08, S10 24 |
| name | G | 21 (lobby rows set to 18 by hand) | 400 | 1.1 | names at the table (02, 18); results names (11, 21); the dead player's name (10, 21); the vote's fallback rows | S02 21 |
| nameSmall | G | 18 | 400 | 1.1 | names under a card on the night board (06), the results' night lines | S06 18 |
| buttonLabelLarge | G | 21 | 400 | 1.0 | "Start a table", "Ready", "Play again" | S01, S04 21 |
| buttonLabel | G | 20 | 400 | 1.0 | every other primary button ("Deal to 6", "Choose a card") | S02 20 |
| buttonLabelSmall | G | 19 | 400 | 1.0 | "Join", "Close", text actions | S01, S03b 19 |
| timer | G | 84 | 400 | 0.9 | the talk's countdown (08) | S08 84 |
| timerVote | G | 76 | 400 | 0.9 | the vote's countdown (09) | S09 76 |
| timerSmall | G | 64 | 400 | 1.0 | the candle's countdown (05) | S05 64 |
| timerCompact | G | 34 (drawn at 0.8: 27) | 400 | 1.0 | the board's corner seconds (06) | S06 34 |
| bodyLarge | F | 17 | 500 | 1.35 | a role's text on the sheet and held face (03b, 04), hints, scanner words | S03b 17 |
| lede | F | 16 | 500 | 1.3 | the lines under the title (01) | S01 16 |
| body | F | 16 | 600 | 1.35 | ordinary text a player reads: notices, "n of 6 locked", row details, held-face lines | mocks' 15 |
| action | F | 16 | 700 | 1.2 | secondary button labels, chips, links, "Leave", "Edit" | S03 14/15 |
| code | F | 17 (+0.12em) | 700 | 1.2 | the code field's typed letters (01) | S01 17 |
| cue | F | 20 | 700 | 1.2 | "Hold" in the hold ring | S04 15 |
| caption | F | 14 | 600 | 1.3 | "Left/Middle/Right", the code hint, field help | mocks' 12/13 |
| tag | F | 14 | 700 | 1.2 | "You", "Practice", "Village" | S03b 12-13 |
| badge | F | 14 | 700 | 1.2 | count badges, role names under deck cards, small tags | S03 12 |

16 distinct sizes outside the timers and the role (46 44 40 36 34 32 28 26 24 21 20 19 18 17 16
14), and three more set by hand (42, 20, 18). What reads as "huge about names": the vote rows are 68 tall with
the name at 26 (a 52 token), the count rows 64 tall at 24, results names 21: three different
name sizes, none of them the lobby's 18, so one player's name is drawn at 18, 21, 24 or 26
depending on the screen.

## 2. Text style set outside the tokens (each one a defect)

Sizes set by hand on a role (the number is then a second source of truth):

| Where | What |
|---|---|
| `lib/features/lobby/presentation/join_screen.dart:152` and `:425` | `heroTitle.copyWith(fontSize: Sizes.joinTitle)`: 42, the token says 46 |
| `lib/design_system/primitives/skin_field.dart:75` | `title.copyWith(fontSize: nameSize)`: the name field at 20, a role of its own that is not in the tokens |
| `lib/design_system/primitives/player_row.dart:82` | the lobby name `name.copyWith(fontSize: 18)`: the token says 21 |
| `lib/design_system/primitives/player_row.dart:166` | the two-up fitted size (derived by fitting; allowed, but only because it is a fit) |
| `lib/features/lobby/presentation/at_table_screen.dart:493` | the same fit's measuring style |
| `lib/design_system/primitives/world_timer.dart:154` | `timerCompact` x `cornerNumberScale` 0.8 = 27: a size no token names |

Weights set by hand: `results_screen.dart:760` (bodyLarge with body's weight),
`role_sheet_body.dart:29` (`TextStyle(fontWeight: action.fontWeight)`), `progress_pips.dart:40`
(bodyLarge at 700): each is a role the tokens do not have.

Derived by fitting (a fit of a role, not a style; allowed but each is a place a number could
sneak in): `fit_line.dart:111` (`FitLine`/`FitWords` scale a role down), `band.dart:584`
(`unitShare`), `face_down_card.dart:310` (`nameSize` from `board_layout.dart:258`),
`hold_cue.dart:149`, `primary_button.dart:237` (icon size from a style).

Debug only (not a player screen; exempt from the guard): `features/debug/presentation/
debug_toolbar_screen.dart:105, 150, 294, 364, 427`.

Count: 6 hand-set sizes, 3 hand-set weights, 5 fits (listed), 5 debug: 9 defects that change
what a player sees. In the two options the 4 that are names or titles (Join's 42, the name
field's 20, the lobby name's 18, and with them the vote and count rows' own roles) disappear
because the token itself is the size (`name`, `heroTitle`); they remain only on `today`. The 3
weights and the corner seconds' 27 are untouched and stay on the list for the guard.

## 3. The two scales

Size in points (family). Timers and the role on your own card stay as they are in both options
(the glance-across-the-table items; the corner seconds drawn at 27 are never smaller than a name).

| Role | Today | Compact | Tight |
|---|---|---|---|
| heroTitle (app name) | 46 (42 on Join) G | 40 G | 36 G |
| heroCode (room code) | 46 G | 32 G | 28 G |
| heroVerdict / heroWinner | 44 / 40 G | 36 / 36 G | 32 / 32 G |
| heroRole (role on your card) | 46 G | 46 G | 46 G |
| display | 36 G | 32 G | 28 G |
| screenTitle (screen question) | 34 G | 28 G | 24 G |
| headline | 32 G | 28 G (same as screenTitle) | 24 G |
| title / heading / tally | 26 / 24 / 28 G | 22 / 22 / 22 G | 20 / 20 / 20 G |
| **name** (rows, vote, count, results) | 26, 24, 21, 18 G | **18 G** | **16 F 700** |
| nameSmall (under a board card) | 18 G | 16 G | 14 F 700 |
| buttonLabel (large / regular / small) | 21 / 20 / 19 G | 16 / 16 / 16 G | 15 / 15 / 15 F 700 |
| timer / timerVote / timerSmall / timerCompact | 84 / 76 / 64 / 34 G | same | same |
| bodyLarge | 17 F 500 | 16 | 15 |
| lede / body | 16 / 16 F 600 | 15 / 15 | 14 / 14 |
| action (secondary labels, chips) | 16 F 700 | 15 | 14 |
| code (typed) / cue ("Hold") | 17 / 20 | 16 / 18 | 15 / 16 |
| caption / tag / badge (small labels) | 14 | 12 | 12 |
| Distinct sizes (without timers and heroRole) | 16 | 9 | 9 |

Layout that follows the type (set in the same enums, three columns each, so a choice deletes two):

| | Today | Compact | Tight |
|---|---|---|---|
| lobby row / token | 46 / 32 | 40 / 28 | 38 / 26 |
| vote row / token | 68 / 52 | 56 / 40 | 52 / 38 |
| count row / token | 64 / 48 | 56 / 38 | 52 / 34 |
| fallback row / token | 52 / 38 | 48 / 34 | 48 / 32 |
| big / regular / compact button | 60 / 56 / 52 | 54 / 50 / 48 | 50 / 48 / 48 |
| name and code fields | 52 | 48 | 48 |

Touch targets are never under 48 in the options (the lobby rows are not buttons).

Display serif or text face: the serif stays for what is announced or named in the game's own
voice (every title, the hero lines, the timers, the role) and, in Compact, for names and
button labels at 18 and 16: Gloock is still clear there and keeps the paper-cut look. In Tight,
names (16) and buttons (15) move to Figtree 700: Gloock's hairlines thin out below about 17
and a name must stay legible across a table; the contrast with the serif titles also gets
sharper. Whether names should be sans at all is the owner's call between the two.

Not changed: colours (every pair keeps its 7:1 or better), copy, art, the board's card sizes
(they re-flow: more room means larger cards), the reading-floor test (see 5).

## 4. What the pictures show

`/tmp/claude-0/-home-user-midnight-village/7a52bb75-a72a-5fc5-84a2-52d40859fece/scratchpad/typescale/`:
`<screen>-today-compact-tight.png` for the first screen, the table at 6, your card, the night
board, the vote at 6 with "Rosalind Fairweather-Okonkwo", and the results, plus `overview.png`.
Nothing is cut; the long name wraps between words at Compact and fits on one line at Tight.
Findings that remain by design: every 12-point label is under the current reading floor (14).
Empty space: the vote and the table keep a tall quiet area under the rows (as today; less is
a taller phone's problem and not new); the night board's cards grew into the room.

## 5. Open points for the owner's pick

- The rules in `frontend/CLAUDE.md` ("16 px to act, 14 px captions") and `ReadingFloor` in
  `layout/space.dart` and the gallery's floor check (`test_screens/reading_floor.dart`) say
  16 and 14. Both options go under them (Compact body 15 and labels 12; Tight body 14, buttons 15).
  The owner's reference does too, so a pick means lowering the floor to the chosen numbers
  (12 for labels is the least any option uses), in the same change.
- The owner's reference has bold small caps for labels and buttons. Not done: the rules say
  no uppercase micro-labels.

## 6. A guard for after the choice

After one scale is chosen and the other two columns and the switch are deleted:

1. `test/design_system/skin/type_guard_test.dart` scans `lib/` (not `features/debug/`): any
   `fontSize:`, `fontWeight:`, `fontFamily:` or `TextStyle(` outside `design_system/skin/` fails,
   except an allowlist of the fitting sites (`fit_line.dart`, `band.dart` unitShare,
   `board_layout.dart`, `face_down_card.dart` nameSize, `hold_cue.dart`, `world_timer.dart`
   corner scale), each named in the test with its reason. A new hand-set size is a failing test,
   not a review comment.
2. Caps per role in the same test, on the tokens: names at most the chosen name size (18 or 16) in
   every role used for a name, `title`/`heading` at most 22, `screenTitle`/`headline` at most
   28, body at most 16, buttons at most 16, labels at least 12; hero roles named one by one with
   their caps. A mock whose value is bigger is converted at the cap, and the cap is in the
   test's message ("the mock says 26; the cap says 18").
3. In the gallery (`reading_floor.dart`): a ceiling next to the floor. Any text that is a player's
   name (`PlayerRow`, `FaceDownCard` name, `FitWords` of a seat) drawn larger than the name cap
   is a finding, so a layout that grows a name back (a new row type, a text scale of 1.0 with
   `copyWith`) shows in `just screens` strict at 360 and 390.
4. The mock-to-skin rows get a column "cap", so a mock's number is never copied: the row says
   what the cap turned it into.
