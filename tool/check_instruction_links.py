#!/usr/bin/env python3
"""Fails when an instruction file names a path, a section or a recipe that is not there.

Every tracked Markdown file is an instruction to someone (third-party skills under
.claude/skills/ are left out: tool/skills.py), and so is frontend/dart_test.yaml.
In each, a path is backticked text with a "/" or a file extension (also the first
word of a line in a code block); text starting with "/" is an API path. In prose, a
word without backticks that starts with one of the repo's top folders and a slash
(`docs/dev/x.md`) is a path too; `a/.../b` stands for any and is not checked.

- A path is read where the document says: from the repo root, or from the
  document's own folder (`./x`, `../x` and Markdown links too). Not from any other
  folder: `docs/app-rules.md` in frontend/CLAUDE.md is not frontend/docs/app-rules.md.
  A contract sample may be named as `http/game/me_voting` (contract_samples/...json).
- A bare file name is in the document's folder, or names exactly one file in the repo.
- A section named after a path (`` `x.md`, "Section" `` or `` `x.md` ("Section") ``)
  must be the start of one of that file's headings.
- `just <recipe>` must be a recipe of the root, backend or frontend justfile.

Gitignored paths count (made locally, e.g. backend/.env). Run by `just check` (the
working tree) and the commit gate with --staged (the staged text, against the index).
`--fix` rewrites a path that names one file from somewhere else to its path from the
repo root, when there is exactly one such file.

usage: tool/check_instruction_links.py [--staged] [--fix] [file...]
"""

import os
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import skills

ROOT = Path(__file__).resolve().parents[1]
EXT = re.compile(
    r"\.(md|py|dart|sh|json|toml|ya?ml|txt|tla|cfg|mjs|cjs|html|png|webp|jpg|lock)$"
)
SKIP = re.compile(
    r"[\s<>*{}$=@(),|]|://|^[-~]|^\.\.\.|^\.\w+$|^(text|application|image)/\w"
)
# Where a path that does not resolve is looked for, only to offer the fix.
ELSEWHERE = [
    "backend",
    "backend/apps",
    "frontend",
    "frontend/lib",
    "frontend/lib/features",
    "frontend/lib/design_system",
    "frontend/test_e2e",
    ".claude",
]
SECTION = re.compile(r'`([^`]+\.md)`(?:,| \()\s*"([^"]+)"')
LINK = re.compile(r"\]\(([^)#\s]+)(?:#[^)]*)?\)")


def git(*args: str) -> str:
    return subprocess.run(
        ["git", "-C", str(ROOT), *args], capture_output=True, text=True
    ).stdout


class Tree:
    def __init__(self, staged: bool):
        self.staged = staged
        listing = ["ls-files", "--cached"] + (
            [] if staged else ["--others", "--exclude-standard"]
        )
        self.files = {p for p in git(*listing).split("\n") if p}
        self.dirs = {str(parent) for p in self.files for parent in Path(p).parents}
        self.tops = {p.split("/", 1)[0] for p in self.files if "/" in p}
        self.by_name: dict[str, list[str]] = {}
        self.ignored: dict[str, bool] = {}
        for p in self.files:
            self.by_name.setdefault(Path(p).name, []).append(p)

    def exists(self, path: str, ignored: bool = True) -> bool:
        """`path` is a file or folder of the tree, or (when `ignored`) one git ignores."""
        p = os.path.normpath(path)
        if p in self.files or p in self.dirs:
            return True
        if not self.staged and (ROOT / p).exists():
            return True
        if ignored and p not in self.ignored:
            self.ignored[p] = (
                subprocess.run(
                    ["git", "-C", str(ROOT), "check-ignore", "--no-index", p, p + "/"],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                ).returncode
                == 0
            )
        return ignored and self.ignored[p]

    def text(self, path: str) -> str:
        if not self.staged:
            return (
                (ROOT / path).read_text(errors="replace")
                if (ROOT / path).is_file()
                else ""
            )
        return git("show", f":{path}")


def instruction_files(tree: Tree) -> list[str]:
    def read(path: str) -> str | None:
        return tree.text(path) if path in tree.files else None

    found = [
        p
        for p in tree.files
        if (p.endswith(".md") and not p.startswith(skills.SKILLS))
        or p == "frontend/dart_test.yaml"
    ]
    return sorted(found + skills.ours(sorted(tree.files), read))


def looks_like_path(token: str) -> bool:
    t = token.rstrip(".,:;")
    last = t.rstrip("/").rsplit("/", 1)[-1]
    if "." in last and not t.endswith("/") and not EXT.search(t):
        return False  # module.attr or Class.member, not a file
    if "/" not in t and last[:1].isupper() and not last.split(".")[0].isupper():
        return False  # Space.md: a Dart member, not README.md
    return "/" in t or bool(EXT.search(t))


def bare_paths(line: str, tree: Tree) -> list[str]:
    """Paths written in prose without backticks: a word that starts with one of the
    repo's top folders and a slash (`docs/dev/x.md`, not `origin/main`)."""
    prose = re.sub(r"`[^`]*`|\]\([^)]*\)|\S+://\S+", " ", line)
    tops = tree.tops
    return [
        m.rstrip(".,:;)")
        for m in re.findall(r"(?<![\w./`-])([\w.-]+/[\w./-]+)", prose)
        if m.split("/", 1)[0] in tops and "/..." not in m  # `a/.../b` stands for any
    ]


