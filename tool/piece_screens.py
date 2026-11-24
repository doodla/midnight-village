#!/usr/bin/env python3
"""Render only the screen states a change can reach, strict, at 360 and 390.

Which states is worked out from the app itself, with nothing kept by hand:

1. Every catalogue state is built once and its widget tree walked
   (frontend/test_screens/state_widgets_test.dart): the names of the widget
   classes it draws. About a minute; kept in frontend/build/ and reused until a
   file under lib/, test_screens/ or test/helpers/ changes.
2. A class name is the file that declares it (read from frontend/lib).
3. A changed file reaches the states that draw one of its widgets. A changed file
   that declares no widget any state draws (a notifier, the copy, the skin) is
   followed to the files that import it, until files with drawn widgets are met.

Everything is rendered instead when that cannot be trusted: an asset, the
catalogue or a test helper changed, or a state could not be built.

usage: tool/piece_screens.py [--list] <changed file>...
"""

import hashlib
import json
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DECLARED = re.compile(
    r"^(?:abstract |final |sealed |base |interface )*(?:class|mixin|enum|extension type)\s+(\w+)",
    re.M,
)
DIRECTIVE = re.compile(r"""^\s*(?:import|export|part)\s+['"]([^'"]+)['"]""", re.M)
WIDTHS = (360, 390)
# Past this share of the catalogue, choosing saves nothing: render it all.
MOST = 0.6


def frontend() -> Path:
    return ROOT / "frontend"


def lib_files() -> list[Path]:
    return [
        f
        for f in sorted((frontend() / "lib").rglob("*.dart"))
        if not f.name.endswith((".g.dart", ".freezed.dart"))
    ]


def content_key() -> str:
    """Changes whenever a file that can change a state's tree does."""
    digest = hashlib.sha256()
    for folder in ("lib", "test_screens", "test/helpers"):
        for f in sorted((frontend() / folder).rglob("*.dart")):
            digest.update(str(f.relative_to(frontend())).encode())
            digest.update(f.read_bytes())
    return digest.hexdigest()


def state_widgets() -> dict[str, list[str]]:
    """{state id: widget class names in its tree}, walked again when the app changed."""
    out = frontend() / "build" / "state_widgets.json"
    key_file = frontend() / "build" / "state_widgets.key"
    key = content_key()
    if out.is_file() and key_file.is_file() and key_file.read_text() == key:
        return json.loads(out.read_text())
    print("screens: reading every state's widget tree (about a minute)...", flush=True)
    done = subprocess.run(
        [
            "flutter",
            "test",
            "test_screens/state_widgets_test.dart",
            "--dart-define=ENV=dev",
            "--reporter",
            "failures-only",
        ],
        cwd=frontend(),
        capture_output=True,
        text=True,
    )
    if done.returncode != 0 or not out.is_file():
        print(done.stdout[-2000:], file=sys.stderr)
        raise SystemExit("screens: could not read the states' widget trees")
    key_file.write_text(key)
    return json.loads(out.read_text())


def owners() -> dict[str, set[str]]:
    """{class name: the lib files that declare one} (a private name can be in two)."""
    found: dict[str, set[str]] = defaultdict(set)
    for f in lib_files():
        for name in DECLARED.findall(f.read_text()):
            found[name].add(str(f.relative_to(ROOT)))
    return found


def importers() -> dict[str, set[str]]:
    """{lib file: the lib files that import, export or hold it as a part}."""
    lib = frontend() / "lib"
    package = "midnight_village"
    match = re.search(
        r"^name:\s*(\S+)", (frontend() / "pubspec.yaml").read_text(), re.M
    )
    if match:
        package = match.group(1)
    back: dict[str, set[str]] = defaultdict(set)
    for f in lib_files():
        for target in DIRECTIVE.findall(f.read_text()):
            if target.startswith(f"package:{package}/"):
                other = lib / target.split("/", 1)[1]
            elif ":" in target:
                continue
            else:
                other = (f.parent / target).resolve()
            if other.is_file():
                back[str(other.relative_to(ROOT))].add(str(f.relative_to(ROOT)))
    return back


def states_for(
    changed: list[str],
    widgets: dict[str, list[str]],
    owner: dict[str, set[str]],
    imported_by: dict[str, set[str]],
) -> tuple[set[str] | None, str]:
    """(the states to render, or None for all of them; why)."""
    for name in changed:
        if name.startswith(
            ("frontend/assets/", "frontend/test_screens/", "frontend/test/helpers/")
        ):
            return None, f"{name} can change any state"
        if name in ("frontend/pubspec.yaml", "frontend/pubspec.lock"):
            return None, f"{name} can change any state"
    drawn_in: dict[str, set[str]] = defaultdict(set)
    for state, names in widgets.items():
        for class_name in names:
            for path in owner.get(class_name, ()):
                drawn_in[path].add(state)
    picked: set[str] = set()
    for name in changed:
        if not (name.startswith("frontend/lib/") and name.endswith(".dart")):
            continue
        # follow importers until files whose widgets some state draws
        frontier, seen = {name}, {name}
        while frontier:
            following: set[str] = set()
            for path in frontier:
                if drawn_in.get(path):
                    picked |= drawn_in[path]
                else:
                    following |= imported_by.get(path, set()) - seen
            seen |= following
            frontier = following
    return picked, ""


def render(states: set[str] | None) -> int:
    """`just screens` strict at each width: all of it, or only `states`."""
    status = 0
    for width in WIDTHS:
        if states is None:
            command = ["just", "screens", str(width), "strict"]
        else:
            wanted = "|".join(re.escape(s) for s in sorted(states))
            command = [
                "flutter",
                "test",
                *sorted(
                    str(p.relative_to(frontend()))
                    for p in (frontend() / "test_screens").glob(
                        "screens_*of*_test.dart"
                    )
                ),
                "--reporter",
                "failures-only",
                "--dart-define=ENV=dev",
                f"--dart-define=SCREENS_WIDTH={width}",
                "--dart-define=SCREENS_STRICT=true",
                "--name",
                f"^({wanted})$",
            ]
        if states is not None:
            # the last run's pictures go first, as `just screens` does: what is in
            # the folder afterwards is this change's states and nothing stale
            out = frontend() / "build" / "screens" / ("" if width == 390 else f"w{width}")
            for stale in [*out.glob("*.png"), *out.glob("summary*.txt")]:
                stale.unlink()
        print(f"screens: at {width}, strict...", flush=True)
        status = subprocess.run(command, cwd=frontend()).returncode or status
    return status


def main(argv: list[str]) -> int:
    only_list = "--list" in argv
    changed = [a for a in argv if not a.startswith("--")]
    widgets = state_widgets()
    states, why_all = states_for(changed, widgets, owners(), importers())
    total = len(widgets)
    if states is not None and len(states) > MOST * total:
        states, why_all = None, f"{len(states)} of {total} states draw what changed"
    if states is None:
        print(f"screens: all {total} states ({why_all}).")
    elif not states:
        print("screens: no state draws what changed; nothing to render.")
        return 0
    else:
        print(f"screens: {len(states)} of {total} states draw what changed:")
        for state in sorted(states):
            print(f"    {state}")
        print("  pictures: frontend/build/screens/ (390) and build/screens/w360/")
    return 0 if only_list else render(states)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
