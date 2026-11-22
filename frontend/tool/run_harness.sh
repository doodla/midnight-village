#!/usr/bin/env bash
# One-command integration harness runner (contract §D5).
#
# Boots the §B5 backend harness (DEBUG=True, throwaway DB, ASGI on
# 127.0.0.1:<port>), waits for health 200, runs the e2e suite HEADLESS on the
# host Dart VM (`flutter test`, NOT flutter drive), writes PNG filmstrips + a
# machine-readable failures.jsonl, exits non-zero on any failure, and stops the
# backend it started.
#
# Parallel runs (other worktrees, other agents) never touch each other: each
# run takes its own port (HARNESS_PORT, or a free one picked here), passes it
# to the tests, and stops ONLY the processes it started (its own process
# group, by pid), with a hard kill after a short grace, since `runserver` can
# ignore SIGTERM.
#
# Usage: tool/run_harness.sh   (run from frontend/; HARNESS_PORT=8123 to pin)
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FRONTEND_DIR="$REPO_ROOT/frontend"
BACKEND_DIR="$REPO_ROOT/backend"
SCREENSHOTS_DIR="$FRONTEND_DIR/integration_test/screenshots"
GRACE_SECONDS=5

free_port() {
  python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])'
}

HARNESS_PORT="${HARNESS_PORT:-$(free_port)}"
export HARNESS_PORT
HEALTH_URL="http://127.0.0.1:${HARNESS_PORT}/api/health/"

backend_pid=""

# True while any process of the backend's group is alive.
group_alive() { kill -0 -- "-$backend_pid" 2>/dev/null; }

cleanup() {
  [[ -z "$backend_pid" ]] && return
  if group_alive; then
    echo "[harness] stopping the backend this run started (group $backend_pid)"
    kill -TERM -- "-$backend_pid" 2>/dev/null || true
    for _ in $(seq 1 $((GRACE_SECONDS * 10))); do
      group_alive || break
      sleep 0.1
    done
    if group_alive; then
      echo "[harness] still up after ${GRACE_SECONDS}s: killing it"
      kill -KILL -- "-$backend_pid" 2>/dev/null || true
    fi
  fi
  wait "$backend_pid" 2>/dev/null || true
  backend_pid=""
}
trap cleanup EXIT
# An interrupted run is never reported as passed, whatever the test runner
# exits with when it is stopped.
interrupted=0
trap 'interrupted=1; echo "[harness] INTERRUPTED" >&2; exit 130' INT TERM

echo "[harness] booting backend harness on 127.0.0.1:${HARNESS_PORT}..."
# Job control on: the background job gets a process group of its own (its
# pid), so cleanup can stop exactly it and everything it spawned (just, uv,
# runserver) and nothing else.
set -m
(
  cd "$BACKEND_DIR"
  exec just --justfile "$BACKEND_DIR/justfile" \
    --working-directory "$BACKEND_DIR" harness-serve
) &
backend_pid=$!
set +m

echo "[harness] waiting for health 200 at $HEALTH_URL..."
ready=0
for _ in $(seq 1 90); do
  code="$(curl -s -o /dev/null -w '%{http_code}' "$HEALTH_URL" 2>/dev/null || echo 000)"
  if [[ "$code" == "200" ]]; then
    ready=1
    break
  fi
  # Bail early if the backend process died (e.g. the port was taken).
  if ! kill -0 "$backend_pid" 2>/dev/null; then
    echo "[harness] backend process exited before becoming healthy" >&2
    exit 1
  fi
  sleep 1
done

if [[ "$ready" != "1" ]]; then
  echo "[harness] backend did not become healthy within 90s" >&2
  exit 1
fi
echo "[harness] backend healthy."

# This run's filmstrips only (frames of an earlier run would mix in).
mkdir -p "$SCREENSHOTS_DIR"
find "$SCREENSHOTS_DIR" -mindepth 1 -maxdepth 1 ! -name .gitkeep -exec rm -rf {} +

echo "[harness] running the e2e suite headless (flutter test, --tags e2e)..."
cd "$FRONTEND_DIR"
# The runner suites live under test_e2e/ — NOT under test/ (so the default
# `flutter test` / `just test`, which only scans test/, never runs these
# live-backend suites with no backend up) and NOT under integration_test/ (whose
# device-bound binding falls back to a web device and dies, "Web devices are not
# supported for integration tests yet"). They run on the host Dart VM under the
# normal flutter_test binding when invoked by explicit path here.
flutter test --tags e2e \
  --dart-define=ENV=dev \
  --dart-define=HARNESS_PORT="$HARNESS_PORT" \
  test_e2e/api_runner_test.dart \
  test_e2e/api_lifecycle_test.dart \
  test_e2e/api_game_test.dart \
  test_e2e/ui_game_test.dart \
  test_e2e/ui_roles_test.dart \
  test_e2e/ui_end_test.dart \
  test_e2e/ui_journey_test.dart \
  test_e2e/ui_setup_test.dart \
  test_e2e/ui_practice_test.dart
test_exit=$?

if [[ "$interrupted" -ne 0 ]]; then
  echo "[harness] INTERRUPTED: not a result."
  exit 130
elif [[ "$test_exit" -ne 0 ]]; then
  echo "[harness] FAILED (exit $test_exit). Machine-readable failures:"
  echo "[harness]   $SCREENSHOTS_DIR/failures.jsonl"
  echo "[harness]   filmstrips: $SCREENSHOTS_DIR/<scenario>/"
else
  echo "[harness] PASSED. Filmstrips: $SCREENSHOTS_DIR/<scenario>/"
fi

exit "$test_exit"
