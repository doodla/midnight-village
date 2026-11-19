"""
End-to-end integration tests for Doppelganger wave-1 follow-up actions.

When the Doppelganger copies a role with an immediate follow-up (Seer, Robber,
Troublemaker, Drunk, Minion), the game must stay in window 1 after the initial
look so the Doppelganger can submit the follow-up action before the window closes.

This tests the service layer's wave management, not the pure engine (which
is covered by test_spec_doppelganger_timing.py).
"""

import functools
from unittest.mock import patch

from django.urls import reverse

import pytest
from rest_framework import status
from rest_framework.test import APIClient

from apps.core.models import Lobby, LobbyMember, User
from apps.onuw.models import Game, Phase, PlayerRole

pytestmark = pytest.mark.integration


def _patch_channels():
    """Mock out channel layer so WebSocket sends are no-ops during tests."""
    return patch("apps.core.effects.get_channel_layer", return_value=None)


def _setup_doppelganger_game(role_assignments: list[str], center_cards: list[str]):
    """
    Create a game with Doppelganger and the given role assignments.

    role_assignments: ordered dict of role_name -> None (auto-creates user)
    Returns (game, users_by_role, action_url)
    """
    users = []
    role_config: dict[str, int] = {}
    user_role_pairs = []

    for i, role_name in enumerate(role_assignments):
        user = User.objects.create_user(username=f"doppel_e2e_{i}", password="pass")
        users.append(user)
        user_role_pairs.append((user, role_name))
        role_config[role_name] = role_config.get(role_name, 0) + 1

    for card in center_cards:
        role_config[card] = role_config.get(card, 0) + 1

    host = users[0]
    lobby = Lobby.objects.create(
        host=host,
        game_type="onuw",
        max_players=10,
        # Minimum window length 0 and a Doppelganger window length of 0 (fixed
        # length off): a window closes as soon as its last actor submits. The
        # minimum and the fixed length have their own tests.
        settings={
            "roles": role_config,
            "night_min_window_seconds": 0,
            "night_doppelganger_window_seconds": 0,
        },
    )
    for user in users:
        LobbyMember.objects.create(lobby=lobby, user=user, is_ready=True)
    lobby.status = Lobby.Status.IN_GAME
    lobby.save()

    game = Game.objects.create(
        lobby=lobby,
        phase=Phase.NIGHT,
        random_seed=42,
        settings=lobby.settings,
        center_cards=center_cards,
    )

    users_by_role: dict[str, list[User]] = {}
    for user, role in user_role_pairs:
        PlayerRole.objects.create(
            game=game,
            user=user,
            original_role=role,
            current_role=role,
        )
        users_by_role.setdefault(role, []).append(user)

    action_url = reverse("onuw:night-action", kwargs={"game_id": str(game.id)})
    return game, users_by_role, action_url


