#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
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

output="$($moon_cmd run cmd/main)"
printf '%s\n' "$output" | grep -q "usage: wasm-obfuscator"
printf '%s\n' "$output" | grep -q "options:"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

cat >"$tmp_dir/input.wat" <<'WAT'
(module (func (export "add") (param i32 i32) (result i32) local.get 0 local.get 1 i32.add))
WAT

wat_run="$($moon_cmd run cmd/main -- "$tmp_dir/input.wat" --output "$tmp_dir/from_wat.wasm" --seed 1337 --spy)"
printf '%s\n' "$wat_run" | grep -q "output:"
test -s "$tmp_dir/from_wat.wasm"

wasm_run="$($moon_cmd run cmd/main -- "$tmp_dir/from_wat.wasm" --output "$tmp_dir/from_wasm.wasm" --seed 1337)"
printf '%s\n' "$wasm_run" | grep -q "output:"
test -s "$tmp_dir/from_wasm.wasm"

echo "CLI smoke test passed."
