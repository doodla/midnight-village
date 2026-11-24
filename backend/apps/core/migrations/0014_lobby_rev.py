"""The lobby body's number: ``Lobby.rev`` (starts at 0, only rises).

Safe to run while the previous code still serves (see "Deploy-safe changes" in
backend/CLAUDE.md): the first operation sets a lock timeout, so an ALTER that
cannot get its lock fails the deploy at once instead of blocking the live site
behind it, and the new NOT NULL column has a database default (0), so the old
code's INSERTs (which omit it) keep working. Nothing is backfilled: every table
that exists starts at 0, and the next change it tells is 1.
"""

from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("core", "0013_lobby_asked"),
    ]

    operations = [
        migrations.RunSQL("SET LOCAL lock_timeout = '5s'", migrations.RunSQL.noop),
        migrations.AddField(
            model_name="lobby",
            name="rev",
            field=models.IntegerField(db_default=0, default=0),
        ),
    ]
