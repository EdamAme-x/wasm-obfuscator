#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out_dir="$repo_root/tests/generated/massive"
out_pkg="$out_dir/moon.pkg"
out_test="$out_dir/generated_obfuscation_matrix_test.mbt"

segments="${SEGMENTS:-20}"
cases_per_segment="${CASES_PER_SEGMENT:-1600}"

mkdir -p "$out_dir"

cat > "$out_pkg" <<'PKG'
import {
  "edamame-x/wasm-obfuscator/obfuscator",
  "edamame-x/wasm-obfuscator/engine",
} for "test"
PKG

{
  cat <<'MBT'
///|
fn prefix_preserved(input : Bytes, output : Bytes) -> Bool {
  let mut ok = output.length() >= input.length()
  if ok {
    for i in 0..<input.length() {
      if input.at(i) != output.at(i) {
        ok = false
      }
    }
  }
  ok
}

///|
fn check_case(
  input : Bytes,
  noise_section_count : Int,
  noise_payload_bytes : Int,
  seed : Int,
) -> Unit {
  let out = @engine.obfuscate_core(
    input,
    noise_section_count,
    noise_payload_bytes,
    seed,
  )
  if out.length() < input.length() {
    panic()
  }
  if !prefix_preserved(input, out) {
    panic()
  }
}

MBT

  for segment in $(seq 0 $((segments - 1))); do
    echo '///|'
    echo "test \"generated matrix segment ${segment}\" {"
    echo '  let input = @obfuscator.fixture_minimal_wasm_add_i32()'
    start=$((segment * cases_per_segment))
    end=$((start + cases_per_segment - 1))
    for i in $(seq "$start" "$end"); do
      section=$((i % 6))
      payload=$(((i * 7) % 96))
      seed=$((100000 + i * 13))
      echo "  check_case(input, ${section}, ${payload}, ${seed})"
    done
    echo '}'
    echo
  done
} > "$out_test"

line_count="$(wc -l < "$out_test")"
echo "generated $out_test ($line_count lines)"
