# Sound candidates: listening sheet (25 Nov 2026)

Made with the ElevenLabs API (music `music_v2_5`, sound effects `eleven_text_to_sound_v2` and `_v3`, stem separation).
Every prompt describes only sound and style: no game, person or artist names.

I cannot hear. Every judgement below comes from measurement and spectrograms: loudness, spectrum, seam tests, key and
tempo estimates, self-similarity, melody proxies. The owner's ears decide. "My pick" means "best on the numbers and the brief".

**My pick: theme A** (woozy organ groove, D minor, 76 BPM). It is the closest to the brief (hypnotic, warm, a
wobbly eerie lead over a slow groove) and the steadiest (LRA 1.2 LU). It has a moving tune, and it has the full layer set.
**Runner-up: B** (music-box waltz). It has the clearest tune and survives phone speakers best, but it has no layers yet.

## Where things are

| Folder | What |
|---|---|
| `masters/` | WAV masters, 48 kHz, 24-bit, stereo. Each loop file loops end to start as it is (no crossfade needed at play time). |
| `masters/sfx/` | SFX masters: WAV 48 kHz 24-bit **mono**, trimmed to the attack. `masters/sfx-stereo/`: stereo originals of the 5 stingers and the night-air bed. |
| `*.m4a`, `*.ogg` (top level) | Listening copies of every theme part: AAC 64 kbps and Opus 64 kbps, stereo. |
| `sfx/` | SFX listening copies (AAC 64 kbps, Opus 48 kbps; the night-air bed is stereo at 96k). |
| `app-loop/` | Loop copies ready for an app: 4096 samples of pre-roll and post-roll; loop between the sample points in each `.json` (see "Lossy loops"). |
| `arc/` | "As heard in a game", one per direction, 90 s (`.m4a` 96k, `.ogg`), timeline in each `.json`. |
| `board/` | Board cards (`sound-theme.json`, `sound-sfx.json`), files to upload (`upload/`), `fill.py`, inline fallback. |
| `prompts/` | Exact prompts (`theme-prompts.json`, `sfx-prompts.json`), composition plans (`plans/`), the scripts I used (`tools/`). |
| `raw/` | Every raw take as delivered by the API, plus a `.json` per take (request body, response headers, song id). |

## 1. Main theme: six directions

Two takes each, rendered at 170 s. I kept the better take per direction and cut a loop from inside it.

How each loop was made:
1. Search for start and end points whose surrounding 16 s of music match (chroma plus 24 band energies), on a 4-bar grid, with a loudness-match penalty.
2. Align the end on the transients (onset envelope), then fine-tune the waveform within about 1.3 ms.
3. Crossfade the music after the end into the head over one beat. The file's last sample therefore runs straight into its first.
4. Check: render the loop twice end to end and test the seam for a click (high-frequency energy against the local 99th percentile), a level step, a gap (the quietest 50 ms) and doubled hits (the onset lag inside the crossfade).

All six pass: no click, no gap, a level step of 0.75 dB or less beyond what the music itself does, and onsets aligned within 1.6 ms.
No direction failed outright. One retry was needed: the first alignment pass left 11 to 32 ms flams in A, B, C and D, which I fixed by aligning on transients, not bass phase.

Keys are estimated from the audio (Krumhansl profile on fine chroma; r = match strength). Tempo is exact on every take (measured).

