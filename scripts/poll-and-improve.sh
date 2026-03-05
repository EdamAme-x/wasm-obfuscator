#!/usr/bin/env bash
set -euo pipefail

INTERVAL_SECONDS="${POLL_INTERVAL_SECONDS:-5}"
TARGET="${MOON_TARGET:-js}"
RUN_TESTS="${RUN_TESTS:-1}"
POLL_LOG_DIR="${POLL_LOG_DIR:-.logs/poll}"
POLL_MAX_LOG_FILES="${POLL_MAX_LOG_FILES:-20}"
POLL_MAX_LOG_BYTES="${POLL_MAX_LOG_BYTES:-1048576}"

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

if ! command -v moon >/dev/null 2>&1; then
  if [[ -x "$HOME/.moon/bin/moon" ]]; then
    export PATH="$HOME/.moon/bin:$PATH"
  fi
fi

if ! command -v moon >/dev/null 2>&1; then
  echo "[poll] moon command not found. Install MoonBit first."
  exit 1
fi

mkdir -p "$POLL_LOG_DIR"

log_line() {
  local level="$1"
  shift
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "[$ts] [poll] [$level] $*"
}

trim_log_file() {
  local file="$1"
  [[ -f "$file" ]] || return 0

  local size
  size="$(wc -c < "$file")"
  if (( size > POLL_MAX_LOG_BYTES )); then
    tail -c "$POLL_MAX_LOG_BYTES" "$file" > "$file.tmp"
    mv "$file.tmp" "$file"
  fi
}

rotate_logs() {
  local glob="$1"
  local i=0
  shopt -s nullglob
  for file in "$POLL_LOG_DIR"/$glob; do
    :
  done
  shopt -u nullglob

  while IFS= read -r file; do
    i=$((i + 1))
    if (( i > POLL_MAX_LOG_FILES )); then
      rm -f "$file"
    fi
  done < <(ls -1t "$POLL_LOG_DIR"/$glob 2>/dev/null || true)
}

improve_once() {
  local run_log="$1"
  {
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[$ts] improve: moon fmt"
    moon fmt

    echo "[$ts] improve: moon check --target ${TARGET}"
    moon check --target "${TARGET}"

    if [[ "${RUN_TESTS}" == "1" ]]; then
      echo "[$ts] improve: moon test --target ${TARGET}"
      moon test --target "${TARGET}"
    fi

    echo "[$ts] improve: success"
  } >>"$run_log" 2>&1
}

log_line INFO "repo: $repo_root"
log_line INFO "interval: ${INTERVAL_SECONDS}s"
log_line INFO "target: ${TARGET}"
log_line INFO "tests: ${RUN_TESTS}"
log_line INFO "log dir: ${POLL_LOG_DIR}"

last_snapshot=""

while true; do
  head_rev="$(git rev-parse --verify HEAD 2>/dev/null || echo NO_HEAD)"
  snapshot="$({
    echo "$head_rev"
    git status --short --untracked-files=all -- . \
      ':(exclude)_build' \
      ':(exclude).mooncakes'
  } | sha256sum | awk '{print $1}')"

  if [[ "$snapshot" != "$last_snapshot" ]]; then
    ts="$(date '+%Y%m%d-%H%M%S')"
    run_log="$POLL_LOG_DIR/run-${ts}.log"

    log_line INFO "change detected"
    git status --short --untracked-files=all -- . \
      ':(exclude)_build' \
      ':(exclude).mooncakes' || true

    if improve_once "$run_log"; then
      trim_log_file "$run_log"
      rotate_logs 'run-*.log'
      rotate_logs 'failure-*.log'
      log_line INFO "improve: success (log: $run_log)"
    else
      failure_log="$POLL_LOG_DIR/failure-${ts}.log"
      {
        echo "timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "head_rev: $head_rev"
        echo "target: $TARGET"
        echo "run_tests: $RUN_TESTS"
        echo "snapshot: $snapshot"
        echo "--- status ---"
        git status --short --untracked-files=all -- . \
          ':(exclude)_build' \
          ':(exclude).mooncakes' || true
        echo "--- run-log ---"
        cat "$run_log"
      } > "$failure_log"

      trim_log_file "$run_log"
      trim_log_file "$failure_log"
      rotate_logs 'run-*.log'
      rotate_logs 'failure-*.log'

      log_line ERROR "improve: failed (failure log: $failure_log)"
      tail -n 80 "$failure_log" || true
    fi

    last_snapshot="$snapshot"
  fi

  sleep "${INTERVAL_SECONDS}"
done
