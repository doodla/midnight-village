# apps.observe: what the live app measures of itself

The phones' own speed, per game, kept so the owner can read it without copying anything
(`docs/dev/deploy-vercel.md`, "Seeing the live app"). No game logic; imports only
`apps.core.throttles` and `apps.core.wire`.

- `POST /api/observe/summary/` (`views.SummaryView`): one summary from the app's quiet field
  recorder (`frontend/lib/core/perf/field_summary.dart`), as `navigator.sendBeacon` sends it:
  `text/plain`, JSON inside, no account. `summary.clean` keeps only its known shape (times,
  counts, labels made of the app's own characters; anything else is dropped), so a row cannot
  hold a name, role, code or id. 16 KB at most (413), not a summary is 400, limited per
  address (`field_summary`, 600 an hour: a room of tables shares one). Each row kept clears
  rows older than 30 days and all but the newest 5,000. Answers 204.
- `GET /api/observe/report/?games=N` (`report.build`): the last N summaries (30, at most 200)
  merged: per kind of tap and device, each leg's median, 90th percentile and worst; the
  screens with the most long frames; the slowest screen changes; requests; cold starts.
  Read only, no account. `just field-report` prints it (`tool/field_report.py`).
- `FieldSummary` (migration 0001): `received_at`, `commit`, `device` ("android chrome"), `body`.

Samples: `contract_samples/http/observe/` (`tests/contract/observe_scenarios.py`). Tests:
`tests/observe/`.
