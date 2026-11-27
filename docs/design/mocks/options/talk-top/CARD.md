# Card: the top of the talk screen (08)

The owner's words (board, `area-mynight`, 23 Nov): "The hold variant is good, but I don't like the empty space up top.
I'd like to see something better there".

## The card

- **title:** What goes at the top of the talk?
- **what:** Today and three options, each at 5 and 10 players.
- **ask:** Mark the one you want, then Send my pick.
- **pick:** one
- **pictures** (each option's 10-player picture goes in its `views`, caption "10 players"):

| id | picture | 10 players (view) | caption |
|---|---|---|---|
| `today` | `today-5.png` | `today-10.png` | Today: a bare clock in the sky |
| `a` | `a-5.png` | `a-10.png` | A: one banner on every screen |
| `b` | `b-5.png` | `b-10.png` | B: the clock on a sign |
| `c` | `c-5.png` | `c-10.png` | C: everyone's tags on a line |

- **default:** We build B.
- **default_choice:** `b`

pick: B, because the board itself fills the top: no new words, the clock on the same paper and candle as the other screens,
and the most room for the names at 10 players.

## What each option is

- **A, one banner:** the torn paper banner of 04 and the night (title left, time and candle right), pinned over the night sky;
  the village roofs and the moon show under it. The board's slate roof and the lantern go.
- **B, the board's sign:** the sky strip goes; the board's roof and lantern sit at the top of the phone,
  and a paper sign hangs from the eave with the time and the candle. The board starts about 50 pt higher.
- **C, the table's faces:** today's sky keeps its roof and lantern; every player's token hangs on a cord as a tag,
  a ready player's tag turned over (bone paper), the time smaller at the left.

## What is rough (be honest with the owner)

- A draws "The village wakes", the talk's headline, which today is only spoken (spec 08); at 10 players it takes about 10 pt from the board's gaps.
- A's banner hides most of the village: only roof tips and half the moon show.
- B's cords are faint, and the lantern hangs from the top edge of the phone, as it does today.
- C shows who is ready, which the owner took off the board on 23 Nov ("no list of who is ready"); its tags repeat the sigils on the name tags, and at 10 players a tag is 21 pt.
- Every picture is cut from the 25 Nov renders: the board's gaps were cut or grown by rows of felt, not laid out by the app,
  and the banner and sign are new paper cut from 06's banner, with the clock set in Gloock.
- 5 players are shown with My night put away (`08-talk-put-away`); 10 players are `08-talk-10-long`.

## How they were made

`python3 make_mocks.py --screens <dir of renders>` (default `frontend/build/screens`); `paper.py` holds the paper, torn edges, pins and shadows.
