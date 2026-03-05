export type ObfuscationPassName =
  | "RenameIdentifiers"
  | "SplitBlocks"
  | "FlattenControlFlow"
  | "EncodeConstants"
  | "InsertOpaquePredicates";

export interface BrowserObfuscationMetrics {
  inputSize: number;
  outputSize: number;
  sizeGrowthPercent: number;
  estimatedRuntimeSlowdownPercent: number;
  input_size: number;
  output_size: number;
  size_growth_percent: number;
  estimated_runtime_slowdown_percent: number;
}

export interface BrowserSpyEvent {
  pass: number;
  passName: ObfuscationPassName | string;
  phase: string;
  detail: string;
}

export interface BrowserConfig {
  passes: Array<ObfuscationPassName | string>;
  randomSeed: number;
  maxSizeGrowthPercent: number;
  maxRuntimeSlowdownPercent: number;
  emitSpyTrace: boolean;
  random_seed: number;
  max_size_growth_percent: number;
  max_runtime_slowdown_percent: number;
  emit_spy_trace: boolean;
}

export interface BrowserObfuscateOptions {
  inputBytes: Uint8Array | ArrayBuffer | ArrayBufferView;
  inputFormat?: "wasm" | "wat" | "auto";
  format?: "wasm" | "wat" | "auto";
  seed?: number;
  randomSeed?: number;
  random_seed?: number;
  maxSizeGrowthPercent?: number;
  max_size_growth_percent?: number;
  maxRuntimeSlowdownPercent?: number;
  max_runtime_slowdown_percent?: number;
  spy?: boolean;
  emitSpyTrace?: boolean;
  emit_spy_trace?: boolean;
  passes?: Array<number | ObfuscationPassName>;
}

export interface BrowserObfuscateResult {
  inputFormat: "wasm" | "wat";
  outputBytes: Uint8Array;
  metrics: BrowserObfuscationMetrics;
  spyEvents: BrowserSpyEvent[];
  spy_events: BrowserSpyEvent[];
}

export interface BrowserObfuscateWatOptions {
  seed?: number;
  randomSeed?: number;
  random_seed?: number;
  maxSizeGrowthPercent?: number;
  max_size_growth_percent?: number;
  maxRuntimeSlowdownPercent?: number;
  max_runtime_slowdown_percent?: number;
  spy?: boolean;
  emitSpyTrace?: boolean;
  emit_spy_trace?: boolean;
  passes?: Array<number | ObfuscationPassName>;
}

export declare function defaultConfig(): BrowserConfig;
export declare function parseWatToWasm(inputWat: string): Uint8Array;
export declare function obfuscateWat(
  inputWat: string,
  options?: BrowserObfuscateWatOptions,
): BrowserObfuscateResult;
export declare function obfuscateBytes(
  options: BrowserObfuscateOptions,
): BrowserObfuscateResult;
