"""
No-leak sweep for the v2 payloads that exist so far (tokens and seats, where am I,
the night-results ack): in every phase before the results, nothing a player gets
names a role held by someone else. (The oracle is DEBUG-only and not part of this.)
"""

import json
from typing import Any

from django.urls import reverse

import pytest
from rest_framework import status

from apps.core.models import Lobby
from apps.onuw.models import Phase, PlayerRole
from tests.onuw.test_night_windows import Night

pytestmark = pytest.mark.integration

ROLES = {
    "wolf": "Werewolf",
    "seer": "Seer",
    "robber": "Robber",
    "insomniac": "Insomniac",
    "villager": "Villager",
}
CENTER = ["Drunk", "Tanner", "Hunter"]
# Roles in the center are unknown to every player too.
ALL_ROLE_NAMES = {*ROLES.values(), *CENTER, "Doppelganger", "Mason", "Minion"}


def reach(night: Night, phase: str) -> None:
    night.start()
    if phase == Phase.NIGHT:
        return
    night.post("wolf", "see_team")
    night.post("seer", "peek_player", {"player_id": night.users["robber"].id})
    night.post("robber", "swap_with_player", {"player_id": night.users["villager"].id})
    night.post("insomniac", "none")
    assert night.refresh().phase == Phase.DISCUSSION
    if phase == Phase.DISCUSSION:
        return
    night.client.force_authenticate(user=night.host)
    end = reverse("onuw:end-discussion", kwargs={"game_id": str(night.game.id)})
    with night.committed():
        assert night.client.post(end).status_code == status.HTTP_200_OK
    assert night.refresh().phase == Phase.VOTING


def payloads_for(night: Night, name: str) -> dict[str, Any]:
    """Every v2 payload one player gets, by endpoint."""
    client = night.client
    client.force_authenticate(user=night.users[name])
    game_id = str(night.game.id)
    lobby_code = night.game.lobby.code
    me = client.get(reverse("onuw:game-me", kwargs={"game_id": game_id})).data
    return {
        "my_table": client.get(reverse("core:my-table")).data,
        "seen": client.post(
            reverse("onuw:night-results-seen", kwargs={"game_id": game_id}),
            {"seen": 1},
            format="json",
        ).data,
        "players": client.get(
            reverse("onuw:player-list", kwargs={"game_id": game_id})
        ).data,
        "lobby": client.get(
            reverse("core:lobby-detail", kwargs={"code": lobby_code})
        ).data,
        # Of /me/ only the v2 fields: the rest holds the caller's OWN role by design.
        "me_players": me["players"],
        "me_night_results_seen": me["night_results_seen"],
    }


@pytest.mark.parametrize("phase", [Phase.NIGHT, Phase.DISCUSSION, Phase.VOTING])
@pytest.mark.parametrize("viewer", list(ROLES))
def test_v2_payloads_contain_no_foreign_role_names(
    make_night, phase: str, viewer: str
) -> None:
    night = make_night(ROLES, CENTER, night_wave_seconds=60)
    reach(night, phase)
    lobby = Lobby.objects.get(code=night.game.lobby.code)
    assert lobby.status == Lobby.Status.IN_GAME

    mine = {
        role
        for pr in PlayerRole.objects.filter(game=night.game, user=night.users[viewer])
        for role in (pr.original_role, pr.current_role)
    }
    held_by_others = {
        role
        for pr in PlayerRole.objects.filter(game=night.game).exclude(
            user=night.users[viewer]
        )
        for role in (pr.original_role, pr.current_role)
    }
    forbidden = (held_by_others | set(CENTER) | ALL_ROLE_NAMES) - mine

    for endpoint, payload in payloads_for(night, viewer).items():
        text = json.dumps(payload, default=str)
        leaked = {role for role in forbidden if role in text}
        assert not leaked, f"{endpoint} names {leaked} to {viewer} in {phase}"
