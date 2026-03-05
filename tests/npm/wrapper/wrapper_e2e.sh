#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$repo_root"

if ! command -v node >/dev/null 2>&1; then
  echo "node command not found; skipping npm wrapper test" >&2
  exit 0
fi

bash scripts/prepare-npm-package.sh >/dev/null

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

cat > "$tmpdir/input.wat" <<'WAT'
(module
  (func (export "add") (param i32 i32) (result i32)
    local.get 0
    local.get 1
    i32.add))
WAT

echo "not_wasm" > "$tmpdir/input.txt"

node - "$repo_root" "$tmpdir" <<'JS'
const fs = require("node:fs");
const path = require("node:path");

const [repoRoot, tmpdir] = process.argv.slice(2);
const api = require(path.join(repoRoot, "npm", "index.js"));

if (typeof api.obfuscateFile !== "function") {
  throw new Error("obfuscateFile is not exported");
}

const inputWat = path.join(tmpdir, "input.wat");
const outputWasm = path.join(tmpdir, "out.wasm");

const run = api.obfuscateFile({
  inputPath: inputWat,
  outputPath: outputWasm,
  seed: 9876,
  spy: true,
});

if (!fs.existsSync(outputWasm) || fs.statSync(outputWasm).size === 0) {
  throw new Error("obfuscateFile did not write output file");
}

const outBytes = fs.readFileSync(outputWasm);
if (
  outBytes.length < 4 ||
  outBytes[0] !== 0x00 ||
  outBytes[1] !== 0x61 ||
  outBytes[2] !== 0x73 ||
  outBytes[3] !== 0x6d
) {
  throw new Error("output is not a wasm binary");
}

if (!run || typeof run.stdout !== "string" || typeof run.stderr !== "string") {
  throw new Error("obfuscateFile return shape is invalid");
}

let threw = false;
try {
  api.obfuscateFile({});
} catch (_) {
  threw = true;
}
if (!threw) {
  throw new Error("obfuscateFile should reject missing inputPath");
}

threw = false;
try {
  api.obfuscateFile({
    inputPath: path.join(tmpdir, "input.txt"),
    outputPath: path.join(tmpdir, "bad.wasm"),
  });
} catch (_) {
  threw = true;
}
if (!threw) {
  throw new Error("obfuscateFile should fail for unsupported extension");
}

if (typeof api.obfuscateBytes !== "function") {
  throw new Error("obfuscateBytes is not exported");
}

const bytesRun = api.obfuscateBytes({
  inputBytes: outBytes,
  inputFormat: "wasm",
  seed: 1234,
});
if (!bytesRun || !Buffer.isBuffer(bytesRun.outputBytes) || bytesRun.outputBytes.length === 0) {
  throw new Error("obfuscateBytes wasm path returned invalid output");
}

const watBytesRun = api.obfuscateBytes({
  inputBytes: fs.readFileSync(inputWat),
  inputFormat: "auto",
  seed: 4321,
});
if (!Buffer.isBuffer(watBytesRun.outputBytes) || watBytesRun.outputBytes.length === 0) {
  throw new Error("obfuscateBytes wat/auto path returned invalid output");
}

threw = false;
try {
  api.obfuscateBytes({});
} catch (_) {
  threw = true;
}
if (!threw) {
  throw new Error("obfuscateBytes should reject missing inputBytes");
}

console.log("npm wrapper e2e test passed.");
JS
