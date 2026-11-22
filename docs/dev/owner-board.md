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
  "ref": "Questions list, 5 · #24"  // tiny footer
}
```

- 1 picture shows big and cropped to 4:5 (`pos` = CSS object-position, e.g. "50% 0%" for the top
  of a phone screen). 2 pictures show side by side, whole. Tap opens full size.
- No `choices` = a card to look at with no buttons.
- Every decision card must say what happens by default (`default`).

## Add a picture

Upload it to the board's asset store, then use the returned url as `src`:

```
Artifact { action: "publish", url: "<board url>", asset: true,
           file_paths: ["/abs/path/before.png", "/abs/path/after.png"] }
```

The result gives `"/_blob/<32 hex>"` per file; copy it exactly. PNG, JPEG, WebP or SVG.
Today's pictures and their urls: `docs/dev/owner-board/live-map.json`.

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
