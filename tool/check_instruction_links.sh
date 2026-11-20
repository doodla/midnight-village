#!/usr/bin/env bash
# Fails when an instruction file names a repo path or a `just` recipe that does
# not exist. Checked: the CLAUDE.md files, .claude/agents/*.md,
# docs/dev/status.md and docs/claude-architecture.md.
# A path is any backticked text with a "/" or a file extension (also the first
# word of a line in a code block); it may be relative to the repo root, to the
# file's own folder, to backend/, frontend/, frontend/lib/ or .claude/; text
# starting with "/" is an API path, not a file. A bare file name
# must exist somewhere in the repo. `just <recipe>` must be a recipe of the root,
# backend or frontend justfile. Gitignored paths count as existing (they are
# made locally, e.g. backend/.env). Run by `just check` and the commit gate.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

recipes=$(for j in justfile backend/justfile frontend/justfile; do
  just --justfile "$j" --summary 2>/dev/null
done | tr ' ' '\n' | sort -u)

files=(CLAUDE.md backend/CLAUDE.md frontend/CLAUDE.md docs/dev/status.md docs/dev/environment.md
  docs/claude-architecture.md docs/dev/models/README.md docs/dev/old-look-removal.md .claude/agents/*.md
  backend/apps/core/README.md backend/apps/onuw/README.md backend/tests/README.md
  frontend/lib/design_system/README.md frontend/lib/features/game/README.md
  frontend/test/README.md frontend/test/helpers/contract/README.md)
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

BASES = [Path(b) for b in (".", "backend", "backend/apps", "frontend", "frontend/lib",
                            "frontend/lib/features", "frontend/lib/design_system",
                            "frontend/test_e2e", ".claude")]

def path_ok(token, here):
    t = token.rstrip(".,:;")
    slash = "/" if t.endswith("/") else ""
    if "/" not in t:
        return t in basenames
    t = t.lstrip("/")
    bases = [*([] if here.is_absolute() else [here, *here.parents]), *BASES]
    if any((base / t).exists() for base in bases):
        return True
    # a gitignored path (backend/.env, build/...) may not exist in a fresh checkout
    return any(subprocess.run(["git", "check-ignore", "-q", "--no-index", str(base / t) + slash],
                              stderr=subprocess.DEVNULL).returncode == 0
               for base in bases)

def looks_like_path(token):
    t = token.rstrip(".,:;")
    last = t.rstrip("/").rsplit("/", 1)[-1]
    if "." in last and not t.endswith("/") and not EXT.search(t):
        return False  # module.attr or Class.member, not a file
    if "/" not in t and last[:1].isupper() and not last.split(".")[0].isupper():
        return False  # Space.md: a Dart member, not README.md
    return "/" in t or bool(EXT.search(t))

def check_path(token, f, n, here):
    if SKIP.search(token) or not looks_like_path(token):
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
