"""
Tests for the DEBUG-gated developer-harness surfaces (contract Part B).

Covers:
- B1 forced-assignment / seed override on game start
- B2 debug-state oracle
- B3 fire-timer hook

GATING is the load-bearing invariant: every debug surface MUST be inert when
settings.DEBUG is False (403, no side effects). The test settings module sets
DEBUG=False, so the default environment exercises the production gate; the
DEBUG-enabled paths use @override_settings(DEBUG=True).
"""

from __future__ import annotations

from datetime import timedelta
from unittest.mock import MagicMock, patch

from django.test import override_settings
from django.urls import reverse
from django.utils import timezone

import pytest
from rest_framework import status

from apps.core import host as host_module
from apps.core import timers
from apps.core.models import Lobby, LobbyMember, ScheduledTimer, User
from apps.onuw import night_window
from apps.onuw.models import Game, Phase, PlayerRole

pytestmark = pytest.mark.integration


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _create_lobby(host, players, role_config):
    lobby = Lobby.objects.create(
        host=host,
        game_type="onuw",
        max_players=10,
        settings={"roles": role_config},
    )
    LobbyMember.objects.create(lobby=lobby, user=host)
    for player in players:
        LobbyMember.objects.create(lobby=lobby, user=player)
    return lobby


def _make_5_users():
    host = User.objects.create_user(
        username="dh_host", password="pass", display_name="Host"
    )
    others = [
        User.objects.create_user(
            username=f"dh_p{i}", password="pass", display_name=f"P{i}"
        )
        for i in range(4)
    ]
    return host, others


def _start_url(code):
    return reverse("onuw:game-start", kwargs={"code": code})


def _debug_state_url(game_id):
    return reverse("onuw:debug-state", kwargs={"game_id": str(game_id)})


def _fire_timer_url(game_id):
    return reverse("onuw:debug-fire-timer", kwargs={"game_id": str(game_id)})


def _no_channels():
    """Mock out the channel layer so WebSocket sends are no-ops."""
    return patch("apps.core.effects.get_channel_layer", return_value=None)


# ---------------------------------------------------------------------------
# B1 — Forced-assignment / seed override
# ---------------------------------------------------------------------------


