///|
let minimal_wat_expected : String = "(module (func (export \"add\") (param i32 i32) (result i32) local.get 0 local.get 1 i32.add))"

///|
test "unit minimal wat fixture is stable and non-empty" {
  let wat = @obfuscator.fixture_minimal_wat_add_i32()
  inspect(
    wat,
    content="(module (func (export \"add\") (param i32 i32) (result i32) local.get 0 local.get 1 i32.add))",
  )
  inspect(wat.length() > 0, content="true")
}

///|
test "unit invalid wat fixture differs from minimal fixture" {
  let valid = @obfuscator.fixture_minimal_wat_add_i32()
  let invalid = @obfuscator.fixture_invalid_wat()
  inspect(valid == minimal_wat_expected, content="true")
  inspect(invalid == valid, content="false")
  inspect(invalid.length() > 0, content="true")
}

///|
test "unit minimal wat parses into runnable wasm" {
  let wat = @obfuscator.fixture_minimal_wat_add_i32()
  let wasm = try! @obfuscator.parse_wat_to_wasm(wat)
  let out = try! @obfuscator.run_i32_export(wasm, "add", [9, 33])
  inspect(out, content="42")
}

///|
test "unit invalid wat is rejected by parser" {
  let invalid = @obfuscator.fixture_invalid_wat()
  let parsed : Result[Bytes, @obfuscator.ObfuscationError] = try? @obfuscator.parse_wat_to_wasm(
    invalid,
  )
  let rejected = match parsed {
    Err(_) => true
    Ok(_) => false
  }
  inspect(rejected, content="true")
}
