"""Whether a measured step did what the map pass saw the same step do.

The measured pass cannot read the screen's words (semantics is off: a friend's phone
never has it on), so on its own it cannot tell a step that worked from one that lost a
race: a card hold let go before it counted leaves the phone on 04, and every later
moment then times a different screen than it names, in plausible numbers. So the map
pass (semantics on, unslowed) records what each step does, and the measured pass checks
it did the same, outside the timed window:

- its actions: the requests that change something (not reads) the map pass's step sent
  at once (within ACT_SOON of the finger), e.g. `POST /onuw/games/{id}/ready/`;
- its answer: the picture of the words the step waited for ("Ready"), cropped where the
  map pass saw them, must be the same picture (at most ANSWER_DIFF of it differs);
- a hold shows something while it is held; a tap that opens a screen opens one; the
  page got the finger at all.

A step that fails one is lost: the run stops there and says which and why
(`moments.Lost`); no number is kept for it or for anything after it.
"""

import base64
import io
import re


# The map pass counts an action as the step's own when it left this soon after the
# finger (s); the measured pass, slowed, gets ACT_WAIT to send it.
ACT_SOON = 1.0
ACT_WAIT = 8.0
# A share of the answer's box that may differ (`differs`: blurred 2 px, best of 2 px
# shifts). Measured on the map's crops and live frames: the same words at most 0.025
# (a live JPEG frame, a crop 1 px off); other words 0.055 ("Ready ✓" | "Locked") to
# 0.97 ("Look first" | "Ready", the card hold's own test); "Ready ✓" against the vote's
# "Pick a name" 0.072.
ANSWER_DIFF = 0.04
# A hold shows something while held: this share of the screen changes.
HOLD_SHOWS = 0.03
HOLD_CHECKED = 0.3  # holds at least this long (s) are checked so

_UUID = re.compile(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}")
_CODE = re.compile(r"/[A-Z0-9]{6}(?=/|$)")
_NUMBER = re.compile(r"/\d+(?=/|$)")


def action(method, url):
    """A request that changes something, as a template without its ids
    (`POST /onuw/games/{id}/ready/`); None for a read or a request that is not the app's."""
    if method.upper() in ("GET", "HEAD", "OPTIONS") or "/api/" not in url:
        return None
    path = url.split("/api", 1)[1].split("?", 1)[0]
    path = _UUID.sub("{id}", path)
    path = _CODE.sub("/{code}", path)
    path = _NUMBER.sub("/{n}", path)
    return f"{method.upper()} {path}"


def actions(sent, since, until=None):
    """The action templates among `sent` [(url, method, epoch s)] that left from
    `since` (until `until`), in order, each once."""
    out = []
    for url, method, at in sent:
        if at < since - 0.005 or (until is not None and at > until):
            continue
        a = action(method, url)
        if a and a not in out:
            out.append(a)
    return out


def missing(expected, sent):
    return [a for a in expected if a not in sent]


def differs(a, b, threshold=24, blur=2, shift=2):
    """The share of picture `a` that differs from `b` (PIL images, any mode), at the
    best of the alignments within `shift` px, both blurred by `blur` px: an answer's
    box has fractional edges and the paper is speckled, so a crop one pixel off or a
    JPEG of it read 9% different without them (see ANSWER_DIFF)."""
    from PIL import ImageChops, ImageFilter  # here: the rest runs without Pillow

    a, b = a.convert("L"), b.convert("L")
    if a.size != b.size:
        b = b.resize(a.size)
    if blur:
        a, b = a.filter(ImageFilter.BoxBlur(blur)), b.filter(ImageFilter.BoxBlur(blur))
    w, h = a.size
    best = 1.0
    for dx in range(-shift, shift + 1):
        for dy in range(-shift, shift + 1):
            here = (max(0, dx), max(0, dy), w + min(0, dx), h + min(0, dy))
            there = (max(0, -dx), max(0, -dy), w + min(0, -dx), h + min(0, -dy))
            diff = ImageChops.difference(a.crop(here), b.crop(there))
            hist = diff.point(lambda v: 255 if v > threshold else 0).histogram()
            best = min(best, hist[255] / max(1, (here[2] - here[0]) * (here[3] - here[1])))
    return best


def png(data):
    """A picture from its bytes (PNG or JPEG)."""
    from PIL import Image

    return Image.open(io.BytesIO(data))


def shows(answer, frame, width=412):
    """Does a screencast frame (JPEG bytes, `width` CSS px wide) show the answer (the
    map pass's PNG crop, at CSS scale) where the map pass saw it?"""
    img = png(frame)
    k = img.size[0] / width
    box = answer["box"]
    crop = img.crop(
        (
            int(box["x"] * k),
            int(box["y"] * k),
            int((box["x"] + box["w"]) * k) + 1,
            int((box["y"] + box["h"]) * k) + 1,
        )
    )
    return differs(png(base64.b64decode(answer["png"])), crop) <= ANSWER_DIFF


def held_showed(steps, hold):
    """Did anything show while the finger was down? `steps`: [(s after the finger,
    share of the screen changed)]."""
    return any(t <= hold + 0.05 and s >= HOLD_SHOWS for t, s in steps)


def lost_actions(name, expected, sent):
    miss = missing(expected, sent)
    if not miss:
        return None
    return (
        f"it sent no {', '.join(miss)} (the map pass's step did at once): the step did"
        " not happen. Fix: see what the screen showed instead (`--dump`), and give the"
        " step what it needs (a longer hold, a wait for its control)"
    )


def lost_answer(word, share):
    if share <= ANSWER_DIFF:
        return None
    return (
        f"its answer ({word!r}) is not where the map pass saw it: {share:.0%} of that"
        f" box differs (at most {ANSWER_DIFF:.0%} may). The step did not end where it"
        " should: a hold let go too soon, a tap that missed, a screen not yet there"
    )
