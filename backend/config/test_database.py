"""
The name of a test run's database, and which leftover ones may go.

Every pytest run builds its own database, ``test_<DB_NAME>_<process id>``, so two runs
side by side (two agents, two worktrees, or two commands in one checkout) can never be
on the same one. A run that was killed leaves its database behind; the next run drops
those whose process is gone (``tests/conftest.py``).

Plain functions: no Django here, so they are tested without a database.
"""

import os
import re
from collections.abc import Callable, Iterable


def run_database_name(base: str, pid: int) -> str:
    """The test database of the run with this process id."""
    return f"test_{base}_{pid}"


def process_is_alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:  # it exists, and belongs to someone else
        return True
    return True


def leftover_databases(
    names: Iterable[str],
    base: str,
    own_pid: int,
    is_alive: Callable[[int], bool] = process_is_alive,
) -> list[str]:
    """Test databases of this ``DB_NAME`` whose run is no longer there.

    Also the name from before runs had their own (``test_<DB_NAME>``), which
    nothing uses any more. Never this run's own, and never another base's.
    """
    pattern = re.compile(rf"^test_{re.escape(base)}_(\d+)$")
    gone = []
    for name in names:
        if name == f"test_{base}":
            gone.append(name)
            continue
        match = pattern.match(name)
        if (
            match
            and int(match.group(1)) != own_pid
            and not is_alive(int(match.group(1)))
        ):
            gone.append(name)
    return sorted(gone)