class TestForcedAssignment:
    @override_settings(DEBUG=True)
    def test_forced_assignment_lands_exactly(self, api_client, db):
        """Forced roles are applied verbatim; current_role == original_role."""
        host, others = _make_5_users()
        # 5 players + 3 center = 8 total roles.
        roles = {
            "Werewolf": 1,
            "Seer": 1,
            "Robber": 1,
            "Villager": 2,
            "Minion": 1,
            "Drunk": 1,
            "Tanner": 1,
        }
        lobby = _create_lobby(host, others, roles)

        ids = [host.id] + [u.id for u in others]
        # Assign 5 players explicitly; remaining 3 to center.
        player_roles = {
            str(ids[0]): "Werewolf",
            str(ids[1]): "Seer",
            str(ids[2]): "Robber",
            str(ids[3]): "Villager",
            str(ids[4]): "Minion",
        }
        center = ["Villager", "Drunk", "Tanner"]

        api_client.force_authenticate(user=host)
        with _no_channels():
            resp = api_client.post(
                _start_url(lobby.code),
                {
                    "debug": {
                        "forced_assignment": {
                            "player_roles": player_roles,
                            "center": center,
                        }
                    }
                },
                format="json",
            )

        assert resp.status_code == status.HTTP_201_CREATED
        game = Game.objects.get(id=resp.data["game_id"])
        assert sorted(game.center_cards) == sorted(center)

        for uid, role in {
            ids[0]: "Werewolf",
            ids[1]: "Seer",
            ids[2]: "Robber",
            ids[3]: "Villager",
            ids[4]: "Minion",
        }.items():
            pr = PlayerRole.objects.get(game=game, user_id=uid)
            assert pr.original_role == role
            # current_role must equal original_role at game start (forced).
            assert pr.current_role == role

    @override_settings(DEBUG=True)
    def test_string_keys_are_int_coerced(self, api_client, db):
        """player_roles keys arrive as JSON strings and are int()-coerced."""
        host, others = _make_5_users()
        roles = {
            "Werewolf": 1,
            "Seer": 1,
            "Robber": 1,
            "Villager": 2,
            "Minion": 1,
            "Drunk": 1,
            "Tanner": 1,
        }
        lobby = _create_lobby(host, others, roles)
        ids = [host.id] + [u.id for u in others]
        player_roles = {
            str(ids[0]): "Werewolf",
            str(ids[1]): "Seer",
            str(ids[2]): "Robber",
            str(ids[3]): "Villager",
            str(ids[4]): "Minion",
        }
        api_client.force_authenticate(user=host)
        with _no_channels():
            resp = api_client.post(
                _start_url(lobby.code),
                {
                    "debug": {
                        "forced_assignment": {
                            "player_roles": player_roles,
                            "center": ["Villager", "Drunk", "Tanner"],
                        }
                    }
                },
                format="json",
            )
        assert resp.status_code == status.HTTP_201_CREATED
        game = Game.objects.get(id=resp.data["game_id"])
        assert PlayerRole.objects.get(game=game, user_id=ids[0]).original_role == (
            "Werewolf"
        )

    @override_settings(DEBUG=True)
    def test_multiset_mismatch_returns_400_and_creates_nothing(self, api_client, db):
        """A role multiset that doesn't match config -> 400, no game created."""
        host, others = _make_5_users()
        roles = {
            "Werewolf": 1,
            "Seer": 1,
            "Robber": 1,
            "Villager": 2,
            "Minion": 1,
            "Drunk": 1,
            "Tanner": 1,
        }
        lobby = _create_lobby(host, others, roles)
        ids = [host.id] + [u.id for u in others]
        # Two Werewolves but config only allows one -> mismatch.
        player_roles = {
            str(ids[0]): "Werewolf",
            str(ids[1]): "Werewolf",
            str(ids[2]): "Robber",
            str(ids[3]): "Villager",
            str(ids[4]): "Minion",
        }
        api_client.force_authenticate(user=host)
        with _no_channels():
            resp = api_client.post(
                _start_url(lobby.code),
                {
                    "debug": {
                        "forced_assignment": {
                            "player_roles": player_roles,
                            "center": ["Villager", "Drunk", "Tanner"],
                        }
                    }
                },
                format="json",
            )
        assert resp.status_code == status.HTTP_400_BAD_REQUEST
        assert not Game.objects.exists()
        lobby.refresh_from_db()
        # Lobby must remain WAITING — the atomic create never ran.
        assert lobby.status == Lobby.Status.WAITING

    @override_settings(DEBUG=True)
    def test_missing_player_returns_400(self, api_client, db):
        """Every lobby player must appear exactly once -> else 400."""
        host, others = _make_5_users()
        roles = {
            "Werewolf": 1,
            "Seer": 1,
            "Robber": 1,
            "Villager": 2,
            "Minion": 1,
            "Drunk": 1,
            "Tanner": 1,
        }
        lobby = _create_lobby(host, others, roles)
        ids = [host.id] + [u.id for u in others]
        # Only 4 of 5 players present.
        player_roles = {
            str(ids[0]): "Werewolf",
            str(ids[1]): "Seer",
            str(ids[2]): "Robber",
            str(ids[3]): "Villager",
        }
        api_client.force_authenticate(user=host)
        with _no_channels():
            resp = api_client.post(
                _start_url(lobby.code),
                {
                    "debug": {
                        "forced_assignment": {
                            "player_roles": player_roles,
                            "center": ["Villager", "Drunk", "Tanner", "Minion"],
                        }
                    }
                },
                format="json",
            )
        assert resp.status_code == status.HTTP_400_BAD_REQUEST
        assert not Game.objects.exists()

    @override_settings(DEBUG=True)
    def test_wrong_center_length_returns_400(self, api_client, db):
        """center must be exactly 3 cards."""
        host, others = _make_5_users()
        roles = {
            "Werewolf": 1,
            "Seer": 1,
            "Robber": 1,
            "Villager": 2,
            "Minion": 1,
            "Drunk": 1,
            "Tanner": 1,
        }
        lobby = _create_lobby(host, others, roles)
        ids = [host.id] + [u.id for u in others]
        player_roles = {
            str(ids[0]): "Werewolf",
            str(ids[1]): "Seer",
            str(ids[2]): "Robber",
            str(ids[3]): "Villager",
            str(ids[4]): "Minion",
        }
        api_client.force_authenticate(user=host)
        with _no_channels():
            resp = api_client.post(
                _start_url(lobby.code),
                {
                    "debug": {
                        "forced_assignment": {
                            "player_roles": player_roles,
                            "center": ["Villager", "Drunk"],  # only 2
                        }
                    }
                },
                format="json",
            )
        assert resp.status_code == status.HTTP_400_BAD_REQUEST
        assert not Game.objects.exists()

    @override_settings(DEBUG=True)
    def test_unknown_role_returns_400_without_leaking_role_name(self, api_client, db):
        """An unknown role name -> 400 with a generic, non-leaky message."""
        host, others = _make_5_users()
        roles = {
            "Werewolf": 1,
            "Seer": 1,
            "Robber": 1,
            "Villager": 2,
            "Minion": 1,
            "Drunk": 1,
            "Tanner": 1,
        }
        lobby = _create_lobby(host, others, roles)
        ids = [host.id] + [u.id for u in others]
        player_roles = {
            str(ids[0]): "Vampire",  # not a v1 role
            str(ids[1]): "Seer",
            str(ids[2]): "Robber",
            str(ids[3]): "Villager",
            str(ids[4]): "Minion",
        }
        api_client.force_authenticate(user=host)
        with _no_channels():
            resp = api_client.post(
                _start_url(lobby.code),
                {
                    "debug": {
                        "forced_assignment": {
                            "player_roles": player_roles,
                            "center": ["Villager", "Drunk", "Tanner"],
                        }
                    }
                },
                format="json",
            )
        assert resp.status_code == status.HTTP_400_BAD_REQUEST
        # The error must not echo the offending (or any) role name.
        assert "Vampire" not in str(resp.data)
        assert "Werewolf" not in str(resp.data)

    @override_settings(DEBUG=True)
    def test_seed_is_reproducible(self, api_client, db):
        """The same seed produces the same assignment across two games."""

        def _start_with_seed(seed_value, tag):
            host = User.objects.create_user(
                username=f"seed_host_{tag}", password="pass"
            )
            others = [
                User.objects.create_user(username=f"seed_{tag}_p{i}", password="pass")
                for i in range(4)
            ]
            roles = {
                "Werewolf": 2,
                "Seer": 1,
                "Robber": 1,
                "Villager": 1,
                "Drunk": 1,
                "Insomniac": 1,
                "Troublemaker": 1,
            }
            lobby = _create_lobby(host, others, roles)
            api_client.force_authenticate(user=host)
            with _no_channels():
                resp = api_client.post(
                    _start_url(lobby.code),
                    {"debug": {"seed": seed_value}},
                    format="json",
                )
            assert resp.status_code == status.HTTP_201_CREATED
            game = Game.objects.get(id=resp.data["game_id"])
            # Map by ORDER of user creation so the two games are comparable.
            order = [host.id] + [u.id for u in others]
            roles_by_order = [
                PlayerRole.objects.get(game=game, user_id=uid).original_role
                for uid in order
            ]
            return roles_by_order, list(game.center_cards)

        a_roles, a_center = _start_with_seed(123456789, "a")
        b_roles, b_center = _start_with_seed(123456789, "b")
        assert a_roles == b_roles
        assert a_center == b_center

    @override_settings(DEBUG=True)
    def test_malformed_seed_returns_400_not_500(self, api_client, db):
        """A non-integer seed -> 400 (never a 500), and no game is created."""
        host, others = _make_5_users()
        roles = {
            "Werewolf": 2,
            "Seer": 1,
            "Robber": 1,
            "Villager": 1,
            "Drunk": 1,
            "Insomniac": 1,
            "Troublemaker": 1,
        }
        lobby = _create_lobby(host, others, roles)
        api_client.force_authenticate(user=host)
        with _no_channels():
            resp = api_client.post(
                _start_url(lobby.code),
                {"debug": {"seed": "not-a-number"}},
                format="json",
            )
        assert resp.status_code == status.HTTP_400_BAD_REQUEST
        assert not Game.objects.exists()

    def test_debug_false_ignores_forced_assignment(self, api_client, db):
        """With DEBUG=False the `debug` key is ignored; random assignment runs."""
        host, others = _make_5_users()
        roles = {
            "Werewolf": 1,
            "Seer": 1,
            "Robber": 1,
            "Villager": 2,
            "Minion": 1,
            "Drunk": 1,
            "Tanner": 1,
        }
        lobby = _create_lobby(host, others, roles)
        ids = [host.id] + [u.id for u in others]
        # A deliberately INVALID forced assignment (two Werewolves). If honored
        # it would 400; ignored, the game starts with a random valid assignment.
        player_roles = {
            str(ids[0]): "Werewolf",
            str(ids[1]): "Werewolf",
            str(ids[2]): "Robber",
            str(ids[3]): "Villager",
            str(ids[4]): "Minion",
        }
        api_client.force_authenticate(user=host)
        with _no_channels():
            resp = api_client.post(
                _start_url(lobby.code),
                {
                    "debug": {
                        "forced_assignment": {
                            "player_roles": player_roles,
                            "center": ["Villager", "Drunk", "Tanner"],
                        }
                    }
                },
                format="json",
            )
        # DEBUG=False -> override ignored -> normal random start succeeds.
        assert resp.status_code == status.HTTP_201_CREATED
        game = Game.objects.get(id=resp.data["game_id"])
        # Exactly one Werewolf, per the configured multiset (NOT the forced two).
        ww_count = PlayerRole.objects.filter(
            game=game, original_role="Werewolf"
        ).count() + game.center_cards.count("Werewolf")
        assert ww_count == 1


