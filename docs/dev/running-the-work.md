# Running the work

For the session that talks to the owner and hands work out. Someone given one piece of work
does that piece and reports; the rest of this page is not theirs to do.

## The shape of a piece

1. One builder, in its own worktree with its own `DB_NAME`, gets a brief with the owner's words
   in it and builds one finished piece. It commits in small steps that each pass the checks.
2. One fresh reviewer, not given the builder's conclusions, reads the change and looks at the
   pictures. The builder fixes what it found; this session checks the fixes against the list.
   A second review only for a serious finding in the server or the game's rules.
3. Anything visible goes to the owner as before and after pictures before it merges.
4. The piece becomes its own pull request and is merged when its checks are green. The owner
   has asked for this as the standing way of working. Nothing unfinished merges; no giant
   changes.

One heavy piece at a time: every worker shares this one machine. No extra cloud sessions.
Step back often and look at the whole game, not the last report.

## Who does what

A hook refuses any worker that is not on an allowed model with an effort set
(`.claude/guardrails/config.toml` holds the list; `docs/claude-architecture.md` describes it).

- Only `opus` or `sonnet`. Never this session's own model, never `haiku`, never a fork (a fork
  inherits this session's model): start a fresh worker with the context in its brief.
- Opus for design-heavy or tricky work and for reviews. Sonnet for well-specified work and
  lookups.
- Effort: `low` for lookups, `medium` for routine edits, `high` for design and review.

## Outside this repository

- Fetch and merge before pushing: the deployment session pushes to the same branch. After
  pushing anything that changes the server, tell it (its id is in `docs/dev/status.md`).
- Never open or read https://github.com/mankidev/antialgorithm in this session. A worker may,
  and must not reproduce it in its report.

## The owner

Their reports from the live app, in their words, and what is in flight:
`docs/dev/owner-feedback.md`. Keep it current: it is what a new session starts from.
