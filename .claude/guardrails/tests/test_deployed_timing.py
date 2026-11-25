"""tool/deployed_timing.py: the latency leg's arithmetic and its table. (The leg
itself runs against a real server in backend/tests/core/test_deployed_sockets.py.)"""

import importlib.util
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location("deployed_timing", ROOT / "tool" / "deployed_timing.py")
timing = importlib.util.module_from_spec(spec)
spec.loader.exec_module(timing)


class Header(unittest.TestCase):
    def test_the_servers_header_is_read_part_by_part(self):
        self.assertEqual(timing.parts("connect;dur=26.2, total;dur=50"), {"connect": 26.2, "total": 50.0})

    def test_an_answer_that_made_no_connection_has_no_connect(self):
        self.assertEqual(timing.parts("total;dur=0"), {"total": 0.0})

    def test_no_header_is_nothing(self):
        self.assertEqual(timing.parts(None), {})
        self.assertEqual(timing.parts(""), {})


class Rows(unittest.TestCase):
    def setUp(self):
        self.t = timing.Timings()
        # the first opened its connection (a handshake); the rest reused it
        self.t.add("read the table", 0.400, "connect;dur=30, total;dur=100", True)
        for seconds, header in ((0.080, "connect;dur=20, total;dur=50"), (0.120, "total;dur=50"), (0.100, "connect;dur=40, total;dur=150")):
            self.t.add("read the table", seconds, header, False)
        self.t.add("deal", 0.300, None, False)

    def test_the_handshake_is_kept_out_of_the_median_and_the_worst(self):
        (row,) = [r for r in self.t.rows() if r["kind"] == "read the table"]
        self.assertEqual((row["count"], row["first_ms"]), (4, 400))
        self.assertEqual((row["median_ms"], row["worst_ms"]), (100, 120))
        self.assertEqual(row["with_handshake_ms"], 400)

    def test_connect_counts_only_the_answers_that_made_a_connection(self):
        (row,) = [r for r in self.t.rows() if r["kind"] == "read the table"]
        self.assertEqual((row["connects"], row["connect_median"], row["connect_worst"]), (3, 30, 40))
        self.assertEqual((row["server_total_median"], row["server_total_worst"]), (75, 150))

    def test_an_answer_with_no_header_says_so_and_does_not_break_the_table(self):
        table = self.t.table()
        self.assertIn("| deal | 1 | 300 | 300 | 300 |  | no header | none made |", table)
        self.assertIn("| read the table | 4 | 400 | 100 | 120 | 400 | 75 / 150 | 30.0 / 40.0 of 3 |", table)

    def test_the_socket_delays_are_listed_under_the_table(self):
        self.t.add_heard("game_started", 0.37)
        self.t.add_heard("game_started", 0.371)
        self.assertIn("| game_started | 370, 371 ", self.t.table())

    def test_the_json_holds_the_rows_and_every_request(self):
        said = json.loads(self.t.as_json(commit="abc"))
        self.assertEqual(said["commit"], "abc")
        self.assertEqual(len(said["requests"]["read the table"]), 4)
        self.assertEqual([r["kind"] for r in said["rows"]], ["read the table", "deal"])


class Compared(unittest.TestCase):
    def run_of(self, connects, commit):
        t = timing.Timings()
        t.add("read the table", 0.3, None, True)
        for header in connects:
            t.add("read the table", 0.150 if header else 0.120, header or "total;dur=50", False)
        t.add_heard("game_started", 0.309 if commit == "old" else 0.25)
        return json.loads(t.as_json(commit=commit))

    def test_two_runs_are_set_side_by_side(self):
        before = self.run_of(["connect;dur=23, total;dur=50"] * 3, "old")
        after = self.run_of([None, None, None], "new")
        after["rows"].append({**after["rows"][0], "kind": "a new request"})

        table = timing.compared(before, after)

        self.assertIn("Before: old. After: new.", table)
        self.assertIn("| read the table | 150 -> 120 | 150 -> 120 | 50 -> 50 | 23.0 on 3 of 4 -> none of 4 |", table)
        # a kind only one run has is still a row
        self.assertIn("| a new request | - -> 120 ", table)
        self.assertIn("| game_started | 309 -> 250 |", table)

    def test_the_command_reads_two_files(self):
        import subprocess
        import sys
        import tempfile

        with tempfile.TemporaryDirectory() as d:
            for name in ("a", "b"):
                Path(d, f"{name}.json").write_text(json.dumps(self.run_of([None], name)))
            ran = subprocess.run(
                [sys.executable, str(ROOT / "tool" / "deployed_timing.py"), "compare", f"{d}/a.json", f"{d}/b.json"],
                capture_output=True,
                text=True,
            )
        self.assertEqual(ran.returncode, 0, ran.stderr)
        self.assertIn("Before: a. After: b.", ran.stdout)


if __name__ == "__main__":
    unittest.main()
