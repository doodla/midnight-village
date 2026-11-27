# Board card: the title on the first screen

A picker card (`docs/dev/owner-board.md`, "Group the options for one slot").

- **title:** How should the game's name look on the first screen?
- **what:** Only the name changes; the village, your name and the two buttons stay as they are.
- **ask:** Which one should we build?
- **pictures** (`pick`), each with its id and caption:
  - `today`: Today: plain white words
  - `a`: A road sign by the path
    - view `pick-short-a`: The sign on a small phone
  - `b`: Letters cut from paper
    - view `pick-short-b`: The letters on a small phone
  - `c`: Cut out of the moon
    - note: Gone on short phones
- **default:** We build the pick, B.

pick: B, because the name itself becomes cut paper in the scene, big and clear, with nothing added round it.
A is charming, but its board is one more object between the village and your name, and its letters are smaller.

## Notes for the builder

- Made by `make_options.py` from today's real screen (`frontend/build/screens/01-join.png`); only the title changes.
- A: a post and a deckled indigo board cut from the sky's own paper, bone letters, two pins, turned 2.2 degrees.
  A bone board with ink letters was tried (`make_options.py <screen> bone`); it read as a second name field.
- B: one centred block; the first line's feet stand in the grass at the picture's foot.
- A and B: the title's shadow is stronger than `PaperShadow` (contact .8, four steps at .22, leaning down-right),
  so it reads on the dark ground; building it means a title shadow of its own or a change to the token.
- C: the words are cut out of the moon, so the picture carries them;
  on a short phone, large text or the keyboard the picture is pushed off the top and the name goes with it.
- At text size 1.6 the title (art with "Midnight Village" as its label) does not grow; it moves up with the form.
- Rough: the letters' cut edges are the font's outline with a small jitter, not hand-cut;
  the short phones are put together from today's pieces, not rendered by the app.
