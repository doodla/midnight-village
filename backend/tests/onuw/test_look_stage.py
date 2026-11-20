"""
The look stage: "everyone has looked at their card, then the night starts".

With ``card_look_seconds`` > 0 the deal does not open a night window. The game sits
in night, window 0, with a deadline and a ``card_look`` timer; every phone taps
``POST .../ready/ {"ready": true}`` (looking is one way); when every player not gone
past the grace period has looked, or the backstop fires, or the host taps advance,
the first window opens (``start_night_phase``, idempotent under the Game lock). The
stage shows nothing about roles: it ends on taps, presence and the clock only.

With the setting off (the default) the deal opens the window as it always did.
"""

import threading
from datetime import timedelta
from typing import Any
from unittest.mock import patch

from django.db import connections
from django.urls import reverse
from django.utils import timezone

import pytest
from rest_framework import status
from rest_framework.test import APIClient

from apps.core import timers
from apps.onuw import services
from apps.onuw.engine.validation import validate_onuw_settings
from apps.onuw.models import Game, Phase, PlayerRole
from tests.onuw.test_night_windows import Night
from tests.onuw.test_presence import connect, drop, fire_grace

pytestmark = pytest.mark.integration

ROLES = {
    "wolf": "Werewolf",
    "seer": "Seer",
    "hunter": "Hunter",
    "robber": "Robber",
    "villager": "Villager",
}
CENTER = ["Villager", "Tanner", "Villager"]


def deal(night: Night) -> None:
    """The deal's own step: what ``GameStartView._deal`` calls last."""
    with night.committed():
        services.begin_night(night.game)
    night.refresh()


@pytest.fixture
def looking(make_night) -> Night:
    """Five players dealt in; the look stage is on (30 s)."""
    night = make_night(ROLES, CENTER, card_look_seconds=30, night_wave_seconds=60)
    deal(night)
    assert (night.game.phase, night.game.current_wave) == (Phase.NIGHT, 0)
    return night


def make_v2(night: Night) -> None:
    """Let the game answer with the stage keys (``night_protocol: 2``) from here on,
    without changing how its night opens in this test."""
    Game.objects.filter(id=night.game.id).update(
        settings={**night.game.settings, "night_protocol": 2}
    )
    night.refresh()


def post_ready(night: Night, who: str, body: Any) -> Any:
    night.client.force_authenticate(user=night.users[who])
    with night.committed():
        return night.client.post(
            reverse("onuw:ready", kwargs={"game_id": str(night.game.id)}),
            body,
            format="json",
        )


def look(night: Night, who: str) -> Any:
    return post_ready(night, who, {"ready": True})


def me(night: Night, name: str) -> dict[str, Any]:
    night.client.force_authenticate(user=night.users[name])
    response = night.client.get(
        reverse("onuw:game-me", kwargs={"game_id": str(night.game.id)})
    )
    assert response.status_code == status.HTTP_200_OK
    return response.data


def host_advance(night: Night, body: dict[str, Any] | None = None) -> Any:
    night.client.force_authenticate(user=night.host)
    with night.committed():
        return night.client.post(
            reverse("onuw:wave-advance", kwargs={"game_id": str(night.game.id)}),
            body,
            format="json",
        )


def look_timers(night: Night) -> list[tuple[float, Any]]:
    key = f"{night.game.id}:look"
    return [(delay, cb) for k, delay, cb in night.scheduled if k == key]


def fire_look_timer(night: Night) -> None:
    callbacks = look_timers(night)
    assert callbacks, "no look timer was scheduled"
    with night.committed():
        callbacks[-1][1]()
    night.refresh()


# ── off by default ───────────────────────────────────────────────────────────


