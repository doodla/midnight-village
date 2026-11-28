#!/usr/bin/env python3
"""Move the branches Vercel deploys from: only forward, only to a green main, server first.

Vercel deploys from two branches, not from main (100 deployments in 24 hours, and a
merge that changes only tests, docs or tooling should cost none):

- `live-server`: the server project (backend/vercel.json);
- `live-app`: the app project (frontend/vercel.json).

After each merge this moves a branch to the merged commit when the files that side
ships differ from what the branch holds. It compares with the BRANCH, not with the
last merge, so a run that was cancelled or failed is made up by the next. What a side
ships: everything under its folder except its tests and its Markdown (when in doubt a
path ships: an extra deployment costs little; a missed one leaves players on old code).

What it promises, each held by a test (.claude/guardrails/tests/test_promote_live.py):

1. **Only a green main goes live.** Before moving anything it waits until every check
   `docs/dev/main-ruleset.json` requires has passed ON THE MERGED COMMIT, as a run of
   GitHub Actions (two pull requests that were each green can break each other once
   both are in). A failed check refuses at once; checks still running after
   `--checks-wait` seconds refuse with what is missing.
2. **The server goes first.** The app moves only once `/api/health/` serves the commit
   `live-server` holds, so a new app never talks to an old server.
3. **Only forward.** A live branch moves only to a descendant of what it holds (an
   older run arriving late leaves it be; a commit off to the side is refused).
4. **Never below the floor.** It refuses a commit that does not contain `FLOOR` (below).

Every refusal moves nothing further, says why and what fixes it, and exits 1: the gate
fails closed. If the gate itself is broken, a person runs "Deployed Check" by hand with
`skip_waits` (`--skip-waits`): 1 and 2 are skipped, loudly; 3 and 4 never are.

usage: tool/promote_live.py [--dry-run] [--api <server origin>] [--skip-waits]
                            [--checks-wait <s>] [--health-wait <s>]
Prints one line per side; on GitHub also writes `server=<sha>` and `app=<sha>`
(what each branch holds afterwards) to $GITHUB_OUTPUT.
"""

import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SIDES = {
    # side: (branch, folder, folders inside it that never ship)
    "server": ("live-server", "backend", ("tests/",)),
    "app": (
        "live-app",
        "frontend",
        ("test/", "test_screens/", "test_e2e/", "integration_test/", "test_driver/"),
    ),
}

# THE ROLLBACK FLOOR. Nothing older than this commit may serve again: core migration
# 0012 dropped `LobbyMember.is_ready`, and every build before this one (#81, where the
# model stopped naming it) selects that column, so every lobby page would fail.
# docs/dev/deploy-vercel.md ("Deploy-safe changes") and docs/dev/status.md point here.
# Raise it, in a pull request, when a later two-push removal lands its second push.
FLOOR = "e8f50b5e18410076d29d466dfe90043202a81a4f"
FLOOR_WHY = (
    "#81: older builds select the dropped column is_ready and every lobby page fails"
)

RULESET = "docs/dev/main-ruleset.json"
ACTIONS_APP = "github-actions"  # a check posted any other way is not believed
CHECKS_WAIT = 45 * 60  # Flutter's checks take 10 to 20 minutes on main
HEALTH_WAIT = 15 * 60  # a server build takes a few minutes
POLL = 30

# Injected by the tests: no network there.
sleep = time.sleep
clock = time.monotonic


class Refused(Exception):
    """Why nothing (more) moves, and what fixes it."""


def git(*args: str, check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["git", "-C", str(ROOT), *args], capture_output=True, text=True, check=check
    )


def fetch_json(url: str, headers: dict[str, str]) -> tuple[int, object]:
    """(status, parsed JSON or None) of a GET; no answer at all is status 0."""
    req = urllib.request.Request(url, headers={"Accept": "application/json", **headers})
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            status, raw = resp.status, resp.read()
    except urllib.error.HTTPError as e:
        status, raw = e.code, e.read()
    except (urllib.error.URLError, TimeoutError, OSError):
        return 0, None
    try:
        return status, json.loads(raw)
    except ValueError:
        return status, None


