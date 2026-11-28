#!/usr/bin/env python3
"""The last thing a builder runs, and the only way to hand a piece over.

    just handover <file to write>

Reviews kept bouncing on things a tool can know: work left uncommitted or
unpushed in a worktree, checks "still running" or never run, a screen nobody
looked at at a phone's size, a guard line or a spec section forgotten. This
finds those out itself and writes them down, so the reader starts from facts,
not from a summary.

1. Refuses unless everything is committed, the branch is pushed, and it merges
   with main without a conflict (it says the command that fixes each).
2. Runs the checks this change reaches (`just piece-check`'s plan at both
   widths, plus the end-to-end harness when the app or the server changed) and
   records each as passed or FAILED with its time. When the app's code or assets
   changed it also runs the golden tests and every test that scans all of `lib/`
   (tool/lib_scans.py), which "the nearest test files" never reach and GitHub's
   "Golden Tests" and "Widget Tests" do. A heavy step waits its turn in the queue
   (tool/heavy.py).
   It says which of GitHub's required checks ran here (tool/github_checks.py reads
   them from the workflows and the ruleset): "READY (N of M of GitHub's checks run
   here)" is the first line, and READY is never "GitHub will pass".

It carries on where it stopped: a check that passed and a set of pictures drawn
on this very commit are kept, each recorded the moment it finishes. A run that is
killed part way (a shell that ends a command after ten minutes) loses only the
step it was in: run the same command again.

3. Draws every screen state the change reaches, main beside this change, at
   412x915 and 360x640, and puts the ones whose pixels changed on contact
   sheets (tool/handover_pictures.py, frontend/tool/handover_sheet.py).
4. Works out the "Guards changed" lines the pull request needs, the words that
   changed (before and after), and whether a spec or the owner's feedback file
   was touched.
5. Writes all of it to the file, in one fixed shape. Exit 0 only when every
   check passed and every reached state could be drawn.

`--plan` prints what it would run and what that costs, and runs nothing.
"""

import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import heavy  # noqa: E402

# What the harness and a drawn state cost, in seconds: said before anything runs.
HARNESS_SECONDS, STATE_SECONDS, DRAW_START = 180, 2, 25
HARNESS_FOR = ("frontend/lib/", "backend/apps/", "backend/config/", "contract_samples/")
# A change under these can change a golden picture or fail a scan of all of lib/.
APP_CODE = ("frontend/lib/", "frontend/assets/")
GOLDEN_SECONDS = 120
SPEC_FOR = ("frontend/lib/features/", "frontend/lib/design_system/copy/")
OWNER_FEEDBACK = "docs/dev/owner-feedback.md"
TEETH = ("the deliberate breaks this change reaches", ".", ["tool/prove_guards.py", "--reached"])


