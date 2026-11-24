"""`just brief <area>`: the brief for work that is not a screen (tool/brief.py calls this).

An area is a row of AREAS: what it is, its files, its tests, its model slice if
it has one, and the rules that bite there. Nothing is written twice: files and
tests are globs (so the brief lists what is there today, with sizes), and a
rule is a place in a document, printed word for word from it. A glob that
matches nothing, or a rule that is no longer where the row says, fails
`.claude/guardrails/tests/test_brief.py`, so a row cannot quietly go stale.

A rule is (document, kind, start):
- "bullet": the `- **start...` bullet of the document, whole.
- "section": the `## start...` section, whole (keep to short ones).
- "see": the heading only, with its line, for a section too long to print.
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIMIT = 600

APP = "frontend/CLAUDE.md"
APP_RULES = "frontend/docs/app-rules.md"
GAME = "frontend/lib/features/game/README.md"
KIT = "frontend/lib/design_system/README.md"
SERVER = "backend/CLAUDE.md"
MODELS = "docs/dev/models/README.md"
LOBBY_MODEL = "docs/dev/models/phone/lobby/README.md"

AREAS: dict[str, dict] = {
    "lobby-queue": {
        "what": "The lobby on the phone: the host's settings going out one at a "
        'time, reads, the socket, and the one shared "Try again".',
        "files": [
            "frontend/lib/features/lobby/presentation/lobby_*.dart",
            "frontend/lib/features/lobby/domain/*.dart",
            "frontend/lib/features/lobby/data/lobby_service.dart",
            "frontend/lib/core/requests/player_request.dart",
            "frontend/lib/core/healing/healing.dart",
        ],
        "tests": [
            "frontend/test/features/lobby/presentation/lobby_*_test.dart",
            "frontend/test/features/lobby/presentation/settings_lane*_test.dart",
            "frontend/test/features/lobby/presentation/practice_players_test.dart",
            "frontend/test/features/lobby/presentation/setup_page_test.dart",
            "frontend/test/features/lobby/presentation/read_failing_test.dart",
            "frontend/test/features/lobby/presentation/answers_used_test.dart",
            "frontend/test/features/lobby/domain/*_test.dart",
            "frontend/test/features/lobby/data/*_test.dart",
        ],
        "model": "docs/dev/models/phone/lobby",
        "rules": [
            (APP, "bullet", "Taps change what others can see at once"),
            (APP, "bullet", "Every request a player's tap makes"),
            (APP, "bullet", "Every fetch a screen depends on heals"),
            (APP, "bullet", "No waits."),
            (APP_RULES, "section", "Requests"),
            (MODELS, "section", "When"),
            (LOBBY_MODEL, "section", "Files"),
            (LOBBY_MODEL, "section", "Rules"),
            (LOBBY_MODEL, "see", "Known gaps"),
        ],
    },
    "outbox": {
        "what": "The game on the phone: every tap through the one Outbox, the "
        "stage requests, `/me/` and the socket.",
        "files": [
            "frontend/lib/features/game/presentation/outbox.dart",
            "frontend/lib/features/game/presentation/live_game*.dart",
            "frontend/lib/features/game/presentation/game_socket.dart",
            "frontend/lib/features/game/data/*.dart",
            "frontend/lib/features/game/domain/game_me.dart",
            "frontend/lib/features/game/domain/screen_table.dart",
            "frontend/lib/core/requests/player_request.dart",
            "frontend/lib/core/websocket/*.dart",
        ],
        "tests": [
            "frontend/test/features/game/presentation/live_game*_test.dart",
            "frontend/test/features/game/presentation/waits_and_busy_test.dart",
            "frontend/test/features/game/data/*_test.dart",
            "frontend/test/features/game/domain/*_test.dart",
        ],
        "model": "docs/dev/models/phone",
        "rules": [
            (APP, "bullet", "The server decides."),
            (APP, "bullet", "Taps change what others can see at once"),
            (APP, "bullet", "Every request a player's tap makes"),
            (APP, "bullet", "Every fetch a screen depends on heals"),
            (APP, "bullet", "No waits."),
            (APP_RULES, "section", "Requests"),
            (MODELS, "section", "When"),
        ],
    },
    "design-system": {
        "what": "The kit every screen is built from: the primitives, the skin, "
        "the two dresses.",
        "files": [
            "frontend/lib/design_system/primitives/*.dart",
            "frontend/lib/design_system/skin/*.dart",
            "frontend/lib/design_system/layout/*.dart",
        ],
        "tests": [
            "frontend/test/design_system/primitives/*_test.dart",
            "frontend/test/design_system/skin/*_test.dart",
        ],
        "model": None,
        "rules": [
            (APP, "bullet", "Values from the skin"),
            (APP, "bullet", "One look, two dresses"),
            (APP, "bullet", "Names are never cut"),
            (APP, "bullet", "Reading floor"),
            (APP, "bullet", "A screen's main action never sits silently disabled"),
            (APP, "bullet", "Every place the app waits is `Waiting`"),
            (KIT, "see", "Every component, in both dresses"),
            (KIT, "see", "The skin: one look, values from the skin"),
            (KIT, "see", "The dress: plain, or paper"),
        ],
    },
    "copy": {
        "what": "Every word a player reads: the copy library, its types "
        "(`Words`, `Template`) and the rules that hold the words.",
        "files": [
            "frontend/lib/design_system/copy/*.dart",
            "tool/copy_page.py",
            "tool/words_added.py",
        ],
        "tests": ["frontend/test/design_system/copy/*.dart"],
        "model": None,
        "rules": [
            (APP, "bullet", "Words"),
            (APP, "bullet", "Names are never cut"),
            ("docs/specs/frontend/first-time-play.md", "see", "1."),
        ],
    },
    "models": {
        "what": "The model-checked slices of ordering and concurrency logic "
        "(the server's stages, the phone's queues).",
        "files": [
            "docs/dev/models/README.md",
            "docs/dev/models/*/README.md",
            "docs/dev/models/*/*.tla",
            "docs/dev/models/phone/*/*.tla",
            "docs/dev/models/phone/*/README.md",
        ],
        "tests": [],
        "model": "docs/dev/models",
        "rules": [
            (MODELS, "section", "When"),
            (MODELS, "section", "How"),
            (MODELS, "section", "Models"),
        ],
    },
    "server": {
        "what": "The Django server: the lobby in `apps.core`, the game in "
        "`apps.onuw`, its payloads and migrations. It is LIVE.",
        "files": [
            "backend/apps/core/*.py",
            "backend/apps/onuw/*.py",
            "backend/apps/onuw/engine/*.py",
        ],
        "tests": ["backend/tests/**/test_*.py"],
        "model": "docs/dev/models/night2",
        "rules": [
            (SERVER, "section", "Deploy-safe changes"),
            (SERVER, "section", "Rules that have bitten"),
            (SERVER, "section", "Contract samples"),
            (SERVER, "see", "Adding things"),
        ],
    },
}

COMMANDS = """\
  just piece-check          while building: fast checks + only the tests this change reaches
  just handover <file>      LAST, the only way to hand over
  just brief                every brief there is (screens and areas)
