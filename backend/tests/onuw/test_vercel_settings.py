"""config/settings/vercel.py reads everything from the environment."""

import importlib
import sys

import pytest

pytestmark = pytest.mark.unit

ENV = {
    "SECRET_KEY": "not-a-real-secret",
    "DATABASE_URL": "postgres://app:p%40ss@db.example.com:6543/mv?x=1",
    "REDIS_URL": "rediss://default:pw@redis.example.com:6379",
    "ALLOWED_HOSTS": "api.example.com, other.example.com",
    "CORS_ALLOWED_ORIGINS": "https://app.example.com",
    "CSRF_TRUSTED_ORIGINS": "https://api.example.com",
    "VERCEL_URL": "deploy-123.vercel.app",
}


def load(monkeypatch):
    for key, value in ENV.items():
        monkeypatch.setenv(key, value)
    sys.modules.pop("config.settings.vercel", None)
    return importlib.import_module("config.settings.vercel")


def test_the_settings_come_from_the_environment(monkeypatch):
    s = load(monkeypatch)

    assert s.DEBUG is False
    assert s.SECRET_KEY == "not-a-real-secret"
    db = s.DATABASES["default"]
    assert (db["NAME"], db["USER"], db["PASSWORD"], db["HOST"], db["PORT"]) == (
        "mv",
        "app",
        "p@ss",
        "db.example.com",
        "6543",
    )
    assert db["CONN_MAX_AGE"] == 0
    assert db["ENGINE"] == "apps.core.pooled_postgres"
    assert db["OPTIONS"]["pool"]["min_size"] == 0
    assert db["OPTIONS"]["pool"]["max_size"] == 5
    assert db["OPTIONS"]["sslmode"] == "require"
    assert (
        s.CHANNEL_LAYERS["default"]["BACKEND"]
        == "channels_redis.core.RedisChannelLayer"
    )
    assert s.CHANNEL_LAYERS["default"]["CONFIG"]["hosts"] == [ENV["REDIS_URL"]]
    assert s.ALLOWED_HOSTS == [
        "api.example.com",
        "other.example.com",
        "deploy-123.vercel.app",
    ]
    assert s.CORS_ALLOWED_ORIGINS == ["https://app.example.com"]
    assert s.CSRF_TRUSTED_ORIGINS == ["https://api.example.com"]


def test_an_old_conn_max_age_on_the_project_cannot_stop_the_pool(monkeypatch):
    # Django refuses a pool with persistent connections; an old DB_CONN_MAX_AGE left
    # on the project must not take the server down.
    monkeypatch.setenv("DB_CONN_MAX_AGE", "60")
    monkeypatch.setenv("DB_POOL_MAX_SIZE", "3")
    db = load(monkeypatch).DATABASES["default"]

    assert db["CONN_MAX_AGE"] == 0
    assert db["OPTIONS"]["pool"]["max_size"] == 3


def test_timers_use_the_queue_and_nothing_recovers_at_start_up(monkeypatch):
    s = load(monkeypatch)

    assert s.ONUW_TIMER_BACKEND == "vercel_queue"
    assert s.ONUW_RECOVER_TIMERS_ON_START is False


def test_a_missing_secret_stops_the_app_from_starting(monkeypatch):
    for key, value in ENV.items():
        monkeypatch.setenv(key, value)
    monkeypatch.delenv("SECRET_KEY")
    sys.modules.pop("config.settings.vercel", None)

    with pytest.raises(KeyError):
        importlib.import_module("config.settings.vercel")


def test_a_database_url_that_is_not_postgres_is_refused(monkeypatch):
    for key, value in ENV.items():
        monkeypatch.setenv(key, value)
    monkeypatch.setenv("DATABASE_URL", "mysql://u:p@h/db")
    sys.modules.pop("config.settings.vercel", None)

    with pytest.raises(ValueError):
        importlib.import_module("config.settings.vercel")


def test_the_request_limits_count_by_the_address_vercel_writes(monkeypatch):
    assert load(monkeypatch).CLIENT_ADDRESS_HEADER == "HTTP_X_VERCEL_FORWARDED_FOR"
