///|
fn is_invalid_wasm(error : @obfuscator.ObfuscationError) -> Bool {
  match error {
    @obfuscator.InvalidWasmBinary(_) => true
    _ => false
  }
}

///|
fn is_unsupported_feature(error : @obfuscator.ObfuscationError) -> Bool {
  match error {
    @obfuscator.UnsupportedFeature(_) => true
    _ => false
  }
}

///|
test "failure obfuscate rejects invalid wasm fixture" {
  let result : Result[
    @obfuscator.ObfuscationResult,
    @obfuscator.ObfuscationError,
  ] = try? @obfuscator.obfuscate(
    @obfuscator.fixture_invalid_wasm(),
    @obfuscator.strict_test_config(),
  )
  match result {
    Ok(_) => inspect(false, content="true")
    Err(error) => inspect(is_invalid_wasm(error), content="true")
  }
}

///|
test "failure parse_wat_to_wasm rejects invalid wat fixture" {
  let result : Result[Bytes, @obfuscator.ObfuscationError] = try? @obfuscator.parse_wat_to_wasm(
    @obfuscator.fixture_invalid_wat(),
  )
  match result {
    Ok(_) => inspect(false, content="true")
    Err(error) => inspect(is_invalid_wasm(error), content="true")
  }
}

///|
test "failure run_i32_export rejects unknown export" {
  let wasm = @obfuscator.fixture_minimal_wasm_add_i32()
  let result : Result[Int, @obfuscator.ObfuscationError] = try? @obfuscator.run_i32_export(
    wasm,
    "missing_export",
    [1, 2],
  )
  match result {
    Ok(_) => inspect(false, content="true")
    Err(error) => inspect(is_unsupported_feature(error), content="true")
  }
}

///|
test "failure run_i32_export rejects invalid parameter count" {
  let wasm = @obfuscator.fixture_minimal_wasm_add_i32()
  let result : Result[Int, @obfuscator.ObfuscationError] = try? @obfuscator.run_i32_export(
    wasm,
    "add",
    [1],
  )
  match result {
    Ok(_) => inspect(false, content="true")
    Err(error) => inspect(is_unsupported_feature(error), content="true")
  }
}
