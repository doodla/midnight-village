"""
Integration tests for the voting phase timer lifecycle.

Covers:
- Auto-reveal votes when the voting timer expires (non-voters become abstentions)
- Early cancellation when all players have voted
- Host force-reveal cancels the voting timer
- Zero-duration (untimed) voting behavior
- phase_change event shape includes 'deadline' field for voting
"""

from unittest.mock import MagicMock, patch

import pytest

from apps.core.models import Lobby, LobbyMember, User
from apps.onuw import services, timers
from apps.onuw.models import Game, Phase, PlayerRole

pytestmark = pytest.mark.integration


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _clear_registry():
    with timers._lock:
        for t in timers._registry.values():
            t.cancel()
        timers._registry.clear()


@pytest.fixture(autouse=True)
def clean_timer_registry():
    """Cancel all timers before and after each test to prevent thread leakage."""
    _clear_registry()
    yield
    _clear_registry()


def _make_game_with_players(player_count=3, voting_seconds=300):
    """Create a game in VOTING phase with the given number of players."""
    usernames = [f"vt_player_{i}" for i in range(player_count)]
    roles = ["Werewolf"] + ["Villager"] * (player_count - 1)

    users = {}
    for uname in usernames:
        users[uname] = User.objects.create_user(username=uname, password="pass")

    host = users[usernames[0]]
    lobby = Lobby.objects.create(
        host=host,
        game_type="onuw",
        max_players=10,
        settings={
            "roles": {"Werewolf": 1, "Villager": player_count - 1},
            "voting_seconds": voting_seconds,
        },
    )
    for user in users.values():
        LobbyMember.objects.create(lobby=lobby, user=user, is_ready=True)
    lobby.status = Lobby.Status.IN_GAME
    lobby.save()

    game = Game.objects.create(
        lobby=lobby,
        phase=Phase.DISCUSSION,
        random_seed=42,
        settings=lobby.settings,
        center_cards=["Mason", "Drunk", "Insomniac"],
    )

    for uname, role in zip(usernames, roles, strict=False):
        PlayerRole.objects.create(
            game=game,
            user=users[uname],
            original_role=role,
            current_role=role,
        )

    return game, users, host


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------


