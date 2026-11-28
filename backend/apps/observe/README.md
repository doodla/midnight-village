# apps.observe: what the live app measures of itself

The phones' own speed, kept so the owner can read it without copying anything
(`docs/dev/deploy-vercel.md`, "Seeing the live app"). No game logic; imports only
`apps.core.throttles` and `apps.core.wire`.

- `POST /api/observe/summary/` (`views.SummaryView`): one summary from the app's quiet field
  recorder (`frontend/lib/core/perf/field_summary.dart`): at each game's end, and of the play
  before a tab was hidden. As `navigator.sendBeacon` sends it: `text/plain`, JSON inside, no
  account. `summary.clean` keeps only its known shape, and only labels whose every word is in
  the closed lists of `vocabulary.py` (the app's screens, controls and socket events, and this
  server's own routes with ids as `·`). Of the phone it keeps the kind ("android chrome", in the
  `device` column, derived from the browser's name, which is dropped) and a few coarse numbers.
  8 KB at most (413), not a summary or JSON nested too deep is 400, limited per address
  (`field_summary`, 600 an hour: a room of tables shares one). Each row is stamped to the hour
  (the database's clock); one statement clears rows older than 30 days and all but the newest
  2,000. Answers 204.
- `GET /api/observe/report/?last=N` (`report.build`): the last N summaries (30, at most 60)
  merged, for the owner only: 404 unless the `X-Field-Report-Key` header is the
  `FIELD_REPORT_KEY` setting (an environment variable; unset, the report is closed to
  everyone). It says how many summaries were a game's end, and per kind of tap and device each
  leg's median, 90th percentile and worst; the screens with the most long frames; the slowest
  screen changes; requests; cold starts. Its own allowance (`field_report`, 60 an hour).
  `FIELD_REPORT_KEY=... just field-report` prints it (`tool/field_report.py`).
- `FieldSummary` (migration 0001): `received_at` (the hour), `commit`, `device`, `body`.

Samples: `contract_samples/http/observe/` (`backend/tests/contract/observe_scenarios.py`), and the app's
own summary in `contract_samples/app/field_summary.json` (written by the app's test; the server's
test keeps all of it). Tests: `backend/tests/observe`, and `backend/tests/core/test_open_routes.py` for every
route open without an account.
