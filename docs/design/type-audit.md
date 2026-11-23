# The type scale (the owner's choice, 23 November 2026)

The owner: text across the game felt "so huge", "especially around the names". Their reference
(a generic phone mock at 390): headline 38-40, names 16 in chips with 28 avatars, small labels 12,
body 15, room code 32, button label 14 bold. An audit found 16 distinct sizes (and three set by
hand) and one name drawn at 18, 21, 24 or 26 depending on the screen. Two candidate scales were
rendered (Compact and Tight). The owner chose on 23 November 2026: **"Tight sizes, but keep the
serif names."** The other scale, the old values and the render switch are deleted.

## The scale (one home: the skin's roles in `lib/design_system/skin/skins/shadow_paper.dart`)

G = Gloock (display serif), F = Figtree (text face). Size / weight / line height. The "was" column
is the shipped value before the choice (a mock's number is never copied: a role is converted at its cap).

| Role | Family | Size | Was | Used for |
|---|---|---|---|---|
| heroTitle | G | 36 | 46 (42 on Join) | "Midnight Village" |
| heroCode | G | 28 | 46 | the table code |
| heroVerdict / heroWinner | G | 32 | 44 / 40 | "Dev dies.", "The village wins" |
| heroRole | G | **46** | 46 | the role on your own card (unchanged) |
| display | G | 28 | 36 | the dead player's role, "My night" large |
| screenTitle / headline | G | 24 | 34 / 32 | the screen's question, "Tonight's deck" |
| title / heading / tally | G | 20 | 26 / 24 / 28 | section lines, dialogs, stepper values, votes at a row's end |
| **name** | G | **16** | 26, 24, 21, 18 | every player's name, in every row (the serif kept) |
| nameSmall | G | 14 | 18 | a name under a card on the night board |
| buttonLabel (large, regular, small) | F 700 | 15 | 21 / 20 / 19 (G) | primary button words |
| timer, timerVote, timerSmall | G | **84, 76, 64** | same | the countdowns (unchanged) |
| timerTalk | G | **40** | 40 | the talk's clock in the square's sky (owner, 23 November 2026): the scale's one large timer under 64; the guard holds it to exactly 40 and every other timer to 64 or more (`skin_contract_test.dart`) |
| timerSmall | G | **64** | 64 | the night's seconds, on the board (S06) as on the candle's panel (S05): the one timer style; the role `timerCompact` (27) is gone |
| bodyLarge / bodyStrong | F 500 / 700 | 15 | 17 | a role's text, a count read across the table, a lead word |
| lede, body, action | F | 14 | 16 | ordinary text, secondary buttons, chips |
| code / cue | F 700 | 15 / 16 | 17 / 20 | the typed code, "Hold" |
| caption, tag, badge | F | 12 | 14 | small labels |

Distinct sizes besides the timers and your role: 12, 14, 15, 16, 20, 24, 28, 32, 36 (nine, was 16).

The layout that follows the type (the plain value on its enum, no options): player rows 38 (table),
48 (the vote's fallback), 52 (vote, count); tokens 26 (table), 32, 38 (vote), 34 (count); buttons
48 (50 the big one); the name and code fields 48. Touch targets are never under 48 (the table's rows
are not buttons). The room the smaller type freed is **not** used yet: a design round follows.

## The rules that changed with it

- Reading floor: body and names 14 (was 16), labels 12 (was 14): `ReadingFloor.act` and
  `.caption` in `layout/space.dart`, `frontend/CLAUDE.md`, `first-time-play.md` copy rule 7, and the
  gallery's check (`test_screens/reading_floor.dart`, `just screens strict`). Nothing else was weakened:
  contrast (7:1), full ink for true words, no uppercase micro-labels, one amber fill and every name whole
  stay.
- The night board's title is the role's 24 at any width and text size (never under 0.8 of it, on two
  lines at most), tested in `board_sweep_test.dart`; the old "no smaller than main drew it" table is gone.

## What the audit found outside the roles, and what was done

Six sizes set by hand: Join's 42 (x2), the name field's 20, the lobby name's 18 and the corner seconds'
27: all are roles now (`heroTitle`, `name`). Three weights: `bodyStrong` (the role sheet's
lead word, the progress count) and `body` (the night's story line on the results). Left on purpose, each
named in `type_guard_test.dart`: the fits (a role made smaller to fit its room: `FitLine`/`FitWords`, the
board's one name size, the table's two-up name size, the hold cue word, the timer's unit "s"). Debug only
(`features/debug/`, not a player's screen; exempt): five styles in `debug_toolbar_screen.dart`.

## The guard

- `test/design_system/skin/skin_contract_test.dart`: every role has a cap (names at most 16, questions 24,
  headings 20, body 15, buttons 15, labels 12, hero lines 36, timers and your role as they were) and a
  mock's bigger number is converted at the cap, never copied.
- `test/design_system/skin/type_guard_test.dart`: a `fontSize:`, `fontWeight:`, `fontFamily:`,
  `fontStyle:` or `TextStyle(` anywhere in `lib/` outside `design_system/skin/` and `features/debug/`
  fails, except the named fits (and a stale allowance fails too).
- Not built: a gallery ceiling that flags a name drawn larger than 16 in `just screens` (the roles
  and the source scan make a bigger name impossible without failing a test first).

## Left for the design round

Rows, chips and avatars shrank only enough to fit the smaller names; the freed room (the vote and
the table have a tall quiet area under the rows, the night board's three-seat table leaves more air, the
first screen's top) was not redesigned. The owner's bold small-caps labels and buttons are not done (no
uppercase micro-labels).
