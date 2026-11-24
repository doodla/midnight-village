"""The newest tap applied per game lane: ``PlayerRole.asked`` (issue #16).

Safe to run while the previous code still serves (see "Deploy-safe changes" in
backend/CLAUDE.md): the first operation sets a lock timeout, so an ALTER that
cannot get its lock fails the deploy at once instead of blocking the live site
behind it, and the new NOT NULL column has a database default (``{}``), so the
old code's INSERTs (the deal's ``bulk_create``, which omits it) keep working.
Nothing is backfilled: an empty map means no tap carried ``asked`` yet.
"""

from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("onuw", "0010_playerrole_v2_fields"),
    ]

    operations = [
        migrations.RunSQL("SET LOCAL lock_timeout = '5s'", migrations.RunSQL.noop),
        migrations.AddField(
            model_name="playerrole",
            name="asked",
            # pyrefly: ignore [no-matching-overload]
            field=models.JSONField(
                blank=True,
                db_default=models.Value({}, output_field=models.JSONField()),
                default=dict,
                help_text="The newest tap applied per lane: lane -> [stage, asked] "
                "(apps.core.asked; lanes vote and ready)",
            ),
        ),
    ]