class TestOff:
    def test_look_stage_off_opens_window_at_deal_as_before(self, make_night) -> None:
        night = make_night(ROLES, CENTER)  # no card_look_seconds
        deal(night)

        assert night.game.current_wave == 2  # no Doppelganger: window 2 straight away
        assert look_timers(night) == []
        assert night.broadcasts("wave.start")
        assert night.broadcasts("progress") == []
        assert "progress" not in me(night, "seer")  # the original night's payload

    def test_a_zero_setting_is_off_too(self, make_night) -> None:
        night = make_night(ROLES, CENTER, card_look_seconds=0)
        deal(night)

        assert night.game.current_wave == 2
        assert look_timers(night) == []

    def test_a_bad_stored_value_is_off(self, make_night) -> None:
        night = make_night(ROLES, CENTER, card_look_seconds="30")
        deal(night)

        assert night.game.current_wave == 2


# ── the stage ────────────────────────────────────────────────────────────────


class TestTheStage:
    def test_the_deal_opens_no_window_and_announces_the_stage(self, looking) -> None:
        night = looking

        assert night.broadcasts("wave.start") == []
        assert night.events_to("seer", "action.prompt") == []
        assert night.broadcasts("progress") == [
            {"type": "progress", "stage": "look", "done": 0, "needed": 5}
        ]
        delays = [d for d, _ in look_timers(night)]
        assert delays == [30]
        remaining = (night.game.phase_deadline - timezone.now()).total_seconds()
        assert 28 < remaining <= 30

    def test_the_original_night_payload_has_no_stage_keys(self, looking) -> None:
        body = me(looking, "seer")

        assert not {"progress", "ready", "my_vote"} & set(body)

    def test_me_during_the_stage_is_the_same_for_every_role(self, looking) -> None:
        night = looking
        make_v2(night)
        look(night, "wolf")

        bodies = {name: me(night, name) for name in ROLES}

        for name, body in bodies.items():
            assert body["phase"] == "night"
            assert body["current_wave"] == 0
            assert body["deadline"] == night.game.phase_deadline.isoformat()
            assert body["progress"] == {"stage": "look", "done": 1, "needed": 5}
            assert body["action_prompt"] is None
            assert body["ready"] is (name == "wolf")
            assert body["night_results"] == []

    def test_look_stage_waits_until_all_players_ready(self, looking) -> None:
        night = looking
        for name in ("wolf", "seer", "hunter", "robber"):
            response = look(night, name)
            assert response.status_code == status.HTTP_200_OK
            assert response.data == {"status": "ok", "ready": True}
            assert night.refresh().current_wave == 0
        assert [(e["done"], e["needed"]) for e in night.broadcasts("progress")] == [
            (0, 5),
            (1, 5),
            (2, 5),
            (3, 5),
            (4, 5),
        ]

        look(night, "villager")

        assert night.refresh().current_wave == 2
        assert [e["wave"] for e in night.broadcasts("wave.start")] == [2]
        assert night.events_to("seer", "action.prompt")
        # The window has its own deadline now, not the look's.
        assert night.game.phase_deadline > timezone.now() + timedelta(seconds=50)

    def test_the_first_window_is_window_one_when_the_doppelganger_is_in_the_deck(
        self, make_night
    ) -> None:
        roles = {**ROLES, "villager": "Doppelganger"}
        night = make_night(roles, CENTER, card_look_seconds=30)
        deal(night)

        for name in roles:
            look(night, name)

        assert night.refresh().current_wave == 1

    def test_opening_the_night_cancels_the_look_timer(self, looking) -> None:
        night = looking
        with patch("apps.core.timers.cancel") as cancel:
            for name in ROLES:
                look(night, name)

        assert f"{night.game.id}:look" in [c.args[0] for c in cancel.call_args_list]

    def test_look_stage_backstop_opens_night(self, looking) -> None:
        night = looking
        look(night, "wolf")

        fire_look_timer(night)

        assert night.game.current_wave == 2
        assert [e["wave"] for e in night.broadcasts("wave.start")] == [2]

    def test_a_late_backstop_after_the_night_opened_does_nothing(self, looking) -> None:
        night = looking
        for name in ROLES:
            look(night, name)
        assert night.refresh().current_wave == 2

        fire_look_timer(night)

        assert night.game.current_wave == 2
        assert len(night.broadcasts("wave.start")) == 1

    def test_look_ready_false_rejected(self, looking) -> None:
        night = looking
        look(night, "seer")

        response = post_ready(night, "seer", {"ready": False})

        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert response.data["code"] == "bad_request"
        assert night.role_of("seer").phase_ready is True  # looking is one way

    def test_looking_twice_is_harmless(self, looking) -> None:
        night = looking
        for _ in range(3):
            assert look(night, "seer").status_code == status.HTTP_200_OK
        assert night.refresh().current_wave == 0

    def test_a_night_action_during_the_stage_is_refused_like_any_early_one(
        self, looking
    ) -> None:
        night = looking

        response = night.post(
            "seer", "peek_player", {"player_id": night.users["wolf"].id}
        )

        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert night.role_of("seer").has_acted is False

    def test_the_flags_start_clear_when_the_first_window_opens(self, looking) -> None:
        night = looking
        for name in ROLES:
            look(night, name)

        assert not PlayerRole.objects.filter(game=night.game, phase_ready=True).exists()

    def test_the_talk_after_the_night_starts_with_nobody_ready(self, looking) -> None:
        night = looking
        make_v2(night)
        for name in ROLES:
            look(night, name)
        with night.committed():
            services.transition_to_discussion(night.game)

        assert me(night, "seer")["progress"] == {
            "stage": "talk",
            "done": 0,
            "needed": 5,
        }


