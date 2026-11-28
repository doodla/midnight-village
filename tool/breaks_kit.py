# Guard file: a change here needs its line in the pull request (tool/guard_edits.py).
"""What a deliberate break is, and how one is put into a copy of the tree (tool/prove_guards.py).

A break is a small, realistic mistake, the promise it breaks, and the tests that must
fail on it. Its edits are anchored: each names the function or class it lands in (a
Python file) or a marker line (any other file), and the text it replaces must be there
exactly once. When the code moves so that an edit no longer lands, applying it fails
loudly ("break no longer applies: update it"): a break never passes by missing.
"""

from __future__ import annotations

import ast
from dataclasses import dataclass

# Each promise is one of CLAUDE.md's, with the paths whose change can weaken what holds
# it: `just handover` runs the breaks of the promises a change touches.
PROMISES: dict[str, tuple[str, tuple[str, ...]]] = {
    "server-authoritative": (
        "all game logic on the server",
        (
            "backend/apps/",
            "frontend/lib/core/requests/",
            "frontend/lib/features/game/domain/server_clock.dart",
        ),
    ),
    "hidden-information": (
        "responses, socket events and errors are player-scoped",
        (
            "backend/apps/",
            "backend/tests/contract/",
            "backend/tests/privacy/",
            "backend/config/",
            "contract_samples/",
        ),
    ),
    "state-machine": (
        "phases with explicit transitions; invalid ones rejected",
        ("backend/apps/onuw/", "backend/tests/onuw/"),
    ),
    "atomicity": (
        "state changes are all-or-nothing, the Game row locked first",
        ("backend/apps/", "backend/tests/perf/", "backend/tests/conftest.py"),
    ),
    "determinism": (
        "all randomness seeded and logged",
        ("backend/apps/onuw/engine/", "backend/apps/onuw/night_window.py"),
    ),
    "separate-game-apps": (
        "core is shared; each game is its own app",
        (
            "backend/apps/",
            "backend/tests/core/",
            "backend/tests/onuw/test_module_directions.py",
        ),
    ),
    "http-for-actions": (
        "HTTP for actions, sockets for events",
        ("backend/apps/", "backend/tests/privacy/"),
    ),
    "no-added-waits": (
        "no added waits, minimums or assumed lengths",
        ("backend/apps/", "frontend/lib/core/", "backend/tests/privacy/"),
    ),
    "names-in-full": ("a player's name is never truncated", ("frontend/lib/",)),
    "guards-hold": (
        "a guard cannot be weakened or switched off quietly",
        (
            "backend/tests/conftest.py",
            "backend/pyproject.toml",
            "backend/tests/guard_counts.json",
            "tool/guard_edits.py",
            "tool/guard_counts.py",
            "tool/prove_guards.py", "tool/breaks_",
            ".github/",
        ),
    ),
    "few-words": ("few words on screen, every word from copy.dart", ("frontend/lib/",)),
    "one-look": (
        "a look is a complete design; sizes come from the skin",
        ("frontend/lib/",),
    ),
    "fixtures-from-samples": (
        "test fixtures come only from contract_samples/",
        ("frontend/test/", "contract_samples/", "backend/tests/contract/"),
    ),
    "files-under-600": (
        "a source file stays under 600 lines",
        ("tool/check_file_sizes.py",),
    ),
    "the-wall": (
        "GitHub is the wall; the tools that guard the work do what they say",
        (
            "tool/",
            ".claude/",
            ".github/",
            "justfile",
            "backend/justfile",
            "frontend/justfile",
        ),
    ),
    "screens-still": (
        "a screen at rest draws nothing; taps answer in the frame",
        ("frontend/lib/", "frontend/test/helpers/"),
    ),
}


class NoLongerApplies(Exception):
    """The edit's anchor or text is gone or doubled: the break must be updated."""


@dataclass(frozen=True)
class Edit:
    """Replace `old` by `new` inside `within`; `old=None` adds `new` at its end.

    `within` is a function or class of a Python file (dotted for a method:
    "Consumer.receive_json"), or a line of text in any other file (the region runs
    from it to the end of the file). None: the whole file.
    """

    path: str
    old: str | None
    new: str
    within: str | None = None


