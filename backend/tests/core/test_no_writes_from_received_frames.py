# Guard file: a change here needs its line in the pull request (tool/guard_edits.py).
"""Nothing a socket receives writes game state (CLAUDE.md principle 7: HTTP for actions).

The mechanism is ``apps.core.frames``: while a consumer handles a frame a phone sent,
every database write is refused, on every server. These tests hold its three parts:
every routed consumer (walked from the ASGI router, not a list) handles frames through
the base that marks them; the refusal refuses a write and lets a read by; and every
routed socket, sent a frame named after each action the HTTP API takes (walked from the
URL conf), answers with an error and leaves every row as it was.
"""

from __future__ import annotations

import re
from collections.abc import Iterator

from django.apps import apps
from django.db import transaction
from django.urls import URLPattern, URLResolver, get_resolver

import pytest
from channels.db import database_sync_to_async
from channels.routing import URLRouter
from channels.testing import WebsocketCommunicator

from apps.core import frames
from apps.core.consumers import TolerantJsonWebsocketConsumer
from apps.core.models import User
from config.asgi import application
from tests.onuw.test_game_consumer import _create_game_with_players
from tests.sockets import heard

WRITING = ("post", "put", "patch", "delete")


def _router(app) -> URLRouter:
    """The URLRouter inside the websocket stack's middleware."""
    seen = 0
    while not isinstance(app, URLRouter):
        app = next(
            getattr(app, name)
            for name in ("application", "inner", "app")
            if getattr(app, name, None) is not None
        )
        seen += 1
        assert seen < 10, "no URLRouter found in config.asgi's websocket stack"
    return app


def _socket_routes() -> list[tuple[str, type]]:
    routes = _router(application.application_mapping["websocket"]).routes
    return [(str(r.pattern), r.callback.consumer_class) for r in routes]


def _action_names() -> set[str]:
    """Every name a phone might give an HTTP action, from the URL conf: the literal
    parts of each route a view takes a write on, dashed, underscored and dotted."""

    def walk(patterns, prefix: str) -> Iterator[tuple[str, object]]:
        for entry in patterns:
            route = prefix + str(entry.pattern)
            if isinstance(entry, URLResolver):
                yield from walk(entry.url_patterns, route)
            elif isinstance(entry, URLPattern):
                yield route, getattr(entry.callback, "cls", None)

    names: set[str] = set()
    for route, view in walk(get_resolver().url_patterns, ""):
        if view is None or not any(hasattr(view, m) for m in WRITING):
            continue
        tail = route.rstrip("/").split(">")[-1].strip("/")
        for part in [*re.findall(r"[a-z][a-z-]*", tail), tail.replace("/", "-")]:
            if part:
                names |= {part, part.replace("-", "_"), part.replace("-", ".")}
    return names


@database_sync_to_async
def _rows() -> dict[str, list]:
    """Every row of every model of the project's own apps."""
    return {
        model._meta.label: sorted(map(repr, model.objects.values()))
        for model in apps.get_models()
        if model.__module__.startswith("apps.")
    }


def test_every_routed_consumer_handles_frames_through_the_base_that_marks_them():
    routes = _socket_routes()
    assert routes, "config.asgi routes no socket"
    for pattern, consumer in routes:
        assert issubclass(consumer, TolerantJsonWebsocketConsumer), (
            f"{consumer.__module__}: {consumer.__name__} ({pattern}) does not extend"
            " TolerantJsonWebsocketConsumer, so a frame it receives may write."
            " Fix: extend it (apps.core.consumers)."
        )
        assert consumer.dispatch is TolerantJsonWebsocketConsumer.dispatch, (
            f"{consumer.__module__}: {consumer.__name__} overrides dispatch, past the"
            " mark on received frames. Fix: handle frames in receive_json instead."
        )


@pytest.mark.django_db
def test_a_write_while_a_frame_is_handled_is_refused_and_a_read_is_not():
    User.objects.create_user(username="before", password="x")
    with frames.received("SomeConsumer"):
        assert User.objects.filter(username="before").exists()
        # each refusal rolls its savepoint back, as a failed view's would
        with pytest.raises(frames.WriteFromAFrameError, match="SomeConsumer wrote"):
            with transaction.atomic():
                User.objects.filter(username="before").update(first_name="x")
        with pytest.raises(frames.WriteFromAFrameError), transaction.atomic():
            User.objects.create_user(username="during", password="x")
    User.objects.filter(username="before").update(first_name="after")
    assert User.objects.get(username="before").first_name == "after"


@pytest.mark.parametrize(
    ("sql", "writes"),
    [
        ('SELECT "onuw_game"."id" FROM "onuw_game" WHERE "updated_at" > 1', False),
        ('  UPDATE "onuw_playerrole" SET "phase_ready" = true', True),
        ('INSERT INTO "core_lobby" ("code") VALUES (1)', True),
        ("WITH moved AS (DELETE FROM x RETURNING id) SELECT id FROM moved", True),
        ("SAVEPOINT s1", False),
    ],
)
def test_a_statement_is_a_write_when_it_changes_data(sql, writes):
    assert frames.is_write(sql) is writes


@pytest.mark.integration
@pytest.mark.django_db(transaction=True)
async def test_no_frame_named_after_an_action_writes_on_any_socket():
    game, users = await _create_game_with_players(player_count=3)
    lobby = await database_sync_to_async(lambda: game.lobby)()
    values = {"code": lobby.code, "game_id": str(game.id)}
    names = sorted(_action_names())
    assert {"ready", "vote", "action", "start"} <= set(names), names
    for pattern, consumer in _socket_routes():
        for seat, user in enumerate(users):
            missing = set(re.findall(r"<(?:\w+:)?(\w+)>", pattern)) - set(values)
            assert not missing, (
                f"{pattern}: this test cannot fill {missing}. Fix: add how to"
                " `values` in tests/core/test_no_writes_from_received_frames.py"
            )
            path = "/" + re.sub(
                r"<(?:\w+:)?(\w+)>", lambda m: values[m.group(1)], pattern
            )
            socket = WebsocketCommunicator(application, path)
            socket.scope["headers"] = [(b"origin", b"http://testserver")]
            socket.scope["user"] = user
            assert (await socket.connect())[0], f"{path} refused seat {seat}"
            # the socket's own connect writes its presence, then sends the first beat
            while (await socket.receive_json_from(timeout=2))["type"] != "beat":
                pass
            before = await _rows()
            for name in names[seat :: len(users)]:
                for frame in ({"type": name}, {"type": name, "action": name}):
                    await socket.send_json_to(frame)
                    try:
                        while (await heard(socket))["type"] != "error":
                            pass
                    except frames.WriteFromAFrameError as error:
                        pytest.fail(f"{consumer.__name__} wrote on {frame}: {error}")
            after = await _rows()
            await socket.disconnect()
            changed = [label for label in before if before[label] != after[label]]
            assert not changed, f"{consumer.__name__}: frames wrote {changed}"