# ── dropped phones ───────────────────────────────────────────────────────────


class TestDroppedPhones:
    def test_look_stage_ignores_player_gone_past_grace(self, looking) -> None:
        night = looking
        drop(night, "robber", seconds_ago=60)

        for name in ("wolf", "seer", "hunter"):
            look(night, name)
        assert night.refresh().current_wave == 0
        assert night.broadcasts("progress")[-1] == {
            "type": "progress",
            "stage": "look",
            "done": 3,
            "needed": 4,
        }

        look(night, "villager")

        assert night.refresh().current_wave == 2

    def test_a_player_inside_the_grace_period_is_still_waited_for(
        self, looking
    ) -> None:
        night = looking
        drop(night, "robber", seconds_ago=5)

        for name in ("wolf", "seer", "hunter", "villager"):
            look(night, name)

        assert night.refresh().current_wave == 0

    def test_the_grace_period_ending_opens_the_night_when_everyone_else_has_looked(
        self, looking
    ) -> None:
        night = looking
        drop(night, "robber")
        for name in ("wolf", "seer", "hunter", "villager"):
            look(night, name)
        assert night.refresh().current_wave == 0
        PlayerRole.objects.filter(game=night.game, user=night.users["robber"]).update(
            disconnected_at=timezone.now() - timedelta(seconds=26)
        )

        fire_grace(night, "robber")

        assert night.game.current_wave == 2

    def test_the_grace_period_ending_tells_the_table_the_new_count(
        self, looking
    ) -> None:
        night = looking
        drop(night, "robber")
        look(night, "wolf")
        night.recorder.events.clear()
        PlayerRole.objects.filter(game=night.game, user=night.users["robber"]).update(
            disconnected_at=timezone.now() - timedelta(seconds=26)
        )

        fire_grace(night, "robber")

        assert night.broadcasts("progress") == [
            {"type": "progress", "stage": "look", "done": 1, "needed": 4}
        ]

    def test_a_phone_coming_back_is_counted_again(self, looking) -> None:
        night = looking
        drop(night, "robber", seconds_ago=60)
        for name in ("wolf", "seer", "hunter"):
            look(night, name)
        night.recorder.events.clear()

        connect(night, "robber")

        assert night.broadcasts("progress") == [
            {"type": "progress", "stage": "look", "done": 3, "needed": 5}
        ]
        assert night.refresh().current_wave == 0

    def test_every_phone_gone_means_only_the_backstop_opens_the_night(
        self, looking
    ) -> None:
        night = looking
        for name in ROLES:
            drop(night, name, seconds_ago=60)
        night.refresh()

        fire_grace(night, "wolf")
        assert night.game.current_wave == 0

        fire_look_timer(night)
        assert night.game.current_wave == 2


