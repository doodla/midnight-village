"""
Practice players (``apps.core.practice``, ``apps/onuw/practice.py``): computer-filled
seats, so one person can try the whole game alone.

Everything goes through the real API: the host seats practice players
(``POST /lobbies/<code>/practice/``), deals, and plays its part; the server plays
the practice players through the same functions a phone's request calls. Every game
is seeded (the forced deal fixes the cards, ``SEED`` the practice players' draws)
and has several players.
"""

from __future__ import annotations

import json
from collections.abc import Iterator
from contextlib import contextmanager
from typing import Any
from unittest.mock import patch

from django.test import override_settings
from django.urls import reverse

import pytest
from rest_framework import status
from rest_framework.test import APIClient

from apps.core import host as core_host
from apps.core.models import Lobby, LobbyMember, User
from apps.core.practice import NAMES, USERNAME_PREFIX
from apps.onuw.engine.choose import (
    build_choose_prompt,
    interpret_choice,
    parse_picks,
)
from apps.onuw.engine.practice import practice_picks, practice_rng, practice_vote
from apps.onuw.engine.state import GameState
from apps.onuw.models import Game, Phase, PlayerRole
from apps.onuw.protocol import stage_token
from tests.onuw.test_night_windows import _Recorder

pytestmark = pytest.mark.integration

SEED = 20261122

# Lengths that let a game run with no timer firing (timers are no-ops in tests):
# the look stage is on, so the night opens on the person's "ready".
LENGTHS = {
    "card_look_seconds": 30,
    "night_min_window_seconds": 0,
    "night_doppelganger_window_seconds": 0,
}

ROLE_NAMES = {
    "Werewolf",
    "Minion",
    "Mason",
    "Seer",
    "Robber",
    "Troublemaker",
    "Drunk",
    "Insomniac",
    "Hunter",
    "Tanner",
    "Doppelganger",
    "Villager",
}


_people_made = iter(range(1, 10_000))


def _person(name: str) -> User:
    return User.objects.create_user(
        username=f"person-{next(_people_made)}",
        password=None,
        display_name=name,
        is_guest=True,
    )


