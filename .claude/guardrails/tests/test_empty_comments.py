"""tool/empty_comments.py: a comment is deleted unattended only when code proves it says
nothing, and never when it carries a rule word.

The three fixtures in ThreeRealRules are the comments haiku sorters marked "delete" on
PR #208 that each carried a rule no name says: none of them may be provably empty.

Run with: python3 -m unittest discover -s .claude/guardrails/tests
"""

import importlib.util
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]


def load():
    spec = importlib.util.spec_from_file_location(
        "empty_comments", REPO / "tool" / "empty_comments.py"
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


TOOL = load()


def judge(path, lines, start=1, end=None, kept=()):
    return TOOL.provably_empty(path, lines, start, end or start, set(kept))


class ThreeRealRules(unittest.TestCase):
    def test_own_view_messages_each_on_their_own_group_after_the_commit(self):
        lines = [
            "def own_view_messages(game_id: Any) -> Messages:",
            '    """Every person\'s own view of ``game_id`` as it is now (committed), each on',
            '    their own group."""',
            "    return stage_batch(game_id, [])[0]",
        ]
        self.assertIsNone(judge("backend/apps/onuw/own_view.py", lines, 2, 3))

    def test_the_watchdogs_null_meaning(self):
        lines = [
            "  /// The silence watchdog, due in [due] (none: no beat known, or paused).",
            "  void _watch(Duration? due) {",
        ]
        self.assertIsNone(judge("reconnecting_websocket.dart", lines))

    def test_the_rule_that_forgets_the_beat(self):
        lines = [
            "  /// A connection that was open is over: one that heard no beat at all",
            "  /// counts toward forgetting the beat.",
            "  void _connectionOver() {",
        ]
        self.assertIsNone(judge("reconnecting_websocket.dart", lines, 1, 2))


class TheClasses(unittest.TestCase):
    def test_commented_out_code_and_prose_that_happens_to_parse(self):
        self.assertEqual(
            judge("a.py", ["# total = compute(votes)", "x = 1"]), "commented-out code"
        )
        self.assertEqual(
            judge("a.dart", ["// _channel.sink.close();", "int x = 1;"]),
            "commented-out code",
        )
        self.assertIsNone(judge("a.py", ["# Note: this is it", "x = 1"]))

    def test_a_banner_is_dividers_or_the_files_or_a_class_name(self):
        self.assertEqual(judge("game.py", ["# ── Game ──", "x = 1"]), "a banner")
        lines = ["// -----", "// The beat", "// -----", "class Beat {}"]
        self.assertEqual(judge("socket.dart", lines, 1, 3), "a banner")
        self.assertIsNone(judge("game.py", ["# ── Votes ──", "x = 1"]))

    def test_a_part_of_line_that_repeats_the_directive(self):
        lines = [
            "part of 'at_table_screen.dart';",
            "",
            "// Part of at_table_screen.dart.",
        ]
        self.assertEqual(judge("at_table_view.dart", lines, 3), "a repeated part of")
        other = ["part of 'lobby.dart';", "", "// Part of at_table_screen.dart."]
        self.assertIsNone(judge("at_table_view.dart", other, 3))

    def test_a_comment_that_only_restates_the_names_below_or_beside_it(self):
        python = ["# Join the table group", "self.join_table_group()"]
        self.assertEqual(judge("a.py", python), "it restates the names")
        dart = ["  /// Disposes the socket.", "  void disposeSocket() {"]
        self.assertEqual(judge("a.dart", dart), "it restates the names")
        beside = ["x = load_votes()  # load votes"]
        self.assertEqual(judge("a.py", beside), "it restates the names")
        more = ["  /// Whether socket [name] is up now.", "  bool isUp(String name) =>"]
        self.assertIsNone(judge("a.dart", more))

    def test_a_copy_of_a_comment_the_file_keeps(self):
        lines = ["// a held card stays face down", "int a = 1;"]
        kept = [TOOL.normal("a held card stays face down")]
        self.assertEqual(
            judge("a.dart", lines, kept=kept), "a copy of a comment kept in the file"
        )
        self.assertIsNone(judge("a.dart", lines))

    def test_a_rule_word_keeps_a_comment_out_of_every_class(self):
        for comment in (
            "# total = first(votes)",
            "# ── Game, never ──",
            "# Join the table group only",
            "# join so that table group",
        ):
            with self.subTest(comment):
                self.assertIsNone(
                    judge("game.py", [comment, "self.join_table_group()"], kept=[])
                )

    def test_a_docstring_is_never_applied(self):
        lines = ["def join_table_group():", '    """Join the table group."""']
        self.assertIsNone(judge("a.py", lines, 2))


if __name__ == "__main__":
    unittest.main()
