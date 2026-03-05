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

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

printf '%b' '\x00asm\x01\x00\x00\x00\x01\x07\x01\x60\x02\x7f\x7f\x01\x7f\x03\x02\x01\x00\x07\x07\x01\x03add\x00\x00\x0a\x09\x01\x07\x00\x20\x00\x20\x01\x6a\x0b' > "$tmpdir/input.wasm"
cat > "$tmpdir/input.wat" <<'WAT'
(module
  (func (export "add") (param i32 i32) (result i32)
    local.get 0
    local.get 1
    i32.add))
WAT

"$moon_cmd" run cmd/main -- "$tmpdir/input.wasm" --output "$tmpdir/out_from_wasm.wasm" --seed 123 --spy
[[ -f "$tmpdir/out_from_wasm.wasm" ]]
[[ $(stat -c%s "$tmpdir/out_from_wasm.wasm") -gt $(stat -c%s "$tmpdir/input.wasm") ]]

"$moon_cmd" run cmd/main -- "$tmpdir/input.wat" --output "$tmpdir/out_from_wat.wasm" --seed 456
[[ -f "$tmpdir/out_from_wat.wasm" ]]
[[ "$(xxd -p -l 4 "$tmpdir/out_from_wat.wasm")" == "0061736d" ]]

echo "not wasm" > "$tmpdir/input.txt"
if "$moon_cmd" run cmd/main -- "$tmpdir/input.txt" --output "$tmpdir/out_invalid.wasm"; then
  echo "expected failure for unsupported extension" >&2
  exit 1
fi

cat > "$tmpdir/invalid.wat" <<'WAT'
(module (func (export "add") (param i32) (result i32) local.get 0 i32.add
WAT
if "$moon_cmd" run cmd/main -- "$tmpdir/invalid.wat" --output "$tmpdir/out_invalid2.wasm"; then
  echo "expected failure for invalid wat" >&2
  exit 1
fi

cp "$tmpdir/out_from_wasm.wasm" "$tmpdir/large.wasm"
for i in $(seq 1 12); do
  "$moon_cmd" run cmd/main -- "$tmpdir/large.wasm" --output "$tmpdir/large_next.wasm" --seed "$i" >/dev/null
  mv "$tmpdir/large_next.wasm" "$tmpdir/large.wasm"
done
[[ $(stat -c%s "$tmpdir/large.wasm") -gt $(stat -c%s "$tmpdir/out_from_wasm.wasm") ]]

echo "CLI e2e test passed."