class PracticeTable:
    """A table driven through the API by its people; practice players are the
    server's. ``events`` is every socket message the server sent."""

    def __init__(self, capture: Any, people: list[str], settings: dict[str, Any]):
        self._capture = capture
        self.recorder = _Recorder()
        self.people = {name: _person(name) for name in people}
        self.host = self.people[people[0]]
        self.client = APIClient()
        reply = self.post(
            people[0],
            reverse("core:lobby-list"),
            {"game_type": "onuw", "settings": settings},
        )
        assert reply.status_code == status.HTTP_201_CREATED, reply.data
        self.code = reply.data["code"]
        for name in people[1:]:
            joined = self.post(
                name, reverse("core:lobby-join", kwargs={"code": self.code}), {}
            )
            assert joined.status_code == status.HTTP_200_OK, joined.data
        self.game: Game | None = None

    # -- requests -----------------------------------------------------------

    @contextmanager
    def committed(self) -> Iterator[None]:
        """Run the block as a request whose transaction commits: the on-commit
        callbacks run (socket sends recorded, the practice players' drive)."""
        layer = type("Layer", (), {"group_send": self.recorder.group_send})()
        with (
            patch("apps.core.effects.get_channel_layer", return_value=layer),
            patch("apps.core.effects.async_to_sync", side_effect=lambda f: f),
            patch("apps.core.views.get_channel_layer", return_value=None),
            patch("apps.onuw.views.get_channel_layer", return_value=None),
            self._capture(execute=True),
        ):
            yield

    def post(self, name: str, url: str, body: dict[str, Any]) -> Any:
        self.client.force_authenticate(user=self.people[name])
        with self.committed():
            return self.client.post(url, body, format="json")

    def get(self, name: str, url: str) -> Any:
        self.client.force_authenticate(user=self.people[name])
        with self.committed():
            return self.client.get(url)

    def practice(self, name: str | None = None, **body: Any) -> Any:
        url = reverse("core:lobby-practice", kwargs={"code": self.code})
        return self.post(name or self.host.display_name, url, body)

    def lobby(self, name: str | None = None) -> dict[str, Any]:
        url = reverse("core:lobby-detail", kwargs={"code": self.code})
        return self.get(name or self.host.display_name, url).data

    @property
    def lobby_row(self) -> Lobby:
        return Lobby.objects.get(code=self.code)

    def practice_ids(self) -> list[int]:
        return list(
            LobbyMember.objects.filter(
                lobby=self.lobby_row, user__username__startswith=USERNAME_PREFIX
            )
            .order_by("joined_at", "id")
            .values_list("user_id", flat=True)
        )

    # -- the game -----------------------------------------------------------

    @override_settings(DEBUG=True)
    def deal(self, roles: dict[int, str], center: list[str]) -> Game:
        """Deal these cards (user id -> role) and fix the practice players' seed."""
        reply = self.post(
            self.host.display_name,
            reverse("onuw:game-start", kwargs={"code": self.code}),
            {
                "debug": {
                    "forced_assignment": {
                        "player_roles": {str(k): v for k, v in roles.items()},
                        "center": center,
                    }
                }
            },
        )
        assert reply.status_code == status.HTTP_201_CREATED, reply.data
        Game.objects.filter(id=reply.data["game_id"]).update(random_seed=SEED)
        self.game = Game.objects.get(id=reply.data["game_id"])
        return self.game

    def refresh(self) -> Game:
        assert self.game is not None
        self.game = Game.objects.get(id=self.game.id)
        return self.game

    def url(self, name: str) -> str:
        assert self.game is not None
        return reverse(f"onuw:{name}", kwargs={"game_id": str(self.game.id)})

    def me(self, name: str) -> dict[str, Any]:
        return self.get(name, self.url("game-me")).data

    def ready(self, name: str) -> Any:
        return self.post(
            name, self.url("ready"), {"ready": True, "stage": self.me(name)["stage"]}
        )

    def choose(self, name: str, picks: list[dict[str, Any]] | None = None) -> Any:
        me = self.me(name)
        return self.post(
            name,
            self.url("night-action"),
            {
                "action_type": "choose",
                "picks": picks or [],
                "chosen": me["action_prompt"]["chosen"],
                "stage": me["stage"],
            },
        )

    def vote(self, name: str, target: int) -> Any:
        return self.post(
            name,
            self.url("vote"),
            {
                "target_player_id": target,
                "lock": True,
                "stage": self.me(name)["stage"],
            },
        )

    def role_of(self, user_id: int) -> PlayerRole:
        return PlayerRole.objects.get(game=self.game, user_id=user_id)

    def log_of(self, user_id: int) -> list[dict[str, Any]]:
        return [
            e for e in self.refresh().night_actions_log if e["player_id"] == user_id
        ]


@pytest.fixture
def table(db, django_capture_on_commit_callbacks):
    def make(people: list[str], **settings: Any) -> PracticeTable:
        return PracticeTable(
            django_capture_on_commit_callbacks, people, {**LENGTHS, **settings}
        )

    return make


def _deck(**counts: int) -> dict[str, Any]:
    return {"deck": "custom", "roles": counts}


# ── Seating them ───────────────────────────────────────────────────────────


