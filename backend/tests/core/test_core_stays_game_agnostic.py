# Guard file: a change here needs its line in the pull request (tool/guard_edits.py).
"""Each game is its own app (principle 6): no app of the project imports a game app but
that game itself. Core is shared infrastructure, observe watches every table; a second game
may not reach into the first.

The apps come from Django's apps list (every installed app under ``apps.``), the game
apps from the registry they plug into core with (``tests/game_apps.py``): an app or a game
added tomorrow is held the day it is installed.
"""

import ast
import importlib.util
from pathlib import Path

from django.apps import apps

import pytest
from repo_files import checkout_files

from tests.game_apps import game_apps

pytestmark = pytest.mark.unit

BACKEND = Path(__file__).resolve().parents[2]


def _package(path: Path) -> str:
    """The dotted package a file's relative imports resolve against (an
    ``__init__.py``'s is its own folder, as any other file's)."""
    return ".".join(path.relative_to(BACKEND).parts[:-1])


def _imports(source: str, package: str) -> list[tuple[int, str]]:
    """Every module a file imports, a relative one resolved against its package."""
    found: list[tuple[int, str]] = []
    for node in ast.walk(ast.parse(source)):
        if isinstance(node, ast.Import):
            found += [(node.lineno, alias.name) for alias in node.names]
        elif isinstance(node, ast.ImportFrom):
            module = node.module or ""
            if node.level:
                module = importlib.util.resolve_name("." * node.level + module, package)
            found.append((node.lineno, module))
            found += [(node.lineno, f"{module}.{alias.name}") for alias in node.names]
    return found


def _project_apps():
    return [a for a in apps.get_app_configs() if a.name.startswith("apps.")]


def _names(module: str, app: str) -> bool:
    return module == app or module.startswith(app + ".")


def test_the_rule_sees_the_game_and_the_apps_beside_it():
    games = {a.name for a in game_apps()}
    others = {a.name for a in _project_apps()} - games
    assert "apps.onuw" in games, games
    assert {"apps.core", "apps.observe"} <= others, others


def test_a_relative_import_is_read_as_the_module_it_reaches():
    package = _package(BACKEND / "apps" / "observe" / "report.py")
    source = "from ..onuw.models import PlayerRole\nfrom . import views\n"
    assert package == "apps.observe"
    assert _imports(source, package) == [
        (1, "apps.onuw.models"),
        (1, "apps.onuw.models.PlayerRole"),
        (2, "apps.observe"),
        (2, "apps.observe.views"),
    ]


def test_no_app_imports_a_game_app_but_its_own_game():
    games = [a.name for a in game_apps()]
    offenders = []
    for app in _project_apps():
        root = Path(app.path)
        for path in checkout_files(root, suffixes=(".py",)):
            if "migrations" in path.parts:
                continue
            for line, module in _imports(path.read_text(), _package(path)):
                for game in games:
                    if game != app.name and _names(module, game):
                        offenders.append(
                            f"{path.relative_to(BACKEND)}:{line}: {app.name} imports"
                            f" {module}. Fix: reach the game through"
                            " apps.core.games (GameHooks), never by import."
                        )
    assert offenders == [], "\n".join(offenders)


def test_core_names_no_game_app_even_in_a_string():
    """A migration may depend on a game app's migration (the timer table moved
    out of it); nothing else under core may even mention one by module path."""
    core = Path(apps.get_app_config("core").path)
    games = [a.name for a in game_apps()]
    offenders = []
    for path in checkout_files(core, suffixes=(".py",)):
        if "migrations" in path.parts:
            continue
        for number, line in enumerate(path.read_text().splitlines(), 1):
            if any(game in line for game in games):
                offenders.append(
                    f"{path.relative_to(BACKEND)}:{number}: {line.strip()}"
                )
    assert offenders == [], "\n".join(offenders)
