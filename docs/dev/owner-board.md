# Owner's board: how to update it

The owner does not read issues or pull requests. Anything that needs the owner's eyes or a decision goes on this board: big pictures, few plain words, and for a decision, the choices and what happens by default. Before and after pictures of anything visible go here before it merges.

Board: https://claude.ai/artifact/K5KpLD8VjvzBbYr5VjiBJK (private to the owner; page source
`docs/dev/owner-board/board.html`, hero art `docs/dev/owner-board/art/village-band.webp`).

Everything on the board comes from its database. Never republish the page to change an item.
Load the tools once: `ToolSearch select:ArtifactData`. Every call below takes
`url: "https://claude.ai/artifact/K5KpLD8VjvzBbYr5VjiBJK"`.

## Collections

| Collection | Who writes | What it is |
|---|---|---|
| `items` | you (editors only) | One card each. `section` "answer" = Needs your answer, "look" = Look at this. |
| `answers` | the page (the owner's taps) | One doc per answered item, doc id = the item's id. |
| `decided` | you | The record of decisions, shown under "Decided". |
| `done` | you | The quiet "Done lately" list. |
| collection `meta`, doc `board` | you | `look_intro`: the line under "Look at this". |

## An item (`items/<id>`)

```json
{
  "section": "answer",              // "answer" or "look"
  "order": 70,                      // smaller = higher; questions 10-99, look items 100+
  "status": "open",                 // "retired" hides it
  "title": "Should Back ever take you out of a game?",   // one plain line
  "short": "The Back button during a game",             // used in Decided after a tap
  "what": "Today Back closes panels like this one.",    // line 1: what it is
  "ask": "Keep it that way?",                           // line 2: what we ask
  "choices": [{"id": "keep", "label": "Keep it"}, {"id": "change", "label": "Change it"}],
  "default": "Back closes panels; Leave stays the only way out.",  // shown as "If you don't answer: ..."
  "default_choice": "keep",         // optional: tags that button "Default"
  "note": true,                     // optional: false hides the note box
  "pictures": [{"src": "/_blob/<id>", "alt": "...", "pos": "50% 100%", "caption": "..."}],
  "before": {"src": "/_blob/<id>", "alt": "..."},     // look items: before + after
  "after":  {"src": "/_blob/<id>", "alt": "..."},     //   give a touch slider instead of pictures
  "ref": "Questions list, 5 · #24", // tiny footer
  "sounds": [ ...takes, see "Add sounds to choose by ear" ],   // optional
  "lead": "One plain line shown above the card"                // optional, see below
}
```

- 1 picture shows big and cropped to 4:5 (`pos` = CSS object-position, e.g. "50% 0%" for the top
  of a phone screen). 2 pictures show side by side, whole. Tap opens full size. Many competing
  options for one slot: set `pick`, see "Group the options for one slot".
- No `choices` = a card to look at with no buttons.
- Every decision card must say what happens by default (`default`).

## Group the options for one slot (a picker card)

Options that compete for the same slot go on one card, not one card each. Set `pick` on the item
and give 2 or more `pictures`, each with an `id` and a `caption`:

```json
{
  "section": "answer", "order": 20, "status": "open",
  "title": "Which look for the night screen?",
  "ask": "Mark every one you like.",
  "pick": "many",                       // "many" = mark any number; "one" = marking one unmarks the others
  "pictures": [
    {"id": "lantern", "src": "/_blob/<id>", "alt": "...", "caption": "Lantern square"},
    {"id": "well",    "src": "/_blob/<id>", "alt": "...", "caption": "Moonlit well"},
    {"id": "bridge",  "src": "/_blob/<id>", "alt": "...", "caption": "The long bridge"}
  ],
  "default": "We keep the current screen."
}
```

- The card shows a swipeable strip, one tall (9:16) picture at a time with the next peeking in, the
  caption under it, "3 of 8", and a round tick toggle on each picture. Tapping the picture opens the
  full-size viewer at that picture. On wide screens the strip is a grid.
- Below: how many are marked, the note box, **Send my picks** (**Send my pick** with `"one"`), and a quiet
  **None of these**. Send waits until something is marked or a note is typed.
- No `choices` needed (they are ignored on a picker). Without `pick`, or with fewer than 2 pictures,
  the card is the ordinary one. A picture with no `id` gets `p1`, `p2`, ... by position: give real ids,
  an answer names them. Keep ids free of commas.
- The answer doc is the usual shape plus `choices`, the picked ids in strip order:
  `{"item": "night-look", "choice": "lantern,bridge", "choices": ["lantern", "bridge"],
  "label": "Lantern square, The long bridge", "note": "", "at": "..."}`.
  `choice` is the ids joined by `,` and `label` the captions joined by `, `. "None of these" (or only a
  note, nothing marked) writes `"choice": "none"`, `"choices": []`, `"label": "None of these"`.
- Decided shows the picked captions; "Change my answer" brings the card back with those still marked.

Rules for what goes on a picker (the owner's, 23 Nov):

- One card per area or decision, holding EVERY real option for it. No option appears on two cards.
- Only real alternatives are options. More pictures of the same option (other states, player counts,
  roles) are not options: put them in that option's `views`, a list of `{"src", "alt", "caption"}`.
  They show as small pictures under the option, headed "Same option, N more views"; tapping opens them
  full size; they cannot be marked. Never list "more of option 1" as an option.
- Anything asked of the owner goes on the board at the moment it is asked, not only in chat.

## Add a picture

Upload it to the board's asset store, then use the returned url as `src`:

```
Artifact { action: "publish", url: "<board url>", asset: true,
           file_paths: ["/abs/path/before.png", "/abs/path/after.png"] }
```

The result gives `"/_blob/<32 hex>"` per file; copy it exactly. PNG, JPEG, WebP or SVG.
Today's pictures and their urls: `docs/dev/owner-board/live-map.json`.

## Add sounds to choose by ear

An item with `sounds` shows each take as a row: a big **Play** and a **Hear it on 10 phones**
(the take 10 times at fixed seeded offsets between 0 and 400 ms, the same every time, so the
owner hears the table effect). Sound starts only from a tap. Under the takes the card shows its
`choices` as usual; with exactly 4 choices and `sounds` they sit in one row.

```json
{
  "lead": "Four small sounds, all quiet. No music, and never at night.",   // optional line above the card
  "sounds": [
    {"label": "A", "src": "data:audio/mpeg;base64,....", "note": "Brass bell, soft mallet"},
    {"label": "B", "src": "data:audio/mpeg;base64,...."},
    {"label": "C", "src": "data:audio/mpeg;base64,....", "rates": [0.667, 1, 1.333]}
  ],
  "choices": [{"id": "A", "label": "A", "say": "Take A"}, {"id": "B", "label": "B", "say": "Take B"},
              {"id": "C", "label": "C", "say": "Take C"}, {"id": "none", "label": "None", "say": "None: no sound here"}],
  "default": "Take A.", "default_choice": "A"
}
```

- `label`: the letter on the row. `note`: optional few words under it (leave it out if it would steer the ear).
- `src`: a `data:` URI (base64) or a URL the page can fetch. **Keep audio in the item document as base64**:
  the asset store refuses mp3 (it takes png, jpg, gif, webp, svg, mp4, webm, pdf and a few others), a
  document holds up to 256 KiB (a 1 s mono mp3 at 64 kbps is about 10 KB, 14 KB as base64), and nothing
  needs republishing to add or swap a take. Stay at or under 40 KB a file.
- `rates`: optional. "Hear it on 10 phones" gives phone number *i* the speed `rates[i mod rates.length]`
  (the dawn bell uses root, fifth, octave: `[0.667, 1, 1.333]`, so 4, 3 and 3 phones). Play uses the file as it is.
- `choice.say`: optional fuller words saved as the answer's `label` and shown in Decided ("Take A"
  instead of "A"). The answer doc is otherwise unchanged: `{item, choice, label, note, at}`.
- `lead` works on any item: one plain line shown above that card (not inside it). Put it on the first of a group.

Add audio without typing it into a call: write the item as a local JSON file (base64 included) and
send it with `file_path`:

```
ArtifactData { action: "batch", url, writes: [
  {"op": "set", "collection": "items", "doc_id": "sound-dawn", "file_path": "/abs/path/sound-dawn.json"}, ... ] }
```

Make the files mono, trimmed, tail faded, peak at or under -6 dBFS (check the decoded mp3, not the
source: the encoder adds about 2 dB on tonal sounds). Browsers play mp3 on Safari and Chrome. On an
iPhone the silent switch mutes web audio; Android plays on the media volume.

The takes for the four sounds in #33 are in `docs/dev/owner-board/sounds-candidates/` (12 mp3 files,
a spectrogram tile per sound, `measurements.json`). Items on the board: `sound-dawn`, `sound-seal`,
`sound-knock`, `sound-result` (orders 13 to 16). They were made with the ElevenLabs sound-effects API
(`POST /v1/sound-generation`, model `eleven_text_to_sound_v2`, `prompt_influence` 0.6, minimum length
0.5 s, so the 100 ms sounds are cut from a 0.5 s render), then trimmed, faded, loudness-matched within
each sound and encoded to mono mp3 at 64 kbps. Prompts describe only the sound.

