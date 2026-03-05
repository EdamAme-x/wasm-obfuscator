import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const playgroundRoot = path.resolve(scriptDir, "..");
const repoRoot = path.resolve(playgroundRoot, "..");

function normalizeHex(input) {
  return String(input ?? "").replace(/[^0-9a-fA-F]/g, "").toLowerCase();
}

function hexToBytes(hexInput) {
  const hex = normalizeHex(hexInput);
  if (hex.length === 0) {
    throw new Error("Input is empty.");
  }
  if (hex.length % 2 !== 0) {
    throw new Error("Hex length must be even.");
  }

  const out = new Uint8Array(hex.length / 2);
  for (let i = 0; i < hex.length; i += 2) {
    out[i / 2] = Number.parseInt(hex.slice(i, i + 2), 16);
  }
  return out;
}

function bytesToHex(bytes) {
  return Buffer.from(bytes).toString("hex");
}

function resolveMoonCommand() {
  if (process.env.MOON && process.env.MOON.trim().length > 0) {
    return process.env.MOON;
  }

  const defaultMoon = path.join(os.homedir(), ".moon", "bin", "moon");
  if (fs.existsSync(defaultMoon)) {
    return defaultMoon;
  }
  return "moon";
}

function parseIntLine(stdout, label) {
  const escaped = label.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const pattern = new RegExp(`^${escaped}\\s*:\\s*(-?\\d+)\\s*$`, "m");
  const match = stdout.match(pattern);
  if (!match) {
    return 0;
  }
  return Number.parseInt(match[1], 10);
}

function extractCliError(stderr, stdout) {
  const merged = `${stderr || ""}\n${stdout || ""}`;
  const lines = merged
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line.length > 0);
  const explicitError = lines.find((line) => line.startsWith("error:"));
  if (explicitError) {
    return explicitError.slice("error:".length).trim();
  }
  return lines[lines.length - 1] || "MoonBit obfuscator failed.";
}

function estimateInputSize(outputSize, growthPercent) {
  if (growthPercent <= -100) {
    return 1;
  }
  const estimated = Math.floor((outputSize * 100) / (growthPercent + 100));
  if (Number.isNaN(estimated) || estimated <= 0) {
    return 1;
  }
  if (estimated >= outputSize) {
    return Math.max(1, outputSize - 1);
  }
  return estimated;
}

function runMoonbitObfuscator(payload) {
  const format = payload?.format;
  const input = String(payload?.input ?? "");
  const seed = Number.parseInt(String(payload?.seed ?? "20260305"), 10);
  const maxSizeGrowthPercent = Number.parseInt(
    String(payload?.maxSizeGrowthPercent ?? "10000"),
    10,
  );
  const maxRuntimeSlowdownPercent = Number.parseInt(
    String(payload?.maxRuntimeSlowdownPercent ?? "10000"),
    10,
  );
  const spy = payload?.spy === true;

  if (format !== "wasm-hex" && format !== "wat") {
    throw new Error(`Unsupported format: ${format}`);
  }
  if (Number.isNaN(seed)) {
    throw new Error("Invalid seed.");
  }
  if (Number.isNaN(maxSizeGrowthPercent)) {
    throw new Error("Invalid max size growth percent.");
  }
  if (Number.isNaN(maxRuntimeSlowdownPercent)) {
    throw new Error("Invalid max runtime slowdown percent.");
  }

  let inputBytes = null;
  if (format === "wasm-hex") {
    inputBytes = hexToBytes(input);
  } else if (input.trim().length === 0) {
    throw new Error("Input is empty.");
  }

  const tmpRoot = fs.mkdtempSync(path.join(os.tmpdir(), "wobf-playground-"));
  try {
    const inputPath = path.join(tmpRoot, format === "wat" ? "input.wat" : "input.wasm");
    const outputPath = path.join(tmpRoot, "output.wasm");

    if (format === "wat") {
      fs.writeFileSync(inputPath, input, "utf8");
    } else {
      fs.writeFileSync(inputPath, Buffer.from(inputBytes));
    }

    const moonCmd = resolveMoonCommand();
    const args = [
      "run",
      "cmd/main",
      "--",
      inputPath,
      "--output",
      outputPath,
      "--seed",
      String(seed),
      "--max-size-growth-percent",
      String(maxSizeGrowthPercent),
      "--max-runtime-slowdown-percent",
      String(maxRuntimeSlowdownPercent),
    ];
    if (spy) {
      args.push("--spy");
    }

    const run = spawnSync(moonCmd, args, {
      cwd: repoRoot,
      encoding: "utf8",
    });
    if (run.status !== 0) {
      throw new Error(extractCliError(run.stderr, run.stdout));
    }

    if (!fs.existsSync(outputPath)) {
      throw new Error("Output file was not generated.");
    }

    const outputBytes = fs.readFileSync(outputPath);
    const outputSize = outputBytes.length;
    const growth = parseIntLine(run.stdout, "size growth (%)");
    const runtimeSlowdown = parseIntLine(run.stdout, "runtime slowdown (%)");
    const spyEvents = parseIntLine(run.stdout, "spy events");

    const inputSize =
      inputBytes !== null
        ? inputBytes.length
        : estimateInputSize(outputSize, growth);

    return {
      outputHex: bytesToHex(outputBytes),
      inputSize,
      outputSize,
      growth,
      runtimeSlowdown,
      spyEvents,
    };
  } finally {
    fs.rmSync(tmpRoot, { recursive: true, force: true });
  }
}

function readRequestBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on("data", (chunk) => chunks.push(Buffer.from(chunk)));
    req.on("end", () => {
      try {
        const raw = Buffer.concat(chunks).toString("utf8");
        resolve(raw.length === 0 ? {} : JSON.parse(raw));
      } catch (error) {
        reject(error);
      }
    });
    req.on("error", reject);
  });
}

function installApiMiddleware(server) {
  server.middlewares.use("/api/obfuscate", async (req, res) => {
    if (req.method !== "POST") {
      res.statusCode = 405;
      res.setHeader("content-type", "application/json");
      res.end(JSON.stringify({ error: "Method not allowed." }));
      return;
    }

    try {
      const payload = await readRequestBody(req);
      const result = runMoonbitObfuscator(payload);
      res.statusCode = 200;
      res.setHeader("content-type", "application/json");
      res.end(JSON.stringify(result));
    } catch (error) {
      res.statusCode = 400;
      res.setHeader("content-type", "application/json");
      const message = error instanceof Error ? error.message : String(error);
      res.end(JSON.stringify({ error: message }));
    }
  });
}

export function moonbitObfuscateApiPlugin() {
  return {
    name: "moonbit-obfuscate-api",
    configureServer(server) {
      installApiMiddleware(server);
    },
    configurePreviewServer(server) {
      installApiMiddleware(server);
    },
  };
}
