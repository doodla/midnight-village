"""
Harness settings — for the deterministic integration-test harness ONLY.

Inherits development (DEBUG=True, InMemoryChannelLayer, CORS open) but points at a
THROWAWAY database so the harness never touches dev data, and relaxes the guest
throttle so a suite can create many guests rapidly without 429s.

NOTE: GuestCreateView hardcodes throttle_classes=[AnonRateThrottle] (scope "anon"),
so we relax by raising the "anon" rate, not by clearing DEFAULT_THROTTLE_CLASSES.
"""

from .development import *
from .development import DATABASES, REST_FRAMEWORK

# Throwaway DB — ALWAYS this fixed name, never dev. We deliberately do NOT honor
# DB_NAME (development.py does): an exported DB_NAME=midnight_village_dev would
# otherwise aim the harness's migrate / throwaway-data workflow at the dev
# database. The `harness-serve` recipe createdb's this same name.
DATABASES["default"]["NAME"] = "midnight_village_harness"

# Effectively disable rate limiting for the harness (high ceiling beats removing
# the class, since the guest view sets throttle_classes explicitly).
REST_FRAMEWORK["DEFAULT_THROTTLE_RATES"] = {
    "anon": "1000000/minute",
    "user": "1000000/minute",
}
