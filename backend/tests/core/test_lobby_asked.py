"""
A late, lost lobby request must not overwrite a newer tap (issue #16).

A phone may send ``"asked"`` (its tap time in ms, increasing per phone) with a
settings PATCH or a practice request. Per settings key (and ``practice``) the
server keeps the newest ``asked`` it applied and whose it was (``Lobby.asked``);
a key a NEWER tap of the same user set is dropped from an older request. Every
key dropped: ``409 stale_request``, nothing stored or sent. No ``asked``: as
before. All through the real API, a host and three players at the table.
"""

from __future__ import annotations

import random
from unittest.mock import AsyncMock, MagicMock, patch

from django.urls import reverse

import pytest
from rest_framework import status
from rest_framework.test import APIClient

from apps.core.models import Lobby, LobbyMember, User

pytestmark = pytest.mark.integration

ABSENT = object()  # no "asked" in the body (an older phone)


def stale(newest: int) -> dict:
    """The one stale body: ``newest`` is the requester's own stored ``asked``."""
    return {
        "detail": "A newer tap from this phone already got there.",
        "code": "stale_request",
        "newest": newest,
    }


class Table:
    """A waiting ONUW table: the host and three players; every lobby_update the
    PATCH sends is counted."""

    def __init__(self) -> None:
        self.users = [
            User.objects.create_user(username=f"asked-{i}", password=None)
            for i in range(4)
        ]
        self.host = self.users[0]
        self.lobby = Lobby.objects.create(
            host=self.host,
            game_type="onuw",
            max_players=10,
            settings={"pace": "normal", "discussion_seconds": 300},
        )
        for user in self.users:
            LobbyMember.objects.create(lobby=self.lobby, user=user)
        self.sent: list[dict] = []

    def client(self, user: User | None = None) -> APIClient:
        client = APIClient()
        client.force_authenticate(user=user or self.host)
        return client

    def patch(self, settings: dict, asked=ABSENT, *, user: User | None = None):
        """PATCH ``settings`` as ``user`` (the host), with ``asked`` unless absent."""
        body: dict = {"settings": settings}
        if asked is not ABSENT:
            body["asked"] = asked
        layer = MagicMock()
        layer.group_send = AsyncMock(side_effect=lambda g, m: self.sent.append(m))
        with patch("apps.core.views.get_channel_layer", return_value=layer):
            return self.client(user).patch(
                reverse("core:lobby-detail", kwargs={"code": self.lobby.code}),
                body,
                format="json",
            )

    def practice(self, body: dict, *, user: User | None = None):
        return self.client(user).post(
            reverse("core:lobby-practice", kwargs={"code": self.lobby.code}),
            body,
            format="json",
        )

    def settings(self) -> dict:
        return Lobby.objects.get(pk=self.lobby.pk).settings

    def asked(self) -> dict:
        return Lobby.objects.get(pk=self.lobby.pk).asked

    def practice_count(self) -> int:
        return LobbyMember.objects.filter(
            lobby=self.lobby, user__username__startswith="practice-"
        ).count()


@pytest.fixture
def table(db) -> Table:
    return Table()


