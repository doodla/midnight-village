#!/usr/bin/env python3
"""The way back from a bad release: a revert branch, and exactly what happens next.

    just revert-release <PR number or commit> [--push]

It never rewinds a live branch: going back is a NEW commit on top of main that undoes
the change, merged like any other (every check green), then promoted by the release job
(tool/promote_live.py), which moves the live branches only forward and never below the
rollback floor. So the way back obeys the same rules as the way forward.

What it does, from a clean working tree:
1. finds the change on origin/main (a PR number is the squash merge whose subject ends
   with `(#N)`); refuses one that is not on main, or that is at or below the floor;
2. makes the branch `revert-<N or commit>` from origin/main and reverts the change there
   (`git revert --no-commit`, then a commit the git hooks check). On a conflict it puts
   everything back as it was and says so;
3. keeps every migration file the change added: the live database has run them, and a
   deploy only migrates forward (docs/dev/deploy-vercel.md, "Deploy-safe changes");
4. prints which side redeploys, what the migrations mean, and the next steps.
Only with `--push` does it push the branch (never a live branch). Then open the pull request.
"""

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import promote_live  # noqa: E402  (what each side ships, and the floor)

MIGRATIONS = "/migrations/"


class Refused(Exception):
    pass


def git(*args: str, check: bool = True) -> subprocess.CompletedProcess:
    done = subprocess.run(
        ["git", "-C", str(ROOT), *args], capture_output=True, text=True
    )
    if check and done.returncode != 0:
        raise Refused(f"`git {' '.join(args)}` failed: {done.stderr.strip()}")
    return done


def find_change(what: str) -> tuple[str, str]:
    """(commit, label) of the change on origin/main."""
    if what.lstrip("#").isdigit():
        number = what.lstrip("#")
        log = git(
            "log",
            "origin/main",
            "--format=%H %s",
            "--fixed-strings",
            f"--grep=(#{number})",
        ).stdout
        hits = [
            line.split(" ", 1)[0]
            for line in log.splitlines()
            if line.endswith(f"(#{number})")
        ]
        if len(hits) != 1:
            raise Refused(
                f"found {len(hits)} merges of #{number} on origin/main; give the commit instead."
            )
        return hits[0], number
    commit = git(
        "rev-parse", "--verify", "-q", f"{what}^{{commit}}", check=False
    ).stdout.strip()
    if not commit:
        raise Refused(
            f"`{what}` is neither a PR number nor a commit here (fetched origin/main?)."
        )
    if not promote_live.is_ancestor(commit, "origin/main"):
        raise Refused(
            f"{commit[:10]} is not on main: only a merged change can be released, or reverted."
        )
    return commit, commit[:10]


def shipped_sides(commit: str) -> list[str]:
    files = git(
        "diff-tree",
        "--no-commit-id",
        "--name-only",
        "-r",
        "--no-renames",
        f"{commit}^",
        commit,
    ).stdout.split()
    return [
        side
        for side, (_, folder, not_shipped) in promote_live.SIDES.items()
        if any(promote_live.ships(f, folder, not_shipped) for f in files)
    ]


def added_migrations(commit: str) -> list[str]:
    out = git(
        "diff-tree",
        "--no-commit-id",
        "--name-only",
        "-r",
        "--diff-filter=A",
        f"{commit}^",
        commit,
    ).stdout
    return [
        f
        for f in out.split()
        if MIGRATIONS in f and f.endswith(".py") and not f.endswith("__init__.py")
    ]


