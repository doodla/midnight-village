"""Player tokens: a column, a backfill of existing members, then the unique rule.

Safe to run while the previous code still serves: the column has a DATABASE
default (``""``), so an INSERT that does not know the column keeps working, and
the unique constraint ignores blank tokens. A member added by the old code after
the backfill stays blank and is given a token at the deal. Existing members get
the token they would have been dealt had they joined under the new code (same
algorithm, join order); members beyond the tenth of a legacy oversize lobby stay
blank. The constraint is added after the backfill so it cannot fail on rows.
"""

from django.db import migrations, models

from apps.core.tokens import first_free_token


def backfill_tokens(apps, schema_editor):
    Lobby = apps.get_model("core", "Lobby")
    LobbyMember = apps.get_model("core", "LobbyMember")
    for lobby in Lobby.objects.all().iterator():
        taken: set[str] = set()
        members = LobbyMember.objects.filter(lobby=lobby).order_by("joined_at", "id")
        for member in members:
            token = first_free_token(lobby.code, taken)
            if token is None:  # a legacy lobby with more than 10 members
                break
            taken.add(token)
            LobbyMember.objects.filter(pk=member.pk).update(token=token)


class Migration(migrations.Migration):
    dependencies = [
        ("core", "0009_scheduledtimer"),
    ]

    operations = [
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
