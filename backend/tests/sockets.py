"""What a test socket hears, beside the socket's own beat.

Every game and lobby socket sends its phone a ``beat`` as it opens and at each
heartbeat (``apps.core.presence.beat_frame``); a test that waits for an event
skips those.
"""

from __future__ import annotations

from typing import Any


async def heard(communicator: Any, timeout: float = 2) -> dict[str, Any]:
    """The next frame ``communicator`` receives that is not a beat."""
    while True:
        frame = await communicator.receive_json_from(timeout=timeout)
        if frame.get("type") != "beat":
            return frame
