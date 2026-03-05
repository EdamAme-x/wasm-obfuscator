///|
fn is_parser_error(error : @wparser.ParseRuntimeError) -> Bool {
  match error {
    @wparser.ParseError(_) => true
    _ => false
  }
}

///|
test "parser wat_to_wasm produces executable wasm" {
  let wat = @obfuscator.fixture_minimal_wat_add_i32()
  let wasm = try! @wparser.wat_to_wasm(wat)
  try! @wparser.validate_wasm(wasm)
  let value = try! @wparser.run_i32_export(wasm, "add", [4, 9])
  assert_eq(value, 13)
}

///|
test "parser wat_to_wasm is deterministic" {
  let wat = @obfuscator.fixture_minimal_wat_add_i32()
  let wasm1 = try! @wparser.wat_to_wasm(wat)
  let wasm2 = try! @wparser.wat_to_wasm(wat)
  inspect(wasm1 == wasm2, content="true")
}

///|
test "parser accepts wat with comments and extra spaces" {
  let wat = "(module ;; this is a comment\n  (func (export \"add\") (param i32 i32) (result i32) local.get 0   local.get 1 i32.add )\n)"
  let wasm = try! @wparser.wat_to_wasm(wat)
  let value = try! @wparser.run_i32_export(wasm, "add", [8, 5])
  assert_eq(value, 13)
}

///|
test "parser rejects malformed wat" {
  let malformed = @obfuscator.fixture_invalid_wat()
  let result : Result[Bytes, @wparser.ParseRuntimeError] = try? @wparser.wat_to_wasm(
    malformed,
  )
  match result {
    Ok(_) => inspect(false, content="true")
    Err(error) => inspect(is_parser_error(error), content="true")
  }
}

///|
test "parser rejects invalid wasm section length" {
  let invalid = b"\x00asm\x01\x00\x00\x00\x01\x05\x00"
  let result : Result[Unit, @wparser.ParseRuntimeError] = try? @wparser.validate_wasm(
    invalid,
  )
  match result {
    Ok(_) => inspect(false, content="true")
    Err(error) => inspect(is_parser_error(error), content="true")
  }
}

///|
test "parser supports block comments and extended local/stack ops" {
  let wat = "(module\n  (; outer (; nested ;) comment ;)\n  (func (export \"compose\") (param i32 i32) (result i32) (local i32 i32)\n    local.get 0\n    local.set 2\n    local.get 1\n    local.tee 3\n    drop\n    local.get 2\n    local.get 3\n    i32.eq\n    drop\n    local.get 2\n    local.get 3\n    i32.xor\n    i32.eqz\n    drop\n    local.get 2\n    local.get 3\n    i32.add\n    nop))"

  let wasm = try! @wparser.wat_to_wasm(wat)
  let value = try! @wparser.run_i32_export(wasm, "compose", [20, 22])
  assert_eq(value, 42)
}
