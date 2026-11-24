"""frontend/tool/web_build_cached.sh: a web build is built once, and again only
when what goes into it changed. Held with a stand-in for the build (a real one
takes a minute), in a copy of the tool beside made-up sources."""

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
TOOL = ROOT / "frontend" / "tool" / "web_build_cached.sh"

# the stand-in: writes what it was asked to build, and counts its runs
BUILD = """#!/bin/sh
out="$1"; shift
mkdir -p "$out"
echo "$@" > "$out/args.txt"
cat lib/main.dart > "$out/main.txt"
echo run >> "$COUNT"
"""


class WebBuildCached(unittest.TestCase):
    def setUp(self):
        self.dir = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.dir, ignore_errors=True)
        front = self.dir / "frontend"
        (front / "tool").mkdir(parents=True)
        (front / "lib").mkdir()
        shutil.copy(TOOL, front / "tool" / "web_build_cached.sh")
        (front / "lib" / "main.dart").write_text("one\n")
        (front / "pubspec.yaml").write_text("name: x\n")
        build = self.dir / "build.sh"
        build.write_text(BUILD)
        build.chmod(0o755)
        self.front = front
        self.count = self.dir / "count"
        self.env = {
            **os.environ,
            "WEB_BUILD_COMMAND": str(build),
            "COUNT": str(self.count),
        }

    def built(self, *args, ok=True):
        run = subprocess.run(
            [str(self.front / "tool" / "web_build_cached.sh"), *args],
            capture_output=True,
            text=True,
            env=self.env,
            cwd=self.dir,
        )
        if ok:
            self.assertEqual(run.returncode, 0, run.stderr)
        return run

    def runs(self):
        return len(self.count.read_text().split()) if self.count.exists() else 0

    def test_the_same_sources_and_arguments_are_built_once(self):
        first = self.built("--release").stdout.strip()
        second = self.built("--release").stdout.strip()

        self.assertEqual(first, second)
        self.assertEqual(self.runs(), 1)
        self.assertEqual((Path(first) / "main.txt").read_text(), "one\n")

    def test_stdout_is_the_folder_and_nothing_else(self):
        out = self.built("--release").stdout

        self.assertEqual(len(out.strip().splitlines()), 1)
        self.assertTrue(Path(out.strip()).is_dir())

    def test_a_changed_source_is_built_again_and_the_old_build_is_still_there(self):
        first = self.built("--release").stdout.strip()
        (self.front / "lib" / "main.dart").write_text("two\n")
        second = self.built("--release").stdout.strip()

        self.assertNotEqual(first, second)
        self.assertEqual((Path(second) / "main.txt").read_text(), "two\n")
        # back to the first sources: its build is used, not made again
        (self.front / "lib" / "main.dart").write_text("one\n")
        self.assertEqual(self.built("--release").stdout.strip(), first)
        self.assertEqual(self.runs(), 2)

    def test_other_arguments_are_another_build(self):
        plain = self.built("--release").stdout.strip()
        ring = self.built("--release", "--dart-define=RING=true").stdout.strip()

        self.assertNotEqual(plain, ring)
        self.assertIn("RING=true", (Path(ring) / "args.txt").read_text())

    def test_a_build_that_fails_leaves_nothing_to_be_used(self):
        self.env["WEB_BUILD_COMMAND"] = "false"
        failed = self.built("--release", ok=False)

        self.assertNotEqual(failed.returncode, 0)
        self.assertEqual(failed.stdout.strip(), "")
        cache = self.front / "build" / "web_cache"
        self.assertEqual([p for p in cache.glob("*") if p.is_dir()], [])

    def test_only_the_newest_few_builds_are_kept(self):
        for n in range(6):
            (self.front / "lib" / "main.dart").write_text(f"{n}\n")
            last = self.built("--release").stdout.strip()

        kept = list((self.front / "build" / "web_cache").glob("*/.built"))
        self.assertEqual(len(kept), 4)
        self.assertTrue(Path(last).is_dir())

    def test_an_output_folder_of_the_callers_is_refused(self):
        refused = self.built("--release", "--output", "x", ok=False)

        self.assertEqual(refused.returncode, 2)
        self.assertEqual(self.runs(), 0)


if __name__ == "__main__":
    unittest.main()