class TestSettingsPatch:
    def test_an_older_tap_arriving_after_a_newer_one_is_dropped(self, table) -> None:
        """The hole: the host taps Quick then Long; Long arrives first, then the
        late Quick. The table keeps Long, and the late copy sends nothing."""
        assert table.patch({"pace": "long"}, asked=2000).status_code == 200
        sent = len(table.sent)

        late = table.patch({"pace": "quick"}, asked=1000)

        assert late.status_code == status.HTTP_409_CONFLICT
        assert late.data == stale(2000)
        assert table.settings()["pace"] == "long"
        assert len(table.sent) == sent  # no lobby_update
        assert table.asked() == {"pace": [table.host.id, 2000]}

    def test_an_equal_asked_is_the_same_tap_sent_again(self, table) -> None:
        first = table.patch({"pace": "quick"}, asked=1500)
        again = table.patch({"pace": "quick"}, asked=1500)

        assert first.status_code == again.status_code == status.HTTP_200_OK
        # The same body, told again: a higher ``rev`` (telling is the bump).
        assert {**first.data, "rev": 0} == {**again.data, "rev": 0}
        assert again.data["rev"] == first.data["rev"] + 1
        assert table.settings()["pace"] == "quick"

    def test_a_newer_tap_replaces_an_older_one(self, table) -> None:
        table.patch({"pace": "quick"}, asked=1000)
        assert table.patch({"pace": "long"}, asked=2000).status_code == 200
        assert table.settings()["pace"] == "long"
        assert table.asked()["pace"] == [table.host.id, 2000]

    def test_of_two_keys_only_the_stale_one_is_dropped(self, table) -> None:
        table.patch({"pace": "long"}, asked=2000)

        mixed = table.patch({"pace": "quick", "discussion_seconds": 120}, asked=1000)

        assert mixed.status_code == status.HTTP_200_OK
        assert mixed.data["settings"]["pace"] == "long"
        assert mixed.data["settings"]["discussion_seconds"] == 120
        assert table.settings()["discussion_seconds"] == 120
        assert table.asked() == {
            "pace": [table.host.id, 2000],
            "discussion_seconds": [table.host.id, 1000],
        }
        assert table.sent[-1]["data"]["settings"]["pace"] == "long"

    def test_every_key_stale_changes_nothing_and_sends_nothing(self, table) -> None:
        """The answer names the largest stored ``asked`` among the keys it lost."""
        table.patch({"pace": "long"}, asked=3000)
        table.patch({"discussion_seconds": 60}, asked=3500)
        before = (table.settings(), table.asked(), len(table.sent))

        late = table.patch({"pace": "quick", "discussion_seconds": 120}, asked=2999)

        assert late.status_code == status.HTTP_409_CONFLICT
        assert late.data == stale(3500)
        assert (table.settings(), table.asked(), len(table.sent)) == before

    def test_validation_reads_only_what_is_left(self, table) -> None:
        """A bad value under a stale key is dropped before the check, so the
        fresh key goes through."""
        table.patch({"discussion_seconds": 60}, asked=5000)

        reply = table.patch({"discussion_seconds": "bad", "pace": "quick"}, asked=4000)

        assert reply.status_code == status.HTTP_200_OK
        assert table.settings()["discussion_seconds"] == 60
        assert table.settings()["pace"] == "quick"

    def test_without_asked_it_is_as_before_even_after_an_asked_tap(self, table) -> None:
        table.patch({"pace": "long"}, asked=9000)

        old_phone = table.patch({"pace": "quick"})

        assert old_phone.status_code == status.HTTP_200_OK
        assert table.settings()["pace"] == "quick"
        assert table.asked() == {"pace": [table.host.id, 9000]}  # left as it was

    def test_another_users_entry_is_never_compared(self, table) -> None:
        """A host handover starts afresh: the acting host's first tap may carry a
        smaller number than the owner's last (another phone, another clock)."""
        table.patch({"pace": "long"}, asked=900_000)
        acting = table.users[2]
        Lobby.objects.filter(pk=table.lobby.pk).update(acting_host=acting)

        reply = table.patch({"pace": "quick"}, asked=5, user=acting)

        assert reply.status_code == status.HTTP_200_OK
        assert table.settings()["pace"] == "quick"
        assert table.asked()["pace"] == [acting.id, 5]

    def test_a_stale_answer_names_only_the_requesters_own_number(self, table) -> None:
        """After a handover the owner's entries are never compared, so never
        told: the acting host's stale answer carries the acting host's number."""
        table.patch({"pace": "long", "discussion_seconds": 60}, asked=900_000)
        acting = table.users[1]
        Lobby.objects.filter(pk=table.lobby.pk).update(acting_host=acting)
        table.patch({"discussion_seconds": 90}, asked=50, user=acting)

        late = table.patch({"discussion_seconds": 120}, asked=40, user=acting)
        mixed = table.patch(
            {"pace": "quick", "discussion_seconds": 120}, asked=45, user=acting
        )

        assert late.data == stale(50)
        assert mixed.status_code == status.HTTP_200_OK  # pace was the owner's
        assert table.settings()["pace"] == "quick"
        assert table.settings()["discussion_seconds"] == 90

    @pytest.mark.parametrize("bad", [None, True, False, -1, 1.5, "100", [1], {}])
    def test_an_asked_that_is_not_a_whole_number_is_bad_request(
        self, table, bad
    ) -> None:
        reply = table.patch({"pace": "quick"}, asked=bad)

        assert reply.status_code == status.HTTP_400_BAD_REQUEST
        assert reply.data["code"] == "bad_request"
        assert isinstance(reply.data["detail"], str)
        assert table.settings()["pace"] == "normal"
        assert table.asked() == {}

    def test_a_refused_patch_stores_no_asked(self, table) -> None:
        reply = table.patch({"discussion_seconds": "bad"}, asked=10)

        assert reply.status_code == status.HTTP_400_BAD_REQUEST
        assert table.asked() == {}

    def test_practice_in_a_patch_is_stripped_and_never_noted(self, table) -> None:
        table.patch({"practice": True, "pace": "quick"}, asked=10)
        assert table.asked() == {"pace": [table.host.id, 10]}
        assert "practice" not in table.settings()

    @pytest.mark.parametrize("seed", range(6))
    def test_taps_in_any_order_leave_the_newest_per_key(self, table, seed) -> None:
        """Seeded: eight taps, each on one of two keys, delivered in a shuffled
        order. Each key ends with the value of its newest tap."""
        rng = random.Random(seed)  # noqa: S311 (seeded test data, not secret)
        taps = []
        for asked in range(1000, 1008):
            if rng.random() < 0.5:
                taps.append((asked, {"pace": rng.choice(["quick", "normal", "long"])}))
            else:
                taps.append((asked, {"discussion_seconds": rng.randint(1, 600)}))
        newest: dict = {}
        for _, setting in taps:  # in tap order: the last one per key wins
            newest.update(setting)
        rng.shuffle(taps)

        for asked, setting in taps:
            assert table.patch(setting, asked=asked).status_code in (200, 409)

        settings = table.settings()
        assert {k: settings[k] for k in newest} == newest