class TestDoppelgangerWave1Followup:
    """Doppelganger copies a role with wave-1 follow-up via HTTP API."""

    def test_doppelganger_as_seer_gets_followup_prompt(self, db):
        """
        Doppelganger copies Seer -> game stays in wave 1 so Doppelganger
        can submit a Seer peek as a follow-up action.
        """
        game, users_by_role, action_url = _setup_doppelganger_game(
            role_assignments=["Doppelganger", "Seer", "Werewolf", "Villager"],
            center_cards=["Robber", "Drunk", "Troublemaker"],
        )

        doppel = users_by_role["Doppelganger"][0]
        seer = users_by_role["Seer"][0]

        with _patch_channels():
            from apps.onuw.services import start_night_phase

            start_night_phase(game)

        game.refresh_from_db()
        assert game.phase == Phase.NIGHT
        assert game.current_wave == 1

        # Doppelganger submits initial peek — copies the Seer
        client = APIClient()
        client.force_authenticate(user=doppel)
        with _patch_channels():
            response = client.post(
                action_url,
                {"action_type": "peek_player", "targets": {"player_id": seer.id}},
                format="json",
            )
        assert response.status_code == status.HTTP_200_OK

        # Game should STILL be in wave 1 (awaiting follow-up)
        game.refresh_from_db()
        assert game.phase == Phase.NIGHT
        assert game.current_wave == 1

        # Doppelganger's has_acted should be reset to False for the follow-up
        pr = PlayerRole.objects.get(game=game, user=doppel)
        assert pr.has_acted is False
        assert pr.night_action_data.get("copied_role") == "Seer"

    def test_doppelganger_as_seer_peek_center_resolves(self, db):
        """
        Full flow: Doppelganger copies Seer -> peeks 2 center cards ->
        game advances past wave 1.
        """
        game, users_by_role, action_url = _setup_doppelganger_game(
            role_assignments=["Doppelganger", "Seer", "Werewolf", "Villager"],
            center_cards=["Robber", "Drunk", "Troublemaker"],
        )

        doppel = users_by_role["Doppelganger"][0]
        seer = users_by_role["Seer"][0]

        with _patch_channels():
            from apps.onuw.services import start_night_phase

            start_night_phase(game)

        client = APIClient()
        client.force_authenticate(user=doppel)

        # Step 1: Initial peek — copy Seer
        with _patch_channels():
            response = client.post(
                action_url,
                {"action_type": "peek_player", "targets": {"player_id": seer.id}},
                format="json",
            )
        assert response.status_code == status.HTTP_200_OK

        # Step 2: Follow-up — Seer peek at 2 center cards
        with _patch_channels():
            response = client.post(
                action_url,
                {
                    "action_type": "peek_center",
                    "targets": {"center_indices": [0, 1]},
                },
                format="json",
            )
        assert response.status_code == status.HTTP_200_OK

        # Game should have advanced past wave 1
        game.refresh_from_db()
        assert game.current_wave != 1 or game.phase != Phase.NIGHT

    def test_doppelganger_as_robber_swaps_in_wave_1(self, db):
        """
        Doppelganger copies Robber -> swaps with another player ->
        roles are swapped correctly, game advances.
        """
        game, users_by_role, action_url = _setup_doppelganger_game(
            role_assignments=["Doppelganger", "Robber", "Werewolf", "Villager"],
            center_cards=["Seer", "Drunk", "Troublemaker"],
        )

        doppel = users_by_role["Doppelganger"][0]
        robber = users_by_role["Robber"][0]
        werewolf = users_by_role["Werewolf"][0]

        with _patch_channels():
            from apps.onuw.services import start_night_phase

            start_night_phase(game)

        client = APIClient()
        client.force_authenticate(user=doppel)

        # Step 1: Initial peek — copy Robber
        with _patch_channels():
            response = client.post(
                action_url,
                {"action_type": "peek_player", "targets": {"player_id": robber.id}},
                format="json",
            )
        assert response.status_code == status.HTTP_200_OK

        # Step 2: Follow-up — swap with Werewolf
        with _patch_channels():
            response = client.post(
                action_url,
                {
                    "action_type": "swap_with_player",
                    "targets": {"player_id": werewolf.id},
                },
                format="json",
            )
        assert response.status_code == status.HTTP_200_OK

        # Verify the swap happened: Doppelganger now holds Werewolf card,
        # Werewolf player now holds Doppelganger card.
        game.refresh_from_db()
        pr_doppel = PlayerRole.objects.get(game=game, user=doppel)
        pr_ww = PlayerRole.objects.get(game=game, user=werewolf)
        assert pr_doppel.current_role == "Werewolf"
        assert pr_ww.current_role == "Doppelganger"

    def test_doppelganger_as_drunk_swaps_center_in_wave_1(self, db):
        """
        Doppelganger copies Drunk -> swaps with center card ->
        Doppelganger card goes to center, center card goes to player.
        """
        game, users_by_role, action_url = _setup_doppelganger_game(
            role_assignments=["Doppelganger", "Drunk", "Werewolf", "Villager"],
            center_cards=["Seer", "Robber", "Troublemaker"],
        )

        doppel = users_by_role["Doppelganger"][0]
        drunk = users_by_role["Drunk"][0]

        with _patch_channels():
            from apps.onuw.services import start_night_phase

            start_night_phase(game)

        client = APIClient()
        client.force_authenticate(user=doppel)

        # Step 1: Initial peek — copy Drunk
        with _patch_channels():
            response = client.post(
                action_url,
                {"action_type": "peek_player", "targets": {"player_id": drunk.id}},
                format="json",
            )
        assert response.status_code == status.HTTP_200_OK

        # Step 2: Follow-up — swap with center card 0 (Seer)
        with _patch_channels():
            response = client.post(
                action_url,
                {
                    "action_type": "swap_with_center",
                    "targets": {"center_index": 0},
                },
                format="json",
            )
        assert response.status_code == status.HTTP_200_OK

        # Verify the swap: Doppelganger now holds Seer card, center[0] is Doppelganger
        game.refresh_from_db()
        pr_doppel = PlayerRole.objects.get(game=game, user=doppel)
        assert pr_doppel.current_role == "Seer"
        assert game.center_cards[0] == "Doppelganger"

    def test_doppelganger_as_minion_sees_werewolves_in_wave_1(self, db):
        """
        Doppelganger copies Minion -> sees Werewolf identities as follow-up.
        """
        game, users_by_role, action_url = _setup_doppelganger_game(
            role_assignments=["Doppelganger", "Minion", "Werewolf", "Villager"],
            center_cards=["Seer", "Robber", "Troublemaker"],
        )

        doppel = users_by_role["Doppelganger"][0]
        minion = users_by_role["Minion"][0]
        werewolf = users_by_role["Werewolf"][0]

        with _patch_channels():
            from apps.onuw.services import start_night_phase

            start_night_phase(game)

        client = APIClient()
        client.force_authenticate(user=doppel)

        # Step 1: Initial peek — copy Minion
        with _patch_channels():
            response = client.post(
                action_url,
                {"action_type": "peek_player", "targets": {"player_id": minion.id}},
                format="json",
            )
        assert response.status_code == status.HTTP_200_OK

        # Step 2: Follow-up — see_team to see Werewolves
        with _patch_channels():
            response = client.post(
                action_url,
                {"action_type": "see_team", "targets": {}},
                format="json",
            )
        assert response.status_code == status.HTTP_200_OK

        # Verify the Doppelganger saw the Werewolf
        pr_doppel = PlayerRole.objects.get(game=game, user=doppel)
        # The follow-up result should contain werewolf info
        followup_result = pr_doppel.night_action_data.get("wave_1_result", {})
        assert werewolf.id in followup_result.get("werewolves", [])

    def test_doppelganger_copies_villager_no_followup(self, db):
        """
        Doppelganger copies Villager (no follow-up action) -> game advances
        past wave 1 immediately after the peek.
        """
        game, users_by_role, action_url = _setup_doppelganger_game(
            role_assignments=["Doppelganger", "Villager", "Werewolf", "Seer"],
            center_cards=["Robber", "Drunk", "Troublemaker"],
        )

        doppel = users_by_role["Doppelganger"][0]
        villager = users_by_role["Villager"][0]

        with _patch_channels():
            from apps.onuw.services import start_night_phase

            start_night_phase(game)

        client = APIClient()
        client.force_authenticate(user=doppel)

        # Peek at Villager — no follow-up needed
        with _patch_channels():
            response = client.post(
                action_url,
                {
                    "action_type": "peek_player",
                    "targets": {"player_id": villager.id},
                },
                format="json",
            )
        assert response.status_code == status.HTTP_200_OK

        # Game should advance past wave 1 (to wave 2 for Werewolves)
        game.refresh_from_db()
        assert game.current_wave > 1 or game.phase != Phase.NIGHT