@dataclass(frozen=True)
class Break:
    name: str
    promise: str
    why: str
    edits: tuple[Edit, ...]
    # repo-relative test files, `path::test` for one test (backend: pytest's node id;
    # guardrails: `path::Class.test`; frontend: `path::plain name`)
    tests: tuple[str, ...] = ()
    # instead of tests: a command run from the copy's root, which must exit non-zero
    # and print `expect` (what its guard says), or the run proves nothing
    command: tuple[str, ...] = ()
    # a command's: what its guard prints. A backend break's: words its killer's failing
    # assertion says (the promise's own assertion), unless every test is `path::test`
    expect: str = ""
    env: tuple[tuple[str, str], ...] = ()
    # guard files proved besides the test files: a helper those tests import, or a
    # command break's own file (breaks_rules.helper_problems)
    guards: tuple[str, ...] = ()
    # a break nothing kills yet: why, and what will. `just prove-guards` reports it and
    # fails the day it is killed (take the line off then).
    survives: str = ""
    # re-record contract_samples/ with the mistake in before the tests run, as a
    # builder following "after a payload change run `just samples`" would
    resample: bool = False
    # a break that is NOT a mistake its tests should catch (a bogus one: it only makes
    # the script fail): the harness must judge it "broken"; "killed" is a false catch
    proves_nothing: bool = False

    def runner(self) -> str:
        if self.command:
            return "cmd"
        first = self.tests[0]
        if first.startswith("backend/"):
            return "backend"
        if first.startswith("frontend/"):
            return "flutter"
        return "guardrails"

    def killers(self) -> tuple[str, ...]:
        tests = (t.split("::")[0] for t in self.tests)
        return tuple(dict.fromkeys([*tests, *self.guards]))

    def files(self) -> set[str]:
        return {e.path for e in self.edits} | set(self.killers())


def _python_region(text: str, within: str, path: str) -> tuple[int, int]:
    tree = ast.parse(text)
    parts = within.split(".")
    found: list[ast.AST] = []

    def walk(nodes, depth: int) -> None:
        for node in nodes:
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
                if node.name == parts[depth]:
                    if depth == len(parts) - 1:
                        found.append(node)
                    else:
                        walk(node.body, depth + 1)
            elif depth == 0 and isinstance(node, (ast.If, ast.Try, ast.With)):
                walk(ast.iter_child_nodes(node), depth)

    walk(tree.body, 0)
    if len(found) != 1:
        raise NoLongerApplies(
            f"{path}: {len(found)} definitions named {within!r}, not one"
        )
    node = found[0]
    lines = text.splitlines(keepends=True)
    start = sum(len(line) for line in lines[: node.lineno - 1])
    end = sum(len(line) for line in lines[: node.end_lineno])
    return start, end


def region(text: str, edit: Edit) -> tuple[int, int]:
    if edit.within is None:
        return 0, len(text)
    if edit.path.endswith(".py"):
        return _python_region(text, edit.within, edit.path)
    count = text.count(edit.within)
    if count != 1:
        raise NoLongerApplies(
            f"{edit.path}: the marker {edit.within!r} is there {count} times"
        )
    return text.index(edit.within), len(text)


def apply_edit(text: str, edit: Edit) -> str:
    start, end = region(text, edit)
    part = text[start:end]
    if edit.old is None:
        tail = "" if part.endswith("\n") or not part else "\n"
        changed = part + tail + edit.new
    else:
        count = part.count(edit.old)
        if count != 1:
            where = f"within {edit.within!r}" if edit.within else "in the file"
            raise NoLongerApplies(
                f"{edit.path}: the text to replace is there {count} times {where}, not once:"
                f" {edit.old[:70]!r}"
            )
        changed = part.replace(edit.old, edit.new, 1)
    result = text[:start] + changed + text[end:]
    if edit.path.endswith(".py"):
        try:
            ast.parse(result)
        except SyntaxError as error:
            raise NoLongerApplies(
                f"{edit.path}: the mutated file does not parse ({error})"
            )
    return result
