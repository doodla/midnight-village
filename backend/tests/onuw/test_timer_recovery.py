"""
Countdowns survive a server restart.

The timer registry lives in one process's memory; the stored deadlines
(``Game.phase_deadline``, ``Game.night_window_opened_at``) are the source of
truth. A "restart" here is clearing the recorded timers, then recovering from
the database.

Covered: the night window deadline, the deferred "everyone has acted but the
minimum has not passed" close, the fixed Doppelganger window, an overdue
deadline (fires promptly), discussion and voting, idempotence, a stale window
callback that must not close the next window, the lazy repair on GET /me/, the
start-up hook, and presence reset on restart.
"""

from datetime import timedelta
from typing import Any
from unittest.mock import patch

from django.core.exceptions import ImproperlyConfigured
from django.db import OperationalError
from django.urls import reverse
from django.utils import timezone

import pytest

from apps.core import timers
from apps.onuw import presence, recovery, services
from apps.onuw.models import Game, Phase, PlayerRole, SocketPresence
from tests.onuw.stages import staged
from tests.onuw.test_night_windows import Night, _Recorder

pytestmark = pytest.mark.integration

ROLES = {
    "wolf": "Werewolf",
    "seer": "Seer",
    "robber": "Robber",
    "villager": "Villager",
}


def connect_after_restart(night: Night, name: str) -> None:
    with night.committed():
        services.register_connection(night.game.id, night.users[name].id)


def _restart(night: Night) -> None:
    """Pretend the server restarted: every in-memory timer is gone."""
    night.scheduled.clear()


def _recover(night: Night) -> None:
    with night.committed():
        recovery.recover_timers()
    night.refresh()


def _timer(night: Night, suffix: str) -> tuple[float, Any]:
    """(delay, callback) of the one timer scheduled under ``<game id>:<suffix>``."""
    key = f"{night.game.id}:{suffix}"
    found = [(delay, cb) for k, delay, cb in night.scheduled if k == key]
    assert len(found) == 1, f"expected exactly one timer for {suffix}, got {found}"
    return found[0]


def _phase_timer_keys(night: Night) -> list[str]:
    """Keys of the scheduled phase / window timers (not grace or host timers)."""
    return [
        k
        for k, _, _ in night.scheduled
        if ":grace:" not in k and not k.startswith("lobby:")
    ]


ALLOWANCE = recovery.RECOVERY_RECONNECT_ALLOWANCE_SECONDS


def _reconnect_everyone_quietly(night: Night) -> None:
    """Every phone is back (set directly, so no presence re-check runs)."""
    PlayerRole.objects.filter(game=night.game).update(disconnected_at=None)
    now = timezone.now()
    for name in ROLES:
        SocketPresence.objects.update_or_create(
            channel_name=f"quiet-{night.users[name].id}",
            defaults={
                "user": night.users[name],
                "game": night.game,
                "connected_at": now,
                "last_seen": now,
            },
        )


def _everyone_just_noticed_gone(night: Night) -> None:
    """The presence checks have just noticed every phone is gone (no restart
    reset exists: this is what the stale rows lead to)."""
    SocketPresence.objects.filter(game=night.game).delete()
    PlayerRole.objects.filter(game=night.game).update(disconnected_at=timezone.now())


def _set_deadline(night: Night, seconds_from_now: float) -> None:
    Game.objects.filter(id=night.game.id).update(
        phase_deadline=timezone.now() + timedelta(seconds=seconds_from_now)
    )
    night.refresh()


def _act_everyone(night: Night) -> None:
    """Every phone with a choice chooses the harmless thing in window 2."""
    night.post("wolf", "see_team")
    night.post("seer", "skip")
    night.post("robber", "skip")
    night.post("villager", "none")


# ── Night windows ────────────────────────────────────────────────────────────


