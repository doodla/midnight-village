# Guard file: a change here needs its line in the pull request (tool/guard_edits.py).
"""What a break's run proved (tool/prove_guards.py): killed, survived, or broken.

A break is killed only when a NAMED killer test fails an assertion, and (backend) the
failure says what the break names (`expect=`: the words of the promise's own assertion,
"learns" for the two-deal test). Anything else that ends a run non-zero proves nothing and
is "broken", which fails `just prove-guards` with its own message: an import or
collection error, a test that errors rather than fails, a crash inside the code under test
(an ImportError raised by a lazily loaded module, a 500), a script that could not play
(the two-deal test's `ScriptError`: a scripted move refused, a case whose games did not
differ), a failure that is not the one named, a command that cannot start or fails without
printing what its guard prints, a Flutter file that does not compile.

Each function returns (status, the killer files that failed, why).
"""

from __future__ import annotations

import re
import xml.etree.ElementTree as ElementTree
from pathlib import Path

# The first words of a failure that is a test's own judgement, not a crash.
JUDGED = re.compile(r"^(AssertionError\b|assert\b|Failed: |E\s+assert\b)")
CRASH = re.compile(
    r"^(ImportError|ModuleNotFoundError|NameError|SyntaxError|IndentationError)\b"
)
# The two-deal test's own failure to play (backend/tests/privacy/two_deals.py).
SCRIPT = "ScriptError"
UNITTEST_FAIL = re.compile(r"^FAIL: \w+ \(([\w.]+)\)", re.M)
UNITTEST_SUMMARY = re.compile(r"^FAILED \(([^)]*)\)", re.M)
FLUTTER_UNBUILT = ("Failed to load", "Compilation failed", "Error: Could not resolve")
FLUTTER_JUDGED = ("Expected:", "TestFailure")


def module_of(path: str) -> str:
    """`backend/tests/privacy/test_x.py` -> `tests.privacy.test_x` (pytest's classname)."""
    return ".".join(Path(path.removeprefix("backend/")).with_suffix("").parts)


def backend(code: int, junit: str | None, killers: list[str], expect: str = ""):
    if code == 0:
        return "survived", set(), ""
    if code != 1 or not junit:
        return "broken", set(), f"pytest ended with {code}: no test failed an assertion"
    failed: set[str] = set()
    for case in ElementTree.fromstring(junit).iter("testcase"):
        where = case.get("classname", "")
        for kind in ("error", "failure"):
            for node in case.iter(kind):
                message = (node.get("message") or "").strip()
                said = message + "\n" + (node.text or "")
                test = f"{where}::{case.get('name')}"
                if kind == "error":
                    return (
                        "broken",
                        set(),
                        f"{test} errored, it did not fail: {message[:120]}",
                    )
                if SCRIPT in said:
                    return (
                        "broken",
                        set(),
                        f"{test}: the script could not play, which is not the comparison"
                        f" failing: {message[:160]}",
                    )
                if CRASH.match(message) or not JUDGED.match(message):
                    return (
                        "broken",
                        set(),
                        f"{test} crashed, it did not judge: {message[:120]}",
                    )
                if expect and expect not in said:
                    return (
                        "broken",
                        set(),
                        f"{test} failed, but not as the break names ({expect!r}):"
                        f" {message[:160]}",
                    )
                failed |= {
                    k
                    for k in killers
                    if where == module_of(k) or where.startswith(module_of(k) + ".")
                }
    if not failed:
        return "broken", set(), "no test of a named killer failed"
    return "killed", failed, ""


def guardrails(code: int, output: str, killer: str):
    if code == 0:
        return "survived", set(), ""
    summary = UNITTEST_SUMMARY.search(output)
    if summary is None or "errors=" in summary.group(1):
        return (
            "broken",
            set(),
            f"unittest: {summary.group(0) if summary else 'no summary'}",
        )
    stem = Path(killer).stem
    if not any(name.split(".")[0] == stem for name in UNITTEST_FAIL.findall(output)):
        return "broken", set(), f"no test of {killer} failed"
    return "killed", {killer}, ""


def flutter(code: int, output: str, killer: str):
    if code == 0:
        return "survived", set(), ""
    if any(mark in output for mark in FLUTTER_UNBUILT):
        return "broken", set(), "the test file did not build"
    if not any(mark in output for mark in FLUTTER_JUDGED):
        return "broken", set(), "no expectation failed"
    return "killed", {killer}, ""


def command(code: int, output: str, expect: str, killer: str):
    if code == 0:
        return "survived", set(), ""
    if not expect or expect not in output:
        return (
            "broken",
            set(),
            f"the command failed without saying {expect!r} (exit {code})",
        )
    return "killed", {killer}, ""