# ---- what git says ---------------------------------------------------------------


def ships(path: str, folder: str, not_shipped: tuple[str, ...]) -> bool:
    """Whether a changed path is part of what this side's build serves."""
    if not path.startswith(folder + "/"):
        return False
    inside = path[len(folder) + 1 :]
    return not inside.endswith(".md") and not inside.startswith(not_shipped)


def remote_head(branch: str) -> str:
    """The commit the branch holds on the remote ('' when it does not exist yet)."""
    out = git("ls-remote", "origin", f"refs/heads/{branch}").stdout.split()
    return out[0] if out else ""


def have(commit: str) -> bool:
    if git("cat-file", "-e", f"{commit}^{{commit}}", check=False).returncode == 0:
        return True
    git("fetch", "-q", "--no-tags", "origin", commit, check=False)
    return git("cat-file", "-e", f"{commit}^{{commit}}", check=False).returncode == 0


def is_ancestor(older: str, newer: str) -> bool:
    return git("merge-base", "--is-ancestor", older, newer, check=False).returncode == 0


def relation(holds: str, head: str) -> str:
    """How `head` stands to what a branch holds: new, same, ahead, behind or diverged."""
    if not holds:
        return "new"
    if holds == head:
        return "same"
    if not have(holds):
        raise Refused(
            f"the live branch holds {holds[:10]}, which this checkout cannot see:"
            " run with the whole history (actions/checkout `fetch-depth: 0`)."
        )
    if is_ancestor(holds, head):
        return "ahead"
    if is_ancestor(head, holds):
        return "behind"
    return "diverged"


def above_floor(head: str) -> bool:
    floor = FLOOR  # read at the call: the tests put their own floor here
    if not have(floor):
        raise Refused(
            f"cannot see the rollback floor {floor[:10]} in this checkout, so cannot prove"
            f" {head[:10]} is above it: run with the whole history (`fetch-depth: 0`)."
        )
    return is_ancestor(floor, head)


def shipped_changes(side: str, holds: str, head: str) -> list[str]:
    _, folder, not_shipped = SIDES[side]
    names = git("diff", "--name-only", "--no-renames", holds, head).stdout.splitlines()
    return [p for p in names if ships(p, folder, not_shipped)]


# ---- the decision ------------------------------------------------------------------


@dataclass
class Plan:
    side: str
    branch: str
    holds: str
    move: bool
    why: str


def verdict(
    side: str, holds: str, head: str, rel: str, moved: list[str], floor_ok: bool
) -> Plan:
    """Whether a side moves to `head`. Pure: what git says goes in, the decision comes out."""
    branch = SIDES[side][0]
    if not floor_ok:
        raise Refused(
            f"{side}: {head[:10]} is older than the rollback floor {FLOOR[:10]}"
            f" ({FLOOR_WHY}). Nothing before it may serve again: roll forward instead"
            " (`just revert-release <PR>` makes a new commit on top of main)."
        )
    if rel == "same":
        return Plan(side, branch, holds, False, f"{branch} is already at {head[:10]}")
    if rel == "behind":
        return Plan(
            side,
            branch,
            holds,
            False,
            f"{branch} is already past {head[:10]} (at {holds[:10]})",
        )
    if rel == "diverged":
        raise Refused(
            f"{side}: {branch} holds {holds[:10]}, which is not in the history of"
            f" {head[:10]}. A live branch only moves forward along main; something moved"
            f" it by hand. Find out what {holds[:10]} is before anything else goes live"
            f" (`git log -1 {holds[:10]}`); only the release job moves the live branches."
        )
    if rel == "new":
        return Plan(side, branch, holds, True, "the branch does not exist yet")
    if not moved:
        return Plan(
            side,
            branch,
            holds,
            False,
            f"nothing it ships changed since {holds[:10]}; {branch} stays",
        )
    return Plan(
        side,
        branch,
        holds,
        True,
        f"{len(moved)} shipped files changed (first: {moved[0]})",
    )


