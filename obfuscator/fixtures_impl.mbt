///|
pub fn fixture_minimal_wasm_add_i32() -> Bytes {
  b"\x00asm\x01\x00\x00\x00\x01\x07\x01\x60\x02\x7f\x7f\x01\x7f\x03\x02\x01\x00\x07\x07\x01\x03add\x00\x00\x0a\x09\x01\x07\x00\x20\x00\x20\x01\x6a\x0b"
}

///|
pub fn fixture_invalid_wasm() -> Bytes {
  b"\x00asx\x01\x00\x00\x00"
}

///|
pub fn fixture_minimal_wat_add_i32() -> String {
  "(module (func (export \"add\") (param i32 i32) (result i32) local.get 0 local.get 1 i32.add))"
}

///|
pub fn fixture_invalid_wat() -> String {
  "(module (func (export \"add\") (param i32) (result i32) local.get))"
}
