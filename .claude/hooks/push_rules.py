"""Which branches a `git push` would write: the live ones are the release job's alone.

`live-server` and `live-app` are what Vercel deploys from: a push to either puts code
on the live database without main's checks. Only the release job moves them
(`.github/workflows/deployed-check.yml`, `tool/promote_live.py`), after main's required
checks have passed. So the Bash guard (git_guard.py) refuses a push whose destination
is one of them, however it is spelled:

- a refspec's destination (`HEAD:live-server`, `main:refs/heads/live-app`, `+x:live-app`,
  `:live-server` and `--delete live-server`, which delete it);
- a refspec without a colon names its own destination (`git push origin live-app`);
- no refspec, `HEAD` or `@`: the current branch, and where `git push` would send it
  (`@{push}`, which follows push.default and the upstream);
- a pattern whose destination could match (`refs/heads/*:refs/heads/*`), the matching
  push `:`, and `--all`, `--branches`, `--mirror` (every branch, the live ones included).

A destination the shell fills in (`$B`, `$(...)`) is not judged here: the guard is not a
wall (see git_guard.py); GitHub's ruleset on the live branches is.
"""

import fnmatch
import subprocess

LIVE = ("live-server", "live-app")
WITH_VALUE = {"-o", "--push-option", "--repo", "--receive-pack", "--exec"}
EVERY_BRANCH = {"--all", "--branches", "--mirror"}
WHY = (
    " is refused: only the release job (Deployed Check, tool/promote_live.py) moves the"
    " live branches, once main's checks pass. Merge to main instead; to undo a release,"
    " use `just revert-release <PR>`."
)


def where_current_goes(cwd: str) -> list[str]:
    """The current branch, and the branch `git push` would send it to (when it says)."""
    names = []
    for args in (
        ["symbolic-ref", "--short", "-q", "HEAD"],
        ["rev-parse", "--symbolic-full-name", "@{push}"],
    ):
        try:
            got = subprocess.run(
                ["git", "-C", cwd, *args], capture_output=True, text=True, timeout=5
            )
        except (OSError, subprocess.SubprocessError):
            continue
        if got.returncode == 0 and got.stdout.strip():
            name = got.stdout.strip()
            # refs/remotes/<remote>/<branch>: the branch on the remote
            names.append(
                name.split("/", 3)[3] if name.startswith("refs/remotes/") else name
            )
    return names


def branch_of(ref: str) -> str | None:
    """The branch a destination ref names, or None when it is not a branch."""
    if ref.startswith("refs/heads/"):
        return ref[len("refs/heads/") :]
    if ref.startswith("refs/"):
        return None  # a tag, a note: not a branch
    return ref.removeprefix("heads/")


def hits_live(branch: str | None) -> list[str]:
    if branch is None:
        return []
    return [
        live
        for live in LIVE
        if branch == live or ("*" in branch and fnmatch.fnmatchcase(live, branch))
    ]


def live_pushes(args: list[str], cwd: str, unknown: str = "\x00") -> list[str]:
    """Why this push (the arguments after `git push`) is refused; [] when it writes no live branch."""
    reasons, words, i = [], [], 0
    while i < len(args):
        a = args[i]
        if a == "--":
            words += args[i + 1 :]
            break
        if a in WITH_VALUE:
            i += 2
            continue
        if a in EVERY_BRANCH:
            reasons.append(
                f"`git push {a}` writes every branch, the live ones included, and" + WHY
            )
        elif not a.startswith("-"):
            words.append(a)
        i += 1
    current = None
    for spec in words[1:] or [""]:  # the first word is the remote
        if "$" in spec or unknown in spec:
            continue  # the shell fills it in: not judged here
        spec = spec.removeprefix("+")
        if spec == ":":
            reasons.append(
                "`git push <remote> :` writes every matching branch, the live ones included, and"
                + WHY
            )
            continue
        dst = spec.rsplit(":", 1)[1] if ":" in spec else spec
        if dst in ("", "HEAD", "@"):
            if ":" in spec and dst == "":
                continue  # `src:` is not a push git accepts
            current = current if current is not None else where_current_goes(cwd)
            targets = current
        else:
            targets = [dst]
        for target in targets:
            for live in hits_live(branch_of(target)):
                reasons.append(f"`git push` to {live}" + WHY)
    return list(dict.fromkeys(reasons))