class TestSeatingPracticePlayers:
    def test_a_table_that_never_used_them_is_answered_as_before(self, table):
        t = table(["Ana", "Ben"])
        body = t.lobby()
        assert "practice" not in body
        assert all("practice" not in p for p in body["players"])

    def test_switching_on_seats_nobody_and_says_how_many_fit(self, table):
        t = table(["Ana", "Ben"], seats=5)
        reply = t.practice(on=True)
        assert reply.status_code == status.HTTP_200_OK
        assert reply.data["practice"] == {"most": 3}
        assert reply.data["settings"]["practice"] is True
        assert len(reply.data["players"]) == 2

    def test_count_seats_village_things_marked_and_always_here(self, table):
        t = table(["Ana", "Ben"], seats=5, deck="auto", deck_chip="simple")
        reply = t.practice(count=3)
        assert reply.status_code == status.HTTP_200_OK
        players = reply.data["players"]
        practice = [p for p in players if p.get("practice")]
        assert [p["user"]["display_name"] for p in practice] == list(NAMES[:3])
        assert all(p["connected"] is True for p in practice)
        assert all(p["token"] for p in practice)  # a seat token like anyone's
        people = [p for p in players if not p.get("practice")]
        assert [p["user"]["display_name"] for p in people] == ["Ana", "Ben"]
        # They fill seats: the table is full and the deal counts them.
        assert reply.data["deal"]["ok"] is True
        assert reply.data["practice"] == {"most": 3}
        assert reply.data["settings"]["practice"] is True

    def test_the_count_is_a_target_so_a_resend_changes_nothing(self, table):
        t = table(["Ana"])
        first = t.practice(count=2)
        again = t.practice(count=2)
        assert again.status_code == status.HTTP_200_OK
        assert t.practice_ids() == [
            p["user"]["id"] for p in first.data["players"] if p.get("practice")
        ]
        assert len(t.practice_ids()) == 2

    def test_lowering_the_count_takes_the_newest_away_and_its_account(self, table):
        t = table(["Ana"])
        t.practice(count=3)
        ids = t.practice_ids()
        t.practice(count=1)
        assert t.practice_ids() == ids[:1]
        assert not User.objects.filter(pk__in=ids[1:]).exists()

    def test_switching_off_takes_every_one_away(self, table):
        t = table(["Ana", "Ben"])
        t.practice(count=2)
        ids = t.practice_ids()
        reply = t.practice(on=False)
        assert reply.status_code == status.HTTP_200_OK
        assert "practice" not in reply.data
        assert "practice" not in reply.data["settings"]
        assert t.practice_ids() == []
        assert not User.objects.filter(pk__in=ids).exists()

    def test_more_than_the_free_seats_is_lobby_full_and_changes_nothing(self, table):
        t = table(["Ana", "Ben"], seats=4)
        t.practice(count=1)
        reply = t.practice(count=3)
        assert reply.status_code == status.HTTP_400_BAD_REQUEST
        assert reply.data["code"] == "lobby_full"
        assert len(t.practice_ids()) == 1

    @pytest.mark.parametrize(
        "body",
        [{}, {"on": "yes"}, {"count": -1}, {"count": True}, {"count": "2"}, {"on": 1}],
    )
    def test_a_malformed_request_is_bad_request(self, table, body):
        t = table(["Ana", "Ben"])
        url = reverse("core:lobby-practice", kwargs={"code": t.code})
        reply = t.post("Ana", url, body)
        assert reply.status_code == status.HTTP_400_BAD_REQUEST
        assert reply.data["code"] == "bad_request"

    def test_only_the_host_seats_them(self, table):
        t = table(["Ana", "Ben"])
        reply = t.practice("Ben", count=1)
        assert reply.status_code == status.HTTP_403_FORBIDDEN
        assert t.practice_ids() == []

    def test_an_unknown_table_is_not_found(self, table):
        t = table(["Ana"])
        url = reverse("core:lobby-practice", kwargs={"code": "ZZZZZZ"})
        assert t.post("Ana", url, {"on": True}).status_code == 404

    def test_once_dealt_they_cannot_change(self, table):
        t = table(["Ana"], **_deck(Werewolf=1, Seer=1, Robber=1, Villager=3))
        t.practice(count=2)
        ids = [t.host.pk, *t.practice_ids()]
        t.deal(
            dict(zip(ids, ["Seer", "Robber", "Villager"], strict=True)),
            ["Werewolf", "Villager", "Villager"],
        )
        reply = t.practice(count=0)
        assert reply.status_code == status.HTTP_409_CONFLICT
        assert reply.data["code"] == "lobby_closed"

    def test_a_person_joining_a_full_table_takes_a_practice_seat(self, table):
        t = table(["Ana"], seats=3)
        t.practice(count=2)
        ids = t.practice_ids()
        cleo = _person("Cleo")
        t.people["Cleo"] = cleo
        reply = t.post("Cleo", reverse("core:lobby-join", kwargs={"code": t.code}), {})
        assert reply.status_code == status.HTTP_200_OK
        assert t.practice_ids() == ids[:1]
        names = [p["user"]["display_name"] for p in reply.data["players"]]
        assert names == ["Ana", NAMES[0], "Cleo"]

    def test_a_table_full_of_people_still_refuses_a_join(self, table):
        t = table(["Ana", "Ben", "Cleo"], seats=3)
        dev = _person("Dev")
        t.people["Dev"] = dev
        reply = t.post("Dev", reverse("core:lobby-join", kwargs={"code": t.code}), {})
        assert reply.data["code"] == "lobby_full"


