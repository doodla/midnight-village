"""PlayerRole v2 columns, the dealt centre, and PlayerRole ordering.

Safe to run while the previous code still serves (see "Deploy-safe changes" in
backend/CLAUDE.md): the first operation sets a lock timeout, so an ALTER that
cannot get its lock fails the deploy at once instead of blocking the live site
behind it, and every new NOT NULL column has a database default, so the old code's
INSERTs (which omit the columns) keep working.
"""

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("onuw", "0009_core_owns_timers"),
    ]

    operations = [
        migrations.RunSQL("SET LOCAL lock_timeout = '5s'", migrations.RunSQL.noop),
        migrations.AlterModelOptions(
            name="playerrole",
            options={"ordering": ("seat", "user_id")},
        ),
        migrations.AddField(
            model_name="game",
            name="dealt_center_cards",
            # pyrefly: ignore [no-matching-overload]
            field=models.JSONField(
                blank=True,
                db_default=models.Value([], output_field=models.JSONField()),
                default=list,
                help_text="The 3 center cards as dealt; never changed (empty: dealt before this)",
            ),
        ),
        migrations.AddField(
            model_name="playerrole",
            name="night_results_seen",
            field=models.PositiveSmallIntegerField(
                db_default=0,
                default=0,
                help_text="How many of the player's night results they have acknowledged",
            ),
        ),
        migrations.AddField(
            model_name="playerrole",
            name="phase_ready",
            field=models.BooleanField(
                db_default=False,
                default=False,
                help_text='"Looked at my card" (night, window 0) / "ready to vote" (talk)',
            ),
        ),
        migrations.AddField(
            model_name="playerrole",
            name="seat",
            field=models.PositiveSmallIntegerField(
                blank=True,
                help_text="Join order at the deal (0-based); None for games dealt before seats",
                null=True,
            ),
        ),
        migrations.AddField(
            model_name="playerrole",
            name="token",
            field=models.CharField(
                blank=True, db_default="", default="", max_length=16
            ),
        ),
    ]
