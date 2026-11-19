"""
Lobby socket rows (``SocketPresence`` rows with a lobby) are copied to
``core.LobbySocket`` (data only; the schema change follows in 0009, in its own
migration so this step reverses cleanly).
"""

from django.db import migrations


def lobby_sockets_to_core(apps, schema_editor):
    SocketPresence = apps.get_model("onuw", "SocketPresence")
    LobbySocket = apps.get_model("core", "LobbySocket")
    rows = SocketPresence.objects.filter(lobby__isnull=False)
    LobbySocket.objects.bulk_create(
        [
            LobbySocket(
                user_id=row.user_id,
                lobby_id=row.lobby_id,
                channel_name=row.channel_name,
                connected_at=row.connected_at,
                last_seen=row.last_seen,
            )
            for row in rows
        ]
    )
    rows.delete()


def lobby_sockets_back_to_onuw(apps, schema_editor):
    SocketPresence = apps.get_model("onuw", "SocketPresence")
    LobbySocket = apps.get_model("core", "LobbySocket")
    SocketPresence.objects.bulk_create(
        [
            SocketPresence(
                user_id=row.user_id,
                lobby_id=row.lobby_id,
                game_id=None,
                channel_name=row.channel_name,
                connected_at=row.connected_at,
                last_seen=row.last_seen,
            )
            for row in LobbySocket.objects.all()
        ]
    )
    LobbySocket.objects.all().delete()


class Migration(migrations.Migration):
    dependencies = [
        ("core", "0008_lobbysocket"),
        ("onuw", "0007_timer_publication"),
    ]

    operations = [
        # 1. Lobby socket rows go to core; SocketPresence becomes game-only.
        migrations.RunPython(lobby_sockets_to_core, lobby_sockets_back_to_onuw),
    ]
