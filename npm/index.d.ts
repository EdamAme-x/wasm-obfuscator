import { Buffer } from "node:buffer";

export interface ObfuscateFileOptions {
  inputPath: string;
  outputPath?: string;
  seed?: number;
  spy?: boolean;
  maxSizeGrowthPercent?: number;
  maxRuntimeSlowdownPercent?: number;
}

export interface ObfuscateBytesOptions {
  inputBytes: Uint8Array | Buffer | ArrayBuffer;
  inputFormat?: "wasm" | "wat" | "auto";
  seed?: number;
  spy?: boolean;
  maxSizeGrowthPercent?: number;
  maxRuntimeSlowdownPercent?: number;
}

export interface ObfuscateFileResult {
  inputFormat: "wasm" | "wat";
  status: number | null;
  stdout: string;
  stderr: string;
  outputPath: string;
}

export interface ObfuscateBytesResult {
  inputFormat: "wasm" | "wat";
  outputBytes: Buffer;
  status: number | null;
  stdout: string;
  stderr: string;
}

export declare const cliPath: string;
export declare function obfuscateBytes(
  options: ObfuscateBytesOptions,
): ObfuscateBytesResult;
export declare function obfuscateFile(
  options: ObfuscateFileOptions,
): ObfuscateFileResult;
