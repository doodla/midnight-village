"""
Request limits.

What they are for: stopping one source from creating guest accounts by the thousand,
and from scraping the "N at tables" number. Nothing else. They must never be felt at
a table: friends in one room share one network address, so every allowance here is
sized for several tables signing in, retrying and playing from ONE address. Requests
inside a game carry no limit at all.

They count per client address, per server instance (each instance has its own
memory): a courtesy against a naive script, not a wall. A shared counter would need
a shared store, which this does not have.

The address is the one the platform vouches for (``CLIENT_ADDRESS_HEADER``, set in
the Vercel settings to the header Vercel writes itself), else the connection's own
address. It is never read from ``X-Forwarded-For`` as the client sent it: that would
hand anyone a fresh allowance per request. A vouched header counts only when it is
exactly one valid address: a list or anything else (which only a caller adding
headers of their own could produce) shares ONE allowance with every other such
request, so making addresses up buys nothing. An IPv6 caller is counted by network
(/64): one home or venue holds a whole /64.
"""

from __future__ import annotations

import ipaddress
import logging

from django.conf import settings

from rest_framework.request import Request
from rest_framework.throttling import SimpleRateThrottle

logger = logging.getLogger(__name__)


def _counted_as(text: str) -> str | None:
    """One valid address as the key it is counted under, else None."""
    try:
        address = ipaddress.ip_address(text.strip())
    except ValueError:
        return None
    if address.version == 6:
        if address.ipv4_mapped:
            return str(address.ipv4_mapped)
        return str(ipaddress.ip_network(f"{address}/64", strict=False).network_address)
    return str(address)


def client_address(request: Request) -> str:
    """The address a client cannot choose."""
    header = getattr(settings, "CLIENT_ADDRESS_HEADER", None)
    if header:
        vouched = request.META.get(header)
        if vouched is not None:
            return _counted_as(vouched) or "unverified"
        # the platform always writes it: without it every phone shares one allowance
        logger.warning("request limits: %s is missing from a request", header)
    return _counted_as(request.META.get("REMOTE_ADDR") or "") or "unknown"


class ClientAddressThrottle(SimpleRateThrottle):
    """An allowance per client address, for everyone who calls (signed in or not)."""

    def get_cache_key(self, request: Request, view: object) -> str:
        return self.cache_format % {
            "scope": self.scope,
            "ident": client_address(request),
        }


class SignUpThrottle(ClientAddressThrottle):
    """Guest accounts made from one address."""

    scope = "sign_up"


class OnlineStatsThrottle(ClientAddressThrottle):
    """Its own budget: the home screen polls this, guest sign-up must not pay for it."""

    scope = "online_stats"
