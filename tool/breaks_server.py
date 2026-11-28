# Guard file: a change here needs its line in the pull request (tool/guard_edits.py).
"""The server's deliberate breaks (tool/prove_guards.py). The first sixteen are the correctness
audit's of 28 November 2026 (B1 to B12 here, F1 and F3 in breaks_app.py), kept under their
audit names."""

from breaks_kit import Break, Edit

VOTING = "backend/apps/onuw/voting.py"
CONSUMER = "backend/apps/onuw/consumers.py"
NIGHT_WINDOW = "backend/apps/onuw/night_window.py"
TWO_DEALS = "backend/tests/privacy/test_two_deals.py"
TWO_DEALS_HELPER = "backend/tests/privacy/two_deals.py"
SERIALIZERS = "backend/apps/onuw/serializers.py"
ME_ANCHOR = '        data["vote_targets"] = self._vote_targets(instance)\n'


def _two_deals(name: str, why: str, *edits: Edit) -> Break:
    """A leak the two-deal test must see (the review of 28 November 2026 found each)."""
    return Break(
        name=name,
        promise="hidden-information",
        why=why,
        edits=edits,
        tests=(TWO_DEALS,),
        guards=(TWO_DEALS_HELPER,),
    )


def _on_me(name: str, why: str, line: str) -> Break:
    return _two_deals(name, why, Edit(SERIALIZERS, ME_ANCHOR, ME_ANCHOR + line))


LEAKS: tuple[Break, ...] = (
    _on_me(
        "L1_wolf_count_on_me",
        "/me/ counts the werewolves seated",
        '        data["x"] = sum(pr.original_role == "Werewolf"'
        ' for pr in self.context.get("all_player_roles", []))\n',
    ),
    _on_me(
        "L2_wolf_in_the_centre_on_me",
        "/me/ says whether a werewolf is in the centre",
        '        data["x"] = "Werewolf" in (instance.dealt_center_cards'
        " or instance.center_cards)\n",
    ),
    _on_me(
        "L3_your_card_now_while_voting",
        "/me/ shows the card you hold now, while voting",
        '        data["x"] = self.context["player_role"].current_role'
        ' if instance.phase == "voting" else None\n',
    ),
    _on_me(
        "L4_votes_on_you_before_the_reveal",
        "/me/ counts the votes on you before the reveal",
        '        data["x"] = sum(pr.vote_target_id == self.context["player_role"].user_id'
        ' for pr in self.context.get("all_player_roles", []))\n',
    ),
    _two_deals(
        "L5_players_ordered_by_role",
        "the players list is ordered by role",
        Edit(
            "backend/apps/onuw/views_read.py",
            'all_prs = game.player_roles.select_related("user").all()',
            'all_prs = game.player_roles.select_related("user").order_by("original_role", "user_id")',
        ),
    ),
    _two_deals(
        "L6_seen_answers_wolf_ids",
        "marking the night results seen answers the werewolves' ids",
        Edit(
            "backend/apps/onuw/views_play.py",
            '        return Response({"night_results_seen": stored})',
            '        return Response({"night_results_seen": stored, "w": sorted(game.player_roles'
            '.filter(original_role="Werewolf").values_list("user_id", flat=True))})',
        ),
    ),
    # The review's own edit set Server-Timing in the view; the timing middleware writes
    # that header last, so it leaked nothing. The same seat in a header that stays:
    _two_deals(
        "L7_a_seat_in_a_header_of_me",
        "/me/ answers with a header carrying the first werewolf's seat",
        Edit(
            "backend/apps/onuw/views.py",
            "        return Response(me_body(game, player_role, all_player_roles))\n",
            "        r = Response(me_body(game, player_role, all_player_roles))\n"
            '        r["X-Table"] = str(next((i for i, pr in enumerate(all_player_roles)'
            ' if pr.original_role == "Werewolf"), 0))\n'
            "        return r\n",
            within="GameMeView.get",
        ),
    ),
    _two_deals(
        "L8_timing_detail_on_live",
        "the live settings switch the Server-Timing detail on (its counts tell hidden play)",
        Edit(
            "backend/config/settings/vercel.py",
            "SERVER_TIMING_DETAIL = False",
            "SERVER_TIMING_DETAIL = True",
        ),
    ),
)
LOCKED_READY = (
    "        game = Game.objects.select_for_update().get(id=game.id)\n"
    "        require_stage(game, stage, expected=(LOOK, TALK))"
)
FIRST_LINE_OF_RECEIVE = (
    '        """Reject client-sent messages — game actions go through HTTP API."""\n'
)


