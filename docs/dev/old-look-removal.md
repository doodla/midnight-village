# Removing the old look (frontend)

Paths below are relative to `frontend/lib/design_system/` (`components/`, `models/`, `tokens/`) or to `frontend/` (`lib/`, `features/` meaning `lib/features/`, `test/`, `test_screens/`, `tool/`, `assets/`). Delete a line here when its files are gone, and this file with the last one.

The old look (Firelit Gothic tokens, `lib/design_system/components/`) stays only while screens still use it. Every old-look file starts with `// OLD LOOK: delete when <screen> is rebuilt` and is a library marked `@Deprecated('OLD LOOK: ...')`, so the analyzer reports every import of it. `just analyze` (`tool/analyze_gate.sh`) lets those reports through only in the files listed in `tool/old_look_users.txt` (the users when it was marked) and fails on any other file's, so no new code takes up the old look; when a listed file stops using it, delete its line (the gate fails until you do). Delete an old-look file in the change that rebuilds the last screen named there. Screens by brief number: 01 Join, 02 Table and 03 Deck are rebuilt (`features/lobby/presentation/`; the old home and lobby screens are gone, with the old text input and app bar); 04 to 11 are `game_container_screen.dart` and the views in `features/game/presentation/`.


| Dies with | Files |
|---|---|
| 08 Talk | `components/game/role_token_list.dart` |
| 05, 06, 08 and 09 | `components/game/game_timer.dart` (+ test) |
| 06 Night action | `components/game/night_action_prompt.dart`, `components/game/center_cards.dart` (+ tests), `models/night_action.dart` |
| 06 and 09 | `components/game/player_circle.dart` (+ test, golden test and `goldens/player_circle_*.png`), `models/player_display.dart` (+ `player_display.freezed.dart`) |
| 08 Talk | `components/core/mv_dialog.dart` |
| 09 Vote | `components/game/vote_submission.dart` (+ test) |
| 10 The count and 11 Results | `components/game/game_results.dart` (+ test) |
| 04, 06, 07, 10 and 11 | `components/game/role_card.dart` (+ golden test and `goldens/role_card_*.png`); the private `_parseRoleId` copies in `features/game/presentation/game_container_screen.dart` and `night_result_view.dart` (use `RoleId.fromServer`) |
| 04 to 11 | `components/foundation/player_avatar.dart`, `models/avatar_size.dart` (+ test); `RoleIdX.teamColor`, `placeholderIcon` and the `app_tokens` import in `models/role.dart` |
| 04 to 11 | `components/foundation/atmospheric_background.dart` (+ test), `components/core/mv_error.dart`, `components/core/mv_loading.dart`, `assets/textures/noise_grain.png` (and its pubspec entry) |
| the last old-look screen | `components/core/primary_button.dart` (+ test); all of `design_system/tokens/` (`app_tokens*.dart`, `firelit_gothic_theme.dart`, `app_colors.dart`, `app_decorations.dart`, `app_radius.dart`, `app_shadows.dart`, `app_spacing.dart` and their tests in `test/design_system/tokens/`); the test-only old theme and helpers `test/design_system/test_helpers/{midnight_village_theme,test_theme,pump_with_tokens}.dart`, `test/helpers/golden_test_helper.dart` (move `golden_smoke_test.dart` onto a skin first) and every `activeThemeProvider` override in tests; `tool/old_look_users.txt` and the old-look branch of `tool/analyze_gate.sh` (then `just analyze` is plain `flutter analyze` again); the `google_fonts` dependency, `test/helpers/font_loading_smoke_test.dart`, the google_fonts line in `test/flutter_test_config.dart`, the "Retired families" section of `test/helpers/test_fonts.dart`, `quietRetiredFonts` in `test_screens/screen_gallery.dart` and the notes about stand-in fonts in `frontend/test/README.md` and in the gallery summary |
