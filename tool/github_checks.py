#!/usr/bin/env python3
"""What GitHub requires before a merge, and how much of it a local run covered.

A piece twice reported "every check passed" and then failed GitHub's required checks:
the hand-over had run only what it could reach, and said so nowhere. This reads the
required checks from the workflow files and the ruleset, so the list cannot drift,
and says for each one whether this run covered it.

    tool/github_checks.py            the required checks and the `just` recipes each runs

A check is required when `docs/dev/main-ruleset.json` names it. Each is a job of a
workflow (a matrix job once for each value; a job that `needs` others also holds what
they run). The recipes a job runs are its steps that start with `just` (setup recipes,
and steps that run only after a failure, are not checks). Nothing here is listed by hand
except which local step stands for which recipe (`COVERS`), and a test holds that
every recipe it names exists.

No YAML library: the workflows are plain enough to read by indentation
(`guardrails/tests/test_workflows.py` reads them the same way).
"""

import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RULESET = "docs/dev/main-ruleset.json"
# Recipes that prepare a job and prove nothing.
SETUP = re.compile(r"^(install|.*-setup)$")
# A shell word that ends a recipe's arguments.
SHELL_END = re.compile(r"^(\||\|\||&&|;|>|>>|\d?>.*|2>&1|#.*)$")

# What a local step proves of a recipe GitHub runs: a step's recipe (or tool) -> the
# recipes it covers whole. A recipe a step only partly covers is in PARTLY. A frontend
# `just test` is every frontend test, the golden ones included, so it is `flutter-test`.
COVERS = {
    "flutter-test": {"flutter-test", "test-widgets", "flutter-test-golden"},
}
PARTLY = {
    # the nearest test files, or only the whole-lib scans: some of the widget tests
    "flutter test": {"test-widgets"},
    # every backend test without the coverage floor, or only the hook tests
    "test-fast": {"test"},
    "test-guardrails": {"test"},
    # only the states a change reaches, not every screen
    "piece_screens": {"screens"},
}


@dataclass
class Check:
    name: str
    recipes: list[tuple[str, tuple[str, ...]]] = field(default_factory=list)


def jobs_of(text: str) -> dict[str, str]:
    """{job id: its text}: the blocks one level under the top-level `jobs:`."""
    found = re.search(r"^jobs:\s*\n", text, re.M)
    body = text[found.end() :] if found else ""
    parts = re.split(r"^  ([A-Za-z0-9_-]+):\s*$", body, flags=re.M)
    return {parts[i]: parts[i + 1] for i in range(1, len(parts) - 1, 2)}


def matrix_of(text: str) -> tuple[str, list[str]] | None:
    found = re.search(r"^\s+(\w+):\s*\[(.*?)\]\s*$", text, re.M)
    in_matrix = re.search(r"^      matrix:\s*$", text, re.M)
    if not (found and in_matrix):
        return None
    return found.group(1), [v.strip() for v in found.group(2).split(",")]


def steps_of(text: str) -> list[str]:
    """The steps of a job, each its own text."""
    body = text.split("\n    steps:", 1)[-1] if "\n    steps:" in text else ""
    return [s for s in re.split(r"^      - ", body, flags=re.M)[1:]]


def folder_of(text: str) -> str:
    found = re.search(r"^\s+working-directory:\s*(\S+)", text, re.M)
    return found.group(1) if found else "."


def recipes_of(job: str, values: dict[str, str]) -> list[tuple[str, tuple[str, ...]]]:
    """The `just` recipes a job's steps run, with their arguments, when it runs on a pull
    request and nothing has failed yet. The recipe `test` in the frontend folder is the
    frontend's own, so it is named `flutter-test`."""
    found = []
    folder = folder_of(job)
    for step in steps_of(job):
        condition = re.search(r"^\s+if:\s*(.+)$", step, re.M)
        if condition and re.search(r"failure\(\)|always\(\)", condition.group(1)):
            continue  # runs after a failure, for the pictures: not a check
        for line in step.splitlines():
            code = line.split("#", 1)[0].strip()
            code = re.sub(r"^(run:\s*)?\|?\s*", "", code)
            if not code.startswith("just "):
                continue
            for key, value in values.items():
                code = re.sub(r"\$\{\{\s*matrix\." + key + r"\s*\}\}", value, code)
            words = []
            for word in code.split()[1:]:
                if SHELL_END.match(word):
                    break
                words.append(word)
            if not words or SETUP.match(words[0]):
                continue
            name = (
                "flutter-test"
                if (folder, words[0]) == ("frontend", "test")
                else words[0]
            )
            found.append((name, tuple(words[1:])))
    return found


def job_name(text: str) -> str:
    found = re.search(r"^    name:\s*(.+?)\s*$", text, re.M)
    return found.group(1) if found else ""


def required_names(root: Path = ROOT) -> list[str]:
    ruleset = json.loads((root / RULESET).read_text())
    for rule in ruleset["rules"]:
        if rule["type"] == "required_status_checks":
            return [c["context"] for c in rule["parameters"]["required_status_checks"]]
    return []


