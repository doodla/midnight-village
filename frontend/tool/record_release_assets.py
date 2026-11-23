#!/usr/bin/env python3
"""Records the app's bundled files (everything under assets/) in release_assets.json:
the fallback list `test/design_system/asset_release_test.dart` holds the bundle to
when git cannot say what the last release held (the test normally compares with the
files at origin/main, so nothing has to be recorded per merge).

It REFUSES to record while any file of the last release (the committed list, and the
bundle at origin/main when git has it) is gone from the bundle and not covered: a
removed or renamed file is still asked for by an app left open on the last release.
Covered means a dated line under "removedOnPurpose" in release_assets.json
("2026-11-24: why"); a retired alias (`ArtSet.retired`) is covered by staying in the
bundle as a copy. So this cannot be used to regenerate the list over a removal.
The lines under removedOnPurpose are kept; a path that is in the bundle again is
dropped from them."""

import json
import pathlib
import re
import subprocess
import sys

here = pathlib.Path(__file__).resolve().parent
frontend = here.parent
target = here / "release_assets.json"
DATED = re.compile(r"^\d{4}-\d{2}-\d{2}: \S.*")


def bundle_files():
    return sorted(
        p.relative_to(frontend).as_posix()
        for p in (frontend / "assets").rglob("*")
        if p.is_file()
    )


def files_at_origin_main():
    """The bundle's files at origin/main, or None when git cannot say."""
    try:
        out = subprocess.run(
            ["git", "ls-tree", "-r", "--name-only", "origin/main", "--", "assets"],
            cwd=frontend,
            capture_output=True,
            text=True,
            timeout=30,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    if out.returncode != 0:
        return None
    return [line for line in out.stdout.splitlines() if line]


def uncovered(last_release, files, on_purpose):
    """Files of the last release that are gone from the bundle and say no reason."""
    have = set(files)
    return sorted(
        path
        for path in set(last_release)
        if path not in have and not DATED.match(on_purpose.get(path, ""))
    )


def main():
    files = bundle_files()
    old = json.loads(target.read_text()) if target.exists() else {}
    on_purpose = old.get("removedOnPurpose", {})
    last_release = set(old.get("files", []))
    at_main = files_at_origin_main()
    if at_main is not None:
        last_release |= set(at_main)
    gone = uncovered(last_release, files, on_purpose)
    if gone:
        print(
            "NOT recorded: these files of the last release are gone from the bundle,\n"
            "and an app left open on that release still asks for them:\n  "
            + "\n  ".join(gone)
            + "\nKeep each as a copy of its successor and list it in ArtSet.retired, or,"
            ' when nothing draws it any more and it is safe to lose, add\n  "<path>":'
            ' "YYYY-MM-DD: why"\nunder removedOnPurpose in tool/release_assets.json,'
            " then run this again.",
            file=sys.stderr,
        )
        return 1
    removed = {path: why for path, why in on_purpose.items() if path not in files}
    target.write_text(
        json.dumps({"removedOnPurpose": removed, "files": files}, indent=2) + "\n"
    )
    print(f"recorded {len(files)} files in {target.relative_to(frontend)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
