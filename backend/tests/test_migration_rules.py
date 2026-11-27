"""
Rules every migration file follows (see "Deploy-safe changes" in backend/CLAUDE.md).

* A migration never imports application code: the code changes, the migration must
  keep meaning what it meant when it was written.
* Every migration starts by setting a lock timeout, so an ALTER that cannot get its
  lock fails the deploy at once instead of blocking the live site behind it. Only the
  ones written before the rule are exempt, by name (``BEFORE_THE_RULE``, frozen): a
  new app's first migration is held to it like any other.
"""

import ast
import re
from pathlib import Path

import pytest
from repo_files import checkout_files

pytestmark = pytest.mark.unit

APPS = Path(__file__).resolve().parents[1] / "apps"
MIGRATIONS = [
    p
    for p in checkout_files(APPS, suffixes=(".py",))
    if p.parent.name == "migrations"
    and p.parent.parent.parent == APPS
    and p.name != "__init__.py"
    and re.match(r"\d{4}_", p.name)
]
# Written before the rule; never add to this list.
BEFORE_THE_RULE = frozenset(
    {
        "core/0001_initial",
        "core/0002_lobby",
        "core/0003_lobbymember",
        "core/0004_alter_lobbymember_options_user_display_name_and_more",
        "core/0005_alter_lobbymember_unique_together_and_more",
        "core/0006_host_handover",
        "core/0007_remove_lobbymember_connections",
        "core/0008_lobbysocket",
        "core/0009_scheduledtimer",
        "onuw/0001_initial",
        "onuw/0002_add_phase_deadline",
        "onuw/0003_night_windows",
        "onuw/0004_play_again_and_presence",
        "onuw/0005_scheduled_timer",
        "onuw/0006_socket_presence",
        "onuw/0007_timer_publication",
        "onuw/0008_lobby_sockets_to_core",
        "onuw/0009_core_owns_timers",
    }
)


def _name(path: Path) -> str:
    return f"{path.parent.parent.name}/{path.stem}"


def test_the_exempt_list_names_only_migrations_that_exist() -> None:
    assert BEFORE_THE_RULE <= {_name(p) for p in MIGRATIONS}


def imported_modules(tree: ast.AST) -> list[str]:
    found: list[str] = []
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            found += [alias.name for alias in node.names]
        elif isinstance(node, ast.ImportFrom):
            found.append(node.module or "")
    return found


def first_operation(tree: ast.AST) -> ast.expr | None:
    for node in ast.walk(tree):
        if isinstance(node, ast.Assign) and any(
            isinstance(t, ast.Name) and t.id == "operations" for t in node.targets
        ):
            ops = node.value
            if isinstance(ops, ast.List) and ops.elts:
                return ops.elts[0]
    return None


def test_the_scan_finds_the_migrations() -> None:
    names = {f"{p.parent.parent.name}/{p.name}" for p in MIGRATIONS}
    assert "core/0010_lobbymember_token.py" in names
    assert "onuw/0010_playerrole_v2_fields.py" in names


@pytest.mark.parametrize(
    "path", MIGRATIONS, ids=lambda p: f"{p.parent.parent.name}/{p.stem}"
)
def test_a_migration_imports_no_application_code(path: Path) -> None:
    offenders = [
        name
        for name in imported_modules(ast.parse(path.read_text()))
        if name == "apps" or name.startswith("apps.")
    ]
    assert offenders == []


@pytest.mark.parametrize(
    "path",
    [p for p in MIGRATIONS if _name(p) not in BEFORE_THE_RULE],
    ids=lambda p: f"{p.parent.parent.name}/{p.stem}",
)
def test_a_new_migration_starts_with_a_lock_timeout(path: Path) -> None:
    first = first_operation(ast.parse(path.read_text()))

    assert isinstance(first, ast.Call)
    assert isinstance(first.func, ast.Attribute) and first.func.attr == "RunSQL"
    sql = first.args[0]
    assert isinstance(sql, ast.Constant)
    assert isinstance(sql.value, str)
    assert re.search(r"SET\s+LOCAL\s+lock_timeout", sql.value, re.IGNORECASE)
