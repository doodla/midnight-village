#!/usr/bin/env python3
"""Says when main is red, in one place, and takes it back when main is green.

Every merge is checked again on main itself (the checks, the deployed check).
Two pull requests that were each green can still break main between them, and
until now nobody was told: the next builder met the failure as if it were theirs.

Run by .github/workflows/main-red.yml after each of main's own runs:
- a run failed and no issue is open: open ONE issue, "main is red", naming the
  check, the run and the merge it ran on (the first bad one: the run before it
  on main passed);
- a run failed and the issue is open: add a line to it;
- a run passed and the issue is open: when the newest run of every watched
  workflow on main has passed, close it.

usage: tool/main_red.py     (reads the run from the workflow's environment; needs `gh`)
"""

import json
import os
import subprocess
import sys

TITLE = "main is red"
WATCHED = ("Backend Tests", "Flutter Tests", "Deployed Check")


def decide(conclusion: str, issue_open: bool, others_green: bool) -> str:
    """What to do about one finished run on main: open, add, close or nothing."""
    if conclusion == "failure":
        return "add" if issue_open else "open"
    if conclusion == "success" and issue_open and others_green:
        return "close"
    return "nothing"


def gh(*args: str) -> str:
    return subprocess.run(["gh", *args], capture_output=True, text=True, check=True).stdout


def open_issue() -> int | None:
    found = json.loads(gh("issue", "list", "--state", "open", "--search", f'"{TITLE}" in:title', "--json", "number,title"))
    return next((i["number"] for i in found if i["title"].startswith(TITLE)), None)


def newest_passed(workflow: str) -> bool:
    runs = json.loads(gh("run", "list", "--branch", "main", "--event", "push", "--workflow", workflow, "--limit", "1", "--json", "conclusion,status"))
    return bool(runs) and runs[0]["status"] == "completed" and runs[0]["conclusion"] == "success"


def main() -> int:
    conclusion = os.environ["RUN_CONCLUSION"]
    workflow, url = os.environ["RUN_WORKFLOW"], os.environ["RUN_URL"]
    sha, title = os.environ["RUN_SHA"][:9], os.environ.get("RUN_COMMIT", "").splitlines()[0:1]
    merge = f"{sha} ({title[0]})" if title else sha
    number = open_issue()
    action = decide(
        conclusion,
        number is not None,
        number is not None and conclusion == "success" and all(newest_passed(w) for w in WATCHED),
    )
    line = f"**{workflow}** failed on main at {merge}: {url}"
    if action == "open":
        gh(
            "issue", "create", "--title", f"{TITLE}: {workflow}",
            "--body",
            f"{line}\n\nThis is the first failing run on main: the merge named above, or it"
            " together with the one before it, broke it. Pull requests opened or re-run"
            " since then show the same failure and it is not theirs.\n\nThis issue closes"
            " itself when main's newest runs have all passed.",
        )
        print(f"main is red: opened an issue for {workflow} at {merge}")
    elif action == "add":
        gh("issue", "comment", str(number), "--body", line)
        print(f"main is red: added {workflow} at {merge} to #{number}")
    elif action == "close":
        gh("issue", "close", str(number), "--comment", f"main is green again at {merge}: {url}")
        print(f"main is green: closed #{number}")
    else:
        print(f"main: {workflow} {conclusion} at {merge}; nothing to say")
    return 0


if __name__ == "__main__":
    sys.exit(main())
