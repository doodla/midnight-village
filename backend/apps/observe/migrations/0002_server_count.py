"""What the server counts of itself for the owner's report (``ServerCount``): one
new table.

Safe to run while the previous code still serves: the previous code knows nothing of
this table and never touches it. The lock timeout comes first, as in every migration
from core 0010 on.
"""

from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("observe", "0001_initial"),
    ]

    operations = [
        migrations.RunSQL("SET LOCAL lock_timeout = '5s'", migrations.RunSQL.noop),
        migrations.CreateModel(
            name="ServerCount",
            fields=[
                (
                    "id",
                    models.BigAutoField(
                        auto_created=True,
                        primary_key=True,
                        serialize=False,
                        verbose_name="ID",
                    ),
                ),
                ("word", models.CharField(max_length=32)),
                ("hour", models.DateTimeField()),
                ("n", models.PositiveIntegerField(db_default=0, default=0)),
            ],
            options={
                "constraints": [
                    models.UniqueConstraint(
                        fields=("word", "hour"), name="observe_count_word_hour"
                    )
                ],
            },
        ),
    ]
