# Strings Inventory — Midnight Village

Every user-facing string in the app, organized by screen. Use this as the copy deck for `l10n/` or a constants file.

Template variables use `{curly_braces}`.

---

## S01 — Welcome

| Key | String | Context |
|-----|--------|---------|
| `app_title_line1` | `MIDNIGHT` | Title, thin weight |
| `app_title_line2` | `VILLAGE` | Title, bold |
| `tagline` | `Who among you is the werewolf?` | Subtitle |
| `name_label` | `Your name` | Input label |
| `name_hint` | `Leave blank for a random name` | Input placeholder |
| `enter_cta` | `Enter the Village` | Primary button |
| `online_count` | `{count} Villagers Online` | Status indicator |
| `games_live` | `{count} Games Live` | Status indicator |

## S02 — Home

| Key | String | Context |
|-----|--------|---------|
| `greeting` | `Hello, {displayName}!` | User greeting |
| `greeting_subtitle` | `The village awaits your decision...` | Flavor text |
| `create_game` | `Create Game` | Card title |
| `create_game_subtitle` | `Start a new lobby` | Card description |
| `join_game` | `Join Game` | Card title |
| `join_game_subtitle` | `Enter a lobby code` | Card description |
| `join_lobby` | `JOIN LOBBY` | Join button |
| `logout` | `Logout` | Text link |
| `active_game_banner` | `You have an active game` | Reconnection banner |
| `rejoin` | `Rejoin` | Reconnection button |

### Home — Errors

| Key | String |
|-----|--------|
| `error_network` | `Check your connection and try again` |
| `error_server` | `Server temporarily unavailable` |
| `error_lobby_not_found` | `No lobby with that code` |
| `error_lobby_full` | `This lobby is full` |
| `error_game_in_progress` | `Game already in progress` |

## S03 — Lobby

| Key | String | Context |
|-----|--------|---------|
| `lobby_title` | `Lobby` | App bar |
| `share_code` | `SHARE THIS CODE` | Label above code |
| `player_count` | `{current}/{max} players` | Subtitle |
| `villagers_waiting` | `Villagers in Waiting` | Section header |
| `host_badge` | `Host` | Badge on host player |
| `roles_selected` | `{count} roles selected` | Role summary bar |
| `ready` | `Ready` | Toggle button (not ready state) |
| `not_ready` | `Not Ready` | Toggle button (ready state) |
| `start_game` | `Start Game` | Host CTA |
| `leave_lobby_title` | `Leave this lobby?` | Confirmation dialog |
| `leave_lobby_confirm` | `Leave` | Dialog confirm |
| `leave_lobby_cancel` | `Cancel` | Dialog cancel |

### Lobby — Errors/States

| Key | String |
|-----|--------|
| `need_players` | `Need at least 3 players` |
| `not_all_ready` | `Not all players are ready` |
| `host_disbanded` | `Host left the lobby` |
| `reconnecting` | `Reconnecting...` |

## S04 — Role Selection

| Key | String | Context |
|-----|--------|---------|
| `game_setup` | `Game Setup` | App bar |
| `card_count` | `{selected}/{required} cards` | Counter |
| `werewolf_team` | `WEREWOLF TEAM` | Section header |
| `village_team` | `VILLAGE TEAM` | Section header |
| `independent` | `INDEPENDENT` | Section header |
| `save_setup` | `Save Setup` | CTA |

### Role Descriptions (one-liners)

| Key | String |
|-----|--------|
| `role_desc_werewolf` | `Knows other werewolves` |
| `role_desc_minion` | `Knows werewolves, they don't know you` |
| `role_desc_seer` | `Peeks at one player or two center cards` |
| `role_desc_robber` | `Swaps card with another player` |
| `role_desc_troublemaker` | `Swaps two other players' cards` |
| `role_desc_drunk` | `Blindly swaps with center card` |
| `role_desc_insomniac` | `Sees own card after all swaps` |
| `role_desc_mason` | `Knows the other Mason` |
| `role_desc_hunter` | `If eliminated, kills who you voted for` |
| `role_desc_tanner` | `Wins if eliminated` |
| `role_desc_villager` | `No night action` |
| `role_desc_doppelganger` | `Copies another player's role` |

### Validation Errors

| Key | String |
|-----|--------|
| `val_card_count` | `Need {required} roles ({players} players + 3), have {selected}` |
| `val_mason_pair` | `Masons must be 0 or 2, not 1` |

## S05 — Role Reveal

| Key | String | Context |
|-----|--------|---------|
| `you_are_the` | `You are the` | Above role name |
| `village_team_label` | `Village Team` | Team badge |
| `werewolf_team_label` | `Werewolf Team` | Team badge |
| `independent_label` | `Independent` | Team badge |
| `night_begins` | `The night begins...` | Atmospheric text |

### Full Role Descriptions (card text)