def tool(name: str):
    spec = importlib.util.spec_from_file_location(name, ROOT / "tool" / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.ROOT = ROOT
    return module


def git(*args: str, check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["git", "-C", str(ROOT), *args],
        capture_output=True,
        text=True,
        errors="replace",
        check=check,
    )


# ---- 1. is it ready to hand over at all ------------------------------------------


def not_ready() -> list[str]:
    """Why this cannot be handed over yet, each with the command that fixes it."""
    problems = []
    dirty = git("status", "--porcelain").stdout.splitlines()
    if dirty:
        shown = "\n".join(f"      {line}" for line in dirty[:12])
        more = f"\n      ... and {len(dirty) - 12} more" if len(dirty) > 12 else ""
        problems.append(
            f"{len(dirty)} files are not committed:\n{shown}{more}\n"
            "    fix: commit what belongs to the piece (`git add -A && git commit`),"
            " remove what does not."
        )
    branch = git("rev-parse", "--abbrev-ref", "HEAD").stdout.strip()
    if branch in ("HEAD", "main"):
        problems.append(
            f"this checkout is on '{branch}', not on the piece's branch.\n"
            "    fix: `git switch -c <branch>` (a piece is handed over on its own branch)."
        )
        return problems
    git("fetch", "--quiet", "--no-tags", "origin", "main", check=False)
    git("fetch", "--quiet", "--no-tags", "origin", branch, check=False)
    head = git("rev-parse", "HEAD").stdout.strip()
    pushed = git(
        "rev-parse", "-q", "--verify", f"origin/{branch}", check=False
    ).stdout.strip()
    if pushed != head:
        ahead = (
            "the branch is not on the remote"
            if not pushed
            else "the remote branch is at another commit"
        )
        problems.append(
            f"{ahead} (here: {head[:9]}, remote: {pushed[:9] or 'none'}).\n"
            f"    fix: `git push -u origin {branch}`. A reviewer can only read what is pushed."
        )
    merged = git(
        "merge-tree", "--write-tree", "--name-only", "origin/main", "HEAD", check=False
    )
    if merged.returncode == 1:
        files = [line for line in merged.stdout.splitlines()[1:] if line.strip()]
        files = files[: files.index("")] if "" in files else files
        shown = "\n".join(f"      {name}" for name in files[:12])
        problems.append(
            f"main has moved and this branch conflicts with it in:\n{shown}\n"
            "    fix: `git fetch origin main && git merge origin/main`, resolve those"
            f" files, commit, `git push origin {branch}`."
        )
    return problems


# ---- 2. the checks ---------------------------------------------------------------


def steps_for(changed: list[str], piece) -> list[tuple[str, str, list[str]]]:
    steps = piece.plan(changed, screens=True, both_widths=True)
    if any(name.startswith(HARNESS_FOR) for name in changed):
        steps.append(("the end-to-end harness", ".", ["just", "test-harness"]))
    # The deliberate breaks of the promises this change touches (tool/prove_guards.py).
    proving = tool("prove_guards")
    if proving.reached(proving.BREAKS, changed):
        steps.append(TEETH)
    # The nearest test files never reach a picture test or a scan of all of lib/, and
    # GitHub runs both: a change to the app's code or assets runs them here too.
    all_tests = ("frontend", ["just", "test"])
    everything = any((folder, cmd) == all_tests for _, folder, cmd in steps)
    if any(name.startswith(APP_CODE) for name in changed) and not everything:
        steps.append(("the golden tests", "frontend", ["just", "flutter-test-golden"]))
        scans = tool("lib_scans").whole_lib_tests(ROOT)
        if scans:
            steps.append(
                (
                    f"{len(scans)} tests that scan all of lib/",
                    "frontend",
                    scan_command(scans),
                )
            )
    return steps


SCAN_FLAGS = [
    "--dart-define=ENV=dev",
    "--exclude-tags",
    "e2e",
    "--reporter",
    "failures-only",
]


def scan_command(files: list[str]) -> list[str]:
    return ["flutter", "test", *SCAN_FLAGS, *files]


def guess(what: str, command: list[str], piece) -> int:
    if "harness" in what:
        return HARNESS_SECONDS
    if "tests that scan" in what:
        files = len(command) - 2 - len(SCAN_FLAGS)
        return piece.FRONTEND_START + piece.FRONTEND_FILE * files
    return GOLDEN_SECONDS if "golden" in what else piece.guess(what, command)


def run_quietly(command, folder: Path, what: str, started: float, log: Path) -> bool:
    """Runs a step with its output kept in `log` (the harness alone prints tens of
    thousands of lines): a line every 30 s says it is alive, and a step that
    fails shows its last lines and where the rest is. A heavy step waits its turn in
    the queue (tool/heavy.py), which says where it stands here, not in the log."""
    log.parent.mkdir(parents=True, exist_ok=True)
    say = os.dup(2)
    with log.open("w") as out:
        process = subprocess.Popen(
            heavy.wrap(command, what),
            cwd=folder,
            stdout=out,
            stderr=subprocess.STDOUT,
            pass_fds=(say,),
            env={**os.environ, "HEAVY_SAY_FD": str(say)},
        )
        os.close(say)
        while True:
            try:
                code = process.wait(timeout=30)
                break
            except subprocess.TimeoutExpired:
                print(
                    f"   ... still running after {time.monotonic() - started:.0f} s: {what}",
                    flush=True,
                )
    if code != 0:
        tail = log.read_text(errors="replace").splitlines()[-40:]
        print("\n".join(f"   | {line[:200]}" for line in tail))
        print(f"   (all of it: {log})")
    return code == 0


def run_checks(steps, head: str, piece, kept: Path) -> list[dict]:
    """Each step's result on this commit; one that already passed on it is kept."""
    before = json.loads(kept.read_text()) if kept.is_file() else {}
    results = []
    for number, (what, folder, command) in enumerate(steps, 1):
        key = " ".join(command)
        was = before.get(key)
        if was and was["ok"]:
            print(
                f"== {number}/{len(steps)} {what}: passed on this commit already",
                flush=True,
            )
            results.append(
                {
                    **was,
                    "what": what,
                    "again": False,
                    "folder": folder,
                    "command": command,
                }
            )
            continue
        print(f"\n== {number}/{len(steps)} {what}", flush=True)
        started = time.monotonic()
        log = (
            kept.parent / "logs" / f"{number}-{what.split()[0]}-{what.split()[-1]}.log"
        )
        ok = run_quietly(command, ROOT / folder, what, started, log)
        result = {
            "ok": ok,
            "seconds": round(time.monotonic() - started),
            "what": what,
            "again": True,
            "log": "" if ok else str(log),
            "folder": folder,
            "command": command,
        }
        print(
            f"== {'ok' if ok else 'FAILED'} in {result['seconds']} s: {what}",
            flush=True,
        )
        results.append(result)
        before[key] = {"ok": ok, "seconds": result["seconds"]}
        kept.parent.mkdir(parents=True, exist_ok=True)
        kept.write_text(json.dumps(before))
    return results


# ---- 4. the facts ----------------------------------------------------------------


def words_changed(base: str, copy) -> list[tuple[str, str, str]]:
    """(key, words on main, words now) for each copy key added, removed or reworded."""

    def keys(classes) -> dict[str, str]:
        return {
            f"{item['name']}.{member['name']}": (
                " · ".join(member["words"])
                or ("(put together in code)" if member["built"] else member["same_as"])
            )
            for item in classes
            for member in item["members"]
        }

    now = keys(copy.all_copy())
    folder = copy.COPY.relative_to(ROOT)
    with tempfile.TemporaryDirectory() as scratch:
        for name in git(
            "ls-tree", "-r", "--name-only", base, "--", str(folder), check=False
        ).stdout.split():
            (Path(scratch) / Path(name).name).write_text(
                git("show", f"{base}:{name}").stdout
            )
        was = keys(
            [
                {**item}
                for path in sorted(Path(scratch).glob("*.dart"))
                for item in copy.parse(path)
                if item["members"]
            ]
        )
    return [
        (key, was.get(key, ""), now.get(key, ""))
        for key in sorted(set(was) | set(now))
        if was.get(key) != now.get(key)
    ]


def facts(changed: list[str], base: str) -> dict:
    guards = [path for path, _, _ in tool("guard_edits").edited_guards(base)]
    specs = [c for c in changed if c.startswith("docs/specs/")]
    screen_code = [
        c
        for c in changed
        if c.startswith(SPEC_FOR) and not c.endswith((".g.dart", ".freezed.dart"))
    ]
    return {
        "guards": guards,
        "more_words": [
            (item["name"], item["added"])
            for item in (lambda w: w.grown(w.copy_at(base), w.by_class(w.all_copy())))(
                tool("words_added")
            )
        ],
        "words": words_changed(base, tool("copy_page")),
        "specs": specs,
        "screen_code": screen_code,
        "owner_feedback": OWNER_FEEDBACK in changed,
    }


# ---- 5. the file -----------------------------------------------------------------


def write(
    path: Path,
    branch: str,
    head: str,
    behind: int,
    changed,
    results,
    shots,
    states,
    why_all,
    found,
    rows=None,
) -> bool:
    failed = [r for r in results if not r["ok"]]
    ready = not failed and not shots["missing"]
    cell = lambda text: (text or "(none)").replace("|", "\\|").replace("\n", " ")  # noqa: E731
    said = (
        tool("github_checks").headline(rows, ready)
        if rows
        else "READY"
        if ready
        else "NOT READY"
    )
    out = [
        f"**{said}**: "
        + (
            "every check run here passed and every reached state was drawn. READY does not"
            " say GitHub will pass: its other checks are in the table below."
            if ready
            else "see FAILED below."
        ),
        "",
        f"# Hand-over: {branch} at {head[:9]}",
        "",
    ]
    if shots["sheets"]:
        out += [
            "",
            "Look first (main | this change | changed pixels in red, at 412x915 and 360x640):",
        ]
        out += [f"- {sheet}" for sheet in shots["sheets"]]
    if rows:
        out += ["", "## GitHub's required checks, and how many ran here", ""]
        out += tool("github_checks").table(rows)
    out += [
        "",
        "## Ready",
        "",
        f"- Committed and pushed: `origin/{branch}` is {head[:9]}.",
        f"- Merges with main without a conflict ({behind} commits behind it).",
        "",
        f"## Checks, run on {head[:9]}",
        "",
        "| Result | Time | Step |",
        "|---|---|---|",
    ]
    for r in results:
        note = "" if r["again"] else " (passed earlier on this same commit)"
        out.append(
            f"| {'passed' if r['ok'] else '**FAILED**'} | {r['seconds']} s | {r['what']}{note} |"
        )
    out += [
        f"- The output of `{r['what']}`: `{r['log']}`" for r in results if r.get("log")
    ]
    out += ["", "## Screens", ""]
    if not states:
        out.append("No app file that a screen draws changed: nothing to look at.")
    else:
        out.append(
            f"{len(states)} catalogue states can be reached by this change"
            + (f" ({why_all})" if why_all else "")
            + "."
        )
        out.append(
            f"- Pixels changed in {len(shots['changed'])}: "
            + (", ".join(f"`{s}`" for s in shots["changed"]) or "none")
        )
        if shots["new"]:
            out.append(
                "- New (main has no such state): "
                + ", ".join(f"`{s}`" for s in shots["new"])
            )
        if shots["missing"]:
            out.append(
                "- **FAILED to draw**: " + ", ".join(f"`{s}`" for s in shots["missing"])
            )
        same = [
            s
            for s in states
            if s not in shots["changed"]
            and s not in shots["new"]
            and s not in shots["missing"]
        ]
        out.append(
            f"- Identical to main at both sizes ({len(same)}): "
            + (", ".join(f"`{s}`" for s in same) or "none")
        )
        out.append(
            "- Each changed state alone, full size: `frontend/build/handover/<state>-<width>x<height>.png`"
        )
        for state, was, now in shots.get("wordier", []):
            out.append(
                f"- More words on screen at once: `{state}` shows {now}, main shows {was}."
            )
    out += ["", "## For the pull request", ""]
    if found["guards"]:
        out += [
            "This change edits guard files. The description needs, under `Guards changed`:",
            "",
            "```",
            "Guards changed",
        ]
        out += [f"- {Path(g).name}: <why, in a sentence>" for g in found["guards"]] + [
            "```"
        ]
    else:
        out.append("No guard file is edited: no `Guards changed` section needed.")
    if found.get("more_words"):
        out += [
            "",
            "This change adds words a player reads. The description needs, under `Words added`:",
            "",
            "```",
            "Words added",
        ]
        out += [
            f"- {name}: <why, in a sentence>   (+{added})"
            for name, added in found["more_words"]
        ]
        out += ["```"]
    out += ["", "## Words", ""]
    if found["words"]:
        out += ["| Key | On main | Now |", "|---|---|---|"]
        out += [
            f"| `{key}` | {cell(was)} | {cell(now)} |"
            for key, was, now in found["words"]
        ]
    else:
        out.append("No word a player reads changed.")
    out += ["", "## Spec and the owner's feedback", ""]
    if found["specs"]:
        out.append("Spec files changed: " + ", ".join(f"`{s}`" for s in found["specs"]))
    elif found["screen_code"]:
        out.append(
            f"**No spec file changed**, though {len(found['screen_code'])} screen or copy files did"
            " (the first: `"
            + found["screen_code"][0]
            + "`). Either the spec already says this, or it is now out of date: say which."
        )
    else:
        out.append("No screen or copy file changed, and no spec file.")
    out.append(
        f"`{OWNER_FEEDBACK}` "
        + ("was changed." if found["owner_feedback"] else "was not changed.")
    )
    out += ["", f"## Changed files ({len(changed)})", ""] + [
        f"- `{name}`" for name in changed
    ]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(out) + "\n")
    return ready


