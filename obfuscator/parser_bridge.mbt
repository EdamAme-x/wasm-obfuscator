///|
fn map_parser_error(error : @parser.ParseRuntimeError) -> ObfuscationError {
  match error {
    @parser.ParseError(message) => InvalidWasmBinary(message)
    @parser.RuntimeError(message) => UnsupportedFeature(message)
  }
}

///|
fn ensure_parsed_wasm(wasm : Bytes) -> Unit raise ObfuscationError {
  validate_wasm_binary(wasm)
  @parser.validate_wasm(wasm) catch {
    error => raise map_parser_error(error)
  }
}

///|
pub fn parse_wat_to_wasm(wat : String) -> Bytes raise ObfuscationError {
  @parser.wat_to_wasm(wat) catch {
    error => raise map_parser_error(error)
  }
}
