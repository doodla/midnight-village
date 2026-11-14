#!/usr/bin/env bash
# One-command integration harness runner (contract §D5).
#
# Boots the §B5 backend harness (DEBUG=True, throwaway DB, ASGI on
# 127.0.0.1:8001), waits for health 200, runs the integration_test suite
# HEADLESS on the host Dart VM (`flutter test`, NOT flutter drive), writes PNG
# filmstrips + a machine-readable failures.jsonl, exits non-zero on any failure,
# and tears the backend down.
#
# Usage: tool/run_harness.sh   (run from frontend/)
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FRONTEND_DIR="$REPO_ROOT/frontend"
BACKEND_DIR="$REPO_ROOT/backend"
HARNESS_PORT=8001
HEALTH_URL="http://127.0.0.1:${HARNESS_PORT}/api/health/"
SCREENSHOTS_DIR="$FRONTEND_DIR/integration_test/screenshots"

backend_pid=""

cleanup() {
  if [[ -n "$backend_pid" ]] && kill -0 "$backend_pid" 2>/dev/null; then
    echo "[harness] stopping backend (pid $backend_pid)"
    kill "$backend_pid" 2>/dev/null || true
  fi
  # The runserver/daphne server is a grandchild of the `just` launcher, so on
  # macOS (no process group, no setsid) killing $backend_pid does not reliably
  # reap it. Kill whatever is actually LISTENing on the harness port — that IS
  # the server, matched by port rather than a brittle argv pattern.
  local listeners
  listeners="$(lsof -tiTCP:"$HARNESS_PORT" -sTCP:LISTEN 2>/dev/null || true)"
  if [[ -n "$listeners" ]]; then
    echo "$listeners" | xargs kill 2>/dev/null || true
  fi
  wait "$backend_pid" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

echo "[harness] booting backend harness on 127.0.0.1:8001..."
(
  cd "$BACKEND_DIR"
  exec just --justfile "$BACKEND_DIR/justfile" \
    --working-directory "$BACKEND_DIR" harness-serve
) &
backend_pid=$!

echo "[harness] waiting for health 200 at $HEALTH_URL..."
ready=0
for _ in $(seq 1 60); do
  code="$(curl -s -o /dev/null -w '%{http_code}' "$HEALTH_URL" 2>/dev/null || echo 000)"
  if [[ "$code" == "200" ]]; then
    ready=1
    break
  fi
  # Bail early if the backend process died.
  if ! kill -0 "$backend_pid" 2>/dev/null; then
    echo "[harness] backend process exited before becoming healthy" >&2
    exit 1
  fi
  sleep 1
done

if [[ "$ready" != "1" ]]; then
  echo "[harness] backend did not become healthy within 60s" >&2
  exit 1
fi
echo "[harness] backend healthy."

mkdir -p "$SCREENSHOTS_DIR"

echo "[harness] running integration suite headless (flutter test, --tags e2e)..."
cd "$FRONTEND_DIR"
# The runner suites live under test_e2e/ — NOT under test/ (so the default
# `flutter test` / `just test`, which only scans test/, never runs these
# live-backend suites with no backend up) and NOT under integration_test/ (whose
# device-bound binding falls back to a web device and dies, "Web devices are not
# supported for integration tests yet"). They run on the host Dart VM under the
# normal flutter_test binding when invoked by explicit path here.
flutter test --tags e2e \
  test_e2e/api_runner_test.dart \
  test_e2e/ui_runner_test.dart
test_exit=$?

if [[ "$test_exit" -ne 0 ]]; then
  echo "[harness] FAILED (exit $test_exit). Machine-readable failures:"
  echo "[harness]   $SCREENSHOTS_DIR/failures.jsonl"
  echo "[harness]   filmstrips: $SCREENSHOTS_DIR/<scenario>/"
else
  echo "[harness] PASSED. Filmstrips: $SCREENSHOTS_DIR/<scenario>/"
fi

exit "$test_exit"
