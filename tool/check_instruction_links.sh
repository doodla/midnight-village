#!/usr/bin/env bash
# Fails when an instruction file names a repo path or a `just` recipe that does
# not exist. Checked: the CLAUDE.md files, .claude/agents/*.md,
# docs/dev/status.md and docs/claude-architecture.md.
# A path is any backticked text with a "/" or a file extension (also the first
# word of a line in a code block); it may be relative to the repo root, to the
# file's own folder, to backend/, frontend/, frontend/lib/ or .claude/; text
# starting with "/" is an API path, not a file. A bare file name
# must exist somewhere in the repo. `just <recipe>` must be a recipe of the root,
# backend or frontend justfile. Run by `just check` and the commit gate.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

recipes=$(for j in justfile backend/justfile frontend/justfile; do
  just --justfile "$j" --summary 2>/dev/null
done | tr ' ' '\n' | sort -u)

files=(CLAUDE.md backend/CLAUDE.md frontend/CLAUDE.md docs/dev/status.md docs/claude-architecture.md .claude/agents/*.md)
[ $# -gt 0 ] && files=("$@")   # or the files given (used by the gate's tests)

RECIPES="$recipes" python3 - "${files[@]}" <<'EOF'
import os, re, subprocess, sys
from pathlib import Path

recipes = set(os.environ["RECIPES"].split())
known = subprocess.run(["git", "ls-files", "--cached", "--others", "--exclude-standard"],
                       capture_output=True, text=True, check=True).stdout.split("\n")
basenames = {Path(p).name for p in known if p}
EXT = re.compile(r"\.(md|py|dart|sh|json|toml|ya?ml|txt|tla|cfg|mjs|html|png|webp|lock)$")
SKIP = re.compile(r"[\s<>*{}$=@(),|]|://|^[-/~]|^\.\.\.|^\.\w+$")
bad = []

def path_ok(token, here):
    t = token.rstrip(".,:;")
    if "/" not in t:
        return t in basenames
    t = t.lstrip("/")
    for base in (Path("."), here, Path("backend"), Path("frontend"), Path("frontend/lib"), Path(".claude")):
        if (base / t).exists():
            return True
    return False

def check_path(token, f, n, here):
    if SKIP.search(token) or not ("/" in token or EXT.search(token.rstrip(".,:;"))):
        return
    if not path_ok(token, here):
        bad.append(f"{f}:{n}: path `{token}` does not exist")

def check_just(words, f, n):
    if len(words) > 1 and words[0] == "just" and words[1] not in recipes:
        if not words[1].startswith("-"):
            bad.append(f"{f}:{n}: `just {words[1]}` is not a recipe")

for f in sys.argv[1:]:
    here = Path(f).parent
    fenced = False
    for n, line in enumerate(Path(f).read_text().splitlines(), 1):
        if line.lstrip().startswith("```"):
            fenced = not fenced
            continue
        if fenced:
            words = line.split()
            if words:
                check_just(words, f, n)
                if words[0] != "just":
                    check_path(words[0], f, n, here)
            continue
        for token in re.findall(r"`([^`]+)`", line):
            words = token.split()
            if words and words[0] == "just":
                check_just(words, f, n)
            else:
                check_path(token, f, n, here)

if bad:
    print("\n".join(bad))
    sys.exit(1)
EOF
