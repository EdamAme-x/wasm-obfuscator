const { spawnSync } = require("node:child_process");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const cliPath = path.join(__dirname, "dist", "cli.js");
const WASM_HEADER = Buffer.from([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00]);

function addOption(args, flag, value) {
  if (value === undefined || value === null) {
    return;
  }
  args.push(flag, String(value));
}

function detectInputFormat(inputPath) {
  if (inputPath.endsWith(".wasm")) {
    return "wasm";
  }
  if (inputPath.endsWith(".wat")) {
    return "wat";
  }
  throw new Error(`Unsupported input format: ${inputPath} (expected .wasm or .wat)`);
}

function deriveOutputPath(inputPath) {
  if (inputPath.endsWith(".wasm")) {
    return inputPath.slice(0, -5) + ".obf.wasm";
  }
  if (inputPath.endsWith(".wat")) {
    return inputPath.slice(0, -4) + ".obf.wasm";
  }
  return `${inputPath}.obf.wasm`;
}

function normalizeBytes(inputBytes) {
  if (Buffer.isBuffer(inputBytes)) {
    return inputBytes;
  }
  if (inputBytes instanceof Uint8Array) {
    return Buffer.from(inputBytes);
  }
  if (inputBytes instanceof ArrayBuffer) {
    return Buffer.from(new Uint8Array(inputBytes));
  }
  throw new Error("inputBytes must be a Buffer, Uint8Array, or ArrayBuffer");
}

function hasWasmHeader(inputBytes) {
  if (inputBytes.length < WASM_HEADER.length) {
    return false;
  }
  for (let i = 0; i < WASM_HEADER.length; i += 1) {
    if (inputBytes[i] !== WASM_HEADER[i]) {
      return false;
    }
  }
  return true;
}

function isLikelyWatText(inputBytes) {
  const sample = inputBytes.subarray(0, 1024).toString("utf8");
  if (sample.includes("\u0000")) {
    return false;
  }
  const trimmed = sample.trimStart();
  return trimmed.startsWith("(module") || trimmed.startsWith("(") || trimmed.startsWith(";;");
}

function detectInputFormatFromBytes(inputBytes) {
  if (hasWasmHeader(inputBytes)) {
    return "wasm";
  }
  if (isLikelyWatText(inputBytes)) {
    return "wat";
  }
  return "wasm";
}

function runCli(inputPath, outputPath, options) {
  const args = [inputPath, "--output", outputPath];
  addOption(args, "--seed", options.seed);
  if (options.spy === true) {
    args.push("--spy");
  }
  addOption(args, "--max-size-growth-percent", options.maxSizeGrowthPercent);
  addOption(
    args,
    "--max-runtime-slowdown-percent",
    options.maxRuntimeSlowdownPercent,
  );

  const run = spawnSync(process.execPath, [cliPath, ...args], {
    encoding: "utf8",
  });

  if (run.status !== 0) {
    const stderr = (run.stderr || "").trim();
    const stdout = (run.stdout || "").trim();
    throw new Error(`wasm-obfuscator failed (status=${run.status}): ${stderr || stdout}`);
  }

  return run;
}

function obfuscateBytes(options) {
  if (!options || options.inputBytes === undefined || options.inputBytes === null) {
    throw new Error("inputBytes is required");
  }

  const requestedInputFormat = options.inputFormat || "auto";
  if (
    requestedInputFormat !== "wasm" &&
    requestedInputFormat !== "wat" &&
    requestedInputFormat !== "auto"
  ) {
    throw new Error(`Unsupported inputFormat: ${requestedInputFormat}`);
  }

  const inputBytes = normalizeBytes(options.inputBytes);
  const inputFormat = requestedInputFormat === "auto"
    ? detectInputFormatFromBytes(inputBytes)
    : requestedInputFormat;
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "wasm-obfuscator-"));
  try {
    const inputPath = path.join(tmpDir, inputFormat === "wat" ? "input.wat" : "input.wasm");
    const outputPath = path.join(tmpDir, "output.wasm");
    fs.writeFileSync(inputPath, inputBytes);

    const run = runCli(inputPath, outputPath, options);
    const outputBytes = fs.readFileSync(outputPath);

    return {
      inputFormat,
      outputBytes,
      status: run.status,
      stdout: run.stdout,
      stderr: run.stderr,
    };
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
}

function obfuscateFile(options) {
  if (!options || !options.inputPath) {
    throw new Error("inputPath is required");
  }

  const inputFormat = detectInputFormat(options.inputPath);
  const outputPath = options.outputPath || deriveOutputPath(options.inputPath);
  const inputBytes = fs.readFileSync(options.inputPath);

  const run = obfuscateBytes({
    inputBytes,
    inputFormat,
    seed: options.seed,
    spy: options.spy,
    maxSizeGrowthPercent: options.maxSizeGrowthPercent,
    maxRuntimeSlowdownPercent: options.maxRuntimeSlowdownPercent,
  });
  fs.writeFileSync(outputPath, run.outputBytes);

  return {
    inputFormat,
    status: run.status,
    stdout: run.stdout,
    stderr: run.stderr,
    outputPath,
  };
}

module.exports = {
  cliPath,
  obfuscateBytes,
  obfuscateFile,
};
