"""The check that runs after each merge (`tool/deployed_check.py`) against this server.

It is the same script GitHub runs against the live addresses, here pointed at a
local server: a change to the guest, table, join or leave answers that would
break the check after a merge fails here first, on the pull request.
"""

import http.server
import importlib.util
import threading
from pathlib import Path

from django.contrib.auth import get_user_model

import pytest

from apps.core.models import Lobby

SCRIPT = Path(__file__).resolve().parents[3] / "tool" / "deployed_check.py"
spec = importlib.util.spec_from_file_location("deployed_check", SCRIPT)
assert spec and spec.loader
deployed_check = importlib.util.module_from_spec(spec)
spec.loader.exec_module(deployed_check)

pytestmark = [pytest.mark.integration, pytest.mark.django_db(transaction=True)]


def test_start_and_join_pass_against_a_real_server_and_leave_no_table(live_server):
    failures = deployed_check.run(live_server.url)

    assert failures == []
    # the last one out deletes the table; only the two named guests stay behind
    assert Lobby.objects.count() == 0
    names = sorted(get_user_model().objects.values_list("display_name", flat=True))
    assert names == sorted(deployed_check.GUEST_NAMES)


def test_health_names_the_commit_the_build_was_made_from(live_server, monkeypatch):
    monkeypatch.setenv("VERCEL_GIT_COMMIT_SHA", "abc123")

    assert deployed_check.live_commits(live_server.url, None) == ("abc123", "")
    deployed_check.wait_for_commit(live_server.url, None, "abc123", seconds=0)


def test_waiting_for_a_commit_that_never_arrives_fails_and_says_what_is_live(
    live_server,
):
    with pytest.raises(
        deployed_check.Failed, match=r"server: NO deploy of f{10} arrived"
    ):
        deployed_check.wait_for_commit(live_server.url, None, "f" * 40, seconds=0)
    failures = deployed_check.run(live_server.url, commit="f" * 40, wait=0)
    # the missing deploy is the one failure: the build that IS serving is still
    # checked (health, Start and Join), and works
    assert len(failures) == 1 and "NO deploy of" in failures[0]


def test_a_missing_deploy_is_told_for_the_server_and_the_app_each_on_its_own():
    """Vercel builds and skips the two separately: the message says which."""
    merged, older = "a" * 40, "b" * 40
    app_only = deployed_check.no_deploy_message(merged, 900, older, merged, True)
    assert (
        f"server: NO deploy of {merged[:10]} arrived; still serving {older[:10]}"
        in app_only
    )
    assert "app: deployed" in app_only
    neither = deployed_check.no_deploy_message(merged, 900, older, "", True)
    assert neither.count("NO deploy of") == 2
    server_alone = deployed_check.no_deploy_message(merged, 900, older, "", False)
    assert "app:" not in server_alone


def test_each_side_can_wait_for_its_own_commit(live_server, monkeypatch):
    """The server and the app are deployed from their own branches."""
    monkeypatch.setenv("VERCEL_GIT_COMMIT_SHA", "abc123")
    told = deployed_check.no_deploy_message(
        "abc123", 0, "abc123", "old", True, "def456"
    )
    assert "server: deployed (abc123)" in told
    assert "app: NO deploy of def456 arrived; still serving old" in told
    # with no app address only the server's commit is waited for
    deployed_check.wait_for_commit(live_server.url, None, "abc123", 0, app_commit="zzz")


def test_a_page_of_html_where_json_belongs_fails_the_step(live_server):
    # what a broken rewrite serves: the admin login page stands in for index.html
    with pytest.raises(deployed_check.Failed, match="wanted 200 JSON"):
        deployed_check.json_call(
            "health", "GET", f"{live_server.url}/admin/login/", 200
        )


def test_a_failed_step_still_makes_both_guests_leave(live_server, monkeypatch):
    real = deployed_check.json_call

    def break_the_read(what, method, url, want, **kwargs):
        if what == "read the table":
            raise deployed_check.Failed("the table could not be read")
        return real(what, method, url, want, **kwargs)

    monkeypatch.setattr(deployed_check, "json_call", break_the_read)

    with pytest.raises(deployed_check.Failed, match="could not be read"):
        deployed_check.start_and_join(live_server.url)
    assert Lobby.objects.count() == 0


def test_a_join_whose_answer_was_lost_is_still_cleaned_up(live_server, monkeypatch):
    real = deployed_check.json_call

    def lose_the_join_answer(what, method, url, want, **kwargs):
        body = real(what, method, url, want, **kwargs)
        if what == "Join by code":
            raise deployed_check.Failed("the join happened, its answer never arrived")
        return body

    monkeypatch.setattr(deployed_check, "json_call", lose_the_join_answer)

    with pytest.raises(deployed_check.Failed, match="never arrived"):
        deployed_check.start_and_join(live_server.url)
    assert Lobby.objects.count() == 0


