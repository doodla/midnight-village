"""What would differ from run to run of the contract recorder, pinned: the lobby
codes in the order the tables are opened, the game ids in the order the games are
dealt, and the forced deal's seed (``recorder.recording``)."""

LOBBY_CODES = (
    "K7QX4M",
    "M2RV8P",
    "Q4TW9N",
    # The choose tables (scenarios.choose_tables) come after.
    "R5ZD3H",
    "T8NB6C",
    "V9YC2J",
    "W3XF7K",
    # The results, three-player and ten-player tables (scenarios.results_tables).
    "X2PG5N",
    "Y6HM8R",
    "Z4KQ3T",
    # The lobby table (scenarios.lobby_table).
    "B7DH4Q",
    "C9FJ2K",
    # The table set for eight (scenarios._seats_table).
    "D3GL6S",
    # The account that is gone (scenarios.gone_account) opens no lobby, so the
    # table of practice players after it (scenarios.practice_table) is given
    # this code by the generator and takes it from the create's answer.
    "F5HN2V",
    # Its run.table() slot (never a lobby's code). The story table
    # (story_scenarios, after it) is given this one by the generator.
    "G8JP4W",
    # The story table's run.table() slot (never a lobby's code). The asked table
    # (asked_scenarios, after it) is given this one by the generator.
    "H6KS9X",
    # The asked table's run.table() slot (never a lobby's code).
    "J3MU5Z",
    # The six-seat stream table's run.table() slot (never a lobby's code). The
    # stream table (stream_scenarios, last) is given J3MU5Z by the generator.
    "K5NW2Y",
)
# Stand-ins for the game ids, in the order the games are dealt.
GAME_IDS = (
    "7d3f2c1a-5b8e-4c2d-9a6f-1e0b3c4d5e6f",
    "9a1e5c7b-3d2f-4b6a-8c0e-2f4a6b8c0d1e",
    *(f"00000000-0000-4000-a000-{n:012d}" for n in range(3, 45)),
)
FORCED_SEED = 424242
