#!/usr/bin/env python3
"""What failed, in a few lines, as the LAST thing a red test run prints.

A red job used to end in "4022 passed, 1 failed" with the test's name thousands
of lines up, or under a dump of the database's own log. Whoever was woken by the
red check had to dig for the name. This reads the run's machine report and
prints each failed test: its file, its name, and the first line of its error.

    tool/failed_tests.py flutter <report.jsonl>   `flutter test --file-reporter json:<file>`
    tool/failed_tests.py junit <report.xml>       `pytest --junitxml=<file>`

On GitHub it also writes one error annotation per failed test, so the check's
own page (and its API) names them. It always exits 0: it reports, the test run
decides. A report that is missing or unreadable is said, never an error.
"""

import json
import os
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

MOST = 40


def first_line(text: str, lines: int = 1) -> str:
    """The first lines that say something (not a frame of dashes or a blank)."""
    kept = []
    for line in (text or "").splitlines():
        line = line.strip()
        if line and not set(line) <= set("=-_*═│┄─ "):
            kept.append(line)
            if len(kept) == lines:
                break
    return "  ".join(kept)[:300]


def flutter(report: Path) -> list[tuple[str, str, str]]:
    """[(file, test name, first error line)] from a `flutter test` json report."""
    tests: dict[int, dict] = {}
    errors: dict[int, str] = {}
    failed: list[int] = []
    prints: dict[int, list[str]] = {}
    for raw in report.read_text(errors="replace").splitlines():
        try:
            event = json.loads(raw)
        except ValueError:
            continue
        if not isinstance(event, dict):
            continue
        kind = event.get("type")
        if kind == "testStart":
            tests[event["test"]["id"]] = event["test"]
        elif kind == "error":
            errors.setdefault(event["testID"], event.get("error", ""))
        elif kind == "print":
            prints.setdefault(event.get("testID"), []).append(event.get("message", ""))
        elif kind == "testDone" and event.get("result") in ("failure", "error"):
            failed.append(event["testID"])
    found = []
    for test_id in failed:
        test = tests.get(test_id, {})
        where = (test.get("root_url") or test.get("url") or "").split("/frontend/")[-1]
        where = where.removeprefix("file://")
        line = test.get("root_line") or test.get("line")
        found.append(
            (
                f"{where}:{line}" if line else where,
                test.get("name", "?"),
                thrown("\n".join(prints.get(test_id, [])))
                or expected(errors.get(test_id, "")),
            )
        )
    return found


def expected(error: str) -> str:
    """A failed expectation in a line: its first two lines, and for a value
    too long to say there (a map, a list) the matcher's own "Which:" line,
    which is the one that names the difference."""
    said = first_line(error, lines=2)
    which = next(
        (line.strip() for line in error.splitlines() if line.strip().startswith("Which:")),
        "",
    )
    return f"{said}  {which}"[:300] if which and which not in said else said


def thrown(printed: str) -> str:
    """What a widget test threw: Flutter prints it in a box, and the error
    event then says only "Test failed. See exception logs above."."""
    lines = printed.splitlines()
    for i, line in enumerate(lines):
        if line.startswith("The following") and "thrown" in line:
            return " ".join([line.strip(), first_line("\n".join(lines[i + 1 :]))])[:300]
    return ""


def junit(report: Path) -> list[tuple[str, str, str]]:
    """[(file, test name, first error line)] from a junit xml report (pytest's)."""
    found = []
    for case in ET.parse(report).getroot().iter("testcase"):
        for problem in [*case.findall("failure"), *case.findall("error")]:
            where = case.get("classname", "").replace(".", "/")
            found.append(
                (
                    case.get("file") or f"{where}.py",
                    case.get("name", "?"),
                    first_line(problem.get("message") or problem.text or ""),
                )
            )
            break
    return found


def said(failures: list[tuple[str, str, str]], on_github: bool) -> str:
    """The lines to print: empty when nothing failed."""
    if not failures:
        return ""
    out = ["", f"WHAT FAILED ({len(failures)}):"]
    for where, name, why in failures[:MOST]:
        out.append(f"  {where}")
        out.append(f"    {name}")
        if why:
            out.append(f"    {why}")
    if len(failures) > MOST:
        out.append(f"  ... and {len(failures) - MOST} more")
    if on_github:
        for where, name, why in failures[:MOST]:
            # an annotation is one line: its own separators are escaped
            text = f"{name}: {why}".replace("%", "%25").replace("\n", " ")
            title = where.replace(",", " ").replace("::", " ")
            out.append(f"::error title={title}::{text}")
    return "\n".join(out)


def main(argv: list[str]) -> int:
    if len(argv) != 2 or argv[0] not in ("flutter", "junit"):
        print(__doc__, file=sys.stderr)
        return 2
    report = Path(argv[1])
    if not report.is_file():
        print(
            f"\nWHAT FAILED: no report at {report} (the run stopped before it wrote one)."
        )
        return 0
    try:
        failures = (flutter if argv[0] == "flutter" else junit)(report)
    except (ET.ParseError, KeyError, OSError) as error:
        print(f"\nWHAT FAILED: the report at {report} could not be read ({error}).")
        return 0
    text = said(failures, os.environ.get("GITHUB_ACTIONS") == "true")
    if text:
        print(text)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