| Key | String |
|-----|--------|
| `role_full_seer` | `You may look at one other player's card, or two cards from the center.` |
| `role_full_robber` | `You may exchange your card with another player's card, and then view your new card.` |
| `role_full_troublemaker` | `You may exchange cards between two other players.` |
| `role_full_drunk` | `Exchange your card with a card from the center. You won't see your new role.` |
| `role_full_insomniac` | `After all other actions, you may look at your card to see if it changed.` |
| `role_full_werewolf` | `Look for other werewolves. If you're the only one, you may peek at one center card.` |
| `role_full_minion` | `You know who the werewolves are, but they don't know you. Protect them.` |
| `role_full_mason` | `Look for the other Mason. If you're alone, the other Mason is in the center.` |
| `role_full_hunter` | `If you are eliminated, the player you voted for is also eliminated.` |
| `role_full_tanner` | `You win only if you are eliminated. Try to look suspicious.` |
| `role_full_villager` | `You have no night action. Use the discussion to find the werewolves.` |
| `role_full_doppelganger` | `Look at another player's card. You become that role and perform its action.` |

## S06 — Night Action: Seer

| Key | String |
|-----|--------|
| `seer_title` | `SEER'S VISION` |
| `choose_action` | `Choose your action:` |
| `peek_player` | `Peek Player` |
| `peek_player_desc` | `Look at one player's card` |
| `peek_center` | `Peek Center` |
| `peek_center_desc` | `Look at two center cards` |
| `confirm` | `Confirm` |

## S07 — Night Action: Robber

| Key | String |
|-----|--------|
| `robber_title` | `ROBBER'S STEALTH` |
| `robber_instruction` | `Choose a player to rob. You'll swap cards and see your new role.` |
| `swap_with` | `Swap with {name}` |
| `stay_as_robber` | `Stay as Robber` |
| `optional_skip` | `(Optional — skip if you don't want to swap)` |

## S08 — Night Action: Troublemaker

| Key | String |
|-----|--------|
| `troublemaker_title` | `TROUBLEMAKER` |
| `troublemaker_instruction` | `Choose two players to swap their cards. You won't see what they have.` |
| `swap_names` | `Swap {name1} and {name2}` |

## S08b — Night Action: Drunk

| Key | String |
|-----|--------|
| `drunk_title` | `THE DRUNK` |
| `drunk_instruction` | `Exchange your card with one from the center. You won't see what you get.` |
| `swap_center` | `Swap with Center Card {index}` |
| `center_card_label` | `Center Card {index}` |

## S08c — Night Action: See Team

| Key | String |
|-----|--------|
| `your_pack` | `Your pack: {names}` |
| `lone_werewolf` | `You are the only werewolf.` |
| `lone_werewolf_peek` | `You may peek at one center card.` |
| `fellow_mason` | `Your fellow Mason: {name}` |
| `lone_mason` | `You are the lone Mason. The other Mason is in the center.` |
| `minion_sees` | `The werewolves are: {names}` |
| `minion_no_wolves` | `There are no werewolves among the players.` |

## S08d — Night Action: Doppelganger

| Key | String |
|-----|--------|
| `doppelganger_title` | `DOPPELGANGER` |
| `doppelganger_peek` | `Choose a player to copy. You will become their role.` |
| `you_are_now` | `You are now a {role}!` |
| `doppelganger_followup` | `As {role}, perform your action now.` |

## S08e — Night Action: Insomniac

| Key | String |
|-----|--------|
| `insomniac_title` | `INSOMNIAC` |
| `card_unchanged` | `Your card is still: {role}` |
| `card_changed` | `Your card is now: {role}!` |

## S09 — Night Waiting

| Key | String |
|-----|--------|
| `village_sleeps` | `The village sleeps...` |
| `wave_progress` | `Wave {current} of {total}` |
| `others_acting` | `Other players are performing their actions` |

## S10 — Night Action Result

| Key | String |
|-----|--------|
| `cards_card` | `{name}'s card` |
| `player_is_role` | `{name} is a {role}` |
| `you_are_now_role` | `You are now a {role}` |
| `you_swapped` | `You swapped {name1} and {name2}` |
| `you_swapped_center` | `You swapped your card with center card {index}` |
| `memorize` | `Memorize this...` |
| `returning_sleep` | `returning to sleep` |

## S11 — Discussion

| Key | String |
|-----|--------|
| `discussion` | `DISCUSSION` |
| `your_info_seer_player` | `You saw {name}'s card: {role}` |
| `your_info_seer_center` | `Center cards {i} & {j}: {role1}, {role2}` |
| `your_info_robber` | `You robbed {name} and are now: {role}` |
| `your_info_troublemaker` | `You swapped {name1} and {name2}` |
| `your_info_insomniac` | `Your card is now: {role}` |
| `your_info_insomniac_same` | `Your card is still: {role}` |
| `your_info_werewolf` | `Your pack: {names}` |
| `your_info_lone_wolf` | `Lone wolf. Center card {i}: {role}` |
| `your_info_minion` | `Werewolves: {names}` |
| `your_info_mason` | `Your fellow Mason: {name}` |
| `your_info_no_action` | `You did not wake during the night` |
| `your_info_drunk` | `You swapped with center card {i} (unknown role)` |
| `your_info_doppelganger` | `You copied {name}'s role: {role}` |
| `roles_in_play` | `Roles in Play` |
| `players_count` | `Players ({count})` |
| `end_discussion` | `END DISCUSSION EARLY` |
| `end_discussion_confirm` | `End discussion and start voting? This cannot be undone.` |

