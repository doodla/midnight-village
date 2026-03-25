# Headless Orchestrate Simplification Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace hand-rolled dependency resolution, state queries, and feature detection in `headless-orchestrate` with native `spec-kitty orchestrator-api` calls, reducing ~100 lines of fragile bash/python glue.

**Architecture:** The scripts currently reimplement three things that `orchestrator-api` does natively: (1) wave computation via python topological sort → replaced by `list-ready`, (2) WP lane queries via `agent tasks list-tasks --json | jq` → replaced by `feature-state`, (3) feature acceptance/merge via `agent feature accept` → replaced by `accept-feature` / `merge-feature`. The execution engine (spawning `claude -p`, locking, retries) stays as-is — that's the unique value.

**Tech Stack:** Bash, jq, spec-kitty CLI v2.1.2

---

### Task 1: Rewrite `lib.sh` — Remove `compute_waves`, simplify state queries

**Files:**
- Modify: `.claude/skills/headless-orchestrate/scripts/lib.sh`

**What changes:**

1. **Delete `compute_waves()`** (lines 121-178) — the 58-line function with embedded Python that does topological sort. Replaced by calling `orchestrator-api list-ready` in the main loop.

2. **Replace `get_all_wp_lanes()`** (lines 108-112) with a wrapper around `orchestrator-api feature-state`:
   ```bash
   get_feature_state() {
     spec-kitty orchestrator-api feature-state --feature "$FEATURE_SLUG" 2>/dev/null
   }
   ```

3. **Replace `get_wp_lane()`** (lines 114-118) to extract from `feature-state` instead of `agent tasks list-tasks`:
   ```bash
   get_wp_lane() {
     local wp_id="$1"
     spec-kitty orchestrator-api feature-state --feature "$FEATURE_SLUG" 2>/dev/null \
       | jq -r --arg wp "$wp_id" '.data.work_packages[] | select(.wp_id == $wp) | .lane'
   }
   ```

4. **Replace `detect_feature()`** (lines 84-105) — simplify to use `spec-kitty context` or keep the existing approach but drop the complex sed parsing. The current approach works via `agent tasks list-tasks` which is fine, but we can tighten it.

5. **Keep as-is:** `acquire_lock`, `release_lock`, `safe_state_cmd`, `parse_prompt_file`, `parse_workspace_path`, `parse_feedback_file`, logging functions. These are unique orchestration value.

**Step 1: Read the current lib.sh and make the edits**

Replace `get_all_wp_lanes` and `get_wp_lane` to use `orchestrator-api feature-state`:

```bash
# --- Feature state queries (via orchestrator-api) ---
get_feature_state_json() {
  spec-kitty orchestrator-api feature-state --feature "$FEATURE_SLUG" 2>/dev/null
}

get_wp_lane() {
  local wp_id="$1"
  get_feature_state_json \
    | jq -r --arg wp "$wp_id" '.data.work_packages[] | select(.wp_id == $wp) | .lane'
}

get_lane_summary() {
  get_feature_state_json | jq -r '.data.summary'
}
```

Replace `compute_waves` with a function that calls `list-ready`:

```bash
get_ready_wps() {
  spec-kitty orchestrator-api list-ready --feature "$FEATURE_SLUG" 2>/dev/null \
    | jq -r '.data.ready_work_packages[].wp_id'
}
```

Delete the old `get_all_wp_lanes` function entirely.

Delete the `compute_waves` function (and its 33-line embedded Python) entirely.

**Step 2: Run shellcheck on lib.sh**

Run: `shellcheck .claude/skills/headless-orchestrate/scripts/lib.sh`
Expected: No new errors introduced.

**Step 3: Commit**

```bash
git add .claude/skills/headless-orchestrate/scripts/lib.sh
git commit -m "refactor(headless-orchestrate): replace hand-rolled state queries with orchestrator-api"
```

---

### Task 2: Rewrite `orchestrate.sh` — Replace wave loop with `list-ready` polling loop

**Files:**
- Modify: `.claude/skills/headless-orchestrate/scripts/orchestrate.sh`

**What changes:**

The current flow is:
1. Preflight (reset stuck WPs, count planned)
2. Analysis gate
3. Compute waves (topological sort)
4. Execute waves in order (implement → review → retry per wave)
5. Accept & merge

The new flow:
1. Preflight (reset stuck WPs via `orchestrator-api transition --to planned --force`, count from `feature-state`)
2. Analysis gate (unchanged)
3. **Poll loop:** call `list-ready`, implement+review all ready WPs, repeat until none left
4. Accept & merge (use `orchestrator-api accept-feature` and `merge-feature`)

**Step 1: Rewrite Phase 0 (Preflight)**

Replace the `agent tasks list-tasks --lane doing` query with `feature-state`:

