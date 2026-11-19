"""Lobby sockets as rows (moved here from onuw's SocketPresence lobby scope)."""

import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("core", "0007_remove_lobbymember_connections"),
    ]

    operations = [
        migrations.CreateModel(
            name="LobbySocket",
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
                ("channel_name", models.CharField(max_length=255, unique=True)),
                ("connected_at", models.DateTimeField()),
                ("last_seen", models.DateTimeField()),
                (
                    "lobby",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="sockets",
                        to="core.lobby",
                    ),
                ),
                (
                    "user",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="lobby_sockets",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={
                "indexes": [
                    models.Index(
                        fields=["lobby", "user"], name="core_lobbysock_lobby_user_idx"
                    )
                ],
            },
        ),
    ]
