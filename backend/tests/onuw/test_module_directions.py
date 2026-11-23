"""
Which way the game's modules may depend on each other.

``services.py`` is being split into parts that can each be read whole. A part that was
moved out must not be imported back by ``services.py``: that would be an import cycle
waiting to happen, and it would mean the part was not really separate.
"""

import ast
from pathlib import Path

import pytest

pytestmark = pytest.mark.unit

ONUW = Path(__file__).resolve().parents[2] / "apps" / "onuw"
# Parts moved out of services.py. services.py imports none of them.
SPLIT_OUT = ("night_results", "recovery")


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


def test_services_imports_none_of_the_parts_moved_out_of_it() -> None:
    assert imported_modules(ONUW / "services.py") & set(SPLIT_OUT) == set()


def test_the_parts_exist_and_the_scan_sees_imports() -> None:
    for name in SPLIT_OUT:
        assert (ONUW / f"{name}.py").is_file()
    # the scan works: recovery does import services, and the views import both parts
    assert "services" in imported_modules(ONUW / "recovery.py")
    assert set(SPLIT_OUT) <= imported_modules(ONUW / "views.py")