class TestPracticePlayersNeverHost:
    def test_the_last_person_leaving_closes_the_table_and_their_accounts(self, table):
        t = table(["Ana"])
        t.practice(count=3)
        ids = t.practice_ids()
        reply = t.post("Ana", reverse("core:lobby-leave", kwargs={"code": t.code}), {})
        assert reply.status_code == status.HTTP_200_OK
        assert not Lobby.objects.filter(code=t.code).exists()
        assert not User.objects.filter(pk__in=ids).exists()

    def test_the_owner_leaving_hands_the_table_to_a_person_not_a_practice_player(
        self, table
    ):
        # The practice players sat down before Ben: join order must not pick them.
        t = table(["Ana"])
        t.practice(count=2)
        ben = _person("Ben")
        t.people["Ben"] = ben
        t.post("Ben", reverse("core:lobby-join", kwargs={"code": t.code}), {})
        t.post("Ana", reverse("core:lobby-leave", kwargs={"code": t.code}), {})
        assert t.lobby_row.host_id == ben.pk
        assert len(t.practice_ids()) == 2

    def test_handover_never_considers_a_practice_player(self, table):
        t = table(["Ana", "Ben"])
        t.practice(count=2)
        snapshot = core_host._Presence(t.lobby_row)
        assert [m.user_id for m in snapshot.members] == [
            t.people["Ana"].pk,
            t.people["Ben"].pk,
        ]


# ── What they pick (pure) ──────────────────────────────────────────────────


def _state(roles: dict[int, str]) -> GameState:
    return GameState(
        player_roles=dict(roles),
        center_cards=["Villager", "Tanner", "Hunter"],
        original_roles=dict(roles),
        doppelganger_copied_role={},
    )


class TestPracticePicks:
    @pytest.mark.parametrize(
        ("role", "window"),
        [
            ("Seer", 2),
            ("Robber", 2),
            ("Troublemaker", 2),
            ("Drunk", 2),
            ("Werewolf", 2),  # alone: a centre card
            ("Doppelganger", 1),
        ],
    )
    def test_every_role_with_a_choice_picks_something_the_server_reads(
        self, role, window
    ):
        roles = {1: role, 2: "Villager", 3: "Villager", 4: "Mason", 5: "Mason"}
        for seed in range(40):
            prompt = build_choose_prompt(_state(roles), 1, window, role, 0)
            picks = practice_picks(prompt, practice_rng(seed, "w", 1))
            parsed = parse_picks(picks, own_id=1, player_ids=set(roles), center_count=3)
            assert parsed is not None
            reading = interpret_choice(role, parsed, lone_werewolf=role == "Werewolf")
            assert reading is not None, (role, picks)

    @pytest.mark.parametrize(
        "role", ["Villager", "Mason", "Minion", "Insomniac", "Hunter", "Tanner"]
    )
    def test_a_role_with_nothing_to_choose_picks_nothing(self, role):
        roles = {1: role, 2: "Werewolf", 3: "Werewolf", 4: "Mason"}
        prompt = build_choose_prompt(_state(roles), 1, 2, role, 0)
        assert practice_picks(prompt, practice_rng(1, "w2", 1)) == []

    def test_the_seer_takes_both_kinds_of_look_over_many_seeds(self):
        roles = {1: "Seer", 2: "Villager", 3: "Villager"}
        prompt = build_choose_prompt(_state(roles), 1, 2, "Seer", 0)
        kinds = {
            next(iter(practice_picks(prompt, practice_rng(s, "w2", 1))[0]))
            for s in range(60)
        }
        assert kinds == {"player_id", "center_index"}

    def test_the_same_seed_picks_the_same(self):
        roles = {1: "Troublemaker", 2: "Villager", 3: "Villager", 4: "Seer"}
        prompt = build_choose_prompt(_state(roles), 1, 2, "Troublemaker", 0)
        assert practice_picks(prompt, practice_rng(7, "w2:0", 1)) == practice_picks(
            prompt, practice_rng(7, "w2:0", 1)
        )

    def test_the_vote_is_one_of_the_targets(self):
        for seed in range(20):
            assert practice_vote([4, 5, 6], practice_rng(seed, "vote", 1)) in {4, 5, 6}
        assert practice_vote([], practice_rng(1, "vote", 1)) is None