class TestNightWindowRecovery:
    def test_open_window_gets_its_deadline_timer_back_after_a_restart(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=30)
        night.start()
        deadline = night.refresh().phase_deadline
        assert deadline is not None

        _restart(night)
        _recover(night)

        delay, _ = _timer(night, "wave:2")
        assert 0 < delay <= 30
        assert delay == pytest.approx(
            (deadline - timezone.now()).total_seconds(), abs=2
        )

    def test_recovered_deadline_timer_closes_the_window(self, make_night) -> None:
        night = make_night(ROLES, night_wave_seconds=30)
        night.start()
        night.post("seer", "skip")
        _restart(night)
        _recover(night)

        _, callback = _timer(night, "wave:2")
        with night.committed():
            callback()

        assert night.refresh().phase == Phase.DISCUSSION
        # The two who never chose were treated as a timeout (the wolf still
        # sees the team, the Robber is skipped).
        assert night.results("wolf")
        assert night.results("robber")[0]["action_type"] == "skip"

    def test_overdue_deadline_is_not_lost_and_gets_a_reconnect_allowance(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=30)
        night.start()
        _set_deadline(night, -45)  # the server was down past the deadline
        _restart(night)

        _recover(night)

        # Not at once (no phone is back yet): the allowance from now, persisted
        # so clients show the right countdown.
        delay, callback = _timer(night, "wave:2")
        assert ALLOWANCE - 1 < delay <= ALLOWANCE
        stored = (night.game.phase_deadline - timezone.now()).total_seconds()
        assert ALLOWANCE - 1 < stored <= ALLOWANCE
        with night.committed():
            callback()
        assert night.refresh().phase == Phase.DISCUSSION

    def test_a_deadline_further_away_than_the_allowance_is_left_alone(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=60)
        night.start()
        _set_deadline(night, 40)
        before = night.refresh().phase_deadline
        _restart(night)

        _recover(night)

        assert night.game.phase_deadline == before
        delay, _ = _timer(night, "wave:2")
        assert 39 < delay <= 40

    def test_a_deadline_closer_than_the_allowance_is_moved_out_to_it(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=60)
        night.start()
        _set_deadline(night, 4)
        _restart(night)

        _recover(night)

        delay, _ = _timer(night, "wave:2")
        assert ALLOWANCE - 1 < delay <= ALLOWANCE

    @pytest.mark.parametrize("acted", [False, True])
    def test_the_allowance_is_the_same_whatever_the_doppelganger_did(
        self, make_night, acted: bool
    ) -> None:
        """Window 1's length says nothing about her: the extension ignores her."""
        night = make_night(
            {"d": "Doppelganger", "s": "Seer", "w": "Werewolf", "v": "Villager"},
            ["Robber", "Tanner", "Hunter"],
            night_doppelganger_window_seconds=10,
            night_wave_seconds=30,
        )
        night.start()
        if acted:
            night.post("d", "peek_player", {"player_id": night.users["s"].id})
        _restart(night)

        _recover(night)

        assert night.game.current_wave == 1
        delay, _ = _timer(night, "wave:1")
        assert ALLOWANCE - 1 < delay <= ALLOWANCE  # the same range either way

    def test_everyone_acted_but_minimum_not_passed_gets_its_deferred_close_back(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=30, night_min_window_seconds=8)
        night.start()
        _act_everyone(night)
        night.refresh()
        assert night.game.phase == Phase.NIGHT  # held for the minimum length
        night.pretend_window_opened(3)
        _restart(night)

        _recover(night)

        delay, callback = _timer(night, "wave:2")
        # Due at the minimum length (about 5 s away), not at the 30 s deadline.
        assert 3 < delay <= 5.5
        _reconnect_everyone_quietly(night)
        with night.committed():
            callback()
        assert night.refresh().phase == Phase.DISCUSSION

    def test_deferred_close_whose_minimum_has_passed_is_due_at_once(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=30, night_min_window_seconds=8)
        night.start()
        _act_everyone(night)
        night.pretend_window_opened(20)
        _restart(night)

        _recover(night)

        delay, callback = _timer(night, "wave:2")
        assert delay == 0
        _reconnect_everyone_quietly(night)
        with night.committed():
            callback()
        assert night.refresh().phase == Phase.DISCUSSION

    def test_that_close_waits_for_phones_that_have_not_reconnected_yet(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=30, night_min_window_seconds=8)
        night.start()
        _act_everyone(night)
        night.pretend_window_opened(20)
        _restart(night)
        _recover(night)
        _everyone_just_noticed_gone(
            night
        )  # every phone is "dropped" until it reconnects
        _, early_close = _timer(night, "wave:2")
        night.scheduled.clear()

        with night.committed():
            early_close()

        assert night.refresh().phase == Phase.NIGHT  # not closed on nobody
        delay, _ = _timer(night, "wave:2")  # its own deadline is back
        assert 0 < delay <= 30
        # Once the phones are back, the last one in closes it.
        for name in ROLES:
            connect_after_restart(night, name)
        assert night.refresh().phase == Phase.DISCUSSION

    def test_window_still_waiting_for_someone_keeps_only_its_deadline(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=30, night_min_window_seconds=8)
        night.start()
        night.post("seer", "skip")  # wolf and robber have not acted
        night.pretend_window_opened(20)
        _restart(night)

        _recover(night)

        delay, _ = _timer(night, "wave:2")
        assert delay > 8  # the deadline, not a minimum-length close

    def test_window_without_a_deadline_and_not_ready_has_no_timer(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=0)
        night.start()
        night.post("seer", "skip")
        _restart(night)

        _recover(night)

        assert not [k for k, _, _ in night.scheduled if ":wave:" in k]
        # ...the host can still close it.
        assert night.host_close_window().status_code == 200

    def test_doppelganger_window_recovers_with_only_its_fixed_deadline(
        self, make_night
    ) -> None:
        night = make_night(
            {"d": "Doppelganger", "s": "Seer", "w": "Werewolf", "v": "Villager"},
            night_doppelganger_window_seconds=10,
            night_min_window_seconds=0,
        )
        night.start()
        assert night.game.current_wave == 1
        _restart(night)

        _recover(night)

        delay, callback = _timer(night, "wave:1")
        assert ALLOWANCE - 1 < delay <= ALLOWANCE  # 10 s left: moved out to 15
        # Nobody can act yet, so a "ready" window must still not close early.
        assert _phase_timer_keys(night) == [f"{night.game.id}:wave:1"]
        with night.committed():
            callback()
        assert night.refresh().current_wave == 2

    def test_stale_window_one_callback_cannot_close_window_two(
        self, make_night
    ) -> None:
        night = make_night(
            {"d": "Doppelganger", "s": "Seer", "w": "Werewolf", "v": "Villager"},
            night_doppelganger_window_seconds=10,
            night_wave_seconds=30,
        )
        night.start()
        _, stale = _timer(night, "wave:1")
        night.host_close_window()  # window 1 closes; window 2 opens
        assert night.refresh().current_wave == 2

        with night.committed():
            stale()  # e.g. a worker that recovered window 1's timer earlier

        assert night.refresh().phase == Phase.NIGHT
        assert night.game.current_wave == 2
        assert night.windows_opened() == [1, 2]  # nothing closed or opened again

    def test_night_that_never_opened_its_first_window_is_opened_at_startup(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=30)
        assert night.game.current_wave == 0  # crashed right after creating the game

        _recover(night)

        assert night.game.current_wave == 2
        assert night.windows_opened() == [2]
        _timer(night, "wave:2")

    def test_recovery_in_two_workers_opens_the_first_window_once(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=30)

        _recover(night)
        _recover(night)  # a second worker starting up

        assert night.windows_opened() == [2]