# ── the host and the clock ───────────────────────────────────────────────────


class TestHostAndRestart:
    def test_host_advance_during_look_opens_window_once(self, looking) -> None:
        night = looking

        first = host_advance(night, {"from_window": 0})
        second = host_advance(night, {"from_window": 0})

        assert first.status_code == status.HTTP_200_OK
        assert first.data["current_wave"] == 2
        assert second.status_code == status.HTTP_409_CONFLICT
        assert second.data["code"] == "wrong_window"
        # The second tap did not close the window it was not aimed at.
        assert night.refresh().current_wave == 2
        assert night.game.phase == Phase.NIGHT
        assert [e["wave"] for e in night.broadcasts("wave.start")] == [2]

    def test_host_advance_without_from_window_opens_the_night_at_window_zero(
        self, looking
    ) -> None:
        night = looking

        response = host_advance(night)

        assert response.status_code == status.HTTP_200_OK
        assert night.refresh().current_wave == 2

    def test_a_stale_host_tap_cannot_close_a_later_window(self, make_night) -> None:
        night = make_night(
            {**ROLES, "villager": "Doppelganger"}, CENTER, night_wave_seconds=60
        )
        night.start()
        assert night.game.current_wave == 1

        stale = host_advance(night, {"from_window": 0})

        assert stale.status_code == status.HTTP_409_CONFLICT
        assert night.refresh().current_wave == 1
        ok = host_advance(night, {"from_window": 1})
        assert ok.status_code == status.HTTP_200_OK
        assert night.refresh().current_wave == 2

    @pytest.mark.parametrize("bad", ["1", 1.5, True, None, -1, [1]], ids=repr)
    def test_from_window_must_be_a_whole_number(self, looking, bad) -> None:
        response = host_advance(looking, {"from_window": bad})

        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert response.data["code"] == "bad_request"
        assert looking.refresh().current_wave == 0

    def test_a_non_host_cannot_advance(self, looking) -> None:
        night = looking
        night.client.force_authenticate(user=night.users["seer"])

        response = night.client.post(
            reverse("onuw:wave-advance", kwargs={"game_id": str(night.game.id)}),
            {"from_window": 0},
            format="json",
        )

        assert response.status_code == status.HTTP_403_FORBIDDEN

    def test_look_timer_rebuilt_by_me_fetch_after_restart(self, looking) -> None:
        night = looking
        before = len(look_timers(night))
        # A restart lost the timer row: nothing is registered any more.
        timers.cancel(f"{night.game.id}:look")

        body = me(night, "seer")

        assert body["current_wave"] == 0  # a fetch never opens the night here
        rebuilt = look_timers(night)[before:]
        assert len(rebuilt) == 1
        assert 0 < rebuilt[0][0] <= 30

    def test_an_overdue_look_deadline_gets_the_reconnect_allowance(
        self, looking
    ) -> None:
        night = looking
        Game.objects.filter(id=night.game.id).update(
            phase_deadline=timezone.now() - timedelta(seconds=20)
        )
        timers.cancel(f"{night.game.id}:look")
        before = len(look_timers(night))

        body = me(night, "seer")

        assert body["current_wave"] == 0
        (delay, _), *_ = look_timers(night)[before:]
        assert 10 < delay <= services.RECOVERY_RECONNECT_ALLOWANCE_SECONDS

    def test_stuck_rule_does_not_open_night_during_look_stage(self, looking) -> None:
        night = looking
        Game.objects.filter(id=night.game.id).update(
            created_at=timezone.now() - timedelta(seconds=300)
        )

        me(night, "seer")

        assert night.refresh().current_wave == 0
        assert night.broadcasts("wave.start") == []

    def test_a_night_that_never_opened_without_a_look_stage_is_still_opened(
        self, make_night
    ) -> None:
        night = make_night(ROLES, CENTER)  # window 0, no deadline: the old stuck case
        Game.objects.filter(id=night.game.id).update(
            created_at=timezone.now() - timedelta(seconds=300)
        )

        night.client.force_authenticate(user=night.users["seer"])
        with night.committed():
            night.client.get(
                reverse("onuw:game-me", kwargs={"game_id": str(night.game.id)})
            )

        assert night.refresh().current_wave == 2

    def test_start_up_recovery_keeps_the_look_stage_and_rebuilds_its_timer(
        self, looking
    ) -> None:
        night = looking
        timers.cancel(f"{night.game.id}:look")
        before = len(look_timers(night))

        with night.committed():
            services.recover_timers()

        assert night.refresh().current_wave == 0
        assert len(look_timers(night)) == before + 1

    def test_start_up_recovery_opens_a_stage_everyone_present_has_looked_at(
        self, looking
    ) -> None:
        night = looking
        PlayerRole.objects.filter(game=night.game).update(phase_ready=True)

        with night.committed():
            services.recover_timers()

        assert night.refresh().current_wave == 2

    def test_start_up_recovery_still_opens_a_night_with_no_look_stage(
        self, make_night
    ) -> None:
        night = make_night(ROLES, CENTER)

        with night.committed():
            services.recover_timers()

        assert night.refresh().current_wave == 2

    @pytest.mark.django_db(transaction=True)
    def test_ready_and_backstop_race_open_window_once(self, looking) -> None:
        night = looking
        for name in ("wolf", "seer", "hunter", "robber"):
            look(night, name)
        url = reverse("onuw:ready", kwargs={"game_id": str(night.game.id)})
        callback = look_timers(night)[-1][1]
        barrier = threading.Barrier(2)
        codes: list[int] = []

        def last_tap() -> None:
            try:
                client = APIClient()
                client.force_authenticate(user=night.users["villager"])
                barrier.wait(timeout=10)
                codes.append(
                    client.post(url, {"ready": True}, format="json").status_code
                )
            finally:
                connections.close_all()

        def backstop() -> None:
            try:
                barrier.wait(timeout=10)
                callback()
            finally:
                connections.close_all()

        threads = [threading.Thread(target=last_tap), threading.Thread(target=backstop)]
        for t in threads:
            t.start()
        for t in threads:
            t.join(timeout=30)

        # The tap opened the night (200), or the backstop did first and the tap
        # got the ordinary "nothing is waiting for you" refusal. Never both.
        assert codes in ([status.HTTP_200_OK], [status.HTTP_400_BAD_REQUEST])
        assert night.refresh().current_wave == 2
        assert [e["wave"] for e in night.broadcasts("wave.start")] == [2]
        assert len(night.events_to("seer", "action.prompt")) == 1


