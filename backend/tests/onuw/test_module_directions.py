# Guard file: a change here needs its line in the pull request (tool/guard_edits.py).
"""
Which way the game's modules may depend on each other.

The game service is split into parts that can each be read whole, in layers: a part
imports only the parts below it. An import upwards would mean the parts were not really
separate.

The whole of ``apps/onuw`` is also held free of import loops, counting the imports
written inside functions: three older loops (through ``choose_night``, ``practice`` and
``presence``) were untangled, and a new one fails here.
"""

import ast
from pathlib import Path

import pytest

pytestmark = pytest.mark.unit

ONUW = Path(__file__).resolve().parents[2] / "apps" / "onuw"
# The game service, bottom to top: each part imports only the ones before it.
LAYERS = (
    "basics",
    "turns",
    "readiness",
    "night_window",
    "night_flow",
    "voting",
    "game_presence",
    "services",
)
# Beside the layers: used by views and the server's start-up, imported by no layer.
BESIDE = ("night_results", "recovery")


def imported_modules(path: Path) -> set[str]:
    """The apps.onuw modules a file imports, anywhere in it (also inside functions)."""
    found: set[str] = set()
    for node in ast.walk(ast.parse(path.read_text())):
        if isinstance(node, ast.ImportFrom):
            module = node.module or ""
            if node.level == 1 and not module:  # from . import x, y
                found.update(alias.name for alias in node.names)
            elif node.level == 1:  # from .x import y
                found.add(module.split(".")[0])
            elif module == "apps.onuw":  # from apps.onuw import x
                found.update(alias.name for alias in node.names)
            elif module.startswith("apps.onuw."):
                found.add(module.split(".")[2])
        elif isinstance(node, ast.Import):
            for alias in node.names:
                if alias.name.startswith("apps.onuw."):
                    found.add(alias.name.split(".")[2])
    return found


@pytest.mark.parametrize("name", LAYERS)
def test_a_part_of_the_service_imports_only_the_parts_before_it(name: str) -> None:
    later = set(LAYERS[LAYERS.index(name) :]) | set(BESIDE)

    assert imported_modules(ONUW / f"{name}.py") & later == set()


def test_the_parts_exist_and_the_scan_sees_imports() -> None:
    for name in LAYERS + BESIDE:
        assert (ONUW / f"{name}.py").is_file()
    # the scan works: the top imports parts below it, recovery reads the layers
    assert "game_presence" in imported_modules(ONUW / "services.py")
    assert imported_modules(ONUW / "recovery.py") & set(LAYERS)
    views = set()
    # the views, and the lazy repair they share with the socket's beat (repair.py)
    for name in ("views", "views_play", "views_read", "repair"):
        views |= imported_modules(ONUW / f"{name}.py")
    assert set(BESIDE) <= views


def test_no_part_is_too_long_to_read_whole() -> None:
    for name in LAYERS + BESIDE:
        lines = len((ONUW / f"{name}.py").read_text().splitlines())
        assert lines <= 600, f"{name}.py is {lines} lines"


def test_no_import_loop_anywhere_in_the_game_app() -> None:
    """No two modules of ``apps/onuw`` import each other, directly or through others,
    at the top of a file or inside a function."""
    graph = {
        path.stem: {m for m in imported_modules(path) if (ONUW / f"{m}.py").is_file()}
        for path in sorted(ONUW.glob("*.py"))
    }
    loops = []
    for start in graph:
        seen, stack = set(), list(graph[start])
        while stack:
            here = stack.pop()
            if here == start:
                loops.append(start)
                break
            if here not in seen:
                seen.add(here)
                stack.extend(graph.get(here, ()))
    assert loops == [], f"modules in an import loop: {sorted(loops)}"
