"""The live server's channel layer: a commit's socket messages in two Redis round trips.

``channels_redis`` sends one group message in four round trips, one after another
(drop expired members, read the members, drop expired messages, push), and a commit
that tells the table three things paid twelve before its answer left.
``group_send_many`` sends a list of ``(group, message)`` as one: one pipeline reads
every group's members, one script pushes every message to every member channel
(per Redis shard; the live server has one).

Order is kept for every socket: a channel's messages are read lowest score first,
and every message this process sends gets a score above the last one it gave (within
a batch in the order given, and from one batch to the next), also when one
socket is in two of the groups (a game socket hears its game and its player). The
data in Redis is exactly what ``group_send`` writes (same keys, members, expiry and
capacity rule), so an instance running the previous build receives these messages
as its own and its sends interleave as before.

Built on ``channels_redis.core.RedisChannelLayer`` 4.x internals (``_group_key``,
``_map_channel_keys_to_connection``, ``connection``); ``tests/core/test_channel_layer.py``
runs it against a real Redis.
"""

from __future__ import annotations

import asyncio
import collections
import logging
import threading
import time
from typing import Any

from channels_redis.core import RedisChannelLayer

logger = logging.getLogger(__name__)

# Between two messages of one batch: far above a score's resolution (a double near
# 1.8e9 resolves 2.4e-7 s), far below the time between two commits.
SCORE_STEP = 1e-5

# The highest score this process has given: every new one is at least a step above
# it, so two batches keep their order however close together they go out and even
# if the instance clock steps back.
_last_score = 0.0
_scores_lock = threading.Lock()


def _next_scores(count: int, now: float) -> list[float]:
    global _last_score
    with _scores_lock:
        scores = []
        for _ in range(count):
            _last_score = max(now, _last_score + SCORE_STEP)
            scores.append(_last_score)
        return scores


PUSH_LUA = """
local n = #KEYS
local cutoff = ARGV[3 * n + 1]
local expiry = ARGV[3 * n + 2]
local over_capacity = 0
for i = 1, n do
    redis.call('ZREMRANGEBYSCORE', KEYS[i], 0, cutoff)
    if redis.call('ZCOUNT', KEYS[i], '-inf', '+inf') < tonumber(ARGV[n + i]) then
        redis.call('ZADD', KEYS[i], ARGV[2 * n + i], ARGV[i])
        redis.call('EXPIRE', KEYS[i], expiry)
    else
        over_capacity = over_capacity + 1
    end
end
return over_capacity
"""


class BatchingRedisChannelLayer(RedisChannelLayer):
    async def group_send_many(self, messages: list[tuple[str, dict[str, Any]]]) -> None:
        """Send every ``(group, message)``, in order, in one round trip per step."""
        if not messages:
            return
        groups = list(dict.fromkeys(group for group, _ in messages))
        for group in groups:
            self.require_valid_group_name(group)  # raises TypeError when not
        members = await self._members(groups)

        now = time.time()
        scores = _next_scores(len(messages), now)
        # Per shard: (channel key, serialised message, capacity, score), in order.
        pushes: dict[int, list[tuple[Any, Any, int, float]]] = collections.defaultdict(
            list
        )
        for (group, message), score in zip(messages, scores, strict=True):
            to_shard, key_message, key_capacity = self._map_channel_keys_to_connection(
                members[group], message
            )
            for shard, keys in to_shard.items():
                for key in keys:
                    pushes[shard].append(
                        (key, key_message[key], key_capacity[key], score)
                    )
        cutoff = int(now) - int(self.expiry)
        await asyncio.gather(
            *(self._push(shard, batch, cutoff) for shard, batch in pushes.items())
        )

    async def _members(self, groups: list[str]) -> dict[str, list[str]]:
        """Every group's channels (expired members dropped first), one pipeline per
        shard holding groups."""
        by_shard: dict[int, list[str]] = collections.defaultdict(list)
        for group in groups:
            by_shard[self.consistent_hash(group)].append(group)
        expired = int(time.time()) - self.group_expiry
        members: dict[str, list[str]] = {}

        async def read(shard: int, names: list[str]) -> None:
            pipe = self.connection(shard).pipeline(transaction=False)
            for name in names:
                key = self._group_key(name)
                pipe.zremrangebyscore(key, min=0, max=expired)
                pipe.zrange(key, 0, -1)
            replies = await pipe.execute()
            for index, name in enumerate(names):
                members[name] = [c.decode("utf8") for c in replies[2 * index + 1]]

        await asyncio.gather(*(read(shard, names) for shard, names in by_shard.items()))
        return members

    async def _push(
        self, shard: int, batch: list[tuple[Any, Any, int, float]], cutoff: int
    ) -> None:
        keys = [key for key, _, _, _ in batch]
        args = [
            *(message for _, message, _, _ in batch),
            *(capacity for _, _, capacity, _ in batch),
            *(score for _, _, _, score in batch),
            cutoff,
            self.expiry,
        ]
        over = await self.connection(shard).eval(PUSH_LUA, len(keys), *keys, *args)
        if over:
            logger.info("%s of %s messages over capacity", over, len(batch))
