"""The phones' speed summaries in, and the report out.

``POST /api/observe/summary/``: one summary (``summary.py``), as the app's
``navigator.sendBeacon`` sends it: ``text/plain`` (so the browser asks no preflight),
JSON inside, at most ``MOST_BYTES``. No account: a beacon carries none, and the row
must not name one. Limited per address (``field_summary``). Each one kept also clears
what is older than ``KEEP_DAYS`` and all but the newest ``KEEP_ROWS``.

``GET /api/observe/report/?games=N``: the last N summaries merged (``report.py``),
read only. It holds times and counts, nothing about anyone.
"""

from __future__ import annotations

import json
from datetime import timedelta

from django.db import transaction
from django.utils import timezone

from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.core.throttles import ClientAddressThrottle

from . import report
from .models import FieldSummary
from .summary import clean, device

MOST_BYTES = 16_384
KEEP_DAYS = 30
KEEP_ROWS = 5_000
DEFAULT_GAMES = 30
MOST_GAMES = 200


class FieldSummaryThrottle(ClientAddressThrottle):
    """Its own allowance: a room of tables shares one address."""

    scope = "field_summary"


class SummaryView(APIView):
    authentication_classes: list = []
    permission_classes = [AllowAny]
    throttle_classes = [FieldSummaryThrottle]

    def post(self, request: Request) -> Response:
        raw = request.body
        if len(raw) > MOST_BYTES:
            return Response(
                {"code": "too_large"}, status=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE
            )
        try:
            kept = clean(json.loads(raw))
        except (ValueError, UnicodeDecodeError):
            kept = None
        if kept is None:
            return Response({"code": "bad_request"}, status=status.HTTP_400_BAD_REQUEST)
        with transaction.atomic():
            row = FieldSummary.objects.create(
                received_at=timezone.now(),
                commit=kept["commit"],
                device=device(kept["env"].get("agent", "")),
                body=kept,
            )
            FieldSummary.objects.filter(
                received_at__lt=timezone.now() - timedelta(days=KEEP_DAYS)
            ).delete()
            FieldSummary.objects.filter(id__lte=row.id - KEEP_ROWS).delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class ReportView(APIView):
    authentication_classes: list = []
    permission_classes = [AllowAny]
    throttle_classes = [FieldSummaryThrottle]

    def get(self, request: Request) -> Response:
        try:
            games = int(request.query_params.get("games", DEFAULT_GAMES))
        except ValueError:
            return Response({"code": "bad_request"}, status=status.HTTP_400_BAD_REQUEST)
        games = max(1, min(games, MOST_GAMES))
        rows = FieldSummary.objects.all()[:games]
        return Response(report.build(rows))