def _phase_change_with(field: str) -> tuple[Edit, ...]:
    """The table-wide phase change to the talk carries `field`, and the socket sends it."""
    return (
        Edit(
            NIGHT_WINDOW,
            '                    "phase": "discussion",\n',
            '                    "phase": "discussion",\n'
            f'                    "w": {field},\n',
            within="transition_to_discussion",
        ),
        Edit(
            CONSUMER,
            '                "phase": event["phase"],\n',
            '                "phase": event["phase"],\n                "w": event.get("w"),\n',
            within="GameConsumer.phase_change",
        ),
    )


SERVER_AUDIT: tuple[Break, ...] = (
    Break(
        name="B1_werewolf_ids_on_the_table_socket",
        promise="hidden-information",
        why="the werewolves' player numbers ride on a message every phone receives",
        edits=_phase_change_with(
            'sorted(game.player_roles.filter(original_role="Werewolf")'
            '.values_list("user_id", flat=True))'
        ),
        resample=True,
        # the privacy guard looks for role words only and passes on this
        tests=(TWO_DEALS,),
        guards=(TWO_DEALS_HELPER,),
    ),
    Break(
        name="B2_role_words_on_the_table_socket",
        promise="hidden-information",
        why="every seat's role, as words, on a message every phone receives",
        edits=_phase_change_with(
            "[pr.original_role for pr in game.player_roles.all()]"
        ),
        resample=True,
        tests=("backend/tests/contract/test_contract_privacy.py",),
    ),
    Break(
        name="B3_no_row_lock_on_the_vote",
        promise="atomicity",
        why="the vote reads the Game and its PlayerRole without locking them (the tap"
        " budget kills it every time; the race test alone may pass)",
        edits=(
            Edit(
                VOTING,
                "game = Game.objects.select_for_update().get(id=game.id)",
                "game = Game.objects.get(id=game.id)",
                within="submit_vote",
            ),
            Edit(
                VOTING,
                "PlayerRole.objects.select_for_update().get(",
                "PlayerRole.objects.get(",
                within="submit_vote",
            ),
        ),
        tests=(
            "backend/tests/onuw/test_lock_in_voting.py::TestReveal::test_concurrent_last_two_locks_reveal_once",
            # the race above is not lost every time; the budget sees the locks go
            "backend/tests/perf/test_tap_query_budget.py",
        ),
    ),
    Break(
        name="B4_ready_without_transaction_or_locks",
        promise="atomicity",
        why="set_ready writes with no transaction and no row locks",
        edits=(
            Edit(
                VOTING,
                "    with transaction.atomic():\n" + LOCKED_READY,
                "    if True:\n"
                "        game = Game.objects.get(id=game.id)\n"
                "        require_stage(game, stage, expected=(LOOK, TALK))",
                within="set_ready",
            ),
            Edit(
                VOTING,
                "pr = PlayerRole.objects.select_for_update().get(game=game, user_id=user_id)",
                "pr = PlayerRole.objects.get(game=game, user_id=user_id)",
                within="set_ready",
            ),
        ),
        tests=("backend/tests/onuw/test_voting_api.py",),
        survives="only the tap budget notices, and `just tap-budget` re-records it (2d)",
    ),
    Break(
        name="B5_unseeded_deal",
        promise="determinism",
        why="the deal draws from an unseeded generator",
        edits=(
            Edit(
                "backend/apps/onuw/engine/assignment.py",
                "rng = random.Random(seed)",
                "rng = random.Random()",
                within="assign_roles",
            ),
        ),
        tests=(
            "backend/tests/onuw/test_role_assignment.py::TestAssignRoles::test_deterministic_same_seed",
        ),
    ),
    Break(
        name="B6_unseeded_drunk_default",
        promise="determinism",
        why="the Drunk's swap when the time runs out is unseeded",
        edits=(
            Edit(
                NIGHT_WINDOW,
                'rng = random.Random(f"{random_seed}:drunk-timeout:{player_id}")',
                "rng = random.Random()",
                within="drunk_timeout_center_index",
            ),
        ),
        tests=("backend/tests/onuw/test_drunk_timeout.py",),
    ),
    Break(
        name="B7_ready_over_the_socket",
        promise="http-for-actions",
        why="the game socket takes a ready and writes it",
        edits=(
            Edit(
                CONSUMER,
                FIRST_LINE_OF_RECEIVE,
                FIRST_LINE_OF_RECEIVE + '        if content.get("type") == "ready":\n'
                "            from channels.db import database_sync_to_async\n\n"
                "            from apps.onuw.models import PlayerRole\n\n"
                "            await database_sync_to_async(\n"
                "                lambda: PlayerRole.objects.filter(\n"
                '                    game_id=self.game_id, user_id=self.scope["user"].id\n'
                "                ).update(phase_ready=True)\n"
                "            )()\n"
                "            return\n",
                within="GameConsumer.receive_json",
            ),
        ),
        tests=(
            "backend/tests/onuw/test_game_consumer.py",
            "backend/tests/onuw/test_unknown_event_tolerance.py",
        ),
        survives="nothing sends an action to the game socket (2b)",
    ),
    Break(
        name="B8a_sleep_in_a_tap",
        promise="no-added-waits",
        why="the ready tap sleeps before it answers",
        edits=(
            Edit(
                VOTING,
                "    with transaction.atomic():\n" + LOCKED_READY,
                "    import time\n\n    time.sleep(0.4)\n    with transaction.atomic():\n"
                + LOCKED_READY,
                within="set_ready",
            ),
        ),
        tests=("backend/tests/onuw/test_voting_api.py",),
        survives="tests only get slower (2c)",
    ),
    Break(
        name="B8b_vote_floor_of_45_seconds",
        promise="no-added-waits",
        why="the vote lasts at least 45 seconds whatever the table set",
        edits=(
            Edit(
                VOTING,
                "timedelta(seconds=voting_seconds)",
                "timedelta(seconds=max(voting_seconds, 45))",
                within="transition_to_voting",
            ),
        ),
        tests=(
            "backend/tests/onuw/test_stage_clock_and_vote_targets.py",
            "backend/tests/onuw/test_lengths_never_freeze.py",
        ),
        survives="no test sets a vote shorter than 45 seconds and reads its deadline (2c)",
    ),
    Break(
        name="B9a_core_imports_the_game",
        promise="separate-game-apps",
        why="core imports the game's models",
        edits=(
            Edit(
                "backend/apps/core/views.py",
                "from . import asked as ask\n",
                "from . import asked as ask\nfrom apps.onuw import models as _game_models  # noqa\n",
            ),
        ),
        tests=("backend/tests/core/test_core_stays_game_agnostic.py",),
    ),
    Break(
        name="B9b_observe_imports_the_game",
        promise="separate-game-apps",
        why="the observe app imports the game's models",
        edits=(
            Edit(
                "backend/apps/observe/report.py",
                "from apps.core.wire import wire_time\n",
                "from apps.core.wire import wire_time\n"
                "from apps.onuw.models import PlayerRole  # noqa: F401\n",
            ),
        ),
        tests=("backend/tests/core/test_core_stays_game_agnostic.py",),
        survives="no rule says what observe may import",
    ),
    Break(
        name="B9c_a_low_layer_imports_up",
        promise="separate-game-apps",
        why="a low layer of the game imports the service, inside a function",
        edits=(
            Edit(
                "backend/apps/onuw/turns.py",
                None,
                "\n\ndef _late():\n    from apps.onuw import services  # noqa: F401\n",
            ),
        ),
        tests=("backend/tests/onuw/test_module_directions.py",),
    ),
    Break(
        name="B11b_two_guards_skipped_from_conftest",
        promise="guards-hold",
        why="conftest stops collecting the privacy and module-direction guards",
        edits=(
            Edit(
                "backend/tests/conftest.py",
                None,
                '\n\ncollect_ignore = ["contract/test_contract_privacy.py",'
                ' "onuw/test_module_directions.py"]\n',
            ),
        ),
        tests=("backend/tests/contract/test_contract_privacy.py",),
        survives="nothing counts what a guard collects (2e)",
    ),
    Break(
        name="B12_privacy_guard_disarmed",
        promise="guards-hold",
        why="the privacy guard's check is made always true, with no line in the pull request",
        edits=(
            Edit(
                "backend/tests/contract/test_contract_privacy.py",
                "    assert ",
                "    assert True or ",
                within="test_nothing_broadcast_to_the_game_before_the_results_names_a_role",
            ),
        ),
        command=("tool/guard_edits.py", "--base", "HEAD"),
        env=(("PR_BODY", ""),),
        expect="<- needs its line",
        guards=("tool/guard_edits.py",),
    ),
)

SERVER: tuple[Break, ...] = SERVER_AUDIT + LEAKS
