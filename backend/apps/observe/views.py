"""The phones' speed summaries in, and the owner's report out.

``POST /api/observe/summary/``: one summary (``summary.py``), as the app's
``navigator.sendBeacon`` sends it: ``text/plain`` (so the browser asks no preflight),
JSON inside, at most ``MOST_BYTES``. No account: a beacon carries none, and the row
must not name one. Limited per address (``field_summary``). Each one kept stamps the
hour it came in (the database's clock, no finer) and clears, in one statement, what is
older than ``KEEP_DAYS`` and all but the newest ``KEEP_ROWS``.

``GET /api/observe/report/?last=N``: the last N summaries merged (``report.py``), for
the owner only. A summary sent mid-game says which screens and controls one phone
used, which can tell what it did at night, so the report is never public: it answers
only a request carrying the ``FIELD_REPORT_KEY`` environment variable's value in the
``X-Field-Report-Key`` header (``just field-report`` sends it from its own
environment). With the variable unset, or any other key, it answers 404, as if there
were no such page: closed by default, the summaries still kept.
"""

from __future__ import annotations

import hmac
import json
from datetime import timedelta

from django.conf import settings
from django.db import transaction
from django.db.models import DateTimeField, Q
from django.db.models.functions import Now, Trunc

from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.core.throttles import ClientAddressThrottle

from . import report
from .models import FieldSummary
from .summary import clean

MOST_BYTES = 8_192
KEEP_DAYS = 30
KEEP_ROWS = 2_000
DEFAULT_ROWS = 30
MOST_ROWS = 60
KEY_HEADER = "HTTP_X_FIELD_REPORT_KEY"


class FieldSummaryThrottle(ClientAddressThrottle):
    """Its own allowance: a room of tables shares one address."""

    scope = "field_summary"


class FieldReportThrottle(ClientAddressThrottle):
    """The owner's reads, apart from the room's summaries."""

    scope = "field_report"


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
        except (ValueError, UnicodeDecodeError, RecursionError):
            kept = None
        if kept is None:
            return Response({"code": "bad_request"}, status=status.HTTP_400_BAD_REQUEST)
        summary, device = kept
        with transaction.atomic():
            row = FieldSummary.objects.create(
                received_at=Trunc(Now(), "hour", output_field=DateTimeField()),
                commit=summary["commit"],
                device=device,
                body=summary,
            )
            FieldSummary.objects.filter(
                Q(received_at__lt=Now() - timedelta(days=KEEP_DAYS))
                | Q(id__lte=row.id - KEEP_ROWS)
            ).delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


def owner_asks(request: Request) -> bool:
    """The request carries the owner's key, and a key is set."""
    key = getattr(settings, "FIELD_REPORT_KEY", "")
    given = request.META.get(KEY_HEADER, "")
    return bool(key) and hmac.compare_digest(given.encode(), key.encode())


class ReportView(APIView):
    authentication_classes: list = []
    permission_classes = [AllowAny]
    throttle_classes = [FieldReportThrottle]

    def get(self, request: Request) -> Response:
        if not owner_asks(request):
            return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)
        try:
            last = int(request.query_params.get("last", DEFAULT_ROWS))
        except ValueError:
            return Response({"code": "bad_request"}, status=status.HTTP_400_BAD_REQUEST)
        last = max(1, min(last, MOST_ROWS))
        return Response(report.build(FieldSummary.objects.all()[:last]))
