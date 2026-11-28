# Rules on the live branches

`live-server` and `live-app` are what Vercel deploys from: whatever lands there serves the
players and migrates the one shared database. Only the release job may move them
(`.github/workflows/deployed-check.yml`, `tool/promote_live.py`), and only after main's checks
pass. These files make GitHub hold that, not only our own code.

| File | What it does | Who imports it |
|---|---|---|
| `live-branches-step1.json` | Nobody deletes or rewinds a live branch. No way through, not even for the release job. | The owner, already. |
| `live-rehearsal.json` | Step 2, aimed at the scratch branch `live-rehearsal`. | The owner, step 5 below. |
| `live-branches-step2.json` | Nobody but the release job's key moves a live branch at all. | The owner, step 7 below, after the rehearsal passed. |

The two steps are separate rulesets on purpose: the key may pass step 2, but step 1 has no way
through, so even the key can only move a live branch forward.

## The owner's steps

1. GitHub, Settings, Environments, New environment `live`. Deployment branches: Selected, add `main`.
2. On your computer, in the project folder, run `tool/make_live_key.sh`. It shows two blocks.
3. Settings, Deploy keys, Add: paste block 1, tick "Allow write access".
4. Environments, `live`, Add secret `LIVE_DEPLOY_KEY`: paste block 2.
5. Settings, Rules, Rulesets, New, Import: `live-rehearsal.json`. Create.
6. Actions, "Live Branches Rehearsal", Run workflow. Wait for green and three PASS lines.
7. Only then import `live-branches-step2.json` the same way, and delete the rehearsal ruleset.

## Why this design

Two designs were weighed:

- **(a) Require status checks that only a merged main commit has, with no way through.** Rejected.
  A check is matched by its name (and at most by the app that posted it, which is GitHub
  Actions for every workflow), so a workflow on any branch can make a green check of that name,
  and a pull request's own head commit already carries green checks of every required name.
  It would not stop `git push origin <unmerged commit>:live-server`.
- **(b) "Restrict updates", with a deploy key as the only way through.** Chosen. The release job
  pushes with that key; the key lives in the environment `live`, which only jobs running on
  `main` may use, and `main` changes only through a pull request with every check green. So a
  workflow on another branch cannot read it, and the job's own token, an agent's token or the
  owner's account cannot move a live branch. Until the owner adds the key, the job pushes with
  its token as before (actions/checkout falls back to it), so merging this changes nothing on
  its own.

What can stop a normal release under (b), and what then happens: a missing, wrong or read-only
key, or the environment not allowing `main`. The push is refused, the run is red, and
`tool/promote_live.py` says the release job's key is missing or wrong and points here. Nothing
else moves, so players keep the last good build. The rehearsal exists to find this before it
matters. A person can still release by hand: "Run workflow" on Deployed Check (with the key in
place).

## Verified in GitHub's docs, and assumed

Verified (docs.github.com and the GitHub changelog, 28 November 2026):
- "Restrict updates": "only users with bypass permissions can push to branches or tags whose
  name matches the pattern" (available rules for rulesets); the rule's API name is `update`.
- `DeployKey` is a bypass actor type, with `actor_id` null, and `pull_request` mode does not
  apply to it (REST API, repository rules). "Deploy keys are now supported as a bypass actor in
  repository rules" (changelog, 30 April 2024).
- A required-status-check rule names checks by `context`, optionally by `integration_id`
  (the app); for classic branch protection the docs say a commit may be pushed directly once its
  checks passed elsewhere. Hence design (a) is weak.
- Environments are available for public repositories on GitHub Free; environment secrets "are
  only available to workflow jobs that reference the environment"; with "Selected branches" only
  matching branches can deploy to it.

Assumed, and proven by the rehearsal before the real rule is imported:
- that a repository owned by a personal account offers "Deploy keys" in the ruleset's bypass
  list and accepts it from an imported file (the page on repository rulesets lists roles, teams,
  apps and Dependabot, and does not mention deploy keys either way);
- that a job whose branch the environment does not allow gets no secret (the docs say it "is
  not allowed to deploy"; they do not spell out the secret);
- that a refusal by a ruleset says `GH013` (the rehearsal counts a refusal for another reason as
  FAIL, so a wrong guess fails safe).

## What the rehearsal proves, and what it does not

`tool/rehearse_live_rule.py`, from the workflow `live-rehearsal.yml`, on `live-rehearsal`:
1. the key moves the branch forward to main: goes through (else the real rule would stop every
   release);
2. the workflow's own token (with `contents: write`, so only the rule can refuse) pushes a commit
   main never had: refused by the rule;
3. the same token pushes main's own commit: refused too (only the key moves it).

Not proven by it: that the key cannot be read from another branch (the environment's branch
setting, step 1, is what holds that); that the key itself moves only to a green main (that is
`tool/promote_live.py`'s job, held by `.claude/guardrails/tests/test_promote_live.py`).
