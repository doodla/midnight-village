"""Each test run has its own database, and only a dead run's database is dropped."""

import multiprocessing
import os

from django.conf import settings
from django.db import connection

import pytest

from config.test_database import leftover_databases, process_is_alive, run_database_name

pytestmark = pytest.mark.unit


def test_two_runs_of_one_checkout_get_different_databases():
    assert run_database_name("mv_dev", 101) != run_database_name("mv_dev", 102)
    assert run_database_name("mv_dev", 101) == "test_mv_dev_101"


def test_only_databases_of_dead_runs_of_this_name_are_leftovers():
    names = [
        "postgres",
        "mv_dev",
        "test_mv_dev",  # not a run's database: could be someone's own
        "test_mv_dev_10",  # dead
        "test_mv_dev_20",  # still running
        "test_mv_dev_30",  # this run
        "test_mv_dev_other_10",  # another checkout's name: not ours to touch
        "test_mv_10",
    ]
    gone = leftover_databases(
        names, "mv_dev", own_pid=30, is_alive=lambda pid: pid == 20
    )
    assert gone == ["test_mv_dev_10"]


def test_a_name_with_regex_characters_is_matched_literally():
    assert (
        leftover_databases(["test_axb_1"], "a.b", own_pid=2, is_alive=lambda _: False)
        == []
    )


def test_this_process_is_alive_and_a_spent_one_is_not():
    assert process_is_alive(os.getpid())
    spent = multiprocessing.get_context("spawn").Process(target=int)
    spent.start()
    spent.join()
    assert spent.pid is not None
    assert not process_is_alive(spent.pid)


@pytest.mark.django_db
def test_this_run_is_on_its_own_database():
    base = os.environ.get("DB_NAME", "midnight_village_test")
    assert settings.DATABASES["default"]["TEST"]["NAME"] == run_database_name(
        base, os.getpid()
    )
    assert connection.settings_dict["NAME"] == run_database_name(base, os.getpid())
