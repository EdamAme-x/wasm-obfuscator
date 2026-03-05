#!/usr/bin/env bash
set -euo pipefail

INTERVAL_SECONDS="${SUPERVISOR_INTERVAL_SECONDS:-2}"
POLL_LOG_FILE="${POLL_LOG_FILE:-/tmp/wasm-obfuscator-poll.log}"
SUPERVISOR_LOG_FILE="${SUPERVISOR_LOG_FILE:-/tmp/wasm-obfuscator-supervisor.log}"

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

while true; do
  if ! pgrep -f "scripts/poll-and-improve.sh" >/dev/null 2>&1; then
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[$ts] supervisor: starting poll-and-improve" >> "$SUPERVISOR_LOG_FILE"
    nohup bash ./scripts/poll-and-improve.sh >> "$POLL_LOG_FILE" 2>&1 &
  fi
  sleep "$INTERVAL_SECONDS"
done
