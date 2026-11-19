"""``GET /api/me/table/`` asks the game app through hooks; core imports no game app."""

from django.urls import reverse

import pytest
from rest_framework import status
from rest_framework.test import APIClient

from apps.core import games
from apps.core.games import GameHooks

pytestmark = pytest.mark.integration


def guest_client() -> tuple[APIClient, int]:
    client = APIClient()
    response = client.post(reverse("core:guest-create"), {}, format="json")
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {response.data['access']}")
    return client, response.data["user"]["id"]


def where(client: APIClient) -> dict:
    response = client.get(reverse("core:my-table"))
    assert response.status_code == status.HTTP_200_OK
    return response.data["table"]


class FakeGameHooks(GameHooks):
    def __init__(self) -> None:
        self.asked: list[tuple[str, int]] = []

    def member_game(self, lobby, user_id):
        self.asked.append((lobby.code, user_id))
        return {"game_id": "the-hooks-answer", "phase": "whatever"}


class TestCoreUsesHooks:
    def test_core_view_uses_hooks_not_game_app(self, db) -> None:
        hooks = FakeGameHooks()
        games.register("fakegame", hooks)
        try:
            guest, user_id = guest_client()
            created = guest.post(
                reverse("core:lobby-list"), {"game_type": "fakegame"}, format="json"
            )

            answer = where(guest)

            assert answer["game_type"] == "fakegame"
            assert answer["game"] == {
                "game_id": "the-hooks-answer",
                "phase": "whatever",
            }
            assert hooks.asked == [(created.data["code"], user_id)]
        finally:
            games._registry.pop("fakegame", None)

    def test_a_game_type_with_no_hooks_has_no_game(self, db) -> None:
        guest, _ = guest_client()
        guest.post(reverse("core:lobby-list"), {"game_type": "nogame"}, format="json")

        assert where(guest)["game"] is None
