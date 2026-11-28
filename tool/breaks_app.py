# Guard file: a change here needs its line in the pull request (tool/guard_edits.py).
"""The app's deliberate breaks (tool/prove_guards.py). They run where Flutter is: on GitHub in
"Analyze and Format"; locally when `flutter` is on PATH."""

from breaks_kit import Break, Edit

NAME_TAG = "frontend/lib/design_system/primitives/name_tag.dart"
NAME_LINE = "            Flexible(child: FitLine(name, style: style)),\n"
SEND = "  Future<StageAnswer> _send(OutboxItem item) async {\n"

APP: tuple[Break, ...] = (
    Break(
        name="F1_name_cut_in_the_string",
        promise="names-in-full",
        why="a name tag shows the first seven letters of a long name",
        edits=(
            Edit(
                NAME_TAG,
                NAME_LINE,
                "            Flexible(child: FitLine(name.length > 7 ? name.substring(0, 7)"
                " : name, style: style)),\n",
            ),
        ),
        tests=("frontend/test/design_system/primitives/fit_floor_test.dart",),
        survives="the render checks see drawn text only; a cut string is drawn whole"
        " (a later frontend piece)",
    ),
    Break(
        name="F3_outbox_waits_before_a_tap",
        promise="no-added-waits",
        why="the outbox waits 800 ms before it sends a tap",
        edits=(
            Edit(
                "frontend/lib/features/game/presentation/live_game_taps.dart",
                SEND,
                SEND
                + "    await Future<void>.delayed(const Duration(milliseconds: 800));\n",
            ),
        ),
        tests=("frontend/test/features/game/presentation/live_game_test.dart",),
    ),
    Break(
        name="a_text_size_written_in_a_widget",
        promise="one-look",
        why="a name tag sets its own text size",
        edits=(
            Edit(
                NAME_TAG,
                NAME_LINE,
                "            Flexible(child: FitLine(name, style: style.copyWith(fontSize: 13))),\n",
            ),
        ),
        tests=("frontend/test/design_system/skin/type_guard_test.dart",),
    ),
    Break(
        name="a_label_written_in_a_widget",
        promise="few-words",
        why="a name tag's screen-reader label is written in the widget",
        edits=(
            Edit(NAME_TAG, "      label: name,\n", "      label: 'Player $name',\n"),
        ),
        tests=("frontend/test/design_system/copy/widget_strings_test.dart",),
    ),
    Break(
        name="a_tag_reads_the_seconds",
        promise="screens-still",
        why="a primitive that is no clock reads the seconds",
        edits=(Edit(NAME_TAG, None, "\ntypedef _Seconds = ClockTick;\n"),),
        tests=("frontend/test/design_system/primitives/clock_users_test.dart",),
    ),
    Break(
        name="deal_button_silently_disabled",
        promise="few-words",
        why="Deal sits dimmed with no word of why when the table cannot deal",
        edits=(
            Edit(
                "frontend/lib/features/lobby/presentation/at_table_view.dart",
                "      CanDeal() || CannotDeal() => PrimaryButton(label: label, onPressed: deal),\n",
                "      CanDeal() => PrimaryButton(label: label, onPressed: deal),\n"
                "      CannotDeal() => PrimaryButton(label: label, onPressed: null),\n",
            ),
        ),
        tests=("frontend/test/design_system/primitives/main_button_rule_test.dart",),
    ),
    Break(
        name="talk_deck_four_to_a_row_or_words_alone",
        promise="one-look",
        why="the talk's deck never takes fewer to a row: eight roles at 412 wide are"
        " drawn as words, no portraits (the owner, 28 November 2026)",
        edits=(
            Edit(
                "frontend/lib/features/game/presentation/shell/talk_square.dart",
                "      for (var c = columns; c >= SquareMetrics.fewestColumns; c--)\n",
                "      for (var c = columns; c >= columns; c--)\n",
            ),
        ),
        tests=(
            "frontend/test/features/game/presentation/talk_deck_portraits_test.dart",
        ),
    ),
    Break(
        name="cobbles_plaque_at_the_start_of_its_row",
        promise="one-look",
        why="08's and 09's button sits left of the cobbles' middle on any phone wider"
        " than the button (the owner, 28 November 2026)",
        edits=(
            Edit(
                "frontend/lib/design_system/primitives/square_foot.dart",
                "    alignment: Alignment.topCenter,\n",
                "",
            ),
        ),
        # Every shard of the sweep holds some 08 states.
        tests=("frontend/test/screen_cases/sweep_1of4_test.dart::08-talk",),
    ),
)