# ---------------------------------------------------------------------------
# B2 — Debug-state oracle
# ---------------------------------------------------------------------------


def _make_game_with_roles(players_roles, center_cards, phase=Phase.NIGHT, wave=0):
    """Create a game with explicit roles. players_roles: username -> role."""
    usernames = list(players_roles.keys())
    users = {
        uname: User.objects.create_user(
            username=uname, password="pass", display_name=uname.title()
        )
        for uname in usernames
    }
    host = users[usernames[0]]
    lobby = Lobby.objects.create(
        host=host, game_type="onuw", max_players=10, settings={"roles": {}}
    )
    for user in users.values():
        LobbyMember.objects.create(lobby=lobby, user=user)
    lobby.status = Lobby.Status.IN_GAME
    lobby.save()
    game = Game.objects.create(
        lobby=lobby,
        phase=phase,
        current_wave=wave,
        random_seed=42,
        settings=lobby.settings,
        center_cards=center_cards,
    )
    for uname, role in players_roles.items():
        PlayerRole.objects.create(
            game=game, user=users[uname], original_role=role, current_role=role
        )
    return game, users, host


class TestDebugStateOracle:
    @override_settings(DEBUG=True)
    def test_post_swap_current_role_is_exposed(self, api_client, db):
        """The oracle reports each player's post-swap current_role (truth)."""
        game, users, host = _make_game_with_roles(
            {"alice": "Robber", "bob": "Werewolf", "carol": "Villager"},
            ["Seer", "Drunk", "Tanner"],
        )
        # Simulate a Robber swap: alice now holds Werewolf, bob holds Robber.
        PlayerRole.objects.filter(game=game, user=users["alice"]).update(
            current_role="Werewolf"
        )
        PlayerRole.objects.filter(game=game, user=users["bob"]).update(
            current_role="Robber"
        )

        api_client.force_authenticate(user=host)
        resp = api_client.get(_debug_state_url(game.id))
        assert resp.status_code == status.HTTP_200_OK

        by_id = {p["user_id"]: p for p in resp.data["players"]}
        assert by_id[users["alice"].id]["original_role"] == "Robber"
        assert by_id[users["alice"].id]["current_role"] == "Werewolf"
        assert by_id[users["bob"].id]["original_role"] == "Werewolf"
        assert by_id[users["bob"].id]["current_role"] == "Robber"

    @override_settings(DEBUG=True)
    def test_tanner_team_is_neutral_not_tanner(self, api_client, db):
        """A Tanner's team token is 'neutral', never 'tanner'."""
        game, users, host = _make_game_with_roles(
            {"alice": "Tanner", "bob": "Werewolf", "carol": "Villager"},
            ["Seer", "Drunk", "Robber"],
        )
        api_client.force_authenticate(user=host)
        resp = api_client.get(_debug_state_url(game.id))
        by_id = {p["user_id"]: p for p in resp.data["players"]}
        assert by_id[users["alice"].id]["team"] == "neutral"
        assert by_id[users["bob"].id]["team"] == "werewolf"
        assert by_id[users["carol"].id]["team"] == "village"

    @override_settings(DEBUG=True)
    def test_votes_include_every_player_with_null_for_nonvoters(self, api_client, db):
        """votes has a key per player; null when they have not voted."""
        game, users, host = _make_game_with_roles(
            {"alice": "Villager", "bob": "Werewolf", "carol": "Seer"},
            ["Robber", "Drunk", "Tanner"],
            phase=Phase.VOTING,
            wave=0,
        )
        # alice votes for bob; bob and carol have not voted.
        PlayerRole.objects.filter(game=game, user=users["alice"]).update(
            vote_target=users["bob"], has_acted=True
        )
        api_client.force_authenticate(user=host)
        resp = api_client.get(_debug_state_url(game.id))
        votes = resp.data["votes"]
        assert set(votes.keys()) == {
            str(users["alice"].id),
            str(users["bob"].id),
            str(users["carol"].id),
        }
        assert votes[str(users["alice"].id)] == users["bob"].id
        assert votes[str(users["bob"].id)] is None
        assert votes[str(users["carol"].id)] is None

    @override_settings(DEBUG=True)
    def test_vote_locked_tells_a_pick_from_a_lock(self, api_client, db):
        """votes holds every stored pick; vote_locked says which are final."""
        game, users, host = _make_game_with_roles(
            {"alice": "Villager", "bob": "Werewolf", "carol": "Seer"},
            ["Robber", "Drunk", "Tanner"],
            phase=Phase.VOTING,
            wave=0,
        )
        PlayerRole.objects.filter(game=game, user=users["alice"]).update(
            vote_target=users["bob"], has_acted=True
        )
        PlayerRole.objects.filter(game=game, user=users["bob"]).update(
            vote_target=users["carol"]
        )
        api_client.force_authenticate(user=host)

        body = api_client.get(_debug_state_url(game.id)).data

        PlayerRole.objects.filter(game=game, user=users["carol"]).update(
            phase_ready=True
        )
        body = api_client.get(_debug_state_url(game.id)).data
        assert {p["display_name"]: p["ready"] for p in body["players"]} == {
            users["alice"].display_name or users["alice"].username: False,
            users["bob"].display_name or users["bob"].username: False,
            users["carol"].display_name or users["carol"].username: True,
        }
        assert body["votes"][str(users["bob"].id)] == users["carol"].id
        assert body["vote_locked"] == {
            str(users["alice"].id): True,
            str(users["bob"].id): False,
            str(users["carol"].id): False,
        }

    @override_settings(DEBUG=True)
    def test_current_wave_is_zero_outside_night(self, api_client, db):
        """current_wave is an int 0 outside the night phase (never null)."""
        game, _users, host = _make_game_with_roles(
            {"alice": "Villager", "bob": "Werewolf", "carol": "Seer"},
            ["Robber", "Drunk", "Tanner"],
            phase=Phase.DISCUSSION,
            wave=0,
        )
        api_client.force_authenticate(user=host)
        resp = api_client.get(_debug_state_url(game.id))
        assert resp.data["current_wave"] == 0
        assert resp.data["phase"] == "discussion"
        assert resp.data["results"] is None

    @override_settings(DEBUG=True)
    def test_doppelganger_copied_role_exposed(self, api_client, db):
        """A Doppelganger's copied role surfaces per player; null otherwise."""
        game, users, host = _make_game_with_roles(
            {"alice": "Doppelganger", "bob": "Werewolf", "carol": "Seer"},
            ["Robber", "Drunk", "Tanner"],
            phase=Phase.NIGHT,
            wave=1,
        )
        PlayerRole.objects.filter(game=game, user=users["alice"]).update(
            night_action_data={"copied_role": "Werewolf"}
        )
        api_client.force_authenticate(user=host)
        resp = api_client.get(_debug_state_url(game.id))
        by_id = {p["user_id"]: p for p in resp.data["players"]}
        assert by_id[users["alice"].id]["doppelganger_copied_role"] == "Werewolf"
        # Doppelganger-as-Werewolf resolves to the werewolf team.
        assert by_id[users["alice"].id]["team"] == "werewolf"
        assert by_id[users["bob"].id]["doppelganger_copied_role"] is None

    @override_settings(DEBUG=True)
    def test_night_actions_log_role_acting_as_is_action_time_not_current(
        self, api_client, db
    ):
        """role_acting_as is the role acted AS at action time, read from the
        persisted entry — NOT recomputed from the actor's current_role, which
        may have changed once their own card was swapped."""
        game, users, host = _make_game_with_roles(
            {"alice": "Robber", "bob": "Werewolf", "carol": "Villager"},
            ["Seer", "Drunk", "Tanner"],
            phase=Phase.DISCUSSION,
            wave=0,
        )
        # Alice acted AS Robber, then her own card became Werewolf via a later
        # swap. Recomputing from current_role would wrongly report "Werewolf".
        PlayerRole.objects.filter(game=game, user=users["alice"]).update(
            current_role="Werewolf"
        )
        game.night_actions_log = [
            {
                "wave": 3,
                "player_id": users["alice"].id,
                "action_type": "swap_with_player",
                "targets": {"player_id": users["bob"].id},
                "result": {"new_role": "Werewolf"},
                "timestamp_order": 1,
                "role_acting_as": "Robber",
            }
        ]
        game.save(update_fields=["night_actions_log"])
        api_client.force_authenticate(user=host)
        resp = api_client.get(_debug_state_url(game.id))
        log = resp.data["night_actions_log"]
        assert len(log) == 1
        entry = log[0]
        assert entry["wave"] == 3
        assert entry["player_id"] == users["alice"].id
        assert entry["action_type"] == "swap_with_player"
        assert entry["role_acting_as"] == "Robber"
        assert entry["timestamp_order"] == 1
        assert entry["made_by_server"] is False

    @override_settings(DEBUG=True)
    def test_night_actions_log_marks_a_move_the_server_made(self, api_client, db):
        """made_by_server is true only for an entry the server wrote for a
        player who timed out (the Drunk's seeded swap)."""
        game, users, host = _make_game_with_roles(
            {"alice": "Drunk", "bob": "Werewolf", "carol": "Villager"},
            ["Seer", "Robber", "Tanner"],
            phase=Phase.DISCUSSION,
            wave=0,
        )
        game.night_actions_log = [
            {
                "wave": 3,
                "player_id": users["alice"].id,
                "action_type": "swap_with_center",
                "targets": {"center_index": 1},
                "result": {},
                "timestamp_order": 1,
                "role_acting_as": "Drunk",
                "made_by_server": True,
            },
            {
                "wave": 2,
                "player_id": users["bob"].id,
                "action_type": "see_team",
                "targets": {},
                "result": {},
                "timestamp_order": 2,
                "role_acting_as": "Werewolf",
            },
        ]
        game.save(update_fields=["night_actions_log"])
        api_client.force_authenticate(user=host)
        log = api_client.get(_debug_state_url(game.id)).data["night_actions_log"]
        assert [e["made_by_server"] for e in log] == [True, False]

    @override_settings(DEBUG=True)
    def test_results_present_once_phase_results(self, api_client, db):
        """results is non-null with lowercase winning_teams once in RESULTS."""
        game, users, host = _make_game_with_roles(
            {"alice": "Villager", "bob": "Werewolf", "carol": "Seer"},
            ["Robber", "Drunk", "Tanner"],
            phase=Phase.RESULTS,
            wave=0,
        )
        game.results = {
            "winning_teams": ["village"],
            "reason": "A Werewolf was eliminated.",
            "eliminated_players": [users["bob"].id],
            "elimination_reasons": {str(users["bob"].id): "vote"},
            "player_outcomes": {str(users["alice"].id): "win"},
        }
        game.save(update_fields=["results"])
        api_client.force_authenticate(user=host)
        resp = api_client.get(_debug_state_url(game.id))
        assert resp.data["results"] is not None
        assert resp.data["results"]["winning_teams"] == ["village"]

    @override_settings(DEBUG=True)
    def test_pending_timers_lists_this_games_timers_and_the_host_handover(
        self, api_client, db
    ):
        """pending_timers names the game's own timers (prefix stripped, sorted)
        and the lobby's handover timer; another game's timers are not listed."""
        game, users, host = _make_game_with_roles(
            {"alice": "Villager", "bob": "Werewolf", "carol": "Seer"},
            ["Robber", "Drunk", "Tanner"],
            phase=Phase.NIGHT,
            wave=2,
        )
        later = timezone.now() + timedelta(hours=1)
        for key in (
            f"{game.id}:wave:2",
            f"{game.id}:grace:{users['bob'].id}",
            host_module.timer_key(game.lobby),
            "00000000-0000-0000-0000-000000000001:wave:2",
            host_module.timer_key(game.lobby.pk + 1),
        ):
            ScheduledTimer.objects.create(
                key=key, token="t", job="x", params={}, due_at=later
            )
        api_client.force_authenticate(user=host)
        resp = api_client.get(_debug_state_url(game.id))
        assert resp.data["pending_timers"] == sorted(
            ["wave:2", f"grace:{users['bob'].id}", "host_handover"]
        )

    @override_settings(DEBUG=True)
    def test_pending_timers_is_empty_without_timers(self, api_client, db):
        game, _users, host = _make_game_with_roles(
            {"alice": "Villager", "bob": "Werewolf", "carol": "Seer"},
            ["Robber", "Drunk", "Tanner"],
        )
        api_client.force_authenticate(user=host)
        resp = api_client.get(_debug_state_url(game.id))
        assert resp.data["pending_timers"] == []

    @override_settings(DEBUG=True)
    def test_non_player_cannot_read_oracle(self, api_client, db):
        """Even in DEBUG, a non-player gets 403 (membership bar)."""
        game, _users, _host = _make_game_with_roles(
            {"alice": "Villager", "bob": "Werewolf", "carol": "Seer"},
            ["Robber", "Drunk", "Tanner"],
        )
        outsider = User.objects.create_user(username="outsider", password="pass")
        api_client.force_authenticate(user=outsider)
        resp = api_client.get(_debug_state_url(game.id))
        assert resp.status_code == status.HTTP_403_FORBIDDEN
        # The 403 body must not contain any player's role.
        assert "Werewolf" not in str(resp.data)

    def test_debug_false_returns_403(self, api_client, db):
        """The oracle is inert in production (DEBUG=False -> 403)."""
        game, _users, host = _make_game_with_roles(
            {"alice": "Villager", "bob": "Werewolf", "carol": "Seer"},
            ["Robber", "Drunk", "Tanner"],
        )
        api_client.force_authenticate(user=host)
        resp = api_client.get(_debug_state_url(game.id))
        assert resp.status_code == status.HTTP_403_FORBIDDEN
        # Must not leak any role even to a real player when gated off.
        assert "Werewolf" not in str(resp.data)


