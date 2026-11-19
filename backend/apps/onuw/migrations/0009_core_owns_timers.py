"""
Move shared infrastructure out of the ONUW app, keeping all data (0008 already
copied the lobby sockets to ``core.LobbySocket``):

* ``SocketPresence`` becomes game-only (no lobby);
* ``ScheduledTimer`` becomes ``core.ScheduledTimer``: the table is RENAMED
  (``onuw_scheduledtimer`` -> ``core_scheduledtimer``), not copied; core's
  migration 0009 re-declares the model in its own state.
"""

import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("onuw", "0008_lobby_sockets_to_core"),
    ]

    operations = [
        migrations.RemoveIndex(
            model_name="socketpresence", name="onuw_socket_lobby_i_6848e6_idx"
        ),
        migrations.RemoveField(model_name="socketpresence", name="lobby"),
        migrations.AlterField(
            model_name="socketpresence",
            name="game",
            field=models.ForeignKey(
                on_delete=django.db.models.deletion.CASCADE,
                related_name="sockets",
                to="onuw.game",
            ),
        ),
        migrations.AlterModelTable(name="scheduledtimer", table="core_scheduledtimer"),
        migrations.SeparateDatabaseAndState(
            state_operations=[migrations.DeleteModel(name="ScheduledTimer")],
        ),
    ]
