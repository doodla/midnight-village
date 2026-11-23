"""The lobby ready flag, step 2 of 2: the column is dropped.

Step 1 (0011) took the field out of the model and left the column to the database.
Every build that serves now writes ``core_lobbymember`` without naming ``is_ready``,
so the column can go (issue #20).

After this, a build from before 0011 cannot seat a player (its INSERTs name the
column): roll forward, never back past 0011 (docs/dev/deploy-vercel.md).

Dropping a column rewrites nothing and holds its lock for an instant; the lock
timeout comes first all the same. Backwards puts the column back as 0011 left it
(NOT NULL, database default false); the values it held are gone.
"""

from django.db import migrations


class Migration(migrations.Migration):
    dependencies = [
        ("core", "0011_lobbymember_is_ready_left_to_the_database"),
    ]

    operations = [
        migrations.RunSQL("SET LOCAL lock_timeout = '5s'", migrations.RunSQL.noop),
        # The model's state lost the field in 0011: only the database changes here.
        migrations.RunSQL(
            "ALTER TABLE core_lobbymember DROP COLUMN IF EXISTS is_ready",
            # backwards the timeout above runs last, so it is set here too
            [
                "SET LOCAL lock_timeout = '5s'",
                "ALTER TABLE core_lobbymember"
                " ADD COLUMN IF NOT EXISTS is_ready boolean NOT NULL DEFAULT false",
            ],
        ),
    ]