# ---------------------------------------------------------------------------
# B3 — Fire-timer hook
# ---------------------------------------------------------------------------


class TestFireTimer:
    def _register_fake_timer(self, key, fn):
        """Store a pending timer row whose job is ``fn`` (never armed).

        fire_timer claims the row (ignoring its due time) and runs the job
        synchronously.
        """
        timers.JOBS["debug_test_job"] = fn
        return ScheduledTimer.objects.create(
            key=key,
            token="t",
            job="debug_test_job",
            params={},
            due_at=timezone.now() + timedelta(hours=1),
        )

    @override_settings(DEBUG=True)
    @pytest.mark.uses_timers
    def test_fires_named_wave_timer(self, api_client, db):
        """Firing 'wave:2' invokes the registered callback and reports fired."""
        game, _users, host = _make_game_with_roles(
            {"alice": "Villager", "bob": "Werewolf", "carol": "Seer"},
            ["Robber", "Drunk", "Tanner"],
            phase=Phase.NIGHT,
            wave=2,
        )
        called = MagicMock()
        self._register_fake_timer(f"{game.id}:wave:2", called)

        api_client.force_authenticate(user=host)
        resp = api_client.post(
            _fire_timer_url(game.id), {"key": "wave:2"}, format="json"
        )
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data == {"fired": True, "key": "wave:2"}
        called.assert_called_once()
        # The fired timer is removed from the registry's reachable set only via
        # cancel; the callback ran exactly once.

    @override_settings(DEBUG=True)
    @pytest.mark.uses_timers
    def test_current_resolves_single_key(self, api_client, db):
        """'current' resolves the single pending key under the game prefix."""
        game, _users, host = _make_game_with_roles(
            {"alice": "Villager", "bob": "Werewolf", "carol": "Seer"},
            ["Robber", "Drunk", "Tanner"],
            phase=Phase.DISCUSSION,
            wave=0,
        )
        called = MagicMock()
        self._register_fake_timer(f"{game.id}:discussion", called)

        api_client.force_authenticate(user=host)
        resp = api_client.post(
            _fire_timer_url(game.id), {"key": "current"}, format="json"
        )
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["fired"] is True
        assert resp.data["key"] == "discussion"
        called.assert_called_once()

    @override_settings(DEBUG=True)
    @pytest.mark.uses_timers
    def test_current_rejects_when_zero_keys(self, api_client, db):
        """'current' with no pending timer -> 400 (ambiguous)."""
        game, _users, host = _make_game_with_roles(
            {"alice": "Villager", "bob": "Werewolf", "carol": "Seer"},
            ["Robber", "Drunk", "Tanner"],
        )
        api_client.force_authenticate(user=host)
        resp = api_client.post(
            _fire_timer_url(game.id), {"key": "current"}, format="json"
        )
        assert resp.status_code == status.HTTP_400_BAD_REQUEST

    @override_settings(DEBUG=True)
    @pytest.mark.uses_timers
    def test_current_rejects_when_multiple_keys(self, api_client, db):
        """'current' with >1 pending timer -> 400 (ambiguous)."""
        game, _users, host = _make_game_with_roles(
            {"alice": "Villager", "bob": "Werewolf", "carol": "Seer"},
            ["Robber", "Drunk", "Tanner"],
        )
        self._register_fake_timer(f"{game.id}:wave:1", MagicMock())
        self._register_fake_timer(f"{game.id}:wave:2", MagicMock())
        api_client.force_authenticate(user=host)
        resp = api_client.post(
            _fire_timer_url(game.id), {"key": "current"}, format="json"
        )
        assert resp.status_code == status.HTTP_400_BAD_REQUEST

    @override_settings(DEBUG=True)
    @pytest.mark.uses_timers
    def test_missing_key_is_safe_noop(self, api_client, db):
        """Firing a key with no registered timer is a safe no-op (fired=False)."""
        game, _users, host = _make_game_with_roles(
            {"alice": "Villager", "bob": "Werewolf", "carol": "Seer"},
            ["Robber", "Drunk", "Tanner"],
            phase=Phase.NIGHT,
            wave=2,
        )
        api_client.force_authenticate(user=host)
        resp = api_client.post(
            _fire_timer_url(game.id), {"key": "wave:2"}, format="json"
        )
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data == {"fired": False, "key": "wave:2"}

    @override_settings(DEBUG=True)
    @pytest.mark.uses_timers
    def test_already_fired_timer_does_not_double_transition(
        self, api_client, db, django_capture_on_commit_callbacks
    ):
        """Firing the real window-2 timer closes the window; firing again no-ops.

        The night's timers are scheduled after the transaction commits, so the
        test runs those callbacks (pytest wraps each test in a transaction that
        never commits). The first fire closes window 2 and moves the game to
        discussion; the closing step cancels the window's timer, so the second
        fire finds nothing pending and must not transition anything again.
        """
        game, _users, host = _make_game_with_roles(
            {"alice": "Werewolf", "bob": "Seer", "carol": "Villager"},
            ["Robber", "Drunk", "Tanner"],
            phase=Phase.NIGHT,
            wave=2,
        )
        # Schedule the real window-2 timer via the service (no channel layer).
        with _no_channels(), django_capture_on_commit_callbacks(execute=True):
            night_window.send_wave_prompts(game, 2)
        assert f"{game.id}:wave:2" in timers._registry

        api_client.force_authenticate(user=host)
        with _no_channels(), django_capture_on_commit_callbacks(execute=True):
            first = api_client.post(
                _fire_timer_url(game.id), {"key": "wave:2"}, format="json"
            )
        assert first.status_code == status.HTTP_200_OK
        assert first.data == {"fired": True, "key": "wave:2"}

        game.refresh_from_db()
        # Window 2 is the last window: closing it opens discussion.
        assert game.phase == Phase.DISCUSSION
        assert game.current_wave == 0
        log_after_first = list(game.night_actions_log)

        # Firing the same (now stale) key again must be a safe no-op.
        with _no_channels(), django_capture_on_commit_callbacks(execute=True):
            second = api_client.post(
                _fire_timer_url(game.id), {"key": "wave:2"}, format="json"
            )
        assert second.status_code == status.HTTP_200_OK
        assert second.data == {"fired": False, "key": "wave:2"}
        game.refresh_from_db()
        assert game.phase == Phase.DISCUSSION
        assert list(game.night_actions_log) == log_after_first

    @override_settings(DEBUG=True)
    @pytest.mark.uses_timers
    def test_fire_current_closes_the_open_window(
        self, api_client, db, django_capture_on_commit_callbacks
    ):
        """'current' closes the open window even when the minimum length has not passed."""
        game, _users, host = _make_game_with_roles(
            {"alice": "Werewolf", "bob": "Seer", "carol": "Villager"},
            ["Robber", "Drunk", "Tanner"],
            phase=Phase.NIGHT,
            wave=2,
        )
        game.settings = {"night_min_window_seconds": 3600}
        game.save(update_fields=["settings"])
        with _no_channels(), django_capture_on_commit_callbacks(execute=True):
            night_window.send_wave_prompts(game, 2)

        api_client.force_authenticate(user=host)
        with _no_channels(), django_capture_on_commit_callbacks(execute=True):
            resp = api_client.post(
                _fire_timer_url(game.id), {"key": "current"}, format="json"
            )
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["fired"] is True
        game.refresh_from_db()
        assert game.phase == Phase.DISCUSSION

    @override_settings(DEBUG=True)
    def test_invalid_key_returns_400(self, api_client, db):
        """A malformed key -> 400."""
        game, _users, host = _make_game_with_roles(
            {"alice": "Villager", "bob": "Werewolf", "carol": "Seer"},
            ["Robber", "Drunk", "Tanner"],
        )
        api_client.force_authenticate(user=host)
        for bad in ["wave:", "wave:abc", "bogus", "", None]:
            resp = api_client.post(
                _fire_timer_url(game.id), {"key": bad}, format="json"
            )
            assert resp.status_code == status.HTTP_400_BAD_REQUEST, bad

    @override_settings(DEBUG=True)
    def test_non_player_cannot_fire_timer(self, api_client, db):
        """A non-player gets 403 even in DEBUG."""
        game, _users, _host = _make_game_with_roles(
            {"alice": "Villager", "bob": "Werewolf", "carol": "Seer"},
            ["Robber", "Drunk", "Tanner"],
        )
        outsider = User.objects.create_user(username="ft_outsider", password="pass")
        api_client.force_authenticate(user=outsider)
        resp = api_client.post(
            _fire_timer_url(game.id), {"key": "current"}, format="json"
        )
        assert resp.status_code == status.HTTP_403_FORBIDDEN

    def test_debug_false_returns_403(self, api_client, db):
        """The fire-timer hook is inert in production (DEBUG=False -> 403)."""
        game, _users, host = _make_game_with_roles(
            {"alice": "Villager", "bob": "Werewolf", "carol": "Seer"},
            ["Robber", "Drunk", "Tanner"],
        )
        api_client.force_authenticate(user=host)
        resp = api_client.post(
            _fire_timer_url(game.id), {"key": "current"}, format="json"
        )
        assert resp.status_code == status.HTTP_403_FORBIDDEN


