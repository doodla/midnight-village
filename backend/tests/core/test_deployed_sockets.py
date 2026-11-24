"""The socket leg of the check after each merge (`tool/deployed_sockets.py`), against
this server with its sockets served (Daphne, as live): a change to the deal, a
stage request, play again or what the lobby's socket says that would break the
check after a merge fails here first, on the pull request.
"""

import importlib.util
import json
from pathlib import Path

from django.contrib.auth import get_user_model
from django.test import override_settings

import pytest
from channels.testing import ChannelsLiveServerTestCase

from apps.core.models import Lobby

TOOL = Path(__file__).resolve().parents[3] / "tool"


def loaded(name):
    spec = importlib.util.spec_from_file_location(name, TOOL / f"{name}.py")
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


deployed_check = loaded("deployed_check")
deployed_sockets = deployed_check.socket_leg()

pytestmark = [pytest.mark.integration]


# The live server's rules for lengths, not this suite's relaxed ones: the check's
# first run on the live server was refused a length the relaxed rules accept.
@override_settings(ONUW_ALLOW_UNTIMED_NIGHT=False)
class TheSocketLeg(ChannelsLiveServerTestCase):
    def test_this_server_holds_the_live_rules_for_lengths(self):
        made = deployed_check.call(
            "POST",
            f"{self.live_server_url}/api/auth/guest/",
            body={"display_name": "Rules"},
        )
        token = json.loads(made[2])["access"]
        table = deployed_check.call(
            "POST",
            f"{self.live_server_url}/api/lobbies/",
            body={"game_type": "onuw", "defaults": "v2"},
            token=token,
        )
        code = json.loads(table[2])["code"]

        status, _, raw = deployed_check.call(
            "PATCH",
            f"{self.live_server_url}/api/lobbies/{code}/",
            body={"settings": {"night_min_window_seconds": 0}},
            token=token,
        )

        assert status == 400, raw

    def test_a_deal_and_a_restart_are_heard_and_no_table_is_left(self):
        said = []

        deployed_check.deal_is_heard(self.live_server_url, say=said.append)

        heard = [line for line in said if "heard" in line]
        assert len(heard) == 4, said  # two listeners: the deal, then the restart
        assert Lobby.objects.count() == 0
        names = sorted(get_user_model().objects.values_list("display_name", flat=True))
        assert names == sorted(deployed_sockets.GUEST_NAMES)

    def test_a_listener_that_hears_nothing_fails_and_everyone_still_leaves(self):
        original = deployed_sockets.Listener.hear

        def deaf(listener, wanted, within):
            raise deployed_sockets.SocketFailed(
                "not heard within 5 s (heard instead: nothing)"
            )

        deployed_sockets.Listener.hear = deaf
        try:
            with pytest.raises(deployed_check.Failed, match="did not hear the deal"):
                deployed_check.deal_is_heard(self.live_server_url, say=lambda _: None)
        finally:
            deployed_sockets.Listener.hear = original

        # the abandoned game ended by its own short timers, and the guests left
        assert Lobby.objects.count() == 0
