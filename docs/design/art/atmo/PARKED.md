# Come alive: what is parked (25 November 2026)

The owner, 25 Nov: "Between the performance and beauty changes, prioritize performance."
So after `motion-layer` everything below waits for the coordinator's word. This file holds
what was decided, so nothing is lost. It lives on `atmo-art` with the art it describes and
goes away when the last piece here is built.

## Rules already agreed (they bind every piece below)

- An effect is a small layer of its own over a still image, never a reason to redraw the screen.
- Every loop is an `Ambient` (`frontend/lib/design_system/feel/ambient.dart`): a short burst,
  then true rest; it holds while a finger is down, when the app is hidden and with reduce motion.
- Nothing ships without `just phone-frames` numbers with the effect on and off.
- Night: life only in the far village and the sky, the same on every phone, never near the
  board, never tied to a role (the owner, 25 Nov: allowed). Music only at night, no role or
  turn sounds. Sound effects are on hold until they can be judged in the game.

## Pieces, in order

1. `shared-pieces`: the card staging (the owner's ask in place of kindle/veil).
   - The deal (table to Your card): the deck throws one card to each name, three to the
     middle, yours comes to you face down, holdable from its first frame.
   - Night falls (Your card to the night board): your card is face down before it moves (it
     turns down first if held open), lifts, flies a short arc to its slot, settles; the other
     cards are laid in seat order, the centre three fan in. Under `Motion.scene`, then still.
   - The clock banner is ONE piece on 04 and the night board: same width, same place, only
     the words change. This is the fix for the owner's "jumpy" candle and "different widths".
   - The board takes taps from its first frame; flights are paint only on an overlay that
     takes no touch and costs nothing once done; a tap finishes the motion; reduce motion cuts.
   - Open with the owner (on the board): your slot face down with hold to see, or as today.
     Default: flight face down, slot as today.
   - Split `primitives/scene_switcher.dart` first (488 lines). Sketch: `sheets/card-staging-sketch.png`.
   - Wait for the coordinator: 04, the night board and the banner are in `still-screen` and
     `cheap-frames`; moving layers must sit above a `Still` (`primitives/still.dart`).
2. Press on the eleven tappable primitives with `Pressable` (`feel/press.dart`), after
   `still-screen` and `cheap-frames`; read `primitives/finger_hold.dart` first.
3. Ambient picks (the owner picked all six): windows, moth (one visit a stage at most, never
   over words or a control), tagsettle, sway (quiet: once per stage), plus the flame and the
   moon (kept by the owner; art is here, `flame/` and `moon/`, order of layers in
   `PROVENANCE.md`; fade the moon's phase in after the moon lands at dusk).
4. `audio-theme-layers`: one long bed kept at 32 kHz with loop points in samples, short stage
   layers in phase with it (vote: a pulse of bed/N; reveal: a cloud), night as the bed
   darkened, an ending on the bed's next loop end, a gain per sound, ogg and m4a made from
   the WAV masters. Then the theme's one owner in the shell (`Sounds.claimTheme()`), and a
   mute control (its place needs pictures for the owner). The tap that unmutes must open the
   output itself. The theme is not chosen: the owner asked for a darker, minor-key round.
5. Not proven on a real phone, to try on the owner's once a sound is in: sound starting on
   the first touch, silence on a hidden tab, Chrome suspending by itself, real latency.
6. Left out of `motion-layer`: the hold cue's one more breath after a short tap on the card
   itself (needs a hook in `hold_to_reveal.dart`, which `tap-leaves-now` rewrote).