def plan(side: str, head: str) -> Plan:
    branch = SIDES[side][0]
    holds = remote_head(branch)
    rel = relation(holds, head)
    moved = shipped_changes(side, holds, head) if rel == "ahead" else []
    return verdict(side, holds, head, rel, moved, above_floor(head))


# ---- waiting for main's checks -------------------------------------------------------


def required_checks() -> list[str]:
    """The checks the merge wall requires: the one list, kept with the ruleset."""
    ruleset = json.loads((ROOT / RULESET).read_text())
    for rule in ruleset["rules"]:
        if rule["type"] == "required_status_checks":
            return [c["context"] for c in rule["parameters"]["required_status_checks"]]
    raise Refused(
        f"{RULESET} names no required checks: nothing can prove main is green. Fix the file: its required checks are the list."
    )


def check_state(runs: list[dict], required: list[str]) -> tuple[list[str], list[str]]:
    """(failed, not done) of the required checks, from the commit's check runs. Only runs
    of GitHub Actions count, and of each name the newest (a re-run replaces a failure)."""
    newest: dict[str, dict] = {}
    for run in runs:
        if (run.get("app") or {}).get("slug") != ACTIONS_APP:
            continue
        name = run.get("name", "")
        if name not in newest or run.get("id", 0) > newest[name].get("id", 0):
            newest[name] = run
    failed, waiting = [], []
    for name in required:
        run = newest.get(name)
        if not run or run.get("status") != "completed":
            waiting.append(name)
        elif run.get("conclusion") != "success":
            failed.append(f"{name} ({run.get('conclusion')})")
    return failed, waiting


def check_runs(sha: str) -> list[dict]:
    repo = os.environ.get("GITHUB_REPOSITORY", "")
    token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN", "")
    if not repo or not token:
        raise Refused(
            "cannot read main's checks: GITHUB_REPOSITORY and GH_TOKEN are not set"
            " (this runs on GitHub; locally run it with --dry-run)."
        )
    api = os.environ.get("GITHUB_API_URL", "https://api.github.com")
    headers = {"Authorization": f"Bearer {token}", "X-GitHub-Api-Version": "2022-11-28"}
    runs, page = [], 1
    while True:
        url = f"{api}/repos/{repo}/commits/{sha}/check-runs?per_page=100&page={page}"
        status, body = fetch_json(url, headers)
        if status != 200 or not isinstance(body, dict):
            raise Refused(
                f"GitHub did not list the checks of {sha[:10]} (answered {status}): the job"
                " needs `checks: read`. Nothing moved."
            )
        got = body.get("check_runs") or []
        runs += got
        if len(got) < 100:
            return runs
        page += 1


def wait_for_checks(sha: str, seconds: int, say=print) -> None:
    required = required_checks()
    deadline = clock() + seconds
    while True:
        failed, waiting = check_state(check_runs(sha), required)
        if failed:
            raise Refused(
                f"main is red at {sha[:10]}: {', '.join(failed)}. Nothing moved, so players"
                " keep the last green build. The fix is a new merge to main (the 'main is"
                " red' issue tracks it); that merge's run promotes it."
            )
        if not waiting:
            say(f"main's {len(required)} required checks passed on {sha[:10]}.")
            return
        if clock() >= deadline:
            raise Refused(
                f"after {seconds // 60} minutes main's checks on {sha[:10]} are still not"
                f" done: {', '.join(waiting)}. Nothing moved. The next merge's run tries"
                " again; or run 'Deployed Check' by hand once they finish."
            )
        say(
            f"waiting for main's checks on {sha[:10]}: {len(waiting)} not done ({waiting[0]}, ...)"
        )
        sleep(POLL)


# ---- waiting for the server ----------------------------------------------------------


