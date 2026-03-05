# wasm-obfuscator

Node package for the MoonBit `wasm-obfuscator` project.

## Install

```bash
pnpm add wasm-obfuscator
```

## CLI

```bash
wasm-obfuscator input.wasm --output output.wasm --seed 123 --spy
```

## Node API

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
  spy: true,
});
```

## CLI Options

- `<input.(wasm|wat)>` (required)
- `-o, --output <path>` (default: `<input>.obf.wasm`)
- `--seed <int>` (default: `20260305`)
- `--spy` (enable pass trace output)
- `--max-size-growth-percent <int>` (default: `5000`)
- `--max-runtime-slowdown-percent <int>` (default: `200`)
- `-h, --help`

## `obfuscateBytes` Options

- `inputBytes` (required): `Buffer | Uint8Array | ArrayBuffer`
- `inputFormat` (optional): `"wasm" | "wat" | "auto"` (default: `"auto"`)
  - `auto` は wasm ヘッダ (`00 61 73 6d 01 00 00 00`) を優先判定し、非 wasm は WAT らしさ（`(module` など）を見て判定
- `seed` / `spy` / budget options are the same as `obfuscateFile`

## Current Obfuscation Behavior (v0.1.2)

- Runs 5 passes in order:
  - `RenameIdentifiers` (currently adds `wobf.rename` custom section; no real symbol rename yet)
  - `SplitBlocks` (seed-dependent `nop` sequence injection)
  - `FlattenControlFlow` (seed-dependent `i32.const <imm>; drop` injection)
  - `EncodeConstants` (seed-dependent `enc/mask` xor snippet injection)
  - `InsertOpaquePredicates` (seed-dependent `eq`/`eqz` opaque predicate injection)
- Adds random custom sections with seed-dependent names (`wobf.<rand5>`) per pass.
