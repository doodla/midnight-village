#!/usr/bin/env python3
"""Rehearse the live-branch rule on a scratch branch before it guards the real ones.

Run by .github/workflows/live-rehearsal.yml (a button: "Run workflow"), after the owner
imported docs/dev/rulesets/live-rehearsal.json: the same rule as the real one
(live-branches-step2.json), aimed at `live-rehearsal`. It pushes as the release job
does and as anything else would, and says PASS or FAIL for each:

1. a normal promotion: the release job's key moves `live-rehearsal` forward to main.
   Expected: it goes through (if this fails, the real rule would stop every release);
2. an unchecked commit (made here, never on main), pushed with the workflow's own token
   (`contents: write`, so only the rule can refuse it). Expected: refused by the rule;
3. main's own commit, pushed with that token. Expected: refused too: only the key moves it.

Exit 0 only when all three hold: then the real rule may be imported.
The workflow checks out with the key, so `origin` pushes with it; the token pushes over
HTTPS. Leaves nothing behind: the branch is deleted at the end (with the key).
"""

import base64
import os
import subprocess
import sys

BRANCH = "live-rehearsal"
REF = f"refs/heads/{BRANCH}"
RULE_SAYS = ("GH013", "rule violation", "Repository rule")


def git(*args: str, env=None) -> subprocess.CompletedProcess:
    return subprocess.run(["git", *args], capture_output=True, text=True, env=env)


def by_key(src: str) -> subprocess.CompletedProcess:
    return git("push", "origin", f"{src}:{REF}")


def by_token(src: str) -> subprocess.CompletedProcess:
    repo, token = os.environ["GITHUB_REPOSITORY"], os.environ["GH_TOKEN"]
    auth = base64.b64encode(f"x-access-token:{token}".encode()).decode()
    return git(
        "-c",
        f"http.https://github.com/.extraheader=AUTHORIZATION: basic {auth}",
        "push",
        f"https://github.com/{repo}.git",
        f"{src}:{REF}",
    )


def judge(
    what: str, pushed: subprocess.CompletedProcess, should_pass: bool
) -> tuple[bool, str]:
    """(held, the line to print) for one push."""
    said = (pushed.stderr or "").strip().replace("\n", " | ")[:400]
    if should_pass:
        if pushed.returncode == 0:
            return True, f"PASS  {what}: went through."
        return False, (
            f"FAIL  {what}: refused ({said}). The release job could not move a live branch:"
            " check the deploy key has write access and the secret LIVE_DEPLOY_KEY is in"
            " the environment 'live' (docs/dev/rulesets/README.md). Do NOT import the real rule."
        )
    if pushed.returncode == 0:
        return False, (
            f"FAIL  {what}: went through. The rule is not on (is live-rehearsal.json imported"
            " and Active?). Do NOT import the real rule until this is refused."
        )
    if any(s in said for s in RULE_SAYS):
        return True, f"PASS  {what}: refused by the rule."
    return (
        False,
        f"FAIL  {what}: refused, but not by the rule ({said}): look at the log.",
    )


def rehearse(key=by_key, token=by_token, say=print) -> int:
    if os.environ.get("HAS_KEY") != "true":
        say(
            "FAIL  no key: the secret LIVE_DEPLOY_KEY is not in the environment 'live' (docs/dev/rulesets/README.md)."
        )
        return 1
    head = git("rev-parse", "HEAD").stdout.strip()
    base = git("rev-parse", "HEAD~1").stdout.strip()
    tree = git("rev-parse", "HEAD^{tree}").stdout.strip()
    unchecked = git(
        "commit-tree", tree, "-p", head, "-m", "rehearsal: a commit main never had"
    ).stdout.strip()
    setup = key(f"+{base}")  # start one behind main, so the promotion is a step forward
    if setup.returncode != 0:
        say(f"FAIL  setting up {BRANCH} with the key: {setup.stderr.strip()[:400]}")
        return 1
    results = [
        judge("1. the release job's key moves it forward to main", key(head), True),
        judge(
            "2. the workflow's token pushes an unchecked commit",
            token(unchecked),
            False,
        ),
        judge("3. the workflow's token pushes main's own commit", token(head), False),
    ]
    key("")  # an empty source deletes the branch: nothing is left behind
    for _, line in results:
        say(line)
    held = all(ok for ok, _ in results)
    say(
        "\nPASS: import docs/dev/rulesets/live-branches-step2.json now."
        if held
        else "\nFAIL: do not import the real rule yet."
    )
    return 0 if held else 1


if __name__ == "__main__":
    sys.exit(rehearse())