## Add, change or retire an item

Add (new doc, no `if_version`):
```
ArtifactData { action: "set", url, collection: "items", doc_id: "pass-2-after", data: { ...item } }
```
Change: read it first (`action: "get"`), then
```
ArtifactData { action: "update", url, collection: "items", doc_id: "pass-2", data: {"ask": "..."}, if_version: <version you read> }
```
Retire (hide it; keeps history): `update` with `data: {"status": "retired"}` and `if_version`.
Several at once: `action: "batch"`, `writes: [{op, collection, doc_id, data, if_version}]`.

## Read the owner's answers

```
ArtifactData { action: "list", url, collection: "answers" }
```
Each doc (id = item id):
```json
{"item": "q-back", "choice": "keep", "label": "Keep it: only Leave exits",
 "note": "their optional note", "at": "2026-11-22T09:14:03.000Z"}
```
When the owner taps a choice, the card leaves its section and appears at the top of
"Decided" by itself (the owner can tap "Change my answer", which deletes the answer doc).
So an answer doc can disappear: act on what is there when you read.

## File a decision (after you act on an answer)

Add a `decided` doc with `item` set to the item id; the page then shows your record instead of
the raw answer. Then retire the item. One batch:
```
ArtifactData { action: "batch", url, writes: [
  {"op": "set", "collection": "decided", "doc_id": "d-back",
   "data": {"item": "q-back", "question": "Back during a game", "answer": "Keep it: only Leave exits",
            "quote": false, "detail": "Back closes panels; Leave is the only way out.",
            "date": "2026-11-23", "order": 1}},
  {"op": "update", "collection": "items", "doc_id": "q-back", "data": {"status": "retired"}, "if_version": <v>}
]}
```
`decided` fields: `question` (a few words), `answer` (the owner's own words where we have them),
`quote` (true = shown in quotes as their words; false = a button label), `detail` (optional,
one short plain line), `date` (YYYY-MM-DD), `item` (optional), `order` (ties on a date).
Decisions made outside the board (chat, issues): add a `decided` doc with no `item`.
Newest date shows first.

## Done lately

```
ArtifactData { action: "set", url, collection: "done", doc_id: "done-<slug>",
               data: {"text": "One plain line.", "date": "2026-11-23", "order": 1} }
```
Keep it short: delete old ones (`action: "delete"`, `if_version`) after a week or so.

## Rules of the page

- Editors (and you) write `items`, `decided`, `done`, `meta`; anyone who can use the page can
  write `answers`. Viewers only read.
- Write plainly; no issue numbers in titles (the `ref` footer is the place for them).
- To change the page itself: edit `docs/dev/owner-board/board.html` and publish that file with
  `url` set to the board (omit `capabilities` and `icon` to keep them).