| Dir | What it is | Kept take | Loop | Samples (48 kHz) | Tempo, metre | Key (est.) | Master | m4a / ogg | Phones (harmony kept under a 200 Hz cut) | Mono fold loss |
|---|---|---|---|---|---|---|---|---|---|---|
| **A** | Woozy detuned organ, round synth bass, brushes, wobbly tape lead | a2 (a1 kept in raw) | 48.26 to 161.94 s of the take, **36 bars**, 113.69 s | 5,456,861 | 76 BPM, 4/4 | D minor (r .82), as asked | -18.0 LUFS, -5.8 dBTP, LRA 1.2 | 922 / 1008 KB | 0.77 | 0.27 dB |
| B | Music-box and celesta waltz, plucked bass, felt piano | b2 | 8.64 to 128.64 s, **64 bars of 3/4**, 120.00 s | 5,759,870 | 96 BPM, 3/4 | F-sharp minor (r .72); asked A minor | -18.0, -4.2, LRA 1.6 | 968 / 1114 KB | **0.93** | 1.34 dB (widest stereo) |
| C | Fingerpicked nylon guitar, dulcimer and kalimba hook, low clarinet, frame drum | c2 | 16.15 to 136.15 s, **44 bars**, 120.00 s | 5,759,846 | 88 BPM, 4/4 | G major (r .83); asked E dorian | -18.0, -5.5, LRA 1.8 | 967 / 1108 KB | 0.88 | 0.26 dB |
| D | Late-night jazz trio: vibraphone, walking bass, brushes; a sustained gliding voice from 55 to 82 s | d1 | 16.28 to 153.42 s, **40 bars**, 137.14 s | 6,582,845 | 70 BPM, 4/4 swing | D minor, weak (r .56); asked G minor | -18.0, -3.3, LRA 2.7 | 1106 / 1083 KB | 0.30 | 0.39 dB |
| E | Pizzicato strings, harpsichord and glockenspiel tune, bassoon, woodblock | e1 | 8.28 to 161.88 s, **64 bars**, 153.60 s | 7,372,861 | 100 BPM, 4/4 | G minor (r .70); asked C minor | -18.0, -3.0, LRA 1.0 | 1257 / 1283 KB | 0.48 | 0.90 dB |
| **F** | Dusty wobbly electric piano, round bass, lazy beat, kalimba and whistle motif, crickets | f1 | 28.29 to 161.62 s, **40 bars**, 133.34 s | 6,400,061 | 72 BPM, 4/4 | F minor (r .79), as asked | -18.0, -4.2, LRA 1.8 | 1086 / 1110 KB | 0.60 | 0.11 dB |