def serving(api: str) -> str:
    status, body = fetch_json(
        f"{api}/api/health/", {"User-Agent": "midnight-village-promote"}
    )
    return body.get("commit", "") if status == 200 and isinstance(body, dict) else ""


def wait_for_server(
    api: str, want: str, app_holds: str, seconds: int, say=print
) -> None:
    deadline = clock() + seconds
    while True:
        now = serving(api)
        if now == want:
            say(f"server: {api} serves {want[:10]}.")
            return
        if clock() >= deadline:
            raise Refused(
                f"the server is not serving {want[:10]} after {seconds // 60} minutes (it"
                f" serves {now[:10] or 'nothing that answers'}), so live-app stays at"
                f" {app_holds[:10] or 'nothing'}: the app never goes live ahead of its"
                " server. Look at the server's build in Vercel (failed, queued, or the"
                " daily cap). After an Instant Rollback in Vercel new builds do not go live"
                " until someone promotes one there. The next merge's run tries again."
            )
        say(
            f"waiting for the server to serve {want[:10]} (it serves {now[:10] or '-'})."
        )
        sleep(POLL)


# ---- moving --------------------------------------------------------------------------


def push(p: Plan, head: str, say=print) -> str:
    branch = p.branch
    pushed = git("push", "origin", f"{head}:refs/heads/{branch}", check=False)
    if pushed.returncode == 0:
        say(f"{p.side}: moved {p.branch} to {head[:10]}: {p.why}.")
        return head
    now = remote_head(p.branch)
    if now and have(now) and is_ancestor(head, now):
        say(f"{p.side}: {p.branch} is already past {head[:10]} (at {now[:10]}).")
        return now  # a newer merge's run moved it past us: that commit holds ours
    print(pushed.stderr, file=sys.stderr)
    raise Refused(
        f"{p.side}: the push of {head[:10]} to {p.branch} was refused (above). If it says"
        " a rule blocks it, the release job's key is missing or wrong: fix it as"
        " docs/dev/rulesets/README.md says."
    )


def promote(
    head: str,
    api: str,
    dry_run: bool,
    skip_waits: bool,
    checks_wait: int,
    health_wait: int,
) -> dict[str, str]:
    plans = {side: plan(side, head) for side in SIDES}  # every refusal before any move
    for p in plans.values():
        if not p.move:
            print(f"{p.side}: {p.why}.")
    moving = [p for p in plans.values() if p.move]
    result = {side: (head if p.move else p.holds or head) for side, p in plans.items()}
    if dry_run:
        for p in moving:
            print(f"{p.side}: would move {p.branch} to {head[:10]}: {p.why}.")
        return result
    if not moving:
        return result
    if skip_waits:
        print(
            "WARNING: run by hand with skip_waits: NOT waiting for main's checks or the server."
        )
    else:
        wait_for_checks(head, checks_wait)
    if plans["server"].move:
        result["server"] = push(plans["server"], head)
    if plans["app"].move:
        if not skip_waits:
            if not api:
                raise Refused(
                    "the app moves only after the server serves its commit: pass --api."
                )
            wait_for_server(api, result["server"], plans["app"].holds, health_wait)
        result["app"] = push(plans["app"], head)
    return result


def main(argv: list[str]) -> int:
    def value(flag: str, default: str) -> str:
        return argv[argv.index(flag) + 1] if flag in argv else default

    head = git("rev-parse", "HEAD").stdout.strip()
    try:
        result = promote(
            head,
            api=value("--api", "").rstrip("/"),
            dry_run="--dry-run" in argv,
            skip_waits="--skip-waits" in argv,
            checks_wait=int(value("--checks-wait", str(CHECKS_WAIT))),
            health_wait=int(value("--health-wait", str(HEALTH_WAIT))),
        )
    except Refused as e:
        print(f"REFUSED: {e}", file=sys.stderr)
        return 1
    output = os.environ.get("GITHUB_OUTPUT")
    if output:
        with open(output, "a") as handle:
            for side, commit in result.items():
                handle.write(f"{side}={commit}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
