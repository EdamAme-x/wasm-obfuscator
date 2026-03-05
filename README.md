# wasm-obfuscator

MoonBit-based toolkit for deterministic, semantics-preserving Wasm/WAT obfuscation.

## Install

```bash
pnpm add wasm-obfuscator
```

## Usage

CLI:

```bash
wasm-obfuscator input.wasm --output output.wasm --seed 123 --spy
wasm-obfuscator input.wat --output output.wasm
```

Node API:

```js
import fs from "node:fs";
import wasmObfuscator from "wasm-obfuscator";

const { obfuscateBytes, obfuscateFile } = wasmObfuscator;

const inputBytes = await fs.promises.readFile("input.wasm");
const { outputBytes, inputFormat } = obfuscateBytes({
  inputBytes,
  seed: 123,
});
console.log("detected format:", inputFormat);
await fs.promises.writeFile("output-bytes.wasm", outputBytes);

obfuscateFile({
  inputPath: "input.wasm",
  outputPath: "output.wasm",
  seed: 123,
  spy: true
});
```

## CLI Options

- Positional: `<input.(wasm|wat)>`
  - Required. Input file path.
  - Supported extensions: `.wasm`, `.wat`
- `-o, --output <path>`
  - Output wasm file path.
  - Default: `<input>.obf.wasm` (for both `.wasm` and `.wat` input)
- `--seed <int>`
  - Random seed used by deterministic transforms.
  - Default: `20260305`
- `--spy`
  - Enables pass-level trace events in the result.
  - Default: disabled
- `--max-size-growth-percent <int>`
  - Budget guard. Fails if output size growth exceeds this value.
  - Default: `5000`
- `--max-runtime-slowdown-percent <int>`
  - Budget guard. Fails if estimated slowdown exceeds this value.
  - Default: `200`
- `-h, --help`
  - Show CLI help.

## Current Obfuscation Behavior (v0.1.2)

The default pipeline runs these passes in order:

1. `RenameIdentifiers`
2. `SplitBlocks`
3. `FlattenControlFlow`
4. `EncodeConstants`
5. `InsertOpaquePredicates`

Current implementation details:

- `RenameIdentifiers`
  - Adds custom section `wobf.rename` with payload `seed=<derived-seed>`.
  - It does not rename wasm identifiers yet.
- `SplitBlocks`
  - Rewrites each function body in the code section and injects seed-dependent `nop` sequences before `end`.
- `FlattenControlFlow`
  - Injects seed-dependent `i32.const <imm>; drop` snippets before `end`.
- `EncodeConstants`
  - Injects seed-dependent `i32.const enc; i32.const mask; i32.xor; drop` before `end`.
- `InsertOpaquePredicates`
  - Injects seed-dependent opaque predicates (`eq` or `eqz` variants) before `end`.
- Core noise layer (`engine.obfuscate_core`)
  - Adds random custom sections with seed-dependent names (`wobf.<rand5>`).
  - Per-pass noise plan:
    - `RenameIdentifiers`: `1` section, `8` payload bytes
    - `SplitBlocks`: `2` sections, `12` payload bytes
    - `FlattenControlFlow`: `3` sections, `16` payload bytes
    - `EncodeConstants`: `2` sections, `10` payload bytes
    - `InsertOpaquePredicates`: `4` sections, `20` payload bytes

CLI output includes:

- `size growth (%)`
- `runtime slowdown (%)` (estimated)
- `spy events` count

## Packages

- Module: `edamame-x/wasm-obfuscator`
- Main API: `edamame-x/wasm-obfuscator/obfuscator`
- CLI: `cmd/main`

## Local Quality Commands

```bash
moon fmt --check
moon check --target all
moon test --target js
moon test --target wasm-gc
bash tests/cli/smoke.sh
bash tests/cli/e2e.sh
bash tests/cli/options/error_matrix.sh
bash tests/npm/wrapper/wrapper_e2e.sh
```

## Playground

- Stack: `Vite + React + shadcn/ui + Monaco`
- Path: `playground/`
- Theme: dark
- Fixture data is synced from `obfuscator/fixtures_impl.mbt` at build/dev time.

```bash
pnpm --dir playground install --frozen-lockfile
pnpm --dir playground run dev
pnpm --dir playground run build
pnpm --dir playground run test:e2e
```

## CI and Pages

- `.github/workflows/ci.yml` runs format/check/tests, CLI tests, build, playground build, and Playwright e2e.
- `.github/workflows/playground-pages.yml` deploys playground to GitHub Pages on `main`.

## Publish Scaffold

```bash
bash scripts/prepare-npm-package.sh
pnpm --dir npm publish --access public --no-git-checks
```