Seam figures for each loop (click, then level step beyond the music's own, then onset lag): A -16 dB, -0.72 dB, 0.5 ms;
B -21, -0.19, 0.3; C -21, +0.17, 0.1; D -25, -0.75, 1.6; E -20, -0.03, 1.1; F -36, +0.03, 1.4.
Full numbers are in `masters/theme-<d>.json` and `prompts/tools/`.

Size: every listening copy is under 1.5 MB at 64 kbps stereo (0.9 to 1.3 MB). The trade is plain: 64 kbps AAC is fine for
mellow music on a phone. 96 kbps is audibly cleaner on headphones but takes the long loops (D, E, F) past 1.5 MB. Mono at
64 kbps would be cleaner still per byte, and a phone at a table is mono anyway.

### Honest opinions

- **A**: my pick. It is the most "hypnotic slow groove with an eerie wobbly tune". Its top line moves over 13 semitones, and its texture is the steadiest. It keeps 0.86 of its harmony on a phone speaker once the bass harmonics are added (see the layer set).
- **B**: the clearest tune (the strongest single top voice of all six) and the best on phone speakers. It is sparse and leaves room for talk. The risk is that a music-box waltz may read as "lullaby" rather than "groove". It came out in F-sharp minor, not the A minor I asked for.
- **C**: warm and steady, with a slow, clear melody. It came out in G major, so it is probably the least eerie of the six.
- **D**: a sly jazz feel that suits bluffing, but 81% of its energy is below 200 Hz: on phone speakers most of its harmony disappears (0.30). The gliding voice at 55 to 82 s is a melody, not a glitch.
- **E**: the busiest line (about 4.3 note changes a second). It breaks "never busy" and thins out on phones. I'd drop it first.
- **F**: very steady, the cleanest loop seam, cosy. It is bass-heavy, so it thins on phone speakers (0.60, or 0.69 with bass harmonics).
- Rejected takes: a1 (one riff, little tune), b1 (dark, swings 10 dB with each bar), c1 (drifts and fades), d2 (two sections), e2 (loud and quiet sections, LRA 6.8), f2 (three sections). All are kept in `raw/`.

## 2. Bed plus stage layers (A and F)

This follows the player session's preferred form: one long bed, short layers on top, and night as the bed darkened in the player.

| Part | A | F | How it was made |
|---|---|---|---|
| Bed `theme-<d>-bed.wav` | **5,456,880 samples** (113.685 s, 36 bars, bar = 151,580 samples) | **6,400,080 samples** (133.335 s, 40 bars, bar = 160,002) | The day loop plus upper harmonics of its own bass stem (180 Hz to 1.2 kHz), so the bass line survives a phone speaker: A 0.77 to 0.86, F 0.60 to 0.69. Resampled round the loop (FFT, 3.5 ppm, inaudible) to a length divisible by 60, so layers can be 1/2, 1/3, 1/4, 1/5 or 1/6 of it. |
| Vote layer `theme-<d>-layer-vote.wav` | **1,818,960 samples = bed / 3** (12 bars, 37.9 s) | **1,600,020 samples = bed / 4** (10 bars, 33.3 s) | A generated percussion-only pulse (woodblock tick on each beat, soft hats, shaker) at the bed's tempo. Its bar was resampled to the bed's bar exactly and its phase aligned to the bed's own drum stem: **lag 0.0 ms over the whole bed**. High-passed at 180 Hz (removes a pitched heartbeat drum), gently limited, 10 LU under the bed. No pitch, so no key or tuning risk. |
| Reveal layer `theme-<d>-layer-reveal.wav` | 5,456,880 samples = bed | 6,400,080 = bed | The bed's own chords (its other and piano stems), washed through a 4.5 s circular reverb with no direct sound and high-passed at 350 Hz. It is pulse-free and follows the bed's harmony exactly, so it is in key and in tune by construction. 6 LU under the bed. |
| Ending `theme-<d>-bed-ending.wav` | 11.4 s | 11.3 s | Generated as a continuation of the take's last 10 s, then aligned so its first sample follows the bed's last sample (join click -16 dB under the local 99th percentile). Play it instead of wrapping. |

Checks on the mixes (sample peaks; no clipping anywhere; mono fold loss in brackets):

| Mix | A | F |
|---|---|---|
| bed | -19.7 LUFS, peak -6.8 (0.27 dB) | -20.6 LUFS, peak -6.3 (0.09 dB) |
| bed + vote | -19.3, -4.5 (0.34) | -20.2, -4.5 (0.14) |
| bed + reveal | -19.0, -6.2 (0.67) | -19.7, -5.0 (0.61) |
| bed + vote + reveal | -18.6, **-3.5** (0.71) | -19.3, **-3.5** (0.60) |

- Headroom: the three parts were scaled together so the worst case peaks at -3.5 dBFS. This leaves each bed 1.7 to 2.6 dB under the -18 LUFS of the other directions. If the player never plays both layers at once, the bed can go up about 1 dB.
- Tuning: beds -1.2 and -2.3 cents from A440. The layers come from the bed itself, or have no pitch, so nothing can beat.
- Night: the bed darkened in the player (the arc uses a 1.2 kHz low-pass and -6 dB). Separate night files exist too (below).

What did not work, and what I did instead:
- Generated layers with a stated key and tempo over the bed. Tempo held exactly, but the key did not. Four pulse-free "pad" takes asked for D minor and F minor came back as D major, D-sharp major, C major and C minor. In D major, an F-sharp would sit against the bed's F. I dropped them for the bed-derived wash.
- Generated stage variants conditioned on the bed. Three "night" takes and two "vote" takes kept the same arrangement: their frames match the day loop 0.97 to 0.99, the same as the day loop matches itself. Fresh-prompt vote takes at the same key and tempo did differ (a-tense-T2 and f-tense-T2 match the day loop 0.90 and 0.92); they are kept as whole variants.
- Stem separation of the vote takes, to lift a pulse out of them. A's take came back as a single "other" stem; F's had no drums at all.

### Whole variants (also kept)

These are full alternatives per stage, with the same tempo and key as their direction. Each loops by itself, -18 LUFS (night -21).

| File | Samples | Length | Key (est.) | Made by |
|---|---|---|---|---|
| `theme-a-night` | 5,456,861 | 113.7 s | D minor | the A loop's own stems, without drums: other + 0.8 piano + 0.45 bass, 4.5 kHz low-pass. Sample-aligned with `theme-a.wav`, so the two can cross-fade at any moment. |
| `theme-f-night` | 6,400,061 | 133.3 s | F minor | the same method, aligned with `theme-f.wav` |
| `theme-a-tense` | 4,850,693 | 101.1 s, 32 bars | D minor | a fresh prompt at 76 BPM in D minor (prompt below) |
| `theme-f-tense` | 4,480,153 | 93.3 s, 28 bars | A-flat major (the relative major of F minor: the same notes) | a fresh prompt at 72 BPM in F minor |
| `theme-a-ending`, `theme-f-ending` | 547,200 / 542,400 | 11.4 / 11.3 s | D minor / F minor | follows `theme-a.wav` / `theme-f.wav` (at -18 LUFS) |

### As heard in a game (`arc/`, and on the board)

Each arc is 90 s: 0:00 bed; 0:24 bed darkened (night); 0:44 bed + vote layer; 1:08 the reveal layer swells in;
1:12 reveal sting; 1:22 village-wins sting, and the music fades out. B to E have no layers, so their 0:44 section is the bed alone.
Measured stage levels for A: bed about -20, night about -26.5, vote about -19.5, reveal about -18.5 LUFS.

### Lossy loops (for the app)

- The `.ogg` (Opus) copies decode sample-exact. The `.m4a` (AAC) copies decode up to 1023 samples long, because AAC pads the last frame to 1024 samples. A naive `.m4a` loop therefore has a gap of up to 21 ms.
- Even trimmed to length, a lossy file's decoded start and end don't quite agree. B's `.m4a` clicked at +10.5 dB over the local 99th percentile, and F-night's at +15.
- Fix in `app-loop/`: each copy carries 4096 samples of its own tail before the loop and its own head after it. Loop between `loop_start_sample` and `loop_end_sample` from the `.json`; Web Audio `loopStart`/`loopEnd` do exactly this. Verified on every file: no click.
- F-night and F also needed their wrap point moved into a quiet gap (rotated 4,722,720 samples, the same for both, so they stay aligned). F's reveal-layer `.m4a` needed 80 kbps.
- The WAV masters need none of this.

## 3. Sound effects

Three takes of each, plus redos where the takes were weak; the best one kept. For each sound I picked by spectrogram,
noise floor, how many events it has, and whether it ends in silence.

Mastering:
- Trimmed to 5 ms before the first sound, with a 2 ms fade-in and a raised-cosine fade-out.
- Mono masters; the five stingers and the night-air bed folded down from stereo with their loudness kept (no hollowing; they lose about 3 dB because they are wide).
- Levelled by class on the loudest 100 ms (K-weighted): taps and panels -24, cards and cues -20, stingers -16, the night-air bed -28 LUFS integrated.
- Every peak capped at -6 dBFS in the master and in every decoded copy (the loudest copy decodes at -6.4). Fifteen transient sounds hit that cap before their class level, so they sit 1.8 to 9.2 dB under it (tap, swap, error, panel-close, timer-low, mason, insomniac and more). The app can raise them if they feel faint.

Redone:
- **night-falls**: the first three were wind or rumble with no bell. Redone with a simpler prompt; take 5 is a deep bell (partials at about 150, 450 and 700 Hz) over 2.5 s.
- **mason**: asked for two taps; the takes gave one, three or four. I kept take 3 cut after its second tap.
- **tap**: the take had a faint rustle 280 ms before its tick, which would feel like lag. Re-cut to start 8 ms before the tick.
- **lobby bed**: the 20 s takes would repeat their owl every 20 s; one started with silence. A 30 s take, looped with a 2 s crossfade (seam level step 0.6 dB).

Two things to note:
- `docs/design/feel.md` says night is silent and still, with no sound. "Your turn" and the role sounds are night sounds: they need the owner's yes.
- The role sounds are meant as **public** wake cues, played on every phone at once, like the narrator in the table game. Played only on the acting player's phone, they would tell the table who holds which role.

Model note: v3 takes were often quiet, with high noise floors and tails cut before they decayed. v2 takes usually ended in silence. The kept set mixes both.

| Sound | Kept take (model) | Length | Peak | Loudest 100 ms (LUFS) | WAV / m4a / ogg | Prompt (requested length) |
|---|---|---|---|---|---|---|
| tap | tap-2 (v3) (re-cut to the tick) | 0.14 s | -7.0 dBFS | -26.0 | 20.3 / 2.3 / 1.2 KB | A single soft fingertip tap on a sheet of thick handmade paper lying on a wooden table, one tiny dry papery tick, very short, very close, no echo, nothing else (0.5 s) |
| flip | flip-2 (v3) | 0.69 s | -7.2 dBFS | -20.0 | 97.1 / 6.6 / 3.9 KB | A single stiff paper card flipped over quickly and laid face up on a wooden table, one soft papery swish ending in a light flat tap, close and dry, nothing else (0.8 s) |
| deal | deal-2 (v3) | 0.51 s | -8.7 dBFS | -20.0 | 71.8 / 5.2 / 3.0 KB | One stiff paper card slid quickly across a cloth-covered wooden table, a short soft papery slide and a gentle stop, close and dry, nothing else (0.6 s) |
| night-falls | night-falls-r-5 (v2) | 3.00 s | -10.7 dBFS | -19.0 | 422.0 / 25.0 / 16.6 KB | One deep soft warm bronze bell struck once and slowly fading away, with a soft breath of night wind underneath, calm and gentle, nothing sudden, no voices, nothing else (3.0 s) |
| your-turn | your-turn-3 (v2) | 1.20 s | -14.3 dBFS | -20.0 | 168.8 / 10.7 / 6.4 KB | One soft warm low wooden chime with a tiny glimmer of a small bell on top, gentle and inviting, very quiet, soft fading tail, calm, nothing else (1.2 s) |
| swap | swap-3 (v2) | 0.80 s | -7.0 dBFS | -27.6 | 112.6 / 7.5 / 4.6 KB | Two stiff paper cards quickly swapped on a wooden table, two quick soft papery slides crossing each other, light, close and dry, nothing else (0.8 s) |
| peek | peek-3 (v2) | 0.41 s | -7.0 dBFS | -22.5 | 57.1 / 4.3 / 2.5 KB | A secret glimpse: the corner of a paper card lifted with a faint soft shimmer of tiny glass bells, hushed and mysterious, very close, nothing else (0.9 s) |
| timer-low | timer-low-3 (v2) | 1.65 s | -7.0 dBFS | -26.5 | 231.4 / 14.2 / 9.6 KB | An old wooden clock ticking gently, four slow quiet ticks with a faint warm resonance, calm and soft, not urgent, close, nothing else (2.0 s) |
| ready-vote | ready-vote-1 (v3) | 1.06 s | -7.0 dBFS | -21.8 | 149.9 / 9.6 / 5.7 KB | One gentle low knock on a wooden table followed by a soft warm bell tone, quiet, like an invitation to decide, fading softly, nothing else (1.2 s) |
| vote-cast | vote-cast-2 (v3) | 0.35 s | -7.0 dBFS | -23.6 | 49.3 / 3.9 / 2.0 KB | A small heavy wooden token placed firmly on a wooden table, one soft round satisfying click-thud, close and dry, nothing else (0.6 s) |
| reveal | reveal-1 (v3) | 2.39 s | -10.9 dBFS | -19.1 | 336.2 / 20.3 / 15.3 KB | A gentle mysterious reveal: a soft rising shimmer of small bells and a breath of wind ending on one deep warm soft drum hit with a soft fading tail, not loud, no voices (2.5 s) |
| village-wins | village-wins-2 (v3) | 2.98 s | -7.3 dBFS | -19.0 | 419.2 / 25.0 / 19.8 KB | A warm joyful little fanfare of small hand bells and a soft wooden xylophone rising to a bright major chord, a cosy village celebration, gentle, fading softly, no voices (3.5 s) |
| wolves-win | wolves-win-2 (v3) | 3.23 s | -10.6 dBFS | -19.0 | 455.0 / 26.9 / 17.8 KB | A sly dark little musical sting: a low plucked cello and a soft muted horn sliding down into a minor chord, a faint wolf howl far away in the distance, mischievous not scary, fading softly (3.5 s) |
| dawn | dawn-3 (v2) | 3.00 s | -13.4 dBFS | -18.9 | 422.0 / 25.1 / 17.4 KB | Dawn over a quiet village: a soft warm rising tone, a few distant gentle birds, one small brass bell struck softly, calm and bright, fading softly, nothing sudden (3.0 s) |
| join | join-1 (v3) | 0.66 s | -9.9 dBFS | -20.0 | 92.2 / 6.2 / 3.4 KB | A soft welcoming two-note wooden chime, a small rising interval, warm and quiet, close, short fading tail, nothing else (0.8 s) |
| error | error-3 (v2) | 0.57 s | -7.0 dBFS | -27.2 | 80.3 / 5.6 / 2.8 KB | A soft muted low double knock on wood, gentle and dull, like a polite no, quiet, close and dry, nothing else (0.6 s) |
| panel-open | panel-open-2 (v3) | 0.43 s | -11.6 dBFS | -24.0 | 60.6 / 4.5 / 2.6 KB | A folded sheet of thick paper opened smoothly, a short soft papery rustle, close and dry, nothing else (0.5 s) |
| panel-close | panel-close-2 (v3) | 0.39 s | -7.0 dBFS | -28.8 | 54.2 / 4.3 / 2.3 KB | A sheet of thick paper folded closed with a soft press, a short papery rustle ending in a soft pat, close and dry, nothing else (0.5 s) |
| hold-start | hold-start-3 (v2) | 0.39 s | -7.0 dBFS | -26.4 | 54.2 / 4.2 / 2.4 KB | A paper card slowly lifted a little off a wooden table, a tiny soft papery lift, hushed, very close, nothing else (0.5 s) |
| hold-release | hold-release-3 (v2) | 0.48 s | -7.0 dBFS | -26.1 | 67.6 / 5.0 / 2.3 KB | A paper card let go and settling flat on a wooden table, a tiny soft papery pat, hushed, very close, nothing else (0.5 s) |
| count-tick | count-tick-3 (v2) | 0.40 s | -7.0 dBFS | -23.4 | 55.6 / 4.2 / 2.5 KB | One single soft tick of an old wooden clock, warm, quiet, close and dry, nothing else (0.5 s) |
| lobby-bed | lobby-bed-r-5 (v3) (looped, 2 s crossfade) | 28.00 s | -15.8 dBFS | -28.2 | 3937.6 / 335.1 / 294.2 KB | Quiet even night ambience outside a small village: a soft steady breeze, gentle distant crickets, the faint crackle of a candle flame, and just once a far-away owl hooting softly, calm and peaceful, no music, no voices (30.0 s, loop) |
| role-werewolf | role-werewolf-2 (v3) | 1.76 s | -14.0 dBFS | -20.0 | 247.6 / 15.2 / 9.6 KB | A soft wolf howl very far away across a valley at night with a breath of wind, short, gentle, not scary (1.8 s) |
| role-minion | role-minion-2 (v3) | 0.98 s | -10.1 dBFS | -20.0 | 137.9 / 8.8 / 5.0 KB | A sly little descending pluck of two notes on a low muted string, mischievous, quiet, nothing else (1.0 s) |
| role-mason | role-mason-3 (v2) (cut to 2 taps) | 0.47 s | -7.0 dBFS | -29.2 | 66.9 / 4.9 / 2.5 KB | Two soft taps of a small hammer on stone, close and gentle, a tiny stony ring, nothing else (1.0 s) |
| role-seer | role-seer-2 (v3) | 1.34 s | -13.6 dBFS | -20.0 | 188.5 / 11.9 / 8.0 KB | A soft crystal shimmer, a gentle glassy glimmer rising with a breath of air, mysterious and quiet, nothing else (1.5 s) |
| role-robber | role-robber-1 (v3) | 0.89 s | -7.0 dBFS | -23.5 | 124.6 / 8.2 / 5.0 KB | A quick soft sneaky rustle of a cloth pouch and the faint clink of two small coins, close and quiet, nothing else (1.0 s) |
| role-troublemaker | role-troublemaker-3 (v2) | 0.71 s | -7.0 dBFS | -24.7 | 100.6 / 6.8 / 4.3 KB | A playful quick soft shuffle of two paper cards and a tiny mischievous wooden click, close and quiet, nothing else (1.0 s) |
| role-drunk | role-drunk-3 (v2) | 1.20 s | -10.6 dBFS | -20.0 | 168.8 / 10.6 / 6.5 KB | A soft wobbly pluck on a detuned string with a lazy sliding pitch, playful and tipsy, quiet, nothing else (1.2 s) |
| role-insomniac | role-insomniac-2 (v3) | 1.18 s | -7.0 dBFS | -26.2 | 166.0 / 10.5 / 6.7 KB | A soft creak of an old wooden bed and a small match struck gently to light a candle, quiet, close, nothing else (1.5 s) |
| role-doppelganger | role-doppelganger-3 (v2) | 1.10 s | -9.0 dBFS | -20.0 | 154.8 / 9.8 / 6.1 KB | A soft shimmering mirror-like swell, a gentle glassy reversed sound that folds back into itself, mysterious and quiet, nothing else (1.5 s) |

My picks, by sound:
- **Strongest**: vote-cast (one round thud), timer-low (exactly four even ticks), error (a soft double knock), village-wins (four bell strikes, then a decay), wolves-win (plucks and a horn sliding down, as asked), werewolf (a real howl contour), panel-close, count-tick.
- **Weakest** (ears first): peek (quick flutters; the brighter takes were hiss), your-turn (a single plain tone), drunk (a wobbly tone), reveal (a swell with no clear hit at the end), night-falls (good bell; the wind is faint).

## 4. Board

Two cards, written for the owner, following `docs/dev/owner-board.md`:
- `board/sound-theme.json`, id `sound-theme`, order 11: six directions with two rows each (the loop, and "in a game"). Choices A to F or None; default A.
- `board/sound-sfx.json`, id `sound-sfx`, order 12: 31 rows. Choices: Keep them, Redo some (name them in the note), Redo all; default keep.

The audio is too big for base64 in a card document (theme previews are about 1 MB each; the SFX total 380 KB as base64, over the 256 KiB limit), so each row's `src` is a placeholder, `UPLOAD:<file>`. To publish:
1. Upload `board/upload/*` (43 files: AAC in `.mp4`, because the asset store refuses mp3) with `Artifact publish asset:true file_paths:[...]` to the board url, 25 per call. I have not confirmed the store accepts audio-only `.mp4`; if it refuses them, use the fallback below for the SFX.
2. Write `{"theme-a.mp4": "/_blob/...", ...}` from the results and run `python3 board/fill.py map.json`. It writes `board/ready/sound-theme.json` and `board/ready/sound-sfx.json`, and stops if any file has no url.
3. `ArtifactData batch` `set` for `items/sound-theme` and `items/sound-sfx`, with `file_path` pointing at those files.

Fallback: `board/sound-sfx-inline.json` (201 KB) is the SFX card with 30 sounds as base64 mp3 (mono, 32 kbps: thinner on the top end). It needs no upload, but leaves out the night-air loop.
Theme previews are levelled to the same loudness (loops -18 LUFS, arcs -19 LUFS), so no direction wins by being louder.

## 5. Requests and credits

- Music: 36 renders. Six directions x 2 takes at 170 s, 1 early test at 100 s, 3 night, 4 vote and 4 ending continuations, 4 fresh vote takes, 4 pads, 4 pulses.
- Sound effects: 103 renders (93 first takes, 8 redos, 2 model tests).
- Stem separation: 5 calls.
- The account counter went from 0 to **77,695 of 124,844 credits** this cycle (62%). The counter updates late, so per-call costs are rough: about 900 credits a minute of music, about 3,300 per stem separation, about 15 to 20 per short sound effect.
- Building layers for B or C the same way would cost about 5,000 credits each (one separation, two pulse takes).

## 6. Exact prompts

Theme takes (`music_length_ms` 170000, `force_instrumental` true, `store_for_inpainting` true). The verbatim text of every prompt and plan is in `prompts/`.

- **A**: Instrumental loop, 76 BPM, 4/4, D minor. A slow hypnotic groove for a cosy, slightly spooky night by candlelight. A warm, gently detuned electric organ plays a slow swaying chord pattern; a round, soft synth bass walks a simple repeating line; brushed drums and a soft wooden shaker keep a lazy swing. Over it, a wobbly pitch-bending lead with tape wow and flutter sings a short, memorable, eerie melody that repeats and develops slightly. Woozy, warm, dreamy, a little uncanny, never scary. Mellow, low-mid heavy, sits quietly under conversation. Starts immediately at full groove with no intro, keeps the same energy throughout with no build-up, no breakdown, no ending and no fade-out, so it can loop seamlessly.
- **B**: Instrumental loop, 3/4 waltz at 96 BPM, A minor. A gentle, eerie lullaby waltz for a quiet village at night. A soft music box and celesta carry a lilting, memorable little melody; a plucked upright bass on each downbeat; muted felt piano chords on beats two and three; a faint airy bowed tone and soft wind far in the background. Hushed, warm, candlelit, mysterious and pleasant, a little wistful, never horror. Sparse and quiet, leaves room for talking. Starts immediately with the full arrangement, no intro, same energy throughout, no build-up, no ending and no fade-out, so it can loop seamlessly.
- **C**: Instrumental loop, 88 BPM, 4/4, E dorian. A rustic, hypnotic folk groove around a fire in a dark forest village. A fingerpicked nylon-string guitar plays a rolling repeating pattern; a hammered dulcimer and kalimba answer with a short catchy eerie hook; a low clarinet hums a slow countermelody; soft frame drum and a deep heartbeat-like kick keep a slow steady pulse. Warm, earthy, mysterious, gently swaying, never dark or scary. Mellow and uncluttered so it sits under people talking. Starts immediately at full groove, no intro, same energy throughout, no build-up, no ending and no fade-out, so it can loop seamlessly.
- **D**: Instrumental loop, 70 BPM, 4/4 with a soft swing, G minor. A sly, smoky late-night jazz trio for a game of secrets and bluffing. A mellow vibraphone plays a short, sneaky, memorable tune with little chromatic turns; an upright bass walks slowly and warmly; drums played only with brushes on a soft snare and a quiet ride cymbal; a few soft felt piano chords. Mischievous, intimate, a little mysterious, relaxed, never tense. Quiet and spacious so it sits under conversation. Starts immediately at full groove with no intro, same energy throughout, no solo, no build-up, no ending and no fade-out, so it can loop seamlessly.
- **E**: Instrumental loop, 100 BPM, 4/4, C minor. A playful, tiptoeing mystery theme like a moonlit puzzle box. Pizzicato strings pluck a sneaky repeating figure; a harpsichord and a soft glockenspiel share a catchy, slightly crooked melody; a warm bassoon answers in the low register; a soft woodblock and light hand percussion keep time. Curious, mischievous, a little eerie, cosy and charming, never scary or dramatic. Light and uncluttered so it sits under people talking. Starts immediately with the full arrangement, no intro, same energy throughout, no build-up, no ending and no fade-out, so it can loop seamlessly.
- **F**: Instrumental loop, 72 BPM, 4/4, F minor. A dusty, hypnotic lo-fi night groove. A warm, slightly wobbly electric piano plays lazy jazzy chords; a soft, round bass line repeats; a relaxed boom-bap beat with a muffled kick, soft rim clicks and gentle shaker, slightly behind the beat; a small kalimba and a faint whistling synth play a short eerie memorable motif; faint vinyl crackle and night crickets underneath. Woozy, cosy, a little uncanny, never dark. Low and mellow so it sits under conversation. Starts immediately at full groove, no intro, same energy throughout, no build-up, no ending and no fade-out, so it can loop seamlessly.

Vote pulse (A; F is the same at 72 BPM; 60 s): Instrumental percussion only, 76 BPM, 4/4. A soft, steady, slightly suspenseful ticking pulse for a secret vote: a muted woodblock ticking on every beat like a clock, quiet closed hi-hat in eighth notes, a soft wooden shaker, and a very soft low heartbeat-like drum on beats one and three. No pitched instruments, no melody, no chords, no bass, no fills, no build-up, no ending, the same throughout so it can loop seamlessly.

Whole vote variant (A; F is the same at 72 BPM in F minor, with its own instruments; 120 s): Instrumental loop, 76 BPM, 4/4, D minor. Gentle suspense while friends cast a secret vote at a candlelit table. A soft ticking clock-like pulse on a muted woodblock runs throughout; the bass repeats one insistent note in steady eighth notes; chords are held suspended and unresolved; the melody plays low, slow and slightly uneasy, with few notes. Instruments: a gently detuned electric organ, a round soft synth bass and a wobbly pitch-bending lead with tape wow and flutter. Cosy but on edge, quiet and steady, never scary. Starts immediately with no intro, same energy throughout, no build-up, no ending and no fade-out, so it can loop seamlessly.

Ending (a composition plan): the take's last 10 s as an audio chunk, then a 12 s chunk.
- Text: `[Ending] {final cadence resolves home} {last chord rings out and fades to silence}`.
- Styles: "a short resolved ending of the same piece", "same tempo 76 BPM and same key", "the band plays one final cadence that resolves home with a slight slow-down", "the last chord rings out warmly with a soft tape wobble and fades to silence", plus the direction's instruments.
- Conditioned on the take's last 30 s, strength high.

Pads (rejected for key) and the night and vote continuation plans (rejected as too similar to the day loop) are in `prompts/plans/`.
