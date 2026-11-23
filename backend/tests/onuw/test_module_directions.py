"""
Which way the game's modules may depend on each other.

The game service is split into parts that can each be read whole, in layers: a part
imports only the parts below it. An import upwards would mean the parts were not really
separate.

What this checks is the DIRECT imports between the layers. Three older modules beside
them still close a loop when followed through, as they did when the service was one
file (they load in any order; a review ran every first import): ``choose_night``
(imported by ``readiness``, imports the night's layers), ``practice`` (imported inside
one function of ``basics``, imports ``voting``) and ``presence`` (imported by
``readiness``, imports ``game_presence`` inside a function). Untangling those is
separate work; do not add a fourth.
"""

import ast
from pathlib import Path

import pytest

pytestmark = pytest.mark.unit

ONUW = Path(__file__).resolve().parents[2] / "apps" / "onuw"
# The game service, bottom to top: each part imports only the ones before it.
LAYERS = (
    "basics",
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
    assert set(BESIDE) <= imported_modules(ONUW / "views.py")


def test_no_part_is_too_long_to_read_whole() -> None:
    for name in LAYERS + BESIDE:
        lines = len((ONUW / f"{name}.py").read_text().splitlines())
        assert lines <= 600, f"{name}.py is {lines} lines"
