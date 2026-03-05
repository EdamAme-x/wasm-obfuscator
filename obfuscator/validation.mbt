///|
let wasm_header : Bytes = b"\x00asm\x01\x00\x00\x00"

///|
fn validate_wasm_binary(wasm : Bytes) -> Unit raise ObfuscationError {
  if wasm.length() < wasm_header.length() {
    raise InvalidWasmBinary(
      "Wasm binary must include the 8-byte magic+version header.",
    )
  }
  for i in 0..<wasm_header.length() {
    if wasm.at(i) != wasm_header.at(i) {
      raise InvalidWasmBinary("Wasm magic or version is invalid.")
    }
  }
}

///|
fn validate_config(config : ObfuscationConfig) -> Unit raise ObfuscationError {
  if config.passes.length() == 0 {
    raise InvalidConfig("At least one obfuscation pass must be configured.")
  }
  if config.max_size_growth_percent < 0 {
    raise InvalidConfig("max_size_growth_percent must be >= 0.")
  }
  if config.max_runtime_slowdown_percent < 0 {
    raise InvalidConfig("max_runtime_slowdown_percent must be >= 0.")
  }
}