## S12 — Voting

| Key | String |
|-----|--------|
| `vote` | `VOTE` |
| `votes_count` | `{submitted}/{total} VOTES` |
| `vote_to_eliminate` | `Vote to eliminate {name}?` |
| `confirm_vote` | `CONFIRM VOTE` |
| `change_selection` | `Change` |
| `vote_locked` | `Vote locked in` |
| `voting_status` | `Voting...` |
| `waiting_votes` | `Waiting for votes...` |

## S13 — Vote Reveal

| Key | String |
|-----|--------|
| `votes_title` | `VOTES` |
| `vote_tally` | `Vote Tally` |
| `n_votes` | `{count} votes` |
| `one_vote` | `1 vote` |
| `most_votes` | `{name} received the most votes` |
| `tied_votes` | `{names} are tied with {count} votes each` |
| `no_majority` | `No player received 2 or more votes` |

## S14 — Elimination

| Key | String |
|-----|--------|
| `eliminated` | `has been eliminated` |
| `eliminated_plural` | `have been eliminated` |
| `no_one_dies` | `NO ONE DIES` |
| `no_one_dies_reason` | `No player received 2 or more votes.` |
| `role_was` | `{name}'s role was...` |
| `hunter_revenge` | `The Hunter's revenge!` |
| `also_eliminated` | `{name} is also eliminated!` |
| `proceeding` | `Proceeding to results...` |

## S15 — Results

| Key | String |
|-----|--------|
| `village_wins` | `VILLAGE WINS!` |
| `werewolves_win` | `WEREWOLVES WIN!` |
| `tanner_wins` | `TANNER WINS!` |
| `nobody_wins` | `NOBODY WINS` |
| `you_win` | `YOU WIN` |
| `you_lose` | `YOU LOSE` |
| `player_roles` | `Player Roles` |
| `role_arrow` | `{original} → {final}` |
| `voted_for` | `Voted for: {name}` |
| `center_cards` | `Center Cards: {roles}` |
| `night_log_title` | `What happened at night?` |
| `play_again` | `Play Again` |
| `leave_game` | `Leave Game` |

### Night Log Templates

| Key | String |
|-----|--------|
| `log_seer_player` | `{name} (Seer): Looked at {target}'s card and saw {role}` |
| `log_seer_center` | `{name} (Seer): Looked at center cards {i} & {j}: {role1}, {role2}` |
| `log_robber` | `{name} (Robber): Swapped with {target} and received {role}` |
| `log_troublemaker` | `{name} (Troublemaker): Swapped {target1} and {target2}` |
| `log_drunk` | `{name} (Drunk): Swapped with center card {i}` |
| `log_werewolf_team` | `{name} (Werewolf): Saw teammates: {names}` |
| `log_lone_wolf` | `{name} (Werewolf): Lone wolf, peeked center card {i}: {role}` |
| `log_lone_wolf_skip` | `{name} (Werewolf): Lone wolf, did not peek` |
| `log_minion` | `{name} (Minion): Saw werewolves: {names}` |
| `log_mason` | `{name} (Mason): Saw fellow Mason: {target}` |
| `log_insomniac` | `{name} (Insomniac): Checked own card and saw {role}` |
| `log_doppelganger` | `{name} (Doppelganger): Copied {target}'s role ({role})` |
| `log_skip` | `{name} ({role}): Did not wake` |
| `log_action_skipped` | `{name} ({role}): Action skipped (timed out)` |

### Win Reason Templates

| Key | String |
|-----|--------|
| `reason_wolf_eliminated` | `A Werewolf was eliminated.` |
| `reason_no_wolf_eliminated` | `No Werewolf was eliminated.` |
| `reason_tanner_eliminated` | `The Tanner was eliminated.` |
| `reason_no_wolves_no_death` | `No werewolves were in play and no one died.` |
| `reason_no_wolves_death` | `No werewolves were in play but someone died.` |
| `reason_minion_wins` | `The Minion's deception succeeded.` |

---

## String Count Summary

| Category | Count |
|----------|-------|
| Welcome | 8 |
| Home | 10 + 5 errors |
| Lobby | 13 + 4 errors |
| Role Selection | 6 + 12 descriptions + 2 validations |
| Role Reveal | 5 + 12 full descriptions |
| Night Actions | ~35 (across all roles) |
| Night Waiting/Result | ~10 |
| Discussion | ~18 (including info templates) |
| Voting | 8 |
| Vote Reveal | 6 |
| Elimination | 8 |
| Results | 12 + 12 log templates + 6 reasons |
| **Total** | **~165 strings** |
