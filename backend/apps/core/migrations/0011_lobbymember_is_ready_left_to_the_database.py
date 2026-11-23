"""The lobby ready flag, step 1 of 2: the code stops naming the column.

Nothing reads ``LobbyMember.is_ready`` any more, and it is to be dropped. It cannot
be dropped in one push: the previous code still serves while a build migrates, its
model still has the field, so every INSERT it makes names the column, and a join
would fail until the new build is promoted.

So this push only takes the field out of the model (state only) and gives the column
a DATABASE default. After it:

* this code's INSERTs do not name the column and get ``false`` from the database;
* the previous code's INSERTs, which do name it, keep working.

The column itself goes in a later push, once no build that names it serves
(issue #20). Do not run this backwards while this code serves: without the default
its INSERTs fail. Roll the code back first. Setting a default rewrites nothing and holds its lock for an instant;
the lock timeout comes first all the same (backend/CLAUDE.md, "Deploy-safe changes").
"""

from django.db import migrations


class Migration(migrations.Migration):
    dependencies = [
        ("core", "0010_lobbymember_token"),
    ]

    operations = [
        migrations.RunSQL("SET LOCAL lock_timeout = '5s'", migrations.RunSQL.noop),
        migrations.SeparateDatabaseAndState(
            state_operations=[
                migrations.RemoveField(model_name="lobbymember", name="is_ready"),
            ],
            database_operations=[
                migrations.RunSQL(
                    "ALTER TABLE core_lobbymember ALTER COLUMN is_ready SET DEFAULT false",
                    # backwards the timeout above runs last, so it is set here too
                    [
                        "SET LOCAL lock_timeout = '5s'",
                        "ALTER TABLE core_lobbymember ALTER COLUMN is_ready DROP DEFAULT",
                    ],
                ),
            ],
        ),
    ]