```bash
# Reset stuck WPs using orchestrator-api
STUCK_WPS=$(get_feature_state_json \
  | jq -r '.data.work_packages[] | select(.lane == "in_progress" or .lane == "claimed") | .wp_id')

for wp in $STUCK_WPS; do
  log "ORCHESTRATE" "Resetting stuck WP $wp -> planned"
  safe_state_cmd spec-kitty orchestrator-api transition \
    --feature "$FEATURE_SLUG" --wp "$wp" --to planned \
    --actor "headless-orchestrator" --force \
    --note "Reset from stuck state by headless orchestrator" || {
    log "ORCHESTRATE" "WARNING: Could not reset $wp, skipping"
  }
done
```

Replace the planned/done counting with `feature-state` summary:

```bash
STATE_JSON=$(get_feature_state_json)
SUMMARY=$(echo "$STATE_JSON" | jq -r '.data.summary')
PLANNED_COUNT=$(echo "$SUMMARY" | jq -r '.planned // 0')
DONE_COUNT=$(echo "$SUMMARY" | jq -r '.done // 0')
TOTAL_COUNT=$(echo "$STATE_JSON" | jq -r '.data.work_packages | length')
```

**Step 2: Replace Phase 2+3 (Compute Waves + Execute Waves) with a polling loop**

Delete the wave computation phase entirely. Replace Phase 3 with:

```bash
# ===============================================================================
# Phase 2: Execute (poll list-ready until empty)
# ===============================================================================
log "ORCHESTRATE" "=== Phase 2: Execute ==="

ROUND=0
while true; do
  READY_WPS=$(get_ready_wps)

  if [[ -z "$READY_WPS" ]]; then
    # Check if truly done or if we're stuck
    REMAINING=$(get_feature_state_json \
      | jq -r '[.data.work_packages[] | select(.lane != "done")] | length')
    if (( REMAINING == 0 )); then
      log "ORCHESTRATE" "All WPs done"
      break
    else
      log "ORCHESTRATE" "STUCK: $REMAINING WPs remain but none are ready"
      log "ORCHESTRATE" "Remaining:"
      get_feature_state_json \
        | jq -r '.data.work_packages[] | select(.lane != "done") | "\(.wp_id): \(.lane)"'
      FAILED_WPS+=("STUCK")
      break
    fi
  fi

  read -ra round_wps <<< "$READY_WPS"
  log "ORCHESTRATE" "--- Round $ROUND: ${round_wps[*]} ---"

  # --- Implement ---
  # (parallel/sequential logic stays the same, just operates on round_wps instead of wave_wps)
  ...

  # --- Review ---
  # (same review + retry logic, unchanged)
  ...

  ROUND=$((ROUND + 1))
done
```

The implement and review blocks within the loop remain structurally identical — just operating on `round_wps` (from `list-ready`) instead of `wave_wps` (from `compute_waves`).

**Step 3: Replace Phase 4 (Accept & Merge)**

Replace the manual "check all done" loop + `agent feature accept` + `spec-kitty merge` with:

```bash
# Accept
log "ORCHESTRATE" "Running acceptance..."
spec-kitty orchestrator-api accept-feature \
  --feature "$FEATURE_SLUG" --actor "headless-orchestrator" \
  2>&1 | tee -a "$LOG_FILE" || {
  log "ORCHESTRATE" "Acceptance failed"
  exit 1
}

# Merge
log "ORCHESTRATE" "Executing merge..."
spec-kitty orchestrator-api merge-feature \
  --feature "$FEATURE_SLUG" \
  2>&1 | tee -a "$LOG_FILE" || {
  log "ORCHESTRATE" "Merge failed"
  exit 1
}
```

**Step 4: Delete the `array_contains` helper**

It was only needed for the wave-based failure tracking. The new loop structure tracks failures inline.

**Step 5: Run shellcheck on orchestrate.sh**

Run: `shellcheck .claude/skills/headless-orchestrate/scripts/orchestrate.sh`
Expected: No new errors.

**Step 6: Commit**

```bash
git add .claude/skills/headless-orchestrate/scripts/orchestrate.sh
git commit -m "refactor(headless-orchestrate): replace wave computation with orchestrator-api list-ready polling"
```

---

### Task 3: Update `implement-wp.sh` — Use `orchestrator-api` for state transitions

**Files:**
- Modify: `.claude/skills/headless-orchestrate/scripts/implement-wp.sh`

**What changes:**

1. The fallback `safe_state_cmd spec-kitty agent tasks move-task` on line 88 should use `orchestrator-api transition` instead.

2. The `get_wp_lane` call already goes through `lib.sh` which we fixed in Task 1, so that's covered.

**Step 1: Replace the fallback move-task with orchestrator-api transition**