# ── A whole game alone ─────────────────────────────────────────────────────


def _play_alone(t: PracticeTable, person: str = "Ana") -> None:
    """The person's part, start to finish: look, choose (whatever its prompt
    asks), ready to vote, vote. The practice players do the rest."""
    assert t.ready(person).status_code == status.HTTP_200_OK
    while t.refresh().phase == Phase.NIGHT:
        me = t.me(person)
        prompt = me["action_prompt"]
        assert prompt is not None, "the night waits on a practice player"
        if prompt["chooses_left"] > 0:
            picks = practice_picks(prompt, practice_rng(SEED, "person", 0))
            assert t.choose(person, picks).status_code == status.HTTP_200_OK
        else:
            pytest.fail(f"window {me['current_wave']} waits with nothing to do")
    assert t.refresh().phase == Phase.DISCUSSION
    assert t.ready(person).status_code == status.HTTP_200_OK
    assert t.refresh().phase == Phase.VOTING
    target = t.me(person)["vote_targets"][0]
    assert t.vote(person, target).status_code == status.HTTP_200_OK
    assert t.refresh().phase == Phase.RESULTS


class TestAWholeGameAlone:
    def test_one_person_and_four_practice_players_finish_a_game(self, table):
        t = table(
            ["Ana"],
            seats=5,
            **_deck(Werewolf=2, Seer=1, Robber=1, Troublemaker=1, Drunk=1, Villager=2),
        )
        t.practice(count=4)
        ana, *bots = [t.host.pk, *t.practice_ids()]
        t.deal(
            {
                ana: "Villager",
                bots[0]: "Werewolf",
                bots[1]: "Seer",
                bots[2]: "Robber",
                bots[3]: "Troublemaker",
            },
            ["Werewolf", "Drunk", "Villager"],
        )
        # The look: the practice players looked the moment it opened.
        me = t.me("Ana")
        assert me["progress"] == {"stage": "look", "done": 4, "needed": 5}
        # A Villager has nothing to choose: once the person has looked, the
        # practice players' chooses close the night with nobody waiting.
        assert t.ready("Ana").status_code == status.HTTP_200_OK
        assert t.refresh().phase == Phase.DISCUSSION
        assert t.me("Ana")["progress"] == {"stage": "talk", "done": 4, "needed": 5}
        assert t.ready("Ana").status_code == status.HTTP_200_OK
        assert t.refresh().phase == Phase.VOTING
        assert t.me("Ana")["progress"] == {"stage": "vote", "done": 4, "needed": 5}
        assert t.vote("Ana", bots[0]).status_code == status.HTTP_200_OK
        game = t.refresh()
        assert game.phase == Phase.RESULTS
        # Every practice player voted for someone else, and acted at night.
        for bot in bots:
            pr = t.role_of(bot)
            assert pr.has_acted and pr.vote_target_id not in (None, bot)
        (seer,) = t.log_of(bots[1])  # one look, never a skip
        assert seer["action_type"] in ("peek_player", "peek_center")
        assert t.log_of(bots[2])[0]["action_type"] == "swap_with_player"
        assert t.log_of(bots[3])[0]["action_type"] == "swap_others"

    def test_the_results_show_a_practice_players_card_like_anyones(self, table):
        t = table(["Ana"], **_deck(Werewolf=1, Seer=1, Robber=1, Villager=3))
        t.practice(count=2)
        ana, b1, b2 = [t.host.pk, *t.practice_ids()]
        t.deal({ana: "Seer", b1: "Werewolf", b2: "Robber"}, ["Villager"] * 3)
        _play_alone(t)
        results = t.get("Ana", t.url("results")).data
        by_id = {p["player_id"]: p for p in results["players"]}
        assert by_id[b1]["original_role"] == "Werewolf"
        assert by_id[b1]["practice"] is True
        assert "practice" not in by_id[ana]

    def test_the_same_seed_plays_the_same_game(self, table):
        logs = []
        for _ in range(2):
            t = table(["Ana"], **_deck(Werewolf=1, Seer=1, Troublemaker=1, Villager=3))
            t.practice(count=2)
            ana, b1, b2 = [t.host.pk, *t.practice_ids()]
            t.deal(
                {ana: "Villager", b1: "Seer", b2: "Troublemaker"},
                ["Werewolf", "Villager", "Villager"],
            )
            _play_alone(t)
            game = t.refresh()
            # Seats are the same; ids differ between the two tables.
            seat = {pr.user_id: pr.seat for pr in game.player_roles.all()}
            logs.append(
                [
                    (
                        seat[e["player_id"]],
                        e["action_type"],
                        json.dumps(e.get("targets")).count("player_id"),
                    )
                    for e in game.night_actions_log
                ]
            )
            t.post("Ana", reverse("core:lobby-leave", kwargs={"code": t.code}), {})
        assert logs[0] == logs[1]


