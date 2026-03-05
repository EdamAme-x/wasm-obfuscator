///|
let wasm_header : Bytes = b"\x00asm\x01\x00\x00\x00"

///|
fn has_wasm_header(wasm : Bytes) -> Bool {
  let mut ok = wasm.length() >= wasm_header.length()
  if ok {
    for i in 0..<wasm_header.length() {
      if wasm.at(i) != wasm_header.at(i) {
        ok = false
      }
    }
  }
  ok
}

///|
test "unit minimal fixture has valid wasm header" {
  let wasm = @obfuscator.fixture_minimal_wasm_add_i32()
  inspect(has_wasm_header(wasm), content="true")
  inspect(wasm.length() > wasm_header.length(), content="true")
}

///|
test "unit invalid fixture intentionally breaks wasm header" {
  let wasm = @obfuscator.fixture_invalid_wasm()
  inspect(has_wasm_header(wasm), content="false")
}