# ---------------------------------------------------------------------------
# parse_forced_assignment — pure structural guards (no DB)
# ---------------------------------------------------------------------------


class TestParseForcedAssignmentGuards:
    """Each guard raises ForcedAssignmentError with a non-leaky message.

    No malformed body silently falls back to a random shuffle — every bad shape
    raises, and the caller maps the raise to a 400.
    """

    _ROLE_COUNTS = {"Werewolf": 1, "Seer": 1, "Villager": 1}
    _PLAYER_IDS = [1, 2]

    @pytest.mark.parametrize(
        "forced",
        [
            None,
            [],
            "nope",
            {"player_roles": [], "center": ["Seer", "Villager", "Werewolf"]},
            {"player_roles": {"1": "Werewolf"}, "center": "Seer"},
            {"player_roles": {"1": "Werewolf"}, "center": ["Seer"]},  # len != 3
            {"player_roles": {"x": "Werewolf"}, "center": ["a", "b", "c"]},  # bad id
            {"player_roles": {"1": 5}, "center": ["a", "b", "c"]},  # role not str
        ],
    )
    def test_structural_guards_raise(self, forced):
        from apps.onuw.debug import ForcedAssignmentError, parse_forced_assignment

        with pytest.raises(ForcedAssignmentError) as exc:
            parse_forced_assignment(forced, self._ROLE_COUNTS, self._PLAYER_IDS)
        # Message never names a role.
        assert "Werewolf" not in str(exc.value)
        assert "Seer" not in str(exc.value)


class TestOracleOrphanLogEntry:
    """The oracle tolerates a log entry whose player is not in the roster."""

    @override_settings(DEBUG=True)
    def test_legacy_log_entry_without_role_acting_as_is_null(self, api_client, db):
        """A legacy entry written before role_acting_as existed surfaces as
        null rather than crashing or guessing."""
        game, users, host = _make_game_with_roles(
            {"alice": "Villager", "bob": "Werewolf", "carol": "Seer"},
            ["Robber", "Drunk", "Tanner"],
            phase=Phase.DISCUSSION,
            wave=0,
        )
        # A log entry with no role_acting_as key (predates the field).
        game.night_actions_log = [
            {
                "wave": 3,
                "player_id": users["carol"].id,
                "action_type": "peek_player",
                "targets": {},
                "result": {},
                "timestamp_order": 1,
            }
        ]
        game.save(update_fields=["night_actions_log"])
        api_client.force_authenticate(user=host)
        resp = api_client.get(_debug_state_url(game.id))
        assert resp.status_code == status.HTTP_200_OK
        entry = resp.data["night_actions_log"][0]
        assert entry["player_id"] == users["carol"].id
        assert entry["role_acting_as"] is None
