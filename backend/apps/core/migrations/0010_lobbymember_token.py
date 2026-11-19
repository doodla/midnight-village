"""Player tokens: a column, a backfill of existing members, then the unique rule.

Safe to run while the previous code still serves (see "Deploy-safe changes" in
backend/CLAUDE.md):

* the first operation sets a lock timeout, so an ALTER that cannot get its lock
  fails the deploy at once instead of queueing behind a long transaction and
  blocking the live site behind itself;
* the column has a DATABASE default (``""``), so an INSERT that does not know the
  column keeps working, and the unique constraint ignores blank tokens;
* the backfill touches only lobbies that are not finished, and gives each member
  the token they would have been dealt had they joined under the new code (same
  algorithm as ``apps.core.tokens``, join order). Everything else stays blank and
  is handled lazily: a finished table never needs tokens again, and a member the
  old code seats after this runs gets one at the deal. Members beyond the tenth of
  a legacy oversize lobby stay blank too.

A migration must not import application code (it would change under it), so the
token list and the algorithm are copied here, frozen as they were.
"""

import random

from django.db import migrations, models

TOKENS = (
    "crow",
    "key",
    "moth",
    "bell",
    "thorn",
    "antler",
    "hare",
    "lantern",
    "spindle",
    "scythe",
)


def backfill_tokens(apps, schema_editor):
    db = schema_editor.connection.alias
    Lobby = apps.get_model("core", "Lobby")
    LobbyMember = apps.get_model("core", "LobbyMember")
    lobbies = Lobby.objects.using(db).exclude(status="finished")
    for lobby in lobbies.iterator():
        rng = random.Random(f"{lobby.code}:tokens")  # the order apps.core.tokens uses
        order = rng.sample(TOKENS, len(TOKENS))
        members = LobbyMember.objects.using(db).filter(lobby=lobby)
        for member, token in zip(members.order_by("joined_at", "id"), order):
            LobbyMember.objects.using(db).filter(pk=member.pk).update(token=token)


class Migration(migrations.Migration):
    dependencies = [
        ("core", "0009_scheduledtimer"),
    ]

    operations = [
        migrations.RunSQL("SET LOCAL lock_timeout = '5s'", migrations.RunSQL.noop),
        migrations.AlterModelOptions(
            name="lobbymember",
            options={"ordering": ("joined_at", "id")},
        ),
        migrations.AddField(
            model_name="lobbymember",
            name="token",
            field=models.CharField(
                blank=True, db_default="", default="", max_length=16
            ),
        ),
        migrations.RunPython(backfill_tokens, migrations.RunPython.noop),
        migrations.AddConstraint(
            model_name="lobbymember",
            constraint=models.UniqueConstraint(
                condition=models.Q(("token", ""), _negated=True),
                fields=("lobby", "token"),
                name="unique_lobby_token",
            ),
        ),
    ]