```bash
# Old:
safe_state_cmd spec-kitty agent tasks move-task "$WP_ID" --to for_review \
  --note "Moved by orchestrator (agent did not complete lifecycle)" || true

# New:
safe_state_cmd spec-kitty orchestrator-api transition \
  --feature "$FEATURE_SLUG" --wp "$WP_ID" --to for_review \
  --actor "headless-orchestrator" \
  --note "Moved by orchestrator (agent did not complete lifecycle)" || true
```

**Step 2: Commit**

```bash
git add .claude/skills/headless-orchestrate/scripts/implement-wp.sh
git commit -m "refactor(headless-orchestrate): use orchestrator-api transition in implement-wp fallback"
```

---

### Task 4: Update `review-wp.sh` — No structural changes needed

**Files:**
- Modify: `.claude/skills/headless-orchestrate/scripts/review-wp.sh` (if any)

**What changes:**

Review the file. The `get_wp_lane` call at line 74 already goes through `lib.sh`. The review script delegates state transitions to the `claude -p` session itself (via its system prompt telling it to call `spec-kitty agent tasks move-task`). This is correct — the headless agent should use the `agent tasks` interface since it's running as an agent, not as an external orchestrator.

No changes needed here — the headless agent's own state transitions are appropriately using the agent-facing API. Only the orchestrator's own fallback/recovery transitions should use `orchestrator-api`.

**Step 1: Verify — read review-wp.sh and confirm no orchestrator-side state mutations exist outside get_wp_lane**

Expected: The only `spec-kitty` calls in the script body (not the claude -p system prompt) are `agent workflow review` and `get_wp_lane`. Both are fine.

**Step 2: No commit needed unless changes are made.**

---

### Task 5: Update `SKILL.md` — Reflect the simplified architecture

**Files:**
- Modify: `.claude/skills/headless-orchestrate/SKILL.md`

**What changes:**

1. Update "How It Works" > "Dependency-Driven Execution" to describe the `list-ready` polling model instead of wave computation.
2. Update "Scripts" table — `lib.sh` description changes from "wave computation" to "orchestrator-api wrappers".
3. Remove mention of wave computation from "Resumability" section — the new model is inherently resumable since `list-ready` always returns the current truth.
4. Update config table — remove `PARALLEL` reference to "wave" (it now applies to "round").

**Step 1: Edit SKILL.md**

Key sections to rewrite:
- "Dependency-Driven Execution" → "Ready-Based Execution"
- Scripts table: `lib.sh` description
- Resumability: simplify

**Step 2: Commit**

```bash
git add .claude/skills/headless-orchestrate/SKILL.md
git commit -m "docs(headless-orchestrate): update skill docs to reflect orchestrator-api simplification"
```

---

### Task 6: Update `docs/claude-architecture.md`

**Files:**
- Modify: `docs/claude-architecture.md`

**What changes:**

Per CLAUDE.md rules: "If you modify anything in `.claude/`, you MUST update `docs/claude-architecture.md` in the same commit." Since we modified `.claude/skills/headless-orchestrate/`, we need to update the architecture doc to reflect the simplification.

**Step 1: Read the current architecture doc and find the headless-orchestrate section**

**Step 2: Update the description to mention orchestrator-api integration**

**Step 3: Commit** (can be combined with Task 5's commit)

```bash
git add docs/claude-architecture.md .claude/skills/headless-orchestrate/SKILL.md
git commit -m "docs(headless-orchestrate): update skill and architecture docs for orchestrator-api simplification"
```

---

## Summary of what gets deleted vs kept

| Component | Action | Reason |
|---|---|---|
| `compute_waves()` + embedded Python | **DELETE** | Replaced by `orchestrator-api list-ready` |
| `get_all_wp_lanes()` | **DELETE** | Replaced by `get_feature_state_json` |
| `get_wp_lane()` | **REWRITE** | Use `feature-state` instead of `list-tasks` |
| `detect_feature()` | **KEEP** | Still useful, no native equivalent |
| `array_contains()` in orchestrate.sh | **DELETE** | Only needed for wave-based tracking |
| Wave computation phase | **DELETE** | Replaced by polling loop |
| Accept/merge phase | **SIMPLIFY** | Use `orchestrator-api accept-feature` / `merge-feature` |
| Locking, logging, parsing | **KEEP** | Unique orchestration value |
| `implement-wp.sh` core | **KEEP** | `claude -p` invocation is the whole point |
| `review-wp.sh` | **KEEP** | Same — unique value |
| `analyze.sh` | **KEEP** | Unchanged |

**Net result:** ~100 lines of bash/python deleted, ~20 lines of orchestrator-api wrappers added. The scripts become thinner consumers of a stable JSON API rather than reimplementing state management.
