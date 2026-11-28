"""Better, level or worse, per moment, from interleaved runs of two sides.

The rule (RULE, below, is what the table prints): a moment is better (or worse) only
when every run of one side beat every run of the other, and the gap between the
medians is wider than the spread either side's own runs show, and at least
FLOOR_SHARE of the base's median and FLOOR_MS. Anything else is level: "no measurable
difference". Why this and not a test of means: run-to-run noise on the slowed phone
is heavy-tailed (one run in ten is 30% off; one row is bimodal), so a mean or a t-test
is moved by one run. Order and the runs' own spread are not. The floor is also the
owner's test: under 10% (50 ms) of a tap, friends at the table do not notice.

The proof is same-code runs (`just speed-verdict origin/main origin/main`), which
must come out level on every moment. 13 such runs of main (28 Nov 2026, 23 moments,
CPU 4x, the heavy queue held alone), judged on every split into two sides: at 2 runs
a side a verdict called something in 87% of them, at 3 in 33%, at 4 (the default) in
5.2% (0.24% of moments), at 5 in 0.8%, at 6 in 0.1%. The one whole A/A verdict at 4
called every moment level. Plain non-overlap of ranges, simulated on the lab's own
noise, called something in 93% at 3 runs a side.

Pure: no browser, no files. `speed_verdict.py` feeds it the runs.
"""

import statistics

FLOOR_SHARE = 0.10
FLOOR_MS = 50
RULE = (
    "better/worse only when every run of one side beat every run of the other, by more"
    f" than either side's own spread and by at least {FLOOR_SHARE:.0%} of the base"
    f" (and {FLOOR_MS} ms); else level"
)


def side(values):
    return {
        "median": round(statistics.median(values)),
        "min": round(min(values)),
        "max": round(max(values)),
        "runs": [round(v) for v in values],
    }


def judge(base, head, floor_share=FLOOR_SHARE, floor_ms=FLOOR_MS):
    """One moment: {verdict, gap_ms, base, head, why}. `base` and `head` are its
    numbers (ms, lower is sooner), one per run, each side at least 2."""
    if len(base) < 2 or len(head) < 2:
        raise ValueError("a verdict needs at least 2 runs a side")
    b, h = side(base), side(head)
    gap = statistics.median(head) - statistics.median(base)
    spread = max(max(base) - min(base), max(head) - min(head))
    floor = max(floor_ms, floor_share * statistics.median(base))
    out = {"gap_ms": round(gap), "base": b, "head": h}
    if min(head) > max(base):
        direction = "worse"
    elif max(head) < min(base):
        direction = "better"
    else:
        out["verdict"] = "level"
        out["why"] = "the runs overlap"
        return out
    if abs(gap) <= spread:
        out["verdict"] = "level"
        out["why"] = (
            f"the gap ({abs(gap):.0f} ms) is inside the runs' own spread ({spread:.0f} ms)"
        )
        return out
    if abs(gap) < floor:
        out["verdict"] = "level"
        out["why"] = f"the gap ({abs(gap):.0f} ms) is under the floor ({floor:.0f} ms)"
        return out
    out["verdict"] = direction
    out["why"] = (
        f"every run {'sooner' if direction == 'better' else 'later'}, by {abs(gap):.0f} ms:"
        f" over the spread ({spread:.0f} ms) and the floor ({floor:.0f} ms)"
    )
    return out


def compare(moments, base_runs, head_runs, runs):
    """Every moment asked for, in order: its verdict, or `not measured` with why.

    `moments`: [{name, kind, plain}]. `base_runs`, `head_runs`: one dict per run,
    {"values": {name: ms}, "lost": {"at": name, "why": ...} or None, "failed": why or
    None}. A moment needs a number from each of `runs` runs a side."""
    out = []
    for m in moments:
        name = m["name"]
        row = {"name": name, "kind": m["kind"], "plain": m.get("plain", name)}
        got, why = {}, []
        for label, side_runs in (("base", base_runs), ("head", head_runs)):
            values = [
                r["values"][name]
                for r in side_runs
                if r["values"].get(name) is not None
            ]
            got[label] = values
            if len(values) < runs:
                why.append(
                    f"{label}: {len(values)} of {runs} runs measured it"
                    + _reasons(side_runs, name)
                )
        if why:
            row["verdict"] = "not measured"
            row["why"] = "; ".join(why)
            for label in ("base", "head"):
                if got[label]:
                    row[label] = side(got[label])
        else:
            row.update(judge(got["base"][:runs], got["head"][:runs]))
        out.append(row)
    return out


def _reasons(side_runs, name):
    said = []
    for r in side_runs:
        if r.get("failed"):
            said.append(r["failed"])
        elif r.get("lost") and r["values"].get(name) is None:
            said.append(f"lost at {r['lost']['at']!r}: {r['lost']['why']}")
        elif r["values"].get(name) is None and not r.get("lost"):
            said.append("the run kept no number for it")
    uniq = list(dict.fromkeys(said))
    return f" ({'; '.join(uniq)})" if uniq else ""


def _seconds(ms):
    ms = abs(ms)
    if ms < 95:
        return f"{ms:.0f} ms"
    return f"{ms / 1000:.1f} s"


def sentence(results):
    """One plain sentence for the owner: what got sooner, what got later, the rest level."""
    groups = {"better": {}, "worse": {}}
    for r in results:
        if r["verdict"] in groups:
            groups[r["verdict"]].setdefault(r["plain"], []).append(r["gap_ms"])
    parts = []
    for verdict, word in (("better", "sooner"), ("worse", "later")):
        for plain, gaps in groups[verdict].items():
            parts.append(
                f"{plain} answers about {_seconds(statistics.median(gaps))} {word}"
            )
    unmeasured = sum(1 for r in results if r["verdict"] == "not measured")
    if not parts:
        text = "No measurable difference: everything measured is level"
    else:
        text = _join(parts)
        text = text[0].upper() + text[1:]
        if any(r["verdict"] == "level" for r in results):
            text += "; everything else is level"
    if unmeasured:
        text += f" ({unmeasured} moment{'s' if unmeasured > 1 else ''} could not be measured)"
    return text + "."


def _join(parts):
    if len(parts) == 1:
        return parts[0]
    return ", ".join(parts[:-1]) + " and " + parts[-1]


def table(results, base_label, head_label):
    head = f"{'moment':46} {'verdict':12} {base_label[:22]:>22} {head_label[:22]:>22} {'gap':>7}"
    lines = [head, "-" * len(head)]
    for r in results:

        def cell(s):
            if not s:
                return "-"
            return f"{s['median']} ({s['min']}-{s['max']})"

        gap = f"{r['gap_ms']:+d}" if "gap_ms" in r else ""
        lines.append(
            f"{r['name'][:46]:46} {r['verdict']:12} {cell(r.get('base')):>22}"
            f" {cell(r.get('head')):>22} {gap:>7}"
        )
        if r["verdict"] == "not measured":
            lines.append(f"{'':46}   {r['why']}")
    return "\n".join(lines)
