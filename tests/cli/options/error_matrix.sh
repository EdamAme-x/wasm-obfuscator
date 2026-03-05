#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$repo_root"

moon_cmd="${MOON:-$HOME/.moon/bin/moon}"
if [[ ! -x "$moon_cmd" ]]; then
  if command -v moon >/dev/null 2>&1; then
    moon_cmd="moon"
  else
    echo "moon command not found" >&2
    exit 1
  fi
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

cat > "$tmpdir/input.wat" <<'WAT'
(module
  (func (export "add") (param i32 i32) (result i32)
    local.get 0
    local.get 1
    i32.add))
WAT
printf '%b' '\x00asm\x01\x00\x00\x00\x01\x07\x01\x60\x02\x7f\x7f\x01\x7f\x03\x02\x01\x00\x07\x07\x01\x03add\x00\x00\x0a\x09\x01\x07\x00\x20\x00\x20\x01\x6a\x0b' > "$tmpdir/input.wasm"
echo "text" > "$tmpdir/input.txt"

expect_fail_contains() {
  local case_name="$1"
  local needle="$2"
  shift 2

  local logfile="$tmpdir/${case_name// /_}.log"
  set +e
  "$moon_cmd" run cmd/main -- "$@" >"$logfile" 2>&1
  local status=$?
  set -e

  if [[ $status -eq 0 ]]; then
    echo "[$case_name] expected failure but command succeeded" >&2
    cat "$logfile" >&2
    exit 1
  fi

  if ! grep -q "$needle" "$logfile"; then
    echo "[$case_name] missing expected message: $needle" >&2
    cat "$logfile" >&2
    exit 1
  fi
}

expect_success() {
  local case_name="$1"
  shift

  local logfile="$tmpdir/${case_name// /_}.log"
  "$moon_cmd" run cmd/main -- "$@" >"$logfile" 2>&1
}

long_help="$($moon_cmd run cmd/main -- --help)"
printf '%s\n' "$long_help" | grep -q "usage: wasm-obfuscator"

short_help="$($moon_cmd run cmd/main -- -h)"
printf '%s\n' "$short_help" | grep -q "options:"

expect_fail_contains "missing_input" "Input file not found" "$tmpdir/none.wasm"
expect_fail_contains "unknown_option" "Unknown option: --unknown" "$tmpdir/input.wat" --unknown
expect_fail_contains "missing_seed" "Missing value for --seed" "$tmpdir/input.wat" --seed
expect_fail_contains "invalid_seed" "Invalid integer for --seed" "$tmpdir/input.wat" --seed abc
expect_fail_contains "missing_output" "Missing value for --output" "$tmpdir/input.wat" --output
expect_fail_contains "missing_size_budget" "Missing value for --max-size-growth-percent" "$tmpdir/input.wat" --max-size-growth-percent
expect_fail_contains "invalid_runtime_budget" "Invalid integer for --max-runtime-slowdown-percent" "$tmpdir/input.wat" --max-runtime-slowdown-percent nope
expect_fail_contains "unsupported_extension" "Unsupported input format" "$tmpdir/input.txt"
expect_fail_contains "budget_exceeded" "exceeds budget" "$tmpdir/input.wasm" --max-size-growth-percent 0 --max-runtime-slowdown-percent 0

expect_success "default_output_wat" "$tmpdir/input.wat" --seed 7
[[ -s "$tmpdir/input.obf.wasm" ]]

rm -f "$tmpdir/input.obf.wasm"
expect_success "default_output_wasm" "$tmpdir/input.wasm" --seed 9
[[ -s "$tmpdir/input.obf.wasm" ]]

if command -v node >/dev/null 2>&1; then
  bash scripts/prepare-npm-package.sh >/dev/null
  node npm/dist/cli.js "$tmpdir/input.wat" --output "$tmpdir/node_cli_out.wasm" --seed 11 >/dev/null
  [[ -s "$tmpdir/node_cli_out.wasm" ]]
fi

echo "CLI option/error matrix test passed."
