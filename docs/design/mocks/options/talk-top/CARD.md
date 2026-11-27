# Card: the top of the talk screen (08)

The owner's words (board, `area-mynight`, 23 Nov): "The hold variant is good, but I don't like the empty space up top.
I'd like to see something better there".

## The card

- **title:** What goes at the top of the talk?
- **what:** Today and three options, each at 5 and 10 players.
- **ask:** Mark the one you want, then Send my pick. A adds a line of words the screen does not have today.
- **pick:** one
- **pictures** (each option's 10-player picture goes in its `views`, caption "10 players"):

| id | picture | 10 players (view) | caption |
|---|---|---|---|
| `today` | `today-5.png` | `today-10.png` | Today: a bare clock, empty sky |
| `a` | `a-5.png` | `a-10.png` | A: banner, adds "The village wakes" |
| `b` | `b-5.png` | `b-10.png` | B: the clock on a sign |
| `c` | `c-5.png` | `c-10.png` | C: moonlit sky, the clock's sign |

- **default:** We build B.
- **default_choice:** `b`

pick: B, because it fills the top with the board itself and adds no words;
its sign is the same paper, numerals and candle as the other screens' banner, so the clock is recognisably one thing all game.

## What each option is

- **A, one banner:** the torn paper banner of 04 and the night (title left, time and candle right), pinned over the night sky;
  the village roofs and the moon show under it and beside it. The board's slate roof and the lantern go.
  It adds a line of words the screen does not have today: "The village wakes" (the talk's headline, today only spoken).
- **B, the board's sign:** the sky strip goes; the board's roof and lantern sit at the top of the phone,
  and a paper sign hangs from the eave with the time and the candle. The board starts about 50 pt higher.
  At 6 players or fewer the role cards are drawn larger, in two columns (the spec's first deck size),
  and the roles, the names and My night are spaced evenly down the board; at 10 players the board is as today.
- **C, the square's sky:** today's strip of sky stays, as a picture: the night village's roofline and the game's moon,
  the lantern as today, and the time on B's paper sign, hung from the lantern's bracket. No new words.

## What is rough (be honest with the owner)

- A at 10 players takes about 10 pt from the board's gaps; its banner still hides most of the roofs.
- B at 5 players: the role cards are the render's own cards scaled 1.15 times (1.25 does not fit with the names and My night), so they are a little soft.
- B and C: the lantern hangs from the top edge of the phone, as it does today; C's bracket is drawn, not art.
- C's sky is narrow: the roofline and the moon are small, and the sign covers part of it.
- Every picture is cut from the 25 Nov renders: the board's gaps were cut or grown by rows of felt, not laid out by the app,
  and the banner and sign are new paper cut from 06's banner, with the clock set in Gloock.
- 5 players are shown with My night put away (`08-talk-put-away`); 10 players are `08-talk-10-long`.

## How they were made

`python3 make_mocks.py --screens <dir of renders>` (default `frontend/build/screens`); `paper.py` holds the paper, torn edges, pins and shadows.