def next_steps(
    label: str, branch: str, sides: list[str], migrations: list[str], pushed: bool
) -> str:
    shown = (
        f"#{label}" if label.isdigit() else label
    )  # a bare number in commands: # starts a comment
    lines = [f"\nThe branch `{branch}` undoes {shown}, on top of origin/main."]
    if len(sides) == 2:
        lines.append(
            "Once merged, the release job moves live-server first, then live-app once the"
            " server serves it: both redeploy."
        )
    elif sides:
        lines.append(f"Once merged, the release job moves live-{sides[0]}: the {sides[0]} redeploys.")
    else:
        lines.append(
            "It changes nothing a side ships (tests, docs, tooling): nothing live redeploys."
        )
    if migrations:
        lines += [
            "It added migrations, which the live database has run and keeps (a deploy only migrates",
            "forward). This revert KEEPS these files:",
            *(f"  {m}" for m in migrations),
            "so `just check` (makemigrations --check) may now ask for a new migration that undoes",
            'them. Make it deploy-safe (docs/dev/deploy-vercel.md, "Deploy-safe changes"): a column',
            "or table goes in two pushes (state-only first, the drop later); never edit or delete",
            "a pushed migration. Until then the code from before the change runs on the newer",
            "schema, which the previous-build check proved it can when the change was merged.",
        ]
    else:
        lines.append("It added no migration: the database needs nothing.")
    floor = promote_live.FLOOR[:10]
    lines.append(
        f"The rollback floor ({floor}, {promote_live.FLOOR_WHY.split(':')[0]}) is not crossed: a"
        " revert is a new commit above it, and the release job refuses anything older."
    )
    lines.append("Next:")
    if not pushed:
        lines.append(
            f"  1. push it: `git push -u origin {branch}` (or next time `just revert-release {label} --push`);"
        )
    lines += [
        f"  {'1' if pushed else '2'}. open its pull request; it merges like any other, with every check green;",
        f'  {"2" if pushed else "3"}. watch the run "Deployed Check" on main: it waits for main\'s checks,'
        " promotes, then plays a game on live.",
        "Faster, by the owner only: Vercel's Instant Rollback (one step back on Hobby). Afterwards",
        "Vercel stops putting new builds live until someone promotes one there (the project's",
        "Production tile, Manage), and the release job's run says the server is not serving its commit.",
    ]
    return "\n".join(lines)


def revert(what: str, push: bool = False, fetch: bool = True, say=print) -> int:
    try:
        if git("status", "--porcelain").stdout.strip():
            raise Refused(
                "the working tree has changes: commit or set them aside first."
            )
        if fetch:
            git("fetch", "-q", "origin", "main")
        commit, label = find_change(what)
        if promote_live.is_ancestor(commit, promote_live.FLOOR):
            raise Refused(
                f"{commit[:10]} is at or below the rollback floor ({promote_live.FLOOR_WHY}):"
                " undoing it would bring back code the live database can no longer serve. Roll forward with a fix."
            )
        subject = git("log", "-1", "--format=%s", commit).stdout.strip()
        branch = f"revert-{label}"
        if (
            git(
                "rev-parse", "--verify", "-q", f"refs/heads/{branch}", check=False
            ).returncode
            == 0
        ):
            raise Refused(f"the branch {branch} already exists: delete it or use it.")
        back_to = git("rev-parse", "--abbrev-ref", "HEAD").stdout.strip()
        git("switch", "-q", "-c", branch, "origin/main")
        undone = git("revert", "--no-commit", commit, check=False)
        if undone.returncode != 0:
            git("revert", "--abort", check=False)
            git("switch", "-q", back_to)
            git("branch", "-q", "-D", branch)
            raise Refused(
                f"{label} does not revert cleanly (later changes build on it): nothing was made."
                f" Roll forward with a fix instead. git said: {undone.stderr.strip()[:300]}"
            )
        migrations = added_migrations(commit)
        if migrations:
            git("checkout", "origin/main", "--", *migrations)
        git(
            "commit",
            "-q",
            "-m",
            f'fix(revert): undo {label}, "{subject}"',
            "-m",
            f"This reverts commit {commit}.",
        )
        sides = shipped_sides(commit)
        if push:
            git("push", "-q", "-u", "origin", branch)
        say(
            next_steps(
                label,
                branch,
                sides,
                migrations,
                push,
            )
        )
        return 0
    except Refused as e:
        say(f"REFUSED: {e}")
        return 1


def main(argv: list[str]) -> int:
    args = [a for a in argv if not a.startswith("--")]
    if len(args) != 1 or set(argv) - set(args) - {"--push"}:
        print(__doc__.split("\n\n")[1].strip())
        return 2
    return revert(args[0], push="--push" in argv)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
