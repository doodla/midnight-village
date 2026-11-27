"""The phones' own speed reports (``apps.observe``): one new table.

Safe to run while the previous code still serves: the previous code knows nothing of
this table and never touches it. The lock timeout comes first all the same, as in
every migration from core 0010 on.
"""

import django.db.models.functions.datetime
import django.utils.timezone
from django.db import migrations, models


class Migration(migrations.Migration):
    initial = True

    dependencies: list = []

    operations = [
        migrations.RunSQL("SET LOCAL lock_timeout = '5s'", migrations.RunSQL.noop),
        migrations.CreateModel(
            name="FieldSummary",
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
                (
                    "received_at",
                    models.DateTimeField(
                        db_default=django.db.models.functions.datetime.Now(),
                        db_index=True,
                        default=django.utils.timezone.now,
                    ),
                ),
                (
                    "commit",
                    models.CharField(db_default="", default="", max_length=40),
                ),
                (
                    "device",
                    models.CharField(db_default="", default="", max_length=32),
                ),
                ("body", models.JSONField()),
            ],
            options={
                "ordering": ["-received_at", "-id"],
            },
        ),
    ]