class TestDoppelgangerFollowupTimeout:
    """The window-1 timer closes the window even if the follow-up is never submitted."""

    def test_window_timer_closes_window_1_without_the_follow_up(
        self, db, django_capture_on_commit_callbacks
    ):
        """
        Window 1 has ONE timer, scheduled when it opens and never moved. If the
        Doppelganger copies a Seer but never submits the follow-up, that timer's
        callback closes the window: the follow-up is skipped and window 2 opens.

        Regression: a callback built with functools.partial must keep working
        when make_idempotent_callback passes it a fresh Game instance.
        """
        from apps.core import timers

        game, users_by_role, action_url = _setup_doppelganger_game(
            role_assignments=["Doppelganger", "Seer", "Werewolf", "Villager"],
            center_cards=["Robber", "Drunk", "Troublemaker"],
        )
        Game.objects.filter(id=game.id).update(
            settings={
                "roles": {},
                "night_min_window_seconds": 0,
                "night_doppelganger_window_seconds": 10,
            }
        )
        game.refresh_from_db()

        doppel = users_by_role["Doppelganger"][0]
        seer = users_by_role["Seer"][0]

        scheduled: list[tuple[str, float, object]] = []

        def capture_schedule(key, delay, job, params=None):
            callback = functools.partial(timers.run_job_quietly, job, params)
            scheduled.append((key, delay, callback))

        client = APIClient()
        client.force_authenticate(user=doppel)
        timer_key = f"{game.id}:wave:1"

        with (
            _patch_channels(),
            patch.object(timers, "schedule", side_effect=capture_schedule),
            django_capture_on_commit_callbacks(execute=True),
        ):
            from apps.onuw.services import start_night_phase

            start_night_phase(game)

        assert [(k, d) for k, d, _ in scheduled] == [(timer_key, 10)]

        # The look is submitted; the follow-up is never submitted.
        with (
            _patch_channels(),
            patch.object(timers, "schedule", side_effect=capture_schedule),
            django_capture_on_commit_callbacks(execute=True),
        ):
            response = client.post(
                action_url,
                {"action_type": "peek_player", "targets": {"player_id": seer.id}},
                format="json",
            )
        assert response.status_code == status.HTTP_200_OK

        # Still window 1, and nothing was rescheduled for the follow-up.
        game.refresh_from_db()
        assert game.current_wave == 1
        assert len(scheduled) == 1

        callback = scheduled[0][2]
        with _patch_channels(), django_capture_on_commit_callbacks(execute=True):
            callback()  # type: ignore[operator]

        game.refresh_from_db()
        assert game.current_wave == 2
        skipped = [
            e
            for e in game.night_actions_log
            if e["player_id"] == doppel.id and e["action_type"] == "skip"
        ]
        assert len(skipped) == 1
