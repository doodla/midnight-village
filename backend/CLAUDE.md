# Backend — Midnight Village

## ONUW Game Domain

Understand these mechanics before implementing any game feature.

**Game flow:** Lobby → Night → Discussion → Voting → Results

**Night phase runs in waves:**
1. **Doppelganger** — copies a player's role, may act again in that role's wave
2. **Werewolves, Minion, Masons** — see each other (no state changes)
3. **Seer, Robber, Troublemaker, Drunk** — independent actions, resolve simultaneously
4. **Insomniac, Doppelganger-as-Insomniac** — see own final role after all swaps

**Action types:** `peek_player`, `peek_center`, `swap_with_player`, `swap_with_center`, `swap_others`, `see_team`, `none`

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
- Doppelganger copies a role with a night action → acts again in that wave
- All votes tied → no one dies
- Robber swaps then Troublemaker swaps the same player → order matters (wave ordering resolves this)

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
