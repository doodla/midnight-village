"""The newest tap applied per lobby setting: ``Lobby.asked`` (issue #16).

Safe to run while the previous code still serves (see "Deploy-safe changes" in
backend/CLAUDE.md): the first operation sets a lock timeout, so an ALTER that
cannot get its lock fails the deploy at once instead of blocking the live site
behind it, and the new NOT NULL column has a database default (``{}``), so the
old code's INSERTs (which omit it) keep working. Nothing is backfilled: an empty
map means no tap carried ``asked`` yet.
"""

from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("core", "0012_lobbymember_drop_is_ready"),
    ]

    operations = [
        migrations.RunSQL("SET LOCAL lock_timeout = '5s'", migrations.RunSQL.noop),
        migrations.AddField(
            model_name="lobby",
            name="asked",
            # pyrefly: ignore [no-matching-overload]
            field=models.JSONField(
                blank=True,
                db_default=models.Value({}, output_field=models.JSONField()),
                default=dict,
            ),
        ),
    ]