# ── the setting ──────────────────────────────────────────────────────────────


class TestSetting:
    DECK = {
        "Werewolf": 2,
        "Seer": 1,
        "Robber": 1,
        "Villager": 3,
        "Drunk": 1,
        "Troublemaker": 1,
    }

    @pytest.mark.parametrize("value", [0, 1, 30, 120])
    def test_valid_values(self, value) -> None:
        settings = {"roles": self.DECK, "card_look_seconds": value}
        assert validate_onuw_settings(settings, 6) == []

    @pytest.mark.parametrize("value", [-1, 121, 3600, "30", 1.5, True, None, [30]])
    def test_invalid_values(self, value) -> None:
        settings = {"roles": self.DECK, "card_look_seconds": value}

        errors = validate_onuw_settings(settings, 6)

        assert any("card_look_seconds" in e and "0 to 120" in e for e in errors)


class TestDebugTimer:
    def test_the_fire_timer_hook_accepts_look_and_current_finds_it(
        self, looking, settings
    ) -> None:
        # The fake scheduler only recorded the job: make the row real.
        from apps.core.models import ScheduledTimer
        from apps.onuw.debug import fire_timer

        ScheduledTimer.objects.create(
            key=f"{looking.game.id}:look",
            token="t",
            due_at=timezone.now() + timedelta(seconds=30),
            job="card_look",
            params={"game_id": str(looking.game.id)},
        )

        with looking.committed():
            fired, key = fire_timer(looking.game, "current")

        assert fired is True
        assert key == f"{looking.game.id}:look"
        assert looking.refresh().current_wave == 2

    def test_look_is_an_allowed_key(self) -> None:
        from apps.onuw.debug_views import DebugFireTimerView

        assert DebugFireTimerView._is_valid_key("look")


