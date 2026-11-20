# Server payload quirks (from the contract samples)

Recording every payload the app consumes into `contract_samples/` (see `backend/tests/README.md`, "Contract samples") made a few inconsistencies in what the server sends visible. None is fixed for games that play the original night (protocol 1: the old screens depend on today's bodies, and the committed samples of those games must not change). Items 1, 4 and 5 are fixed **under night protocol 2** (`night_protocol: 2` in the game's settings; see `backend/CLAUDE.md`); the others are still open. Each item names the samples that show it; `just samples` keeps them current.

1. **Role-name casing differs inside `revealed_info`.** Everywhere else a role is TitleCase (`your_role.original_role`, a prompt's `role_acting_as`, `roles_in_game`, the results), but a night result's `revealed_info` uses lowercase for the card it shows: `role`, `roles`, `new_role`, `current_role`, `center_card.role`. One object can carry both: the Doppelganger's look is `{"target_name": "Ben", "role": "seer", "copied_role": "Seer"}`. Samples: `ws/game/action_result_*`, `http/game/me_discussion_result_*`, `ws/game/action_result_doppelganger_look`.

   **Under protocol 2: fixed.** Every role name in `revealed_info` is canonical (`"Werewolf"`, `"Seer"`), `copied_role` included (`http/game/me_discussion_choose_*`, `http/game/me_choose_doppelganger_followup`).

2. **`your_role.has_acted` means two things.** At night it is "submitted a night action"; in the vote it is reset and means "voted" (the Seer who acted at night has `has_acted: false` in `me_voting` and `true` in `me_voting_voted`). `/me/` already has `has_voted` for the second meaning.

3. **Two timestamp formats.** Lobby bodies write `created_at` / `joined_at` as `2024-03-07T20:51:00Z`; `/me/`'s `deadline`, the socket deadlines and recent games' `ended_at` write `2024-03-07T20:57:30+00:00`. Both parse, but a client comparing strings would be wrong. Samples: `http/lobby/detail_waiting`, `http/game/me_night_prompt_seer`, `http/game/recent_games`.

4. **The lone Werewolf's prompt does not offer its centre peek.** `action_prompt_werewolf_lone` is `{"action_types": ["see_team"], "valid_targets": {"see_team": []}}`, the same shape as the pack's with an empty team; the centre peek it accepts (`see_team` with `center_index`) is not advertised. The old app inferred it from the empty team (its protocol-1 game screen, deleted), which was game logic on the client (principle 1). A prompt that lists `center_indices` would remove the inference.

   **Under protocol 2: fixed.** The prompt has `kind: "lone_werewolf"` and the board (`valid_targets.center_indices`); the client does not infer anything (`http/game/me_choose_prompt_werewolf_lone`).

5. **Team prompts reveal teammates when the window opens.** The Werewolf, Mason and Minion prompts carry the teammates' ids in `valid_targets.see_team` as window 2 opens (`ws/game/action_prompt_werewolf_pack`, `_mason`, `_minion`), while `backend/CLAUDE.md` says of window 2 that "nothing is sent to anyone until the window closes". Either the sentence or the prompt should change: as it is, a team view is known before the player acts, and the results that arrive at the close repeat it.

   **Under protocol 2: fixed.** There are no per-player prompt events and a prompt never carries teammates (`http/game/me_choose_prompt_werewolf_pack` (recorded with both Werewolves dealt: a real pack; an earlier recording was a lone Werewolf under this name), `_mason`, `_minion`: `kind: "none"`; the lone Werewolf is `me_choose_prompt_werewolf_lone`); teams are shown with the window's results. A window opens with one group event, `night_window {window, deadline}`.

6. **Lobby bodies carry every member's `username`.** Each member in a lobby body (`GET /lobbies/<code>/`, the join, ready, settings and play-again answers, `lobby_update`) has `user.username`, which for a guest is the account's UUID, and `host` has it too. The app reads only `id` and `display_name`; nothing needs another member's username. Samples: `http/lobby/*`, `ws/lobby/lobby_update`.
