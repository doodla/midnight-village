"""A username never goes out as a player's name (``apps.core.wire.public_name``).

A guest's username is its account's id. An account with no display name used to
be named by it in game bodies and on both sockets.
"""

from __future__ import annotations

import re
from pathlib import Path

import pytest

from apps.core.models import Lobby, LobbyMember, User
from apps.core.serializers import LobbySerializer
from apps.core.wire import NAMELESS, public_name

APPS = Path(__file__).resolve().parents[2] / "apps"
SECRET = "0f8fad5b-d9cb-469f-a165-70867728950e"


def test_a_name_is_the_display_name_and_never_the_username():
    assert public_name(User(username=SECRET, display_name="Cleo")) == "Cleo"
    for nameless in ("", "   "):
        named = public_name(User(username=SECRET, display_name=nameless))
        assert named == NAMELESS
        assert SECRET not in named


@pytest.mark.integration
def test_a_table_with_a_nameless_account_sends_no_username_anywhere(db):
    owner = User.objects.create_user(username=SECRET, display_name="")
    lobby = Lobby.objects.create(host=owner, game_type="onuw")
    LobbyMember.objects.create(lobby=lobby, user=owner)

    body = LobbySerializer(lobby).data
    assert body["host"]["display_name"] == NAMELESS
    assert body["players"][0]["user"]["display_name"] == NAMELESS
    assert SECRET not in str(body)


def test_no_code_falls_back_from_a_name_to_a_username():
    """The mechanism, held: whoever sends a name calls ``public_name``."""
    fallback = re.compile(
        r"display_name\s+or\s+\S*username|username\s+or\s+\S*display_name"
    )
    found = [
        f"{path.relative_to(APPS)}:{number}"
        for path in sorted(APPS.rglob("*.py"))
        if "migrations" not in path.parts
        for number, line in enumerate(path.read_text().splitlines(), 1)
        if fallback.search(line)
        and not line.lstrip().startswith(("#", '"', "A guest", "that id"))
    ]
    assert found == [], f"send public_name(user), never the username: {found}"