def main(argv: list[str]) -> int:
    names = [a for a in argv if not a.startswith("--")]
    if len(names) != 1:
        print(
            "usage: just handover <file to write>   (--plan: what it would run, and nothing else)",
            file=sys.stderr,
        )
        return 2
    problems = not_ready()
    if problems:
        print("handover: not yet. Nothing was run.\n", file=sys.stderr)
        for number, problem in enumerate(problems, 1):
            print(f" {number}. {problem}\n", file=sys.stderr)
        return 1
    piece, screens = tool("piece_check"), tool("piece_screens")
    shots_of = tool("handover_pictures")
    base = git("merge-base", "origin/main", "HEAD").stdout.strip()
    head = git("rev-parse", "HEAD").stdout.strip()
    branch = git("rev-parse", "--abbrev-ref", "HEAD").stdout.strip()
    behind = int(git("rev-list", "--count", "HEAD..origin/main").stdout or 0)
    changed = piece.changed_files(base)
    steps = steps_for(changed, piece)
    states, why_all = shots_of.reached_states(changed, screens)
    cost = sum(guess(what, command, piece) for what, _, command in steps)
    drawing = (
        (DRAW_START + STATE_SECONDS * len(states)) * 2 * len(shots_of.SIZES)
        if states
        else 0
    )
    print(
        f"handover: {branch} at {head[:9]}, {len(changed)} changed files, {behind} commits behind main."
    )
    print(
        f"handover: {len(steps)} checks (about {piece.minutes(cost)}), then {len(states)} states drawn at two sizes from this change and from main (about {piece.minutes(drawing)})."
    )
    print(
        "  It carries on where it stopped: a check that passed and a set of pictures"
        " drawn on this commit are kept. If your shell ends a command after ten"
        " minutes, run the same command again."
    )
    for number, (what, _, command) in enumerate(steps, 1):
        print(
            f"  {number}. {what}  (about {piece.minutes(guess(what, command, piece))})"
        )
    gh = tool("github_checks")
    checks = gh.required_checks(ROOT)
    if "--plan" in argv:
        would = [{"ok": True, "folder": f, "command": c} for _, f, c in steps]
        print("\nhandover: if every step passes, of GitHub's required checks:")
        print("\n".join(gh.table(gh.judge(checks, would))))
        return 0
    out = ROOT / "frontend" / "build" / "handover"
    results = run_checks(steps, head, piece, out / f"checks-{head[:12]}.json")
    shots = (
        shots_of.pictures(states, base, out, head)
        if states
        else {"changed": [], "missing": [], "sheets": [], "new": []}
    )
    target = Path(names[0]).resolve()
    rows = gh.judge(checks, results)
    ready = write(
        target,
        branch,
        head,
        behind,
        changed,
        results,
        shots,
        states,
        why_all,
        facts(changed, base),
        rows,
    )
    print("\nGitHub's required checks:")
    print("\n".join(gh.table(rows)))
    print(f"\nhandover: wrote {target}")
    for sheet in shots["sheets"]:
        print(f"handover: look at {sheet}")
    print(
        f"handover: {gh.headline(rows, ready)}."
        if ready
        else "handover: NOT READY (the file says what failed)."
    )
    return 0 if ready else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
