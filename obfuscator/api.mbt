///|
pub fn obfuscate_wasm(
  wasm : Bytes,
  config? : ObfuscationConfig = default_config(),
) -> Bytes raise ObfuscationError {
  validate_wasm_binary(wasm)
  obfuscate(wasm, config).obfuscated_wasm
}