# ── Discussion and voting ────────────────────────────────────────────────────


@pytest.fixture
def table(make_night):
    """A night factory plus a helper that moves its game to another phase."""

    def build(phase: str, **settings: Any) -> Night:
        night = make_night(ROLES, **settings)
        Game.objects.filter(id=night.game.id).update(phase=phase, current_wave=0)
        night.refresh()
        return night

    return build


class TestDiscussionAndVotingRecovery:
    def test_discussion_timer_comes_back_and_moves_on_to_voting(self, table) -> None:
        night = table(Phase.DISCUSSION, discussion_seconds=300, voting_seconds=120)
        _set_deadline(night, 200)
        _restart(night)

        _recover(night)

        delay, callback = _timer(night, "discussion")
        assert 195 < delay <= 200
        with night.committed():
            callback()
        assert night.refresh().phase == Phase.VOTING
        _timer(night, "voting")  # the vote has its own timer again

    def test_overdue_discussion_gets_the_reconnect_allowance_then_ends(
        self, table
    ) -> None:
        night = table(Phase.DISCUSSION, discussion_seconds=300)
        _set_deadline(night, -10)
        _restart(night)

        _recover(night)

        delay, callback = _timer(night, "discussion")
        assert ALLOWANCE - 1 < delay <= ALLOWANCE
        assert night.game.phase_deadline > timezone.now()
        with night.committed():
            callback()
        assert night.refresh().phase == Phase.VOTING

    def test_voting_timer_comes_back_and_reveals_the_votes(self, table) -> None:
        night = table(Phase.VOTING, voting_seconds=120)
        _set_deadline(night, 60)
        night.client.force_authenticate(user=night.users["seer"])
        night.client.post(
            reverse("onuw:vote", kwargs={"game_id": str(night.game.id)}),
            staged(night, {"target_player_id": night.users["wolf"].id, "lock": True}),
            format="json",
        )
        _restart(night)

        _recover(night)

        delay, callback = _timer(night, "voting")
        assert 55 < delay <= 60
        with night.committed():
            callback()
        night.refresh()
        assert night.game.phase == Phase.RESULTS
        assert night.broadcasts("vote.reveal")[0]["votes"][
            str(night.users["seer"].id)
        ] == (night.users["wolf"].id)

    def test_overdue_vote_is_not_revealed_before_phones_can_reconnect(
        self, table
    ) -> None:
        night = table(Phase.VOTING, voting_seconds=120)
        _set_deadline(night, -5)
        _restart(night)

        _recover(night)

        delay, callback = _timer(night, "voting")
        assert ALLOWANCE - 1 < delay <= ALLOWANCE
        assert night.refresh().phase == Phase.VOTING  # still open for those 15 s
        with night.committed():
            callback()
        assert night.refresh().phase == Phase.RESULTS

    def test_a_reconnected_player_sees_the_extended_countdown(self, table) -> None:
        night = table(Phase.VOTING, voting_seconds=120)
        _set_deadline(night, -5)
        _recover(night)

        night.client.force_authenticate(user=night.users["seer"])
        data = night.client.get(
            reverse("onuw:game-me", kwargs={"game_id": str(night.game.id)})
        ).data

        remaining = (
            timezone.datetime.fromisoformat(data["deadline"]) - timezone.now()
        ).total_seconds()
        assert ALLOWANCE - 1 < remaining <= ALLOWANCE

    @pytest.mark.parametrize("phase", [Phase.DISCUSSION, Phase.VOTING])
    def test_untimed_phase_has_nothing_to_recover_and_the_host_still_moves_it(
        self, table, phase: str
    ) -> None:
        night = table(phase, discussion_seconds=0, voting_seconds=0)
        Game.objects.filter(id=night.game.id).update(phase_deadline=None)
        _restart(night)

        _recover(night)

        assert _phase_timer_keys(night) == []

    def test_finished_game_gets_no_timers(self, table) -> None:
        night = table(Phase.RESULTS)

        _recover(night)

        assert _phase_timer_keys(night) == []


