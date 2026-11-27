# Board card: the title on the first screen

A picker card (`docs/dev/owner-board.md`, "Group the options for one slot").

- **title:** How should the game's name look on the first screen?
- **what:** Only the name changes; the village, your name and the two buttons stay as they are.
- **ask:** Which one should we build?
- **pictures** (`pick`), each with its id and caption:
  - `today`: Today: plain white words
  - `a`: A sign hung in the village
  - `b`: Letters cut from paper
  - `c`: Cut out of the moon
  - `d`: On the paper ribbon
  - `a`'s view `pick-short`: The sign on a small phone
- **default:** We build A, the sign.

pick: A, because the name becomes a thing hanging in the village, larger than today and clear at a glance.
It sits where the name sits today, so nothing else moves, and it still fits on the smallest phone.

## Notes for the builder

- Made by `make_options.py` from today's real screen (`frontend/build/screens/01-join.png`); every piece of art is the app's own.
- A: the board is cut from the end board's notice frame (`docs/design/art/end/frame4.png`); the iron bracket and the cords are drawn.
- C: the words are cut out of the moon, so the picture holds them; on a short phone, large text or the keyboard the picture is pushed off the top and the name goes with it.
- D reuses the end board's ribbon, so the first and last screens would share it.
- At text size 1.6 the sign, a picture with "Midnight Village" as its label, does not grow; it moves up with the form.
- Rough: the bracket is plain flat iron; the letters' cut edges come from the font with a small jitter; branches cross the end of C's words.