class AppStub(http.server.BaseHTTPRequestHandler):
    """The web app as Vercel serves it: real files first, the page for a path with no
    extension, a 404 for any other missing file (frontend/vercel.json)."""

    files: dict = {}
    serve_page_for_files = False
    rewrite_app_routes = True
    page = (
        b"<!DOCTYPE html><html><body>"
        b'<script src="flutter_bootstrap.js" async></script></body></html>'
    )

    def do_GET(self):
        body = self.files.get(self.path)
        if self.path == "/":  # index.html is a real file: no rewrite needed
            body = self.page
        is_route = "." not in self.path and self.rewrite_app_routes
        if body is None and (self.serve_page_for_files or is_route):
            body = self.page
        if body is None:
            self.send_response(404)
            self.end_headers()
            return
        self.send_response(200)
        self.send_header(
            "Content-Type", "text/html" if body is self.page else "text/plain"
        )
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


@pytest.fixture
def app_stub():
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), AppStub)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    AppStub.files = {}
    AppStub.serve_page_for_files = False
    AppStub.rewrite_app_routes = True
    yield f"http://127.0.0.1:{server.server_port}"
    server.shutdown()
    thread.join()


def test_the_apps_page_served_for_commit_txt_is_not_a_commit(live_server, app_stub):
    # a build from before commit.txt answers every unknown path with the page
    assert deployed_check.live_commits(live_server.url, app_stub) == ("", "")
    AppStub.files = {"/commit.txt": b"abc123\n"}
    assert deployed_check.live_commits(live_server.url, app_stub) == ("", "abc123")


def test_an_app_built_against_another_server_fails(live_server, app_stub):
    AppStub.files = {"/main.dart.js": b'var api="https://another-server.example";'}
    with pytest.raises(deployed_check.Failed, match="does not name the server"):
        deployed_check.check_app(live_server.url, app_stub)


def test_an_app_the_server_does_not_let_in_fails(live_server, app_stub, settings):
    settings.CORS_ALLOWED_ORIGINS = []
    AppStub.files = {"/main.dart.js": f'var api="{live_server.url}";'.encode()}
    with pytest.raises(deployed_check.Failed, match="does not let the app call it"):
        deployed_check.check_app(live_server.url, app_stub)


def test_the_app_steps_pass_when_bundle_and_cors_agree(live_server, app_stub, settings):
    settings.CORS_ALLOWED_ORIGINS = [app_stub]
    AppStub.files = {"/main.dart.js": f'var api="{live_server.url}";'.encode()}
    deployed_check.check_app(live_server.url, app_stub)


def test_an_app_that_answers_a_missing_picture_with_its_page_fails(
    live_server, app_stub, settings
):
    settings.CORS_ALLOWED_ORIGINS = [app_stub]
    AppStub.files = {"/main.dart.js": f'var api="{live_server.url}";'.encode()}
    AppStub.serve_page_for_files = True
    with pytest.raises(deployed_check.Failed, match="wanted 404"):
        deployed_check.check_app(live_server.url, app_stub)


def test_the_join_link_of_an_open_table_must_serve_the_app(app_stub):
    deployed_check.check_join_link(app_stub, "ABC123")
    AppStub.rewrite_app_routes = False  # a broken rewrite: `/` still works, routes 404
    with pytest.raises(deployed_check.Failed, match="rewrite for app routes"):
        deployed_check.check_join_link(app_stub, "ABC123")


def test_the_join_link_answered_with_something_else_fails(app_stub):
    AppStub.files = {"/join/ABC123": b"not the app"}
    with pytest.raises(deployed_check.Failed, match="not the app's page"):
        deployed_check.check_join_link(app_stub, "ABC123")


def test_the_apps_commit_must_be_the_merged_one(live_server, app_stub, settings):
    settings.CORS_ALLOWED_ORIGINS = [app_stub]
    AppStub.files = {
        "/main.dart.js": f'var api="{live_server.url}";'.encode(),
        "/commit.txt": b"abc123\n",
    }
    deployed_check.check_app(live_server.url, app_stub, commit="abc123")
    with pytest.raises(deployed_check.Failed, match="wanted the merged commit"):
        deployed_check.check_app(live_server.url, app_stub, commit="def456")


def test_a_run_probes_the_join_link_of_the_table_it_opened(
    live_server, app_stub, settings
):
    settings.CORS_ALLOWED_ORIGINS = [app_stub]
    AppStub.files = {"/main.dart.js": f'var api="{live_server.url}";'.encode()}
    assert deployed_check.run(live_server.url, app_stub) == []

    AppStub.rewrite_app_routes = False
    failures = deployed_check.run(live_server.url, app_stub)
    assert len(failures) == 1 and "the table's link" in failures[0]
    assert Lobby.objects.count() == 0  # the failed probe still left the table
