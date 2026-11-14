# Backend — Midnight Village

## ONUW Game Domain

Understand these mechanics before implementing any game feature.

**Game flow:** Lobby → Night → Discussion → Voting → Results

**Night phase runs in two windows** (`Game.current_wave` holds the window number: 1 or 2, 0 outside night). `RoleDefinition.wave` is the *order group* (position in the wake order), not a phase of the game; action-log entries are tagged with it so the log stays in wake order.
1. **Window 1 — Doppelganger alone.** Runs whenever the Doppelganger card is in the deck (dealt or in the center), even if nobody can act. The look resolves at once (she needs it to choose); a follow-up as Seer/Robber/Troublemaker/Drunk/Minion resolves when the window closes.
2. **Window 2 — everyone else at once.** Always runs, even if nobody has a choice. Every actor is prompted together: dealt Werewolves, Minion, Masons, Seer, Robber, Troublemaker, Drunk, Insomniac, and a Doppelganger who copied Werewolf/Mason/Insomniac. Nothing is sent to anyone until the window closes; then the engine resolves, each step seeing the table after the previous one: team views (group 2), Seer -> Robber -> Troublemaker -> Drunk (group 3, Doppelganger before the real role), Insomniac (group 4). Engine entry points: `get_required_actions_for_window`, `resolve_window` (`resolve_night` still takes actions keyed by order group 1-4).
- **Timing:** a window closes when its last actor submits, but never sooner than `night_min_window_seconds` (default 8) after it opened (the close is scheduled for that moment); `night_wave_seconds` (default 30) is the maximum. Host "advance" closes the window immediately.
- **Dealt-card rule:** who wakes as a Werewolf or Mason, who acts in every step, and who a Minion sees is decided by the card DEALT (`state.original_roles`) plus a Doppelganger who copied that role, never the card held mid-night. A stolen Werewolf card does not make the thief a Werewolf; the player it was taken from still wakes (and can be the "lone" Werewolf). Winning is still decided by the card held at the end.
- **Results** are stored per window (`night_action_data["wave_<window>_result"]`); a player gets at most one in window 2.

**Action types:** `peek_player`, `peek_center`, `swap_with_player`, `swap_with_center`, `swap_others`, `see_team`, `none`, `skip` (explicit "do nothing": Seer, Robber, Troublemaker only, including a Doppelganger follow-up as one of them; advertised in the prompt's `action_types`; never for the Drunk, the Doppelganger's first look, or view-only roles)

**v1 roles (12):** Werewolf, Villager, Seer, Robber, Troublemaker, Drunk, Insomniac, Minion, Tanner, Hunter, Mason, Doppelganger

**Win conditions:**
- Village wins if a Werewolf is eliminated
- Werewolves win if no Werewolf is eliminated
- Tanner wins if Tanner is eliminated (overrides village win)
- Hunter kills the player they voted for if Hunter dies
- No werewolves in play → village must NOT vote to kill anyone to win

**Critical edge cases:**
- Player disconnects mid-action → action skipped after timer
- Timer expires with no submission → action skipped
- Doppelganger copies a role with a night action → acts again (Seer/Robber/Troublemaker/Drunk/Minion immediately in window 1; Werewolf/Mason/Insomniac in window 2)
- All votes tied → no one dies
- Robber swaps then Troublemaker swaps the same player → order matters (resolution order within window 2 settles this)

## Silent Failure Modes

- **WebSocket connections require JWT auth.** The ASGI middleware validates tokens. Tests need `WebsocketCommunicator` with an authenticated user scope — unauthenticated connections are rejected silently.
- **Throttle rates must be configured in test settings.** Guest auth endpoints use DRF throttling. If `DEFAULT_THROTTLE_RATES` is missing from test settings, guest creation tests fail with 429s that look like server errors.
- **Error messages must not leak role information.** Validation errors for night actions must use generic messages ("invalid action") not role-specific ones ("Seer cannot do that") — the role name itself is hidden information.
- **Night action TOCTOU race.** Concurrent action submissions for the same player must be guarded with `select_for_update()`. Without it, two simultaneous requests can both pass validation and both write.

## Adding a New Role

Requires updates in multiple files — the type system won't catch a missed one:

1. `engine/roles.py` — role definition and metadata
2. `engine/behaviors.py` — night action behavior
3. `engine/night.py` — wave assignment
4. `engine/win_conditions.py` — if the role affects win logic
5. `serializers.py` — if the role has special display rules
6. Tests for each of the above

## Adding a New Django App

The `apps.` prefix in the app name is required and easy to forget:

```python
# apps/myapp/apps.py
class MyappConfig(AppConfig):
    name = "apps.myapp"  # NOT just "myapp"
```

Then add `"apps.myapp"` to `INSTALLED_APPS` in `config/settings/base.py` and create test directories under `tests/unit/myapp/` and `tests/integration/myapp/`.

## Commands

```bash
just test              # pytest (all tests)
just test tests/path/to/test_file.py  # specific file
just test-cov          # pytest with coverage
just test-unit         # Unit tests only
just lint              # Ruff check
just format            # Ruff format
just typecheck         # Pyrefly
just check             # All of the above
```

Pre-commit hooks must be run from the **repo root** (not `backend/`), because `.pre-commit-config.yaml` lives at the root and scopes to `backend/` files via the `files: ^backend/` pattern.
