"""tool/tap_hold/: every hold the app uses is a part the browser check touches.

A file under frontend/lib that builds a hold primitive or hands one a hold
(`parts.USES`) is covered by a part of `parts.PARTS` naming that file and that use,
so a new hold on a screen cannot go unchecked. Not counted (read from the code,
`parts.uses`): a hold primitive's own file, and a call whose tap and hold do the
same (`onTap: f, onLongPress: f`), where a quick touch taken for a hold does what
the tap would."""

import sys
import unittest
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tool" / "tap_hold"))
import parts  # noqa: E402


class TapHoldParts(unittest.TestCase):
    def test_every_hold_in_the_app_is_a_part(self):
        covered = Counter((p.file, p.use) for p in parts.PARTS)
        used = Counter((f, u) for f, u, _ in parts.uses())
        lines = {(f, u): line for f, u, line in parts.uses()}
        missing = [
            f"frontend/lib/{f}:{lines[(f, u)]}: `{u}` is a hold the tap/hold check does not "
            f"touch. Fix: add a Part to tool/tap_hold/parts.py (its file, `{u}`, its hold "
            "time's constant, the words to find it, what a tap and a hold do)"
            for (f, u), n in used.items()
            if covered[(f, u)] < n
        ]
        self.assertEqual(missing, [], "\n".join(missing))

    def test_every_part_is_still_in_the_app(self):
        used = {(f, u) for f, u, _ in parts.uses()}
        gone = [
            f"tool/tap_hold/parts.py: {p.name}: frontend/lib/{p.file} no longer uses `{p.use}`. "
            "Fix: point the part at where the hold is now, or remove it"
            for p in parts.PARTS
            if (p.file, p.use) not in used
        ]
        self.assertEqual(gone, [], "\n".join(gone))

    def test_hold_times_come_from_the_code(self):
        for p in parts.PARTS:
            if not p.hold[0].startswith("flutter:"):
                self.assertGreater(parts.hold_ms(p), 0, p.name)

    def test_a_tap_and_a_hold_doing_the_same_is_read_from_the_call(self):
        same = "RoleCard(\n  onTap: () => onRead(role),\n  onLongPress: () => onRead(role),\n)"
        other = "RoleCard(\n  onTap: () => onAdd(role),\n  onLongPress: () => open(role),\n)"
        self.assertTrue(parts.same_both_ways(same, same.index("onLongPress")))
        self.assertFalse(parts.same_both_ways(other, other.index("onLongPress")))


if __name__ == "__main__":
    unittest.main()