# ── Each card a practice player can be dealt ───────────────────────────────

# (the practice player's card, the person's, the other practice player's,
# the centre): five cards a table of three is dealt.
DEALS = [
    ("Werewolf", "Villager", "Seer", ["Robber", "Villager", "Villager"]),  # alone
    ("Werewolf", "Villager", "Werewolf", ["Seer", "Villager", "Villager"]),  # a pair
    ("Minion", "Villager", "Werewolf", ["Seer", "Villager", "Villager"]),
    ("Mason", "Villager", "Mason", ["Werewolf", "Villager", "Villager"]),
    ("Seer", "Villager", "Werewolf", ["Robber", "Villager", "Villager"]),
    ("Robber", "Villager", "Werewolf", ["Seer", "Villager", "Villager"]),
    ("Troublemaker", "Villager", "Werewolf", ["Seer", "Villager", "Villager"]),
    ("Drunk", "Villager", "Werewolf", ["Seer", "Villager", "Villager"]),
    ("Insomniac", "Villager", "Werewolf", ["Seer", "Villager", "Villager"]),
    ("Hunter", "Villager", "Werewolf", ["Seer", "Villager", "Villager"]),
    ("Tanner", "Villager", "Werewolf", ["Seer", "Villager", "Villager"]),
    ("Villager", "Villager", "Werewolf", ["Seer", "Tanner", "Villager"]),
    ("Doppelganger", "Seer", "Robber", ["Werewolf", "Villager", "Villager"]),
]

# What the practice player's night must hold (log entries in order): a role with
# a choice always uses it (never a skip, never the server's Drunk swap).
EXPECTED = {
    "Werewolf alone": ["see_team"],
    "Werewolf pair": ["see_team"],
    "Minion": ["see_team"],
    "Mason": ["see_team"],
    "Seer": [{"peek_player", "peek_center"}],
    "Robber": ["swap_with_player"],
    "Troublemaker": ["swap_others"],
    "Drunk": ["swap_with_center"],
    "Insomniac": ["none"],
    "Hunter": [],
    "Tanner": [],
    "Villager": [],
    # She copies the Seer or the Robber (both others are one of them) and uses
    # the copy at once.
    "Doppelganger": ["peek_player", {"peek_player", "peek_center", "swap_with_player"}],
}


