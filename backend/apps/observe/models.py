"""What phones report about their own speed: one row per summary (``summary.py``)."""

from django.db import models
from django.db.models.functions import Now
from django.utils import timezone


class FieldSummary(models.Model):
    """One phone's numbers for one game (or the stretch of play before its tab was
    hidden). Only times, counts, kinds of screen and control, request paths without
    ids, and what the phone says about itself: ``summary.clean`` keeps nothing else.
    No user, no table, no game: a row cannot be traced to a person."""

    received_at = models.DateTimeField(
        db_default=Now(), default=timezone.now, db_index=True
    )
    commit = models.CharField(max_length=40, db_default="", default="")
    device = models.CharField(max_length=32, db_default="", default="")
    body = models.JSONField()

    class Meta:
        ordering = ["-received_at", "-id"]

    def __str__(self) -> str:
        return f"{self.received_at:%Y-%m-%d %H:%M} {self.device} {self.commit[:7]}"
