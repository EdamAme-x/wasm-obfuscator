///|
fn is_parse_error(error : @wparser.ParseRuntimeError) -> Bool {
  match error {
    @wparser.ParseError(_) => true
    _ => false
  }
}

///|
fn is_runtime_error(error : @wparser.ParseRuntimeError) -> Bool {
  match error {
    @wparser.RuntimeError(_) => true
    _ => false
  }
}

///|
test "parser edge rejects unsupported instruction opcode" {
  let wat = "(module (func (export \"bad\") (param i32 i32) (result i32) local.get 0 local.get 1 i32.div_s))"
  let result : Result[Bytes, @wparser.ParseRuntimeError] = try? @wparser.wat_to_wasm(
    wat,
  )
  match result {
    Ok(_) => inspect(false, content="true")
    Err(error) => inspect(is_runtime_error(error), content="true")
  }
}

///|
test "parser edge rejects unterminated string literal" {
  let wat = "(module (func (export \"add) (param i32 i32) (result i32) local.get 0 local.get 1 i32.add))"
  let result : Result[Bytes, @wparser.ParseRuntimeError] = try? @wparser.wat_to_wasm(
    wat,
  )
  match result {
    Ok(_) => inspect(false, content="true")
    Err(error) => inspect(is_parse_error(error), content="true")
  }
}

///|
test "parser edge rejects unsupported string escape sequence" {
  let wat = "(module (func (export \"bad\\q\") (param i32 i32) (result i32) local.get 0 local.get 1 i32.add))"
  let result : Result[Bytes, @wparser.ParseRuntimeError] = try? @wparser.wat_to_wasm(
    wat,
  )
  match result {
    Ok(_) => inspect(false, content="true")
    Err(error) => inspect(is_parse_error(error), content="true")
  }
}

///|
test "parser edge rejects trailing tokens after module" {
  let wat = "(module (func (export \"add\") (param i32 i32) (result i32) local.get 0 local.get 1 i32.add)) trailing"
  let result : Result[Bytes, @wparser.ParseRuntimeError] = try? @wparser.wat_to_wasm(
    wat,
  )
  match result {
    Ok(_) => inspect(false, content="true")
    Err(error) => inspect(is_parse_error(error), content="true")
  }
}

///|
test "parser edge rejects empty module" {
  let result : Result[Bytes, @wparser.ParseRuntimeError] = try? @wparser.wat_to_wasm(
    "(module)",
  )
  match result {
    Ok(_) => inspect(false, content="true")
    Err(error) => inspect(is_parse_error(error), content="true")
  }
}

///|
test "parser edge supports escaped export names and local zero-init" {
  let wat = "(module\n  (func (export \"sum\\nline\") (param i32 i32) (result i32) (local i32)\n    local.get 0\n    local.get 1\n    i32.add\n    local.get 2\n    i32.add))"

  let wasm = try! @obfuscator.parse_wat_to_wasm(wat)
  let value = try! @obfuscator.run_i32_export(wasm, "sum\nline", [13, 29])
  assert_eq(value, 42)
}
