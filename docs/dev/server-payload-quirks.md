# Server payload quirks (from the contract samples)

Recording every payload the app consumes into `contract_samples/` (see `backend/tests/README.md`, "Contract samples") made a few inconsistencies in what the server sends visible. Those that came with the original per-role night (lower-case role names in `revealed_info`, `has_acted` meaning two things, a lone Werewolf's prompt hiding its centre peek, team prompts that showed teammates when a window opened) went with it: there is one night now (`docs/specs/onuw/api-contract-v2.md`). The ones below are still open. Each item names the samples that show it; `just samples` keeps them current.

1. **Two timestamp formats.** Lobby bodies write `created_at` / `joined_at` as `2024-03-07T20:51:00Z`; `/me/`'s `deadline` and `stage_started_at`, the socket deadlines and recent games' `ended_at` write `2024-03-07T20:57:30+00:00`. Both parse, but a client comparing strings would be wrong. Samples: `http/lobby/detail_waiting`, `http/game/me_choose_prompt_seer`, `http/game/recent_games`.

2. **Lobby bodies carry every member's `username`.** Each member in a lobby body (`GET /lobbies/<code>/`, the join, ready, settings and play-again answers, `lobby_update`) has `user.username`, which for a guest is the account's UUID, and `host` has it too. The app reads only `id` and `display_name`; nothing needs another member's username. Samples: `http/lobby/*`, `ws/lobby/lobby_update`.

3. **Vote refusals from the service keep `detail` as a list.** `vote_invalid_target` and `vote_self` answer `{"detail": ["You cannot vote for yourself."], "code": "invalid_target"}`, where every other refusal's `detail` is a string. The app reads `code`. Samples: `http/game/vote_invalid_target`, `http/game/vote_self`.
