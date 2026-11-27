"""What phones report about their own speed: one row per summary (``summary.py``)."""

from django.db import models
from django.db.models.functions import Now
from django.utils import timezone


class FieldSummary(models.Model):
    """One phone's numbers for one game, or for the play before its tab was hidden.
    Only times, counts, labels from the closed lists (``vocabulary.py``), the kind of
    phone and browser, and the hour it came in: ``summary.clean`` keeps nothing else.
    No user, no table, no game."""

    received_at = models.DateTimeField(
        db_default=Now(), default=timezone.now, db_index=True
    )
    commit = models.CharField(max_length=40, db_default="", default="")
    device = models.CharField(max_length=32, db_default="", default="")
    body = models.JSONField()

    class Meta:
        ordering = ["-id"]

    def __str__(self) -> str:
        return f"{self.received_at:%Y-%m-%d %H}h {self.device} {self.commit[:7]}"