class TestPractice:
    def test_a_late_older_switch_does_not_undo_a_newer_count(self, table) -> None:
        assert table.practice({"count": 3, "asked": 2000}).status_code == 200

        late = table.practice({"on": False, "asked": 1000})

        assert late.status_code == status.HTTP_409_CONFLICT
        assert late.data == stale(2000)
        assert table.practice_count() == 3
        assert table.settings()["practice"] is True
        assert table.asked() == {"practice": [table.host.id, 2000]}

    def test_an_equal_asked_answers_alike(self, table) -> None:
        first = table.practice({"count": 1, "asked": 70})
        again = table.practice({"count": 1, "asked": 70})

        assert first.status_code == again.status_code == status.HTTP_200_OK
        # The same body, told again: a higher ``rev`` (telling is the bump).
        assert {**first.data, "rev": 0} == {**again.data, "rev": 0}
        assert again.data["rev"] == first.data["rev"] + 1
        assert table.practice_count() == 1

    def test_a_practice_tap_and_a_settings_tap_never_shadow_each_other(
        self, table
    ) -> None:
        table.practice({"on": True, "asked": 9000})

        reply = table.patch({"pace": "long"}, asked=10)

        assert reply.status_code == status.HTTP_200_OK
        assert table.practice({"on": False, "asked": 9001}).status_code == 200
        assert table.asked() == {
            "practice": [table.host.id, 9001],
            "pace": [table.host.id, 10],
        }

    def test_without_asked_it_is_as_before(self, table) -> None:
        table.practice({"on": True, "asked": 9000})

        old_phone = table.practice({"on": False})

        assert old_phone.status_code == status.HTTP_200_OK
        assert "practice" not in table.settings()
        assert table.asked() == {"practice": [table.host.id, 9000]}

    @pytest.mark.parametrize("bad", [None, True, -3, "1", 2.0, 2**53])
    def test_a_bad_asked_is_bad_request(self, table, bad) -> None:
        reply = table.practice({"on": True, "asked": bad})

        assert reply.status_code == status.HTTP_400_BAD_REQUEST
        assert reply.data["code"] == "bad_request"
        assert "practice" not in table.settings()
