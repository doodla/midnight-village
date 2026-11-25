# Sound archive

Every tune and sound made for Midnight Village on 24 and 25 November 2026, kept so none is lost.
This branch is an archive: it is never merged into main.

## Round 2 (25 Nov): six darker tunes, all in a minor key

The owner picked **N** (celesta tune over low strings, B minor).

| | What it is | Key |
|---|---|---|
| G | Music-box waltz, bowed glass, low drone | A minor |
| J | Dark folk with a far-off theremin howl | D minor |
| K | Harpsichord and plucked strings creeping, bell | G minor |
| L | Hypnotic synth pattern, wobbly tape | F minor |
| M | Far-off church organ, ticking clock | C minor |
| N | Celesta tune over low strings | B minor |

- `round2/listen/`: one .m4a per tune, to play on any phone or computer.
- `round2/masters/`: lossless masters (.flac, 48 kHz, 24-bit), each a seamless loop; the .json beside each gives the loop length in samples, tempo and key.
- `round2/raw-paid-extras/`: pieces already paid for but not finished (vote pulses and endings for L, M and N).
- `round2/SHEET.md`: the exact prompts, what was measured, what failed.

## Round 1 (24 Nov): six tunes A to F, and 31 sound effects

The owner turned these down ("These are all peppy almost. We'll need a minor key"); sound effects are on hold.

- `round1/listen/`: A to F, plus the night, tense, bed, layer and ending versions made for A and F.
- `round1/game-mixes/`: 90-second "as heard in a game" mixes.
- `round1/masters/`: lossless masters, with loop lengths in the .json files.
- `round1/sfx/`: the 31 sound effects, lossless.
- `round1/SHEET.md`: prompts and notes.

Made with ElevenLabs. To turn a master back into a WAV: `ffmpeg -i name.flac name.wav`.
