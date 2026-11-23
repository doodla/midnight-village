# Guard file: a change here needs its line in the pull request (tool/guard_edits.py).
"""The recorder of the last release's files (frontend/tool/record_release_assets.py) cannot
be used to regenerate the list over a removal: a file of the last release that is gone from
the bundle and has no dated "removedOnPurpose" line stops it (the removed picture an app left
open on the last release still asks for). Run with:
python3 -m unittest discover -s .claude/guardrails/tests
"""

import importlib.util
import json
import pathlib
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "frontend" / "tool" / "record_release_assets.py"


def load(frontend: pathlib.Path):
    spec = importlib.util.spec_from_file_location("record_release_assets", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.frontend = frontend
    module.target = frontend / "tool" / "release_assets.json"
    module.files_at_origin_main = lambda: None  # no git: the committed list alone
    return module


class RecorderRefusesAnUncoveredRemoval(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.frontend = pathlib.Path(self.tmp.name)
        (self.frontend / "tool").mkdir()
        (self.frontend / "assets").mkdir()
        for name in ("a.webp", "b.webp"):
            (self.frontend / "assets" / name).write_bytes(b"x")
        self.recorder = load(self.frontend)
        self.write(
            {"removedOnPurpose": {}, "files": ["assets/a.webp", "assets/b.webp"]}
        )

    def tearDown(self):
        self.tmp.cleanup()

    def write(self, data):
        self.recorder.target.write_text(json.dumps(data))

    def read(self):
        return json.loads(self.recorder.target.read_text())

    def test_nothing_removed_records(self):
        self.assertEqual(self.recorder.main(), 0)
        self.assertEqual(self.read()["files"], ["assets/a.webp", "assets/b.webp"])

    def test_a_removed_file_with_no_reason_is_refused_and_nothing_is_written(self):
        (self.frontend / "assets" / "b.webp").unlink()
        before = self.recorder.target.read_text()
        self.assertEqual(self.recorder.main(), 1)
        self.assertEqual(self.recorder.target.read_text(), before)

    def test_a_reason_without_a_date_is_not_a_reason(self):
        (self.frontend / "assets" / "b.webp").unlink()
        self.write(
            {
                "removedOnPurpose": {"assets/b.webp": "unused"},
                "files": ["assets/a.webp", "assets/b.webp"],
            }
        )
        self.assertEqual(self.recorder.main(), 1)

    def test_a_dated_reason_lets_it_record_and_is_kept(self):
        (self.frontend / "assets" / "b.webp").unlink()
        reason = "2026-11-24: nothing draws it"
        self.write(
            {
                "removedOnPurpose": {"assets/b.webp": reason},
                "files": ["assets/a.webp", "assets/b.webp"],
            }
        )
        self.assertEqual(self.recorder.main(), 0)
        self.assertEqual(self.read()["removedOnPurpose"], {"assets/b.webp": reason})
        self.assertEqual(self.read()["files"], ["assets/a.webp"])

    def test_a_file_gone_at_origin_main_is_refused_even_if_the_list_forgot_it(self):
        (self.frontend / "assets" / "b.webp").unlink()
        self.write({"removedOnPurpose": {}, "files": ["assets/a.webp"]})  # a blind edit
        self.recorder.files_at_origin_main = lambda: ["assets/a.webp", "assets/b.webp"]
        self.assertEqual(self.recorder.main(), 1)


if __name__ == "__main__":
    unittest.main()