# ── through the real deal ────────────────────────────────────────────────────


class TestTheDealThroughTheApi:
    """``POST lobbies/<code>/start/`` end to end: lobby settings in, look stage out."""

    @pytest.fixture
    def deal_api(self, db, settings, django_capture_on_commit_callbacks):
        from tests.onuw.test_play_again import Table

        settings.DEBUG = True  # lets the start endpoint take a fixed seed
        scheduled: list[tuple[str, float, str]] = []
        sent: list[tuple[str, dict[str, Any]]] = []
        layer = type("L", (), {"group_send": lambda self, g, e: sent.append((g, e))})()

        def fake_schedule(key, delay, job, params=None):
            scheduled.append((key, delay, job))

        with (
            patch("apps.core.effects.get_channel_layer", return_value=layer),
            patch("apps.core.effects.async_to_sync", side_effect=lambda f: f),
            patch("apps.core.timers.schedule", side_effect=fake_schedule),
        ):
            table = Table()
            yield table, scheduled, sent, django_capture_on_commit_callbacks

    def deal(self, deal_api, seconds: int | None, **extra: Any):
        table, _scheduled, _sent, capture = deal_api
        if seconds is not None:
            reply = table.host.patch(
                reverse("core:lobby-detail", kwargs={"code": table.code}),
                {"settings": {"card_look_seconds": seconds, **extra}},
                format="json",
            )
            assert reply.status_code == status.HTTP_200_OK, reply.data
        with capture(execute=True):
            response = table.start(seed=11)
        assert response.status_code == status.HTTP_201_CREATED, response.data
        return Game.objects.get(id=response.data["game_id"])

    def test_the_setting_off_opens_the_window_in_the_deal(self, deal_api) -> None:
        _table, scheduled, _sent, _ = deal_api

        game = self.deal(deal_api, None)

        assert game.current_wave == 2
        assert [k for k, _, _ in scheduled if k.endswith(":look")] == []

    def test_the_setting_on_holds_the_night_at_window_zero(self, deal_api) -> None:
        table, scheduled, sent, _ = deal_api

        game = self.deal(deal_api, 30, night_protocol=2)

        assert (game.phase, game.current_wave) == (Phase.NIGHT, 0)
        assert (f"{game.id}:look", 30, "card_look") in scheduled
        assert [k for k, _, _ in scheduled if k.startswith(f"{game.id}:wave")] == []
        assert (
            f"game_{game.id}",
            {"type": "progress", "stage": "look", "done": 0, "needed": 5},
        ) in sent
        # Every player's /me/ is the same shape, whatever they were dealt.
        bodies = [
            client.get(reverse("onuw:game-me", kwargs={"game_id": str(game.id)})).data
            for client in table.clients
        ]
        assert {b["progress"]["stage"] for b in bodies} == {"look"}
        assert all(b["action_prompt"] is None for b in bodies)

    def test_every_player_looking_opens_the_first_window(self, deal_api) -> None:
        table, _scheduled, sent, capture = deal_api
        game = self.deal(deal_api, 30)

        for client in table.clients:
            with capture(execute=True):
                reply = client.post(
                    reverse("onuw:ready", kwargs={"game_id": str(game.id)}),
                    {"ready": True},
                    format="json",
                )
            assert reply.status_code == status.HTTP_200_OK

        game.refresh_from_db()
        assert game.current_wave == 2
        assert [e["wave"] for _, e in sent if e["type"] == "wave.start"] == [2]

    def test_a_lobby_patch_over_the_limit_is_refused(self, deal_api) -> None:
        table, *_ = deal_api

        reply = table.host.patch(
            reverse("core:lobby-detail", kwargs={"code": table.code}),
            {"settings": {"card_look_seconds": 121}},
            format="json",
        )

        assert reply.status_code == status.HTTP_400_BAD_REQUEST