# ── Idempotence, lazy repair, start-up hook ──────────────────────────────────


class TestIdempotenceAndLazyRepair:
    @pytest.mark.uses_timers
    def test_recovery_twice_leaves_one_live_timer(
        self, db, django_capture_on_commit_callbacks
    ) -> None:
        night = Night(
            ROLES,
            ["Villager", "Tanner", "Hunter"],
            {"roles": {}, "night_wave_seconds": 600, "night_min_window_seconds": 0},
            _Recorder(),
            [],
            django_capture_on_commit_callbacks,
        )
        Game.objects.filter(id=night.game.id).update(
            current_wave=2, phase_deadline=timezone.now() + timedelta(seconds=600)
        )
        night.refresh()
        key = f"{night.game.id}:wave:2"
        assert not timers.is_scheduled(key)

        recovery.recover_timers()
        first = timers._registry[key]
        assert timers.is_scheduled(key)
        recovery.ensure_timers(night.refresh())  # already there: left alone
        recovery.recover_timers()  # a second worker / a second pass

        assert timers._registry[key] is first
        live = [k for k in timers._registry if k.startswith(f"{night.game.id}:wave")]
        assert live == [key]

    @pytest.mark.uses_timers
    def test_a_cancelled_or_finished_timer_does_not_count_as_scheduled(
        self, db
    ) -> None:
        timers.schedule("k:1", 600, "discussion_deadline", {"game_id": "none"})
        assert timers.is_scheduled("k:1")
        timers.cancel("k:1")
        assert not timers.is_scheduled("k:1")
        assert not timers.is_scheduled("never:registered")

    def test_fetching_the_game_state_repairs_a_missing_timer(self, make_night) -> None:
        night = make_night(ROLES, night_wave_seconds=30)
        night.start()
        _restart(night)  # start-up recovery was missed

        night.client.force_authenticate(user=night.users["seer"])
        response = night.client.get(
            reverse("onuw:game-me", kwargs={"game_id": str(night.game.id)})
        )

        assert response.status_code == 200
        delay, _ = _timer(night, "wave:2")
        assert 0 < delay <= 30

    def test_the_lazy_repair_gives_the_allowance_only_when_the_timer_is_missing(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=60)
        night.start()
        _set_deadline(night, -3)
        night.scheduled.clear()
        night.client.force_authenticate(user=night.users["seer"])
        url = reverse("onuw:game-me", kwargs={"game_id": str(night.game.id)})

        with patch("apps.core.timers.is_scheduled", return_value=True):
            night.client.get(url)  # the timer exists: nothing is touched
        assert night.scheduled == []
        assert night.refresh().phase_deadline < timezone.now()

        night.client.get(url)  # genuinely missing: rebuilt with the allowance
        delay, _ = _timer(night, "wave:2")
        assert ALLOWANCE - 1 < delay <= ALLOWANCE
        assert night.refresh().phase_deadline > timezone.now()

    def test_fetching_the_game_state_is_cheap_when_the_timer_is_registered(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=30)
        night.start()
        night.scheduled.clear()
        night.client.force_authenticate(user=night.users["seer"])
        url = reverse("onuw:game-me", kwargs={"game_id": str(night.game.id)})

        with patch("apps.core.timers.is_scheduled", return_value=True):
            night.client.get(url)

        assert night.scheduled == []

    def test_a_failing_repair_never_breaks_the_read(self, make_night) -> None:
        night = make_night(ROLES, night_wave_seconds=30)
        night.start()
        night.client.force_authenticate(user=night.users["seer"])
        url = reverse("onuw:game-me", kwargs={"game_id": str(night.game.id)})

        with patch("apps.onuw.views.ensure_timers", side_effect=RuntimeError("boom")):
            response = night.client.get(url)

        assert response.status_code == 200