def resolve(token: str, here: str, tree: Tree) -> bool:
    t = token.rstrip(".,:;")
    if t.startswith("/"):
        return True  # an API path
    if "/" not in t.rstrip("/"):
        # in the document's folder or below it, or one file of that name in the repo
        under = [
            p
            for p in tree.by_name.get(t.rstrip("/"), [])
            if p.startswith(here + "/") or not here
        ]
        return (
            tree.exists(os.path.join(here, t))
            or tree.exists(t)
            or bool(under)
            or len(tree.by_name.get(t, [])) == 1
        )
    if tree.exists(f"contract_samples/{t}.json"):
        return True
    # a path with a folder in it is read from the root; only ./ and ../ from the document
    if t.startswith(("./", "../")):
        return tree.exists(os.path.join(here, t))
    return tree.exists(t)


def suggestion(token: str, here: str, tree: Tree) -> str | None:
    t = token.rstrip(".,:;")
    found = {
        os.path.normpath(os.path.join(base, t))
        for base in [here, *ELSEWHERE, *Path(here).parents]
        if tree.exists(os.path.join(base, t), ignored=False)
    }
    if not found and "/" in t:
        found = {
            p for p in tree.by_name.get(Path(t).name, []) if p.endswith(t.lstrip("./"))
        }
    return found.pop() if len(found) == 1 else None


def headings(text: str) -> list[str]:
    return [
        line.lstrip("#").strip().strip("`")
        for line in text.splitlines()
        if line.startswith("#")
    ]


def check(files: list[str], tree: Tree, recipes: set[str], fix: bool) -> list[str]:
    bad = []
    for f in files:
        here = str(Path(f).parent) if "/" in f else ""
        lines = tree.text(f).splitlines()
        changed, fenced = False, False
        for n, line in enumerate(lines, 1):
            if line.lstrip().startswith("```"):
                fenced = not fenced
                continue
            words = line.split()
            tokens = (
                ([words[0]] if words and words[0] != "just" else [])
                if fenced
                else re.findall(r"`([^`]+)`", line)
            )
            justs = (
                [words]
                if fenced
                else [t.split() for t in re.findall(r"`([^`]+)`", line)]
            )
            for w in justs:
                if (
                    len(w) > 1
                    and w[0] == "just"
                    and w[1] not in recipes
                    and not w[1].startswith("-")
                ):
                    bad.append(
                        f"{f}:{n}: `just {w[1]}` is not a recipe. Fix: `just --list` names them"
                    )
            tokens += (
                []
                if fenced
                else [
                    m if m.startswith((".", "/")) else "./" + m
                    for m in LINK.findall(line)
                    if "://" not in m
                ]  # a Markdown link is relative
            )
            bare = [] if fenced else bare_paths(line, tree)
            for token in tokens + bare:
                if (
                    token.split()[0] == "just"
                    or SKIP.search(token)
                    or not looks_like_path(token)
                ):
                    continue
                if resolve(token, here, tree):
                    continue
                better = suggestion(token, here, tree)
                if fix and better:
                    was = f"`{token}`" if token not in bare else token
                    lines[n - 1] = line = line.replace(
                        was, f"`{better}`" if token not in bare else better
                    )
                    changed = True
                    continue
                hint = (
                    f" Fix: did you mean `{better}`? (tool/check_instruction_links.py --fix)"
                    if better
                    else ""
                )
                bad.append(
                    f"{f}:{n}: path `{token}` does not exist from the repo root or {here or '.'}/.{hint}"
                )
            for path, name in [] if fenced else SECTION.findall(line):
                target = path if tree.exists(path) else os.path.join(here, path)
                if not tree.exists(target):
                    continue
                if not any(
                    h.startswith(name)
                    for h in headings(tree.text(os.path.normpath(target)))
                ):
                    bad.append(
                        f'{f}:{n}: `{path}` has no section "{name}". Fix: name a heading it has'
                    )
        if changed:
            (ROOT / f).write_text("\n".join(lines) + "\n")
            print(f"links: rewrote paths in {f}")
    return bad


def recipe_names(staged: bool) -> set[str]:
    names = set()
    for j in ("justfile", "backend/justfile", "frontend/justfile"):
        src = ROOT / j
        if staged:
            tmp = (
                Path(os.environ.get("TMPDIR", "/tmp"))
                / f"links_{os.getpid()}_{j.replace('/', '_')}"
            )
            tmp.write_text(git("show", f":{j}"))
            src = tmp
        out = subprocess.run(
            [
                "just",
                "--justfile",
                str(src),
                "--working-directory",
                str(ROOT),
                "--summary",
            ],
            capture_output=True,
            text=True,
        ).stdout
        names |= set(out.split())
        if staged:
            src.unlink()
    return names


def main(argv: list[str]) -> int:
    staged, fix = "--staged" in argv, "--fix" in argv
    named = [a for a in argv if not a.startswith("--")]
    tree = Tree(staged)
    files = named or instruction_files(tree)
    bad = check(files, tree, recipe_names(staged), fix and not staged)
    for line in bad:
        print(line)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