def _case(deal: tuple) -> str:
    role, _, other, _ = deal
    if role == "Werewolf":
        return "Werewolf pair" if other == "Werewolf" else "Werewolf alone"
    return role


@pytest.mark.parametrize("deal", DEALS, ids=[_case(d) for d in DEALS])
def test_a_practice_player_plays_each_card_it_can_be_dealt(table, deal):
    role, person, other, center = deal
    cards = [role, person, other, *center]
    counts: dict[str, int] = {}
    for card in cards:
        counts[card] = counts.get(card, 0) + 1
    t = table(["Ana"], **_deck(**counts))
    t.practice(count=2)
    ana, bot, other_bot = [t.host.pk, *t.practice_ids()]
    t.deal({bot: role, ana: person, other_bot: other}, center)
    _play_alone(t)

    entries = t.log_of(bot)
    expected = EXPECTED[_case(deal)]
    assert len(entries) == len(expected), entries
    for entry, want in zip(entries, expected, strict=True):
        allowed = want if isinstance(want, set) else {want}
        assert entry["action_type"] in allowed, entry
        assert not entry.get("made_by_server"), entry
    pr = t.role_of(bot)
    assert pr.vote_target_id not in (None, bot)


def test_a_practice_doppelganger_copies_then_acts_as_her_copy(table):
    t = table(
        ["Ana"],
        **_deck(Doppelganger=1, Robber=1, Troublemaker=1, Werewolf=1, Villager=2),
    )
    t.practice(count=2)
    ana, dop, other = [t.host.pk, *t.practice_ids()]
    # Both others are actors of window 1: whatever she copies, she follows up.
    t.deal(
        {dop: "Doppelganger", ana: "Robber", other: "Troublemaker"},
        ["Werewolf", "Villager", "Villager"],
    )
    _play_alone(t)
    copy, follow_up = t.log_of(dop)[:2]
    copied = t.role_of(dop).night_action_data["copied_role"]
    assert copied in ("Robber", "Troublemaker")
    assert copy["role_acting_as"] == "Doppelganger"
    assert follow_up["role_acting_as"] == copied
    assert (
        follow_up["action_type"]
        == {"Robber": "swap_with_player", "Troublemaker": "swap_others"}[copied]
    )


# ── A mixed table ──────────────────────────────────────────────────────────


def test_at_a_mixed_table_the_game_waits_for_the_people_only(table):
    t = table(
        ["Ana", "Ben"], **_deck(Werewolf=1, Seer=1, Robber=1, Villager=3, Tanner=1)
    )
    t.practice(count=2)
    ana, ben = t.people["Ana"].pk, t.people["Ben"].pk
    b1, b2 = t.practice_ids()
    t.deal(
        {ana: "Villager", ben: "Seer", b1: "Werewolf", b2: "Robber"},
        ["Villager", "Villager", "Tanner"],
    )

    t.ready("Ana")
    assert t.me("Ana")["progress"] == {"stage": "look", "done": 3, "needed": 4}
    t.ready("Ben")
    game = t.refresh()
    assert (game.phase, game.current_wave) == (Phase.NIGHT, 2)
    # Ben's Seer has a choice: the window waits for him, not for the practice
    # players, who chose the moment it opened.
    assert t.role_of(b2).has_acted
    t.choose("Ben", [{"player_id": b1}])
    assert t.refresh().phase == Phase.DISCUSSION
    t.ready("Ana")
    assert t.refresh().phase == Phase.DISCUSSION
    assert t.me("Ben")["progress"] == {"stage": "talk", "done": 3, "needed": 4}
    t.ready("Ben")
    assert t.refresh().phase == Phase.VOTING
    t.vote("Ana", b1)
    assert t.refresh().phase == Phase.VOTING
    t.vote("Ben", b1)
    assert t.refresh().phase == Phase.RESULTS


# ── Hidden information ─────────────────────────────────────────────────────


