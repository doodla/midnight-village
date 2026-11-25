"""The live server's channel layer sends a commit's messages at once, in order
(``apps/core/channel_layer.py``), against a real Redis.

Redis: ``REDIS_TEST_URL`` (GitHub's backend job runs one), else a ``redis-server``
started here on a free port, else these tests are skipped.
"""

from __future__ import annotations

import asyncio
import os
import shutil
import socket
import subprocess
import time
import uuid
from collections.abc import Iterator
from typing import Any
from unittest.mock import patch

import pytest
from channels_redis.core import RedisChannelLayer
from redis.asyncio.client import Pipeline, Redis

from apps.core.channel_layer import BatchingRedisChannelLayer

pytestmark = pytest.mark.unit


def _free_port() -> int:
    with socket.socket() as probe:
        probe.bind(("127.0.0.1", 0))
        return probe.getsockname()[1]


@pytest.fixture(scope="module")
def redis_url(tmp_path_factory: pytest.TempPathFactory) -> Iterator[str]:
    given = os.environ.get("REDIS_TEST_URL")
    if given:
        yield given
        return
    binary = shutil.which("redis-server")
    if binary is None:
        if os.environ.get("CI"):
            pytest.fail("no Redis on CI: REDIS_TEST_URL is not set")
        pytest.skip("no Redis: set REDIS_TEST_URL or install redis-server")
    port = _free_port()
    folder = tmp_path_factory.mktemp("redis")
    server = subprocess.Popen(  # noqa: S603  (a fixed local binary)
        [binary, "--port", str(port), "--save", "", "--dir", str(folder)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    try:
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            with socket.socket() as probe:
                if probe.connect_ex(("127.0.0.1", port)) == 0:
                    break
            time.sleep(0.05)
        yield f"redis://127.0.0.1:{port}/0"
    finally:
        server.terminate()
        server.wait(timeout=10)


def _layers(url: str) -> tuple[BatchingRedisChannelLayer, RedisChannelLayer]:
    """The new layer and the previous build's (stock) one, on the same keys."""
    prefix = f"test{uuid.uuid4().hex[:8]}"
    return (
        BatchingRedisChannelLayer(hosts=[url], prefix=prefix),
        RedisChannelLayer(hosts=[url], prefix=prefix),
    )


async def _received(layer: RedisChannelLayer, channel: str, count: int) -> list[str]:
    got = []
    for _ in range(count):
        message = await asyncio.wait_for(layer.receive(channel), timeout=5)
        got.append(message["text"])
    return got


async def _closed(*layers: RedisChannelLayer) -> None:
    await layers[0].flush()
    for layer in layers:
        await layer.close_pools()


def test_every_socket_hears_a_batch_in_order_even_one_in_two_groups(redis_url):
    async def run() -> dict[str, list[str]]:
        new, old = _layers(redis_url)
        try:
            # Three phones on the game; Ana's socket also hears her own group.
            for channel in ("ana", "ben", "cleo"):
                await new.group_add("game_1", channel)
            await new.group_add("player_ana", "ana")
            await new.group_send_many(
                [
                    ("game_1", {"type": "t", "text": "progress"}),
                    ("player_ana", {"type": "t", "text": "yours"}),
                    ("game_1", {"type": "t", "text": "phase"}),
                    ("game_1", {"type": "t", "text": "count"}),
                ]
            )
            # Read by the previous build's layer: the same data in Redis.
            return {
                "ana": await _received(old, "ana", 4),
                "ben": await _received(old, "ben", 3),
                "cleo": await _received(old, "cleo", 3),
            }
        finally:
            await _closed(new, old)

    heard = asyncio.run(run())

    assert heard["ana"] == ["progress", "yours", "phase", "count"]
    assert heard["ben"] == heard["cleo"] == ["progress", "phase", "count"]


def test_a_batch_costs_two_round_trips_whatever_it_sends(redis_url):
    trips: list[str] = []
    command = Redis.execute_command
    pipeline = Pipeline.execute

    async def counted_command(self: Any, *args: Any, **kwargs: Any) -> Any:
        trips.append(str(args[0]))
        return await command(self, *args, **kwargs)

    async def counted_pipeline(self: Any, *args: Any, **kwargs: Any) -> Any:
        trips.append("PIPELINE")
        return await pipeline(self, *args, **kwargs)

    messages = [
        ("game_1", {"type": "t", "text": "progress"}),
        ("game_1", {"type": "t", "text": "phase"}),
        ("lobby_ABCD", {"type": "t", "text": "table"}),
    ]

    async def run() -> tuple[int, int]:
        new, old = _layers(redis_url)
        try:
            for channel in ("ana", "ben", "cleo", "dev", "esme", "fin"):
                await new.group_add("game_1", channel)
                await new.group_add("lobby_ABCD", f"lobby-{channel}")
            with (
                patch.object(Redis, "execute_command", counted_command),
                patch.object(Pipeline, "execute", counted_pipeline),
            ):
                await new.group_send_many(messages)
                batched = len(trips)
                trips.clear()
                for group, message in messages:
                    await old.group_send(group, message)
                one_by_one = len(trips)
            return batched, one_by_one
        finally:
            await _closed(new, old)

    batched, one_by_one = asyncio.run(run())

    assert batched == 2
    assert one_by_one == 12


def test_a_full_channel_drops_the_message_as_the_stock_layer_does(redis_url):
    async def run() -> list[str]:
        prefix = f"test{uuid.uuid4().hex[:8]}"
        new = BatchingRedisChannelLayer(hosts=[redis_url], prefix=prefix, capacity=2)
        try:
            await new.group_add("game_1", "ana")
            await new.group_send_many(
                [("game_1", {"type": "t", "text": str(n)}) for n in range(3)]
            )
            got = await _received(new, "ana", 2)
            with pytest.raises(TimeoutError):
                await asyncio.wait_for(new.receive("ana"), timeout=0.3)
            return got
        finally:
            await _closed(new)

    assert asyncio.run(run()) == ["0", "1"]


def test_an_empty_batch_sends_nothing(redis_url):
    async def run() -> None:
        new, old = _layers(redis_url)
        try:
            await new.group_send_many([])
        finally:
            await _closed(new, old)

    asyncio.run(run())
