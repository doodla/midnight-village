"""apps.core is shared infrastructure: it must never import a game app (principle 6)."""

import ast
from pathlib import Path

import pytest
from repo_files import checkout_files

pytestmark = pytest.mark.unit

CORE = Path(__file__).resolve().parents[2] / "apps" / "core"
GAME_APPS = ("apps.onuw",)


def _imports(path: Path) -> list[str]:
    found: list[str] = []
    for node in ast.walk(ast.parse(path.read_text())):
        if isinstance(node, ast.Import):
            found += [alias.name for alias in node.names]
        elif isinstance(node, ast.ImportFrom):
            module = node.module or ""
            found.append(module)
            found += [f"{module}.{alias.name}" for alias in node.names]
    return found


def test_core_never_imports_a_game_app():
    offenders = []
    for path in checkout_files(CORE, suffixes=(".py",)):
        if "migrations" in path.parts:
            continue
        for name in _imports(path):
            if name.startswith(GAME_APPS):
                offenders.append(f"{path.relative_to(CORE)}: {name}")
    assert offenders == []


def test_only_migration_dependencies_may_name_a_game_app():
    """A migration may depend on a game app's migration (the timer table moved
    out of it); nothing else under core may even mention one by module path."""
    offenders = []
    for path in checkout_files(CORE, suffixes=(".py",)):
        if "migrations" in path.parts:
            continue
        for number, line in enumerate(path.read_text().splitlines(), 1):
            if "apps.onuw" in line:
                offenders.append(f"{path.relative_to(CORE)}:{number}: {line.strip()}")
    assert offenders == []