def required_checks(root: Path = ROOT) -> list[Check]:
    """The required checks, in the ruleset's order, each with what it runs."""
    by_name: dict[str, Check] = {}
    for workflow in sorted((root / ".github" / "workflows").glob("*.yml")):
        jobs = jobs_of(workflow.read_text())
        needed = {}  # a job -> the jobs it needs
        for job_id, text in jobs.items():
            needs = re.search(r"^    needs:\s*\[([^\]]*)\]", text, re.M)
            needed[job_id] = (
                [n.strip() for n in needs.group(1).split(",")] if needs else []
            )
        parts = {part for needs in needed.values() for part in needs}

        def expansions(job_id: str):
            """(check name, recipes) for each value of the job's matrix, once if none."""
            text = jobs[job_id]
            matrix = matrix_of(text)
            for value in matrix[1] if matrix else [None]:
                values = {matrix[0]: value} if matrix else {}
                name = job_name(text)
                for key, v in values.items():
                    name = re.sub(r"\$\{\{\s*matrix\." + key + r"\s*\}\}", v, name)
                yield name, recipes_of(text, values)

        for job_id in jobs:
            if job_id in parts:
                continue  # a part of another job's check
            if matrix_of(jobs[job_id]):
                # one check for each value of a matrix named by it ("Screens strict at 360")
                for name, recipes in expansions(job_id):
                    by_name[name] = Check(name, recipes)
                continue
            check = Check(job_name(jobs[job_id]), recipes_of(jobs[job_id], {}))
            for part in needed[job_id]:
                for _, recipes in expansions(part):
                    check.recipes += recipes
            by_name[check.name] = check
    return [by_name[n] for n in required_names(root) if n in by_name]


def step_keys(folder: str, command: list[str]) -> tuple[set[str], set[str]]:
    """(recipes this local step covers whole, recipes it covers in part)."""
    if command[:1] == ["just"] and len(command) > 1:
        name = command[1]
        if (folder, name) == ("frontend", "test"):
            name = "flutter-test"
        return COVERS.get(name, {name}), PARTLY.get(name, set())
    if command[:2] == ["flutter", "test"]:
        return set(), PARTLY["flutter test"]
    if any(Path(word).stem == "piece_screens" for word in command[:3]):
        return set(), PARTLY["piece_screens"]
    return set(), set()


def judge(checks: list[Check], results: list[dict]) -> list[dict]:
    """For each required check: `state` is "passed" (every recipe of it was run here, and
    passed), "FAILED" (a step that covers it failed), "partly" (some of it was run and
    passed) or "NOT run here"; `ran` and `not_run` name the recipes. `results` are the
    hand-over's steps: {"folder", "command", "ok"}."""
    rows = []
    for check in checks:
        whole, part, failed = set(), set(), set()
        for result in results:
            full, some = step_keys(result.get("folder", "."), result["command"])
            hit = full | some
            if not result["ok"]:
                failed |= {name for name, _ in check.recipes if name in hit}
            else:
                whole |= full
                part |= some
        ran, missing = [], []
        for name, args in check.recipes:
            label = " ".join(("just", name, *args))
            if name in failed:
                continue
            (ran if name in whole else missing).append(label)
        partial = [label for label in missing if label.split()[1] in part]
        if failed:
            state = "FAILED"
        elif check.recipes and not missing:
            state = "passed"
        elif ran or partial:
            state = "partly"
        else:
            state = "NOT run here"
        rows.append(
            {
                "name": check.name,
                "state": state,
                "ran": ran,
                "partial": partial,
                "not_run": [m for m in missing if m not in partial],
                "failed": sorted(failed),
            }
        )
    return rows


def headline(rows: list[dict], everything_passed: bool) -> str:
    """The first line of a hand-over: READY only when what ran passed, and never silent
    about how much of GitHub's wall that is."""
    here = sum(1 for r in rows if r["state"] == "passed")
    ran = f"{here} of {len(rows)} of GitHub's checks run here"
    if everything_passed and not any(r["state"] == "FAILED" for r in rows):
        return f"READY ({ran})"
    return f"NOT READY ({ran})"


def table(rows: list[dict]) -> list[str]:
    """The checks as a Markdown table: what GitHub requires and what ran here."""
    out = ["| GitHub's required check | Run here | What |", "|---|---|---|"]
    for r in rows:
        parts = []
        if r["ran"]:
            parts.append("ran " + ", ".join(f"`{x}`" for x in r["ran"]))
        if r["partial"]:
            parts.append("only part of " + ", ".join(f"`{x}`" for x in r["partial"]))
        if r["failed"]:
            parts.append("failed " + ", ".join(f"`{x}`" for x in r["failed"]))
        if r["not_run"] and r["state"] != "NOT run here":
            parts.append("not run " + ", ".join(f"`{x}`" for x in r["not_run"]))
        if r["state"] == "NOT run here":
            parts.append(
                "only GitHub runs " + ", ".join(f"`{x}`" for x in r["not_run"])
            )
        shown = {"passed": "passed", "FAILED": "**FAILED**"}.get(r["state"], r["state"])
        out.append(f"| {r['name']} | {shown} | {'; '.join(parts)} |")
    return out


def main(argv: list[str]) -> int:
    for check in required_checks():
        print(check.name)
        for name, args in check.recipes:
            print("   just", name, *args)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
