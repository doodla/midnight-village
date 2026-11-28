"""
CORS: a web app on an allowed origin may read the response ``Date`` header (the
server's clock) and ``Server-Timing`` (what the answer cost the server: the field
recorder splits a round trip with it), on an ordinary answer and on a preflight. ``CORS_EXPOSE_HEADERS``
lives in the base settings, so every environment that imports them sends it; the
allowed origins stay per environment, and a stranger's origin is told nothing.
"""

from pathlib import Path

from django.conf import settings
from django.test import override_settings
from django.urls import reverse

import pytest
from repo_files import checkout_files

pytestmark = pytest.mark.integration

APP = "https://app.example"
SETTINGS = Path(settings.BASE_DIR) / "config" / "settings"


@pytest.fixture(autouse=True)
def app_origin():
    """This environment's allowed origin is the app's (as Vercel's is)."""
    with override_settings(CORS_ALLOWED_ORIGINS=[APP], CORS_ALLOW_ALL_ORIGINS=False):
        yield


@pytest.mark.django_db
class TestDateIsExposed:
    def test_an_answer_to_the_app_exposes_date(self, api_client) -> None:
        response = api_client.get(reverse("core:health-check"), HTTP_ORIGIN=APP)

        assert response.status_code == 200
        assert response["Access-Control-Allow-Origin"] == APP
        assert response["Access-Control-Expose-Headers"] == "Date, Server-Timing"

    def test_a_preflight_exposes_date(self, api_client) -> None:
        response = api_client.options(
            reverse("core:health-check"),
            HTTP_ORIGIN=APP,
            HTTP_ACCESS_CONTROL_REQUEST_METHOD="GET",
        )

        assert response.status_code == 200
        assert response["Access-Control-Expose-Headers"] == "Date, Server-Timing"

    def test_the_app_may_read_what_the_answer_cost_the_server(self, api_client) -> None:
        """The header is on the answer, and the browser lets the app's code read it."""
        response = api_client.get(reverse("core:health-check"), HTTP_ORIGIN=APP)

        assert response["Server-Timing"].startswith(("connect;", "total;", "db;"))
        exposed = response["Access-Control-Expose-Headers"].split(", ")
        assert "Server-Timing" in exposed

    def test_an_origin_that_is_not_allowed_is_told_nothing(self, api_client) -> None:
        response = api_client.get(
            reverse("core:health-check"), HTTP_ORIGIN="https://elsewhere.example"
        )

        assert "Access-Control-Allow-Origin" not in response
        assert "Access-Control-Expose-Headers" not in response


def test_the_setting_is_in_base_and_no_environment_drops_it() -> None:
    """Every environment's settings start from base and none overrides it."""
    assert settings.CORS_EXPOSE_HEADERS == ["Date", "Server-Timing"]
    assert (
        'CORS_EXPOSE_HEADERS = ["Date", "Server-Timing"]'
        in (SETTINGS / "base.py").read_text()
    )
    settings_dir = SETTINGS.resolve()
    for module in checkout_files(SETTINGS, suffixes=(".py",)):
        if module.parent != settings_dir or module.name in {"base.py", "__init__.py"}:
            continue
        text = module.read_text()
        assert "from .base import *" in text or "from .development import *" in text
        assert "CORS_EXPOSE_HEADERS" not in text, module.name