"""


def files_of(globs: list[str]) -> list[str]:
    """The tracked-looking files the globs match, generated code left out."""
    found = set()
    for pattern in globs:
        for path in ROOT.glob(pattern):
            if path.is_file() and not path.name.endswith((".g.dart", ".freezed.dart")):
                found.add(str(path.relative_to(ROOT)))
    return sorted(found)


def rule_text(document: str, kind: str, start: str) -> tuple[int, str] | None:
    """(line, text) of the rule in the document, or None when it is not there."""
    lines = (ROOT / document).read_text().splitlines()
    if kind == "bullet":
        for i, line in enumerate(lines):
            if line.startswith(f"- **{start}"):
                end = i + 1
                while end < len(lines) and lines[end].startswith("  "):
                    end += 1
                return i + 1, "\n".join(lines[i:end])
        return None
    for i, line in enumerate(lines):
        if line.startswith("#") and line.lstrip("#").strip().startswith(start):
            if kind == "see":
                return i + 1, line.strip()
            depth = len(line) - len(line.lstrip("#"))
            end = i + 1
            while end < len(lines) and not (
                lines[end].startswith("#")
                and len(lines[end]) - len(lines[end].lstrip("#")) <= depth
            ):
                end += 1
            return i + 1, "\n".join(lines[i:end]).rstrip()
    return None


def listing() -> str:
    width = max(len(name) for name in AREAS)
    return "\n".join(
        f"  {name:<{width}}  {area['what']}" for name, area in AREAS.items()
    )


def size(path: str) -> str:
    lines = len((ROOT / path).read_text(errors="replace").splitlines())
    flag = (
        "  OVER THE LIMIT: may shrink, never grow"
        if lines > LIMIT
        else ("  near the limit" if lines > LIMIT - 60 else "")
    )
    return f"{lines:4d} lines  {path}{flag}"

MANY = 40


def listed(paths: list[str], line) -> str:
    """One line a file; past MANY, a line a folder, and only the files at the limit."""
    if len(paths) <= MANY:
        return "\n".join("  " + line(p) for p in paths)
    folders: dict[str, int] = {}
    for path in paths:
        folder = path.rsplit("/", 1)[0]
        folders[folder] = folders.get(folder, 0) + 1
    out = [f"  {count:3d} files  {folder}/" for folder, count in sorted(folders.items())]
    flagged = [line(p) for p in paths if line(p).endswith(("never grow", "near the limit"))]
    return "\n".join(out + [f"  {f}" for f in flagged])


def brief(name: str, others_in) -> str:
    """The brief of area `name`. `others_in` is tool/brief.py's (who else is in files)."""
    area = AREAS[name]
    out = [
        f"# Brief: {name}\n",
        area["what"] + "\n",
        "Everything below is copied from the sources named. Read the source before changing what it says.\n",
        "## The rules that bite here\n",
    ]
    for document, kind, start in area["rules"]:
        found = rule_text(document, kind, start)
        if found is None:
            out.append(
                f"({document}: no '{start}' any more; tell whoever keeps tool/brief_areas.py)\n"
            )
            continue
        line, text = found
        if kind == "see":
            out.append(f"Read: {document}:{line}  {text}\n")
        else:
            out.append(f"({document}:{line})\n\n{text}\n")
    files = files_of(area["files"])
    out.append(f"## Files ({len(files)})\n")
    out.append(listed(files, size) + "\n")
    if area["model"]:
        model = ROOT / area["model"]
        slices = sorted(
            str(p.relative_to(ROOT))
            for p in [
                *model.glob("*.tla"),
                *model.glob("README.md"),
                *model.glob("*.sh"),
            ]
        )
        out.append(f"## The model ({area['model']})\n")
        out.append(
            "Ordering or concurrency logic here is model-checked: change the model with the code"
            " (docs/dev/models/README.md says when and how).\n"
        )
        out.append("\n".join(f"  {p}" for p in slices) + "\n")
    tests = files_of(area["tests"])
    out.append(f"## Tests ({len(tests)})\n")
    out.append((listed(tests, lambda p: p) or "  (none of its own)") + "\n")
    out.append("## Who else is in these files (branches on the remote, not merged)\n")
    others = others_in(set(files))
    if not others:
        out.append("Nobody.\n")
    for branch, theirs in others.items():
        out.append(f"  {branch}: " + ", ".join(theirs))
    out.append("\n## Commands\n\n" + COMMANDS)
    return "\n".join(out)
