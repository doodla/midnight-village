# Main theme, round two: listening sheet (25 Nov 2026)

Round one (A-F) was rejected as "peppy" and not minor. This round has six new loops (G, J, K, L, M, N). **All six are in a minor key, and all are darker than round one.**
I made them with the ElevenLabs music API (`music_v2_5`). The prompts describe only sound and style, with no names of games, films, composers or people.

I cannot hear. Every judgement here comes from measurements: loudness, seam tests, key estimates and pictures of the spectrum. Choose by ear.

**My pick: N** (celesta tune over low strings, B minor, 66 BPM). It has the clearest tune of the six and is clearly minor. It is
steady, keeps all of its harmony on a phone speaker, and reads as "a lullaby gone wrong", which gives unease without horror.
**Runner-up: L** (hypnotic synth pattern, F minor, 88 BPM). It is the steadiest and most hypnotic, the dark version of round one's
"woozy" pull. Its tune is a repeating pattern, not a sung line.

**Scope was cut** (the owner's budget, mid-piece). The loops and listening copies are done. **Still to do, for the chosen one only:**
the bed + layers form (a vote layer, a reveal layer from the bed's own harmony, and the parts peaking together under -3 dBFS), a short
ending, and the 90 s "as heard in a game" mix. Some inputs are already paid for and kept in `raw/`: vote pulses `l-pulse-1`,
`n-pulse-1` and `m-pulse-1` (pitch-free, at each tempo) and endings `l-ending-1`, `n-ending-1` and `m-ending-1` (each continues its
take from the loop's end point). `prompts/tools/bedlayers3.py` builds the bed and layers from a master with no stem separation. It ran
once, on L, and found that the reveal wash dips 4 dB just after the seam. An `even_out` step was added to fix that but never ran.
Check that step first.

## Where things are

| Path | What |
|---|---|
| `masters/theme-<d>.wav` | WAV master: 48 kHz, 24-bit, stereo, -18 LUFS. The last sample runs straight into the first (loop the whole file). `.json` beside each one holds the measurements. |
| `theme-<d>.m4a`, `.ogg` | Listening copies: AAC 64k and Opus 64k, about 1 MB each. Naive looping of a lossy file clicks at the seam (as in round one). For the app, use `sound2/prompts/tools/apploop.py` (it adds pre-roll and post-roll and sets loop points). |
| `board/` | `sound-theme.json` (the card), `fill.py`, `upload/theme-<d>.mp4` (AAC in .mp4: the board's store refuses mp3). |
| `raw/` | Every take as delivered, plus a `.json` for each (request body, headers, song id). |
| `prompts/` | `themes.json` (take 1 prompts), `plans2-round2.json` and `plans2.json` (minor-enforced plans), `plans/` (exact request bodies), `pulse-prompts.json`, `tools/` (scripts), `loops/` (loop and fit reports). |

## The six loops

All loops are bar-aligned. Each seam was checked by rendering the loop twice end to end. "Click" is the seam's high-frequency burst
against the loop's own 99th percentile; any value below 0 means no click. "Step" is the level change across the seam, ranked against the
music's own changes at every bar line inside the loop: 50% means a typical bar line.

| | What it is | Key (fundamentals / chroma) | Tempo | Loop | Samples (48 kHz) | Seam: click, step (rank) | LRA | Phones (harmony kept under a 200 Hz cut) | Mono fold loss |
|---|---|---|---|---|---|---|---|---|---|
| G | Detuned music-box waltz, bowed glass, low drone | **A minor** .92 / A minor .90 | 72, 3/4 | 48 bars, 120.0 s | 5,759,849 | -23 dB, -0.05 dB (4%) | 3.4 | 1.00 | 0.27 dB |
| J | Dark folk: nyckelharpa and hurdy-gurdy over a drone, frame drum, far-off theremin howl | **D minor** .78 / D minor .64 | 80, 4/4 | 44 bars, 132.0 s | 6,336,078 | -7 dB, -1.0 dB (56%) | 1.7 | 0.84 | 0.71 dB |
| K | Harpsichord and pizzicato creeping, distant bell, low bass | **G minor** .78 / G minor .79 | 76, 4/4 | 40 bars, 126.3 s | 6,063,314 | -12 dB, +0.9 dB (36%) | 1.6 | 0.97 | 0.91 dB |
| L | Hypnotic minor synth arpeggio with tape wobble, deep bass, eerie long notes | **F minor** .89 / F minor .78 | 88, 4/4 | 48 bars, 130.9 s | 6,283,741 | -10 dB, +0.2 dB (19%) | 1.0 | 0.79 | 0.44 dB |
| M | Distant church organ and a wordless pad, ticking clock | **C minor** .77 / G minor .78 (same notes; fundamentals and the bass say C) | 60, 4/4 | 32 bars, 128.0 s | 6,144,274 | -12 dB, +1.2 dB (55%) | 2.4 | 1.00 | 0.90 dB |
| **N** | Celesta tune in harmonic minor over low cellos and basses | **B minor** .92 / B minor .88 | 66, 4/4 | 36 bars, 130.9 s | 6,283,581 | -6 dB, -0.0 dB (0%) | 1.3 | 1.00 | 0.87 dB |

How the key was checked: Krumhansl-Kessler key profiles were run twice. The first run used plain chroma (all partials). The second used
the notes actually played, found by harmonic summation (`f0key.py`). The second matters because plain chroma counts every overtone. A
held low note's 5th overtone is its major third, so drones can read "major" when the tune is minor. The number is the match strength
(1 = perfect). A take counted as minor only when both methods agreed, or when they named the same notes and the bass settled the tonic.
On all six masters, the fundamentals method puts the minor reading 0.15 to 0.38 above the best major reading.

How each loop was made (round one's method, plus three changes):
1. Search a 4-bar grid for start and end points whose surrounding 16 s match. Align the end on transients, fine-tune the waveform, then
   crossfade the music after the end into the head over one beat.
2. **Slow level riding** before the search, for G, J, L and N: a gain correction of at most 2 to 3 dB that follows drifts slower than
   8 s. This leaves the beat and phrase dynamics alone. Without it, the J, N and L seams stepped more than 90% of their own bar lines.
3. **Takes extended** for K and M. Each take spent its first 30 s building up, so the steady part was under 2 minutes. I asked the API to
   continue each take for 50 s (a composition plan: the take's last 20 s, then a new chunk conditioned on the take). I spliced the
   result on: the K join is +0.45 dB with no click, and the M join is -1.3 dB with no click. Both joins sit inside the loop.
4. **Mono:** K, M and N were very wide (2 dB lost when folded to mono). Their side signal is turned down to 0.65-0.7, which brings the
   loss under 1 dB. J's side is at 0.8.

Phones: L (0.79) and J (0.84) lose some bass line on a phone speaker. Round one added a soft-clipped copy of the bass. I tested that and
dropped it: soft clipping adds the bass note's 5th harmonic, its major third, and it made L read "F major" on chroma. An octave-only
version is in `phonefit.py` but did not help, so these two loops have no enhancement.

### Honest opinions

- **N** (pick): a clear, sad tune (top-voice salience 0.55; only G and J are higher, and J's top line is the drone) that turns crooked, over dark sustained strings. Very steady. It is the most "eerie but pleasant for an hour" on paper.
- **L**: the most hypnotic and the steadiest (LRA 1.0), and closest to the leave-it-on pull of the brief. Busy at the top (an arpeggio, about 7 note changes a second), with no sung line. Bass-heavy, so it thins on phones.
- **G**: the purest tune of the six (top-voice salience 0.71), and clearly A minor. But it is sparse: single music-box notes swing in level (LRA 3.4), and the phrase it loops back to differs from the one before the seam (the bar and onsets line up; the phrase does not). The most fragile, and maybe the most beautiful.
- **M**: solemn and still, with a built-in tick, a clear 16 s repeating pattern and the best phone survival. At 60 BPM it is the slowest; it may feel churchy rather than village.
- **K**: creeping and sneaky, the closest to "something is in the house". It is busy (6.7 note changes a second) and has the most transient peaks (true peak -1.8 dBTP).
- **J**: the folk ritual feel with a far-off theremin howl. It is the weakest minor reading (an F-sharp sneaks in) and bass-heavy.

## What failed

- **The generator ignores the stated key.** Of eight first takes (each prompt named its minor key), only K and M came back minor.
  - The music-box waltz came back C major. A second try with chord names came back F major, so I stopped writing chord names with "major" in them.
  - Plans with minor-only wording and a negative-style list ("happy", "bright", "cheerful"...) fixed G, L and N on the next take.
  - The cello direction (lone cello, heartbeat, wind) came back **D major three times**, even when asked for F-sharp minor. I **dropped it**.
  - Dark folk came back E major twice. It became minor (D minor) only with the minor triad spelled out ("the notes D, F and A") and a theremin in place of the musical saw.
- **Sparse piano** (creaking wood, low pulse) came back with unclear key twice. Take 1: E-flat major on chroma, G minor on fundamentals, in loud and quiet sections (LRA 16). Take 2: D major or D minor, at an unclear tempo. Its third take was paid for but lost to a full disk on the shared machine, and the retry paid again and was lost too. No credit was left to try again, so it is **dropped**.
- The renders now never retry a paid call after a local failure, and they wait for 600 MB free before paying (`gen.py`, `run*.sh`).

## Credits

- The counter went from 77,695 to **123,045 of 124,844**: **45,350 used, 1,799 left** this cycle (it resets 24 Dec).
- Spent: 22 takes of 150 s (about 2,060 each, two of them the lost piano takes), two 70 s continuations (about 960 each), and three endings and three pulses (about 2,200 together). That is roughly 825 credits per minute of rendered audio, including copied chunks.

## Exact prompts

Take 1 used the prompt in `prompts/themes.json` (150 s, `force_instrumental`). Later takes used composition plans built by
`tools/mkplan.py` from `plans2.json`: two identical 75 s chunks, the second held to the first, with `_positive_common` and
`_negative_common` appended. Each kept take's exact body is in `prompts/plans/<take>.json` and `raw/theme-<take>.mp3.json`.

| | Kept take | Text and main styles |
|---|---|---|
| G | g3 (plan) | `[Main theme, A minor waltz]` · slow waltz in 3/4 at 72 BPM · A minor, a sad minor-key waltz, mournful · a slightly detuned old music box plays a slow, sad, haunting waltz melody in A minor · bowed glass like a glass harmonica sustains cold eerie minor chords · a low dark drone on A · a soft low plucked note on each downbeat |
| J | j3 (plan) | `[Main theme, D minor]` · 80 BPM, 4/4 · D minor, sad minor-key folk harmony · a nyckelharpa and a hurdy-gurdy play a sad, hypnotic minor tune on the notes D, F and A over a low drone on D · a low cello plays slow sad minor chords · a frame drum keeps a slow steady trance-like beat · far away, a theremin sings long gliding notes like a distant wolf howl, eerie but in tune |
| K | k1 (prompt) + continuation | Instrumental loop, 76 BPM, 4/4, G minor... harpsichord and pizzicato strings creep slowly through a sneaky, memorable, minor-key figure that steps down chromatically; a deep distant church bell tolls softly every two bars; a low bowed double bass... (full text in `themes.json` "k"; continuation in `plans/k1-ext.json`) |
| L | l3 (plan) | `[Main theme, F minor]` · 88 BPM, 4/4 · F minor, sad minor-key harmony · the arpeggio outlines minor chords built on the notes F, A-flat and C · a hypnotic endlessly repeating minor synth arpeggio on a warm detuned analog synthesizer with tape wobble and wow · a slow deep round synth bass · a soft muffled steady kick · a dark airy pad · a simple eerie lead melody of a few long wobbling notes |
| M | m1 (prompt) + continuation | Instrumental loop, 60 BPM, 4/4, C minor... a church pipe organ, very quiet and far away... slow, solemn minor chords and a simple melody on a soft flute stop; a soft wordless choir-like synth pad; an old wooden clock ticks on every beat (`themes.json` "m"; `plans/m1-ext.json`) |
| N | n2 (plan) | `[Main theme, B harmonic minor lullaby]` · 66 BPM, 4/4, gently rocking · B minor, harmonic minor with a raised A-sharp, sad minor-key harmony · a lullaby gone wrong, sad and mournful, never sweet · a celesta plays a gentle rocking lullaby melody in B harmonic minor that turns crooked and sad · low cellos and double basses hold dark slow sustained minor chords · a faint high bowed string shimmer |

Common to every plan: "minor key throughout, sad dark minor-key harmony, melancholic"; "instrumental, no vocals with words"; "dread and
mystery, something is out there in the dark, never horror"; "a memorable motif that keeps returning"; "hypnotic, steady, pleasant to hear
for an hour"; "quiet and sparse so it sits under people talking"; "no intro... no fade-out, seamless loop". Negatives: happy, cheerful,
bright, uplifting, hopeful, triumphant, playful, cute, bouncy, jaunty, lyrics, singing words, horror, jump scare, loud hits, build-up,
drop, intro, fade-out, ending.

All takes and their keys (fundamentals): g1 C major, g2 F major, **g3 A minor**; h1, h2 and h3 D major; j1 and j2 E major, **j3 D minor**;
**k1 G minor**; l1 E-flat major, l2 F major/F minor (unclear), **l3 F minor**; **m1 C minor**; n1 B-flat major, **n2 B minor**;
p1 G minor/E-flat major (unclear), p2 D minor/D major (unclear).

## Board

`board/sound-theme.json`: card `sound-theme`, order 11, has six rows. Each label is one letter; the description is in `note`. Choices are
G, J, K, L, M, N or None, and the default is N. The card says all six are in a minor key and darker than the first six.
To publish:
1. Upload `board/upload/*.mp4` (6 files) as assets to the board.
2. Write `{"theme-g.mp4": "/_blob/...", ...}`.
3. Run `python3 board/fill.py map.json`. It writes `board/ready/sound-theme.json`.
4. Set `items/sound-theme` from that file.
