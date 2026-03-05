import { useMemo, useState } from "react";
import Editor from "@monaco-editor/react";
import fixtures from "@/generated/fixtures.json";
import { obfuscateBytes } from "@/generated/moonbit-obfuscator-browser.mjs";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

function normalizeHex(input) {
  return input.replace(/[^0-9a-fA-F]/g, "").toLowerCase();
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
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
}

export default function App() {
  const [format, setFormat] = useState("wasm-hex");
  const [noiseSections, setNoiseSections] = useState(3);
  const [payloadBytes, setPayloadBytes] = useState(16);
  const [seed, setSeed] = useState(20260305);
  const [input, setInput] = useState(fixtures.minimalWasmHex);
  const [output, setOutput] = useState("");
  const [status, setStatus] = useState("Idle");
  const [stats, setStats] = useState({ inputSize: 0, outputSize: 0, growth: 0 });

  const inputLanguage = useMemo(() => (format === "wat" ? "wat" : "plaintext"), [format]);

  function onLoadSample() {
    if (format === "wat") {
      setInput(fixtures.minimalWat);
    } else {
      setInput(fixtures.minimalWasmHex);
    }
    setOutput("");
    setStatus("Sample loaded.");
    setStats({ inputSize: 0, outputSize: 0, growth: 0 });
  }

  async function onRun() {
    try {
      const seedValue = Number(seed);
      if (!Number.isInteger(seedValue)) {
        throw new Error("Seed must be an integer.");
      }
      const maxSizeGrowthPercent = Number(noiseSections) * Number(payloadBytes) * 200 + 100;

      let inputBytes;
      if (format === "wasm-hex") {
        // Keep local validation errors deterministic for editor UX and E2E checks.
        inputBytes = hexToBytes(input);
      } else if (input.trim().length === 0) {
        throw new Error("Input is empty.");
      } else {
        inputBytes = new TextEncoder().encode(input);
      }

      const result = obfuscateBytes({
        inputBytes,
        inputFormat: format === "wat" ? "wat" : "wasm",
        seed: seedValue,
        maxSizeGrowthPercent,
        maxRuntimeSlowdownPercent: 10000,
        spy: false
      });
      const metrics = result.metrics ?? {};
      setOutput(bytesToHex(result.outputBytes ?? new Uint8Array()));
      setStatus("Success");
      setStats({
        inputSize: Number(metrics.inputSize ?? metrics.input_size ?? 0),
        outputSize: Number(metrics.outputSize ?? metrics.output_size ?? 0),
        growth: Number(metrics.sizeGrowthPercent ?? metrics.size_growth_percent ?? 0)
      });
    } catch (error) {
      setStatus(`Error: ${error instanceof Error ? error.message : String(error)}`);
      setOutput("");
      setStats({ inputSize: 0, outputSize: 0, growth: 0 });
    }
  }

  return (
    <main className="mx-auto grid w-full max-w-7xl gap-4 p-4 md:p-6">
      <Card>
        <CardHeader>
          <CardTitle>wasm-obfuscator Playground</CardTitle>
          <CardDescription>
            Runs fully in the browser with generated MoonBit JS runtime (no server middleware).
          </CardDescription>
        </CardHeader>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Controls</CardTitle>
        </CardHeader>
        <CardContent className="grid gap-4 md:grid-cols-5">
          <div className="grid gap-2">
            <Label htmlFor="format">Input format</Label>
            <select
              id="format"
              data-testid="format-select"
              className="h-10 rounded-md border border-input bg-background px-3 text-sm"
              value={format}
              onChange={(e) => {
                const next = e.target.value;
                setFormat(next);
                setInput(next === "wat" ? fixtures.minimalWat : fixtures.minimalWasmHex);
                setOutput("");
              }}
            >
              <option value="wasm-hex">Wasm (hex)</option>
              <option value="wat">WAT</option>
            </select>
          </div>

          <div className="grid gap-2">
            <Label htmlFor="noise">Noise sections</Label>
            <Input
              id="noise"
              type="number"
              value={noiseSections}
              onChange={(e) => setNoiseSections(e.target.value)}
            />
          </div>

          <div className="grid gap-2">
            <Label htmlFor="payload">Payload bytes</Label>
            <Input
              id="payload"
              type="number"
              value={payloadBytes}
              onChange={(e) => setPayloadBytes(e.target.value)}
            />
          </div>

          <div className="grid gap-2">
            <Label htmlFor="seed">Seed</Label>
            <Input id="seed" type="number" value={seed} onChange={(e) => setSeed(e.target.value)} />
          </div>

          <div className="grid content-end gap-2">
            <Button data-testid="run-button" onClick={onRun}>
              Obfuscate
            </Button>
            <Button data-testid="sample-button" variant="outline" onClick={onLoadSample}>
              Load sample
            </Button>
          </div>
        </CardContent>
      </Card>

      <div className="grid gap-4 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle className="text-base">Input</CardTitle>
          </CardHeader>
          <CardContent>
            <Editor
              height="320px"
              language={inputLanguage}
              value={input}
              theme="vs-dark"
              onChange={(value) => setInput(value ?? "")}
              options={{
                minimap: { enabled: false },
                fontSize: 13,
                lineNumbers: "on",
                wordWrap: "on"
              }}
            />
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-base">Output (hex)</CardTitle>
          </CardHeader>
          <CardContent>
            <Editor
              height="320px"
              language="plaintext"
              value={output}
              theme="vs-dark"
              options={{
                readOnly: true,
                minimap: { enabled: false },
                fontSize: 13,
                lineNumbers: "on",
                wordWrap: "on"
              }}
            />
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardContent className="grid gap-3 pt-6 md:grid-cols-4">
          <div className="flex items-center gap-2">
            <Badge variant="secondary">Status</Badge>
            <span data-testid="status-text" className="text-sm text-muted-foreground">
              {status}
            </span>
          </div>
          <div className="text-sm text-muted-foreground">
            Input bytes: <span data-testid="in-size">{stats.inputSize}</span>
          </div>
          <div className="text-sm text-muted-foreground">
            Output bytes: <span data-testid="out-size">{stats.outputSize}</span>
          </div>
          <div className="text-sm text-muted-foreground">
            Growth: <span data-testid="growth">{stats.growth}%</span>
          </div>
        </CardContent>
      </Card>
    </main>
  );
}
