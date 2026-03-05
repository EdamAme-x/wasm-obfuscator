import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const playgroundRoot = path.resolve(scriptDir, "..");
const repoRoot = path.resolve(playgroundRoot, "..");
const fixtureFile = path.join(repoRoot, "obfuscator", "fixtures_impl.mbt");
const outFile = path.join(playgroundRoot, "src", "generated", "fixtures.json");

const source = fs.readFileSync(fixtureFile, "utf8");

function extract(pattern, name) {
  const match = source.match(pattern);
  if (!match) {
    throw new Error(`Failed to extract ${name} from ${fixtureFile}`);
  }
  return match[1];
}

function moonByteLiteralToHex(literal) {
  const bytes = [];
  for (let i = 0; i < literal.length; i += 1) {
    const ch = literal[i];
    if (ch === "\\") {
      const tag = literal[i + 1];
      if (tag === "x") {
        const hex = literal.slice(i + 2, i + 4);
        bytes.push(Number.parseInt(hex, 16));
        i += 3;
        continue;
      }
      if (tag === "n") {
        bytes.push(0x0a);
        i += 1;
        continue;
      }
      if (tag === "t") {
        bytes.push(0x09);
        i += 1;
        continue;
      }
      bytes.push(tag.charCodeAt(0));
      i += 1;
      continue;
    }
    bytes.push(ch.charCodeAt(0));
  }
  return bytes.map((b) => b.toString(16).padStart(2, "0")).join("");
}

const wasmLiteral = extract(
  /pub fn fixture_minimal_wasm_add_i32\(\) -> Bytes \{\s*b"((?:\\.|[^"])*)"/m,
  "fixture_minimal_wasm_add_i32"
);
const watLiteral = extract(
  /pub fn fixture_minimal_wat_add_i32\(\) -> String \{\s*"((?:\\.|[^"])*)"/m,
  "fixture_minimal_wat_add_i32"
);

function unescapeMoonString(value) {
  return value
    .replace(/\\n/g, "\n")
    .replace(/\\t/g, "\t")
    .replace(/\\\"/g, "\"")
    .replace(/\\\\/g, "\\");
}

const payload = {
  minimalWasmHex: moonByteLiteralToHex(wasmLiteral),
  minimalWat: unescapeMoonString(watLiteral)
};

fs.mkdirSync(path.dirname(outFile), { recursive: true });
fs.writeFileSync(outFile, `${JSON.stringify(payload, null, 2)}\n`, "utf8");
console.log(`Synced playground fixtures -> ${path.relative(repoRoot, outFile)}`);
