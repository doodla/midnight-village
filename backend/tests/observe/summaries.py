"""A summary as the app sends one (``frontend/lib/core/perf/field_summary.dart``):
the shape its own test pins (``field_summary_test.dart``), with seeded values."""

from __future__ import annotations

import copy
import random
from typing import Any

AGENT = (
    "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/131.0.0.0 Mobile Safari/537.36"
)


def summary(seed: int = 7, **over: Any) -> dict[str, Any]:
    """Two kinds of tap, three screens, two paths, one cold start."""
    rng = random.Random(seed)  # noqa: S311 — seeded on purpose, not cryptographic

    def ms(low: float, high: float, n: int = 6) -> list[float]:
        return [round(rng.uniform(low, high), 1) for _ in range(n)]

    body: dict[str, Any] = {
        "v": 1,
        "commit": "faf62a1c0ffee",
        "end": "end_board",
        "env": {
            "agent": AGENT,
            "pixel_ratio": 2.625,
            "renderer": "canvaskit",
            "cores": 8,
            "memory_gb": 4,
            "first_frame_ms": 2310,
            "main_bundle_ms": 1650,
            "engine_ms": 1200,
        },
        "taps": {
            "talk tap main_button POST /api/onuw/games/·/ready/": {
                "n": 6,
                "heard": ms(1, 9),
                "screen": ms(20, 90),
                "left": ms(2, 12),
                "answer": ms(80, 400),
                "applied": ms(5, 40),
                "shown": ms(10, 40),
                "total": ms(150, 600),
            },
            "vote tap player_row": {"n": 4, "screen": ms(16, 60, 4)},
        },
        "frames": {
            "talk": {"frames": 900, "over_50": 12, "over_100": 3, "worst": 180.0},
            "vote": {"frames": 400, "over_50": 2, "over_100": 0, "worst": 70.0},
            "end": {"frames": 300, "over_50": 9, "over_100": 4, "worst": 240.0},
        },
        "screens": {
            "talk > vote (socket phase_change)": {
                "n": 1,
                "first": ms(30, 60, 1),
                "content": ms(80, 200, 1),
            },
        },
        "requests": {
            "POST /api/onuw/games/·/ready/": {
                "n": 6,
                "round": ms(80, 400),
                "server": [50.0, 100.0, 50.0, 50.0, 150.0, 50.0],
                "connect": ms(8, 30),
                "outside": ms(30, 250),
            },
            "GET /api/onuw/games/·/me/": {"n": 3, "round": ms(60, 1900, 3)},
        },
        "cold": [
            {
                "kind": "db_wake",
                "path": "GET /api/onuw/games/·/me/",
                "round": 1900.0,
                "server": 1350.0,
                "connect": 1100.0,
                "outside": 550.0,
                "gap_s": 412.0,
            }
        ],
        "socket": {"events": 40, "opened": 2, "dropped": 0},
    }
    body.update(copy.deepcopy(over))
    return body