class TestStartupHook:
    def test_it_is_off_under_the_test_settings(self) -> None:
        with patch("apps.onuw.recovery.recover_timers") as recover:
            recovery.run_startup_recovery()
        recover.assert_not_called()

    def test_it_runs_once_when_enabled(self, settings) -> None:
        settings.ONUW_RECOVER_TIMERS_ON_START = True
        with patch("apps.onuw.recovery.recover_timers", return_value=2) as recover:
            recovery.run_startup_recovery()
        recover.assert_called_once()

    @pytest.mark.parametrize(
        "error", [OperationalError("no db"), ImproperlyConfigured("x")]
    )
    def test_a_database_that_is_not_ready_does_not_stop_the_server(
        self, settings, error: Exception
    ) -> None:
        settings.ONUW_RECOVER_TIMERS_ON_START = True
        with patch("apps.onuw.recovery.recover_timers", side_effect=error):
            recovery.run_startup_recovery()  # must not raise


# ── Presence after a restart ─────────────────────────────────────────────────


class TestPresenceIsNotResetOnRestart:
    def test_a_restart_leaves_socket_rows_and_stamps_alone(self, make_night) -> None:
        night = make_night(ROLES, night_wave_seconds=60)
        night.start()
        for name in ("seer", "wolf"):
            services.register_connection(night.game.id, night.users[name].id)
        before = sorted(SocketPresence.objects.values_list("channel_name", flat=True))
        _restart(night)

        _recover(night)

        assert sorted(
            SocketPresence.objects.values_list("channel_name", flat=True)
        ) == (before)
        for name in ROLES:
            assert night.role_of(name).disconnected_at is None
        # Nobody was marked dropped, so no grace clock is running.
        assert not [k for k, _, _ in night.scheduled if ":grace:" in k]

    def test_a_player_who_is_back_after_a_restart_is_simply_connected(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=60)
        night.start()
        _recover(night)

        with night.committed():
            services.register_connection(night.game.id, night.users["seer"].id)

        assert presence.fresh_rows(
            game_id=night.game.id, user_id=night.users["seer"].id
        ).exists()
        assert night.role_of("seer").disconnected_at is None

    def test_a_player_whose_phone_died_with_the_old_process_is_noticed_later(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=60)
        night.start()
        services.register_connection(night.game.id, night.users["seer"].id)
        SocketPresence.objects.filter(game=night.game).update(
            last_seen=timezone.now() - timedelta(seconds=300)
        )
        _restart(night)
        _recover(night)
        assert night.role_of("seer").disconnected_at is None  # not yet noticed

        with night.committed():  # the re-armed presence check fires
            assert services.check_game_presence(night.game.id, night.users["seer"].id)

        assert night.role_of("seer").disconnected_at is not None
        # ...and now the usual grace period applies.
        delay, _ = _timer(night, f"grace:{night.users['seer'].id}")
        assert 24 < delay <= 25