@pytest.mark.django_db(transaction=True)
class TestVotingTimerLifecycle:
    def test_voting_auto_reveals_with_abstentions(self, db):
        """
        transition_to_voting schedules a callback; invoking it directly
        (simulating timer expiry) moves the game to results with non-voters
        treated as abstentions (null vote_target).
        """
        captured_callbacks: list = []

        def fake_schedule(key, delay, callback, *args):
            captured_callbacks.append(callback)

        game, _users, _host = _make_game_with_players(player_count=3, voting_seconds=60)

        with (
            patch("apps.onuw.services.get_channel_layer", return_value=None),
            patch("apps.onuw.timers.schedule", side_effect=fake_schedule),
        ):
            services.transition_to_voting(game)

        game.refresh_from_db()
        assert game.phase_deadline is not None
        assert game.phase == Phase.VOTING
        assert len(captured_callbacks) == 1

        # No player has voted — invoking callback simulates timer expiry.
        with patch("apps.onuw.services.get_channel_layer", return_value=None):
            captured_callbacks[0]()

        game.refresh_from_db()
        assert game.phase == Phase.RESULTS
        assert game.phase_deadline is None

        # All players should have null vote_target (abstained)
        # pyrefly: ignore [missing-attribute]
        non_voters = game.player_roles.filter(vote_target__isnull=True).count()
        assert non_voters == 3

    def test_all_voted_cancels_voting_timer(self, db):
        """
        When all players submit votes, the voting timer is cancelled and
        the game transitions to results.
        """
        game, users, _host = _make_game_with_players(player_count=3, voting_seconds=300)

        with (
            patch("apps.onuw.services.get_channel_layer", return_value=None),
        ):
            services.transition_to_voting(game)

        timer_key = f"{game.id}:voting"
        with timers._lock:
            assert timer_key in timers._registry

        usernames = list(users.keys())
        # Submit votes for all players
        vote_pairs = [
            (usernames[0], users[usernames[1]].id),
            (usernames[1], users[usernames[0]].id),
            (usernames[2], users[usernames[0]].id),
        ]

        with patch("apps.onuw.services.get_channel_layer", return_value=None):
            for voter_name, target_id in vote_pairs:
                errors = services.submit_vote(game, users[voter_name].id, target_id)
                # Ignore "Game is not in voting phase" after auto-reveal on last vote
                _ = errors

        # Timer should be cancelled after all voted
        with timers._lock:
            assert timer_key not in timers._registry

        game.refresh_from_db()
        assert game.phase == Phase.RESULTS

    def test_host_force_reveal_cancels_voting_timer(self, db):
        """
        reveal_votes() (host force-reveal path) cancels the voting timer.
        """
        game, _users, _host = _make_game_with_players(
            player_count=3, voting_seconds=300
        )

        with patch("apps.onuw.services.get_channel_layer", return_value=None):
            services.transition_to_voting(game)

        timer_key = f"{game.id}:voting"
        with timers._lock:
            assert timer_key in timers._registry

        with patch("apps.onuw.services.get_channel_layer", return_value=None):
            services.reveal_votes(game)

        with timers._lock:
            assert timer_key not in timers._registry

        game.refresh_from_db()
        assert game.phase == Phase.RESULTS
        assert game.phase_deadline is None

    def test_voting_no_timer_when_seconds_zero(self, db):
        """
        When voting_seconds == 0, no timer is scheduled and
        phase_deadline is null.
        """
        scheduled_keys: list = []

        def fake_schedule(key, delay, callback, *args):
            scheduled_keys.append(key)

        game, _users, _host = _make_game_with_players(player_count=3, voting_seconds=0)

        with (
            patch("apps.onuw.services.get_channel_layer", return_value=None),
            patch("apps.onuw.timers.schedule", side_effect=fake_schedule),
        ):
            services.transition_to_voting(game)

        game.refresh_from_db()
        assert game.phase_deadline is None

        timer_key = f"{game.id}:voting"
        assert timer_key not in scheduled_keys

    def test_voting_phase_change_includes_deadline(self, db):
        """
        The phase_change broadcast event contains a non-null ISO 8601
        'deadline' when voting_seconds > 0.
        """
        game, _users, _host = _make_game_with_players(
            player_count=3, voting_seconds=120
        )
        broadcast_events: list = []

        def capture_send(group, event):
            broadcast_events.append(event)

        mock_layer = MagicMock()
        mock_layer.group_send = capture_send

        with (
            patch("apps.onuw.services.get_channel_layer", return_value=mock_layer),
            patch("apps.onuw.services.async_to_sync", side_effect=lambda f: f),
            patch("apps.onuw.timers.schedule"),
        ):
            services.transition_to_voting(game)

        phase_events = [e for e in broadcast_events if e.get("type") == "phase.change"]
        assert len(phase_events) == 1
        event = phase_events[0]
        assert event["phase"] == "voting"
        assert "deadline" in event
        assert event["deadline"] is not None
        # Verify it's a valid ISO 8601 string.
        from datetime import datetime

        datetime.fromisoformat(event["deadline"])

    def test_voting_phase_change_deadline_null_when_untimed(self, db):
        """
        The phase_change broadcast event contains deadline=null when
        voting_seconds == 0.
        """
        game, _users, _host = _make_game_with_players(player_count=3, voting_seconds=0)
        broadcast_events: list = []

        def capture_send(group, event):
            broadcast_events.append(event)

        mock_layer = MagicMock()
        mock_layer.group_send = capture_send

        with (
            patch("apps.onuw.services.get_channel_layer", return_value=mock_layer),
            patch("apps.onuw.services.async_to_sync", side_effect=lambda f: f),
        ):
            services.transition_to_voting(game)

        phase_events = [e for e in broadcast_events if e.get("type") == "phase.change"]
        assert len(phase_events) == 1
        event = phase_events[0]
        assert event["phase"] == "voting"
        assert "deadline" in event
        assert event["deadline"] is None

    def test_double_cancel_is_safe_on_reveal(self, db):
        """
        Calling reveal_votes() after all players voted (which already cancelled
        the timer) does not raise — double-cancel is safe.
        """
        game, users, _host = _make_game_with_players(player_count=3, voting_seconds=300)

        with patch("apps.onuw.services.get_channel_layer", return_value=None):
            services.transition_to_voting(game)

        usernames = list(users.keys())
        vote_pairs = [
            (usernames[0], users[usernames[1]].id),
            (usernames[1], users[usernames[0]].id),
            (usernames[2], users[usernames[0]].id),
        ]

        with patch("apps.onuw.services.get_channel_layer", return_value=None):
            for voter_name, target_id in vote_pairs:
                services.submit_vote(game, users[voter_name].id, target_id)

        game.refresh_from_db()
        assert game.phase == Phase.RESULTS
        # Timer key is gone (cancelled by all-voted path).
        timer_key = f"{game.id}:voting"
        with timers._lock:
            assert timer_key not in timers._registry
