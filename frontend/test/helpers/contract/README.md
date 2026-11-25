# Contract test machinery

Tests may only claim states the server can produce.
The payloads come from `contract_samples/` at the repo root, recorded from the real server
(`just samples` in `backend/` regenerates them; the backend suite fails while they are stale; how they are recorded: `backend/tests/README.md`).
This folder:

- `contract_samples.dart` loads them (`dart:io`, found from the working directory upwards; `ContractSamples.map(name)`, `bodyFor(method, path, status:)`).
  `ContractSamples.index` is every recorded sample;
  every recorded `/me/` names its `stage` (`contract_guard_test.dart` checks it).
- `server_json.dart` builds payloads FROM a sample, changing values only (a key the sample lacks throws):
  `serverResults`, `serverLobby`, `serverLogEntry`, `serverMyTable`, `serverRecentGames`, `serverOnlineStats`;
  players lists carry each seat's own token and seat number (`seatFields`).
  `GameEvents` (no `phase_change` to the night, no `connected` in `/me/` players) works the same way.
  A `/me/` is a recorded sample (`recordedMe`), never built.
- `contract_shape.dart` is the guard: every body registered on `MockHttpClient` (hook installed by `test/flutter_test_config.dart`) and every event pushed with
  `MockWebSocketChannel.addServerEvent` must match the samples of that endpoint+status / event type:
  no key path the server never sends, no other JSON type, no always-sent key missing
  (dictionary keys such as role names in `settings.roles` and `deck_preview`, and player ids, are wildcards).
  Variants, not a union: only the samples of the payload's own situation count
  (the `phase` of a `/me/` or `phase_change`, a prompt's `role_acting_as`, a night result's kind, for each `night_results` entry too), so a night-only key in a
  discussion `/me/` is refused; when no sample has that situation, all samples of the endpoint count.
  An error body needs a sample of that endpoint answering that status (record one in `backend/tests/contract/scenarios.py`).
  It does not check values. A test about malformed input says so:
  `thenReturn(..., offContract: true)` (and `answer(..., offContract: true)`), `addOffContractEvent`.
  5xx bodies are not checked.
- Strict mocks: a request with no registered response fails the test (reported to the test zone even if the app swallows the error);
  an error status is answered as a failed request with its body;
  registered bodies are deep-copied. `MockWebSocketChannel.send` fails (the server takes no client messages) unless made with `acceptsSends: true`
  (socket plumbing tests only).
- Domain objects in a test (`GameMe`, `LobbyState`, `MyTable`, `StageProgress`, `GameEvent`, `HostChange`) come from `FromSample` (`from_sample.dart`):
  a checked payload parsed exactly as the app parses it, then client-only state set with `copyWith`.
  Never a constructor with made-up values.
- `ws_sequence/*` samples are not events: each is, per seat, the list of event types it heard.
  The guard validates them as that (every type has a `ws` sample), `checkSocketEvent` never takes one.
  `game_me_test.dart` parses every recorded `/me/`.
  `FromSample.gameMe`, `.myTable`, `.progress` and `.event` give the game's objects;
  `test/helpers/contract/sample_sets.dart` lists every recorded `/me/`
  (`meScreens`: the screen each is, read from its own phase and stage, so a new sample needs no entry) and every lobby body;
  `test/helpers/sheet/story_samples.dart` names every night of My night's story as a recorded talk `/me/`
  (`withLongNames` is the one change a test makes: the players a night names renamed, off the contract in its values only), and
  `test/helpers/sheet/night_record.dart` reads a night's record from the API contract for a test to judge the story by
  (which other cards, face up or down; which names and roles the sentence carries), sharing nothing with the app's reading of it;
  `test/helpers/live_game_setup.dart` wires the game to the strict mocks (its clock starts before every recorded deadline).
- `fixture_sources_test.dart` scans `test/` and `test_screens/` and fails on any way around the guard:
  a mocked HTTP client (`AuthenticatedClient`, `ApiClient`, `Dio`), a mock answering with a literal map, a server-backed domain constructor, a literal map
  passed to `fromJson`. Its allowed list: the debug controller test's mocked `DebugApiClient` (every answer goes through `checkHttpBody`), the debug client
  test's `_ServerAdapter` (same), and the design system's `User` example.
  It cannot see a literal map stored in a variable and parsed later.
- The app parses strictly: what the samples show the server always sends is required (a missing key throws), so a fixture cannot lean on a default;
  where the server really omits a value (`settings.roles` on a new table, `current_role` before the results, `my_vote` outside the vote, a null `deadline`) a
  test built on that sample says so.
- The web integration test cannot read files: its mock bodies are in `integration_test/helpers/server_bodies.dart`, checked against the samples by `contract_guard_test.dart`.
