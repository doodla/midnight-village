"""ScheduledTimer now belongs to core (its table was renamed by onuw 0008)."""

import django.utils.timezone
from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("core", "0008_lobbysocket"),
        ("onuw", "0009_core_owns_timers"),
    ]

    operations = [
        migrations.SeparateDatabaseAndState(
            state_operations=[
                migrations.CreateModel(
                    name="ScheduledTimer",
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
                        ("key", models.CharField(max_length=200, unique=True)),
                        ("token", models.CharField(max_length=64)),
                        ("job", models.CharField(max_length=64)),
                        ("params", models.JSONField(blank=True, default=dict)),
                        ("due_at", models.DateTimeField(db_index=True)),
                        (
                            "scheduled_at",
                            models.DateTimeField(default=django.utils.timezone.now),
                        ),
                        (
                            "published_at",
                            models.DateTimeField(
                                blank=True,
                                help_text="When the firing was handed to the backend (queue message sent / thread armed). None = the row exists but nothing is known to fire it: the sweep or the lazy repair publishes it again.",
                                null=True,
                            ),
                        ),
                        ("created_at", models.DateTimeField(auto_now_add=True)),
                        ("updated_at", models.DateTimeField(auto_now=True)),
                    ],
                ),
            ],
        ),
    ]