def test_nothing_a_person_gets_names_a_practice_players_card(table):
    t = table(["Ana"], **_deck(Werewolf=1, Seer=1, Robber=1, Villager=3))
    t.practice(count=2)
    ana, b1, b2 = [t.host.pk, *t.practice_ids()]
    t.deal(
        {ana: "Villager", b1: "Werewolf", b2: "Robber"},
        ["Seer", "Villager", "Villager"],
    )
    secret = {"Werewolf", "Robber", "Seer"}  # the person is a Villager

    def check(payload: Any, where: str) -> None:
        text = json.dumps(payload, default=str)
        for name in secret:
            assert name not in text, f"{where} names {name}: {text}"

    t.ready("Ana")
    while t.refresh().phase != Phase.RESULTS:
        me = t.me("Ana")
        check(me["players"], "/me/ players")
        check(me["night_results"], "/me/ night_results")
        check(me["progress"], "/me/ progress")
        check(t.get("Ana", t.url("player-list")).data, "players/")
        lobby = t.lobby()
        check(lobby["players"], "lobby players")
        if t.game.phase == Phase.DISCUSSION:
            t.ready("Ana")
        elif t.game.phase == Phase.VOTING:
            t.vote("Ana", b1)
        else:
            pytest.fail("the night waited on the person, who has nothing to do")
    game_events = [
        (group, event)
        for group, event in t.recorder.events
        if group.startswith("game_")  # the lobby's carry the public deck
    ]
    assert game_events
    for group, event in game_events:
        if event.get("type") in ("vote.reveal", "game.results"):
            break
        check(event, f"event {event.get('type')} to {group}")
    # The practice players' night was played, and told to nobody.
    assert t.log_of(b2)[0]["action_type"] == "swap_with_player"
    assert not [e for _, e in t.recorder.events if "night_action" in json.dumps(e)]


def test_the_players_list_shows_practice_players_as_here(table):
    t = table(["Ana"], **_deck(Werewolf=1, Seer=1, Robber=1, Villager=3))
    t.practice(count=2)
    ana, b1, b2 = [t.host.pk, *t.practice_ids()]
    t.deal(
        {ana: "Villager", b1: "Werewolf", b2: "Robber"},
        ["Seer", "Villager", "Villager"],
    )
    players = t.get("Ana", t.url("player-list")).data["players"]
    by_id = {p["player_id"]: p for p in players}
    assert by_id[b1]["practice"] is True and by_id[b1]["connected"] is True
    assert "practice" not in by_id[ana]
    me = t.me("Ana")
    assert {p["player_id"] for p in me["players"] if p.get("practice")} == {b1, b2}


# ── The backstop ───────────────────────────────────────────────────────────


def test_a_lost_drive_is_made_up_by_the_next_read(table):
    t = table(["Ana"], **_deck(Werewolf=1, Seer=1, Robber=1, Villager=3))
    t.practice(count=2)
    ana, b1, b2 = [t.host.pk, *t.practice_ids()]
    t.deal({ana: "Seer", b1: "Werewolf", b2: "Robber"}, ["Villager"] * 3)
    # The drive after the night opens is lost (an instance died after the commit).
    with patch("apps.onuw.practice.drive"):
        t.ready("Ana")
    game = t.refresh()
    assert (game.phase, game.current_wave) == (Phase.NIGHT, 2)
    assert not t.role_of(b2).has_acted
    # The person's next read makes it up, and shows the game after it.
    me = t.me("Ana")
    assert t.role_of(b2).has_acted and t.role_of(b1).has_acted
    assert me["stage"] == stage_token(t.refresh())
    t.choose("Ana", [{"player_id": b1}])
    assert t.refresh().phase == Phase.DISCUSSION


def test_a_drive_that_fails_never_fails_the_persons_request(table):
    t = table(["Ana"], **_deck(Werewolf=1, Seer=1, Robber=1, Villager=3))
    t.practice(count=2)
    ana, b1, b2 = [t.host.pk, *t.practice_ids()]
    t.deal({ana: "Seer", b1: "Werewolf", b2: "Robber"}, ["Villager"] * 3)
    with patch("apps.onuw.practice._drive", side_effect=RuntimeError("boom")):
        assert t.ready("Ana").status_code == status.HTTP_200_OK
    assert t.refresh().current_wave == 2
