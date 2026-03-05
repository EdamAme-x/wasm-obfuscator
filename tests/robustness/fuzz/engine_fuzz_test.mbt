///|
fn prefix_preserved(input : Bytes, output : Bytes) -> Bool {
  let mut ok = output.length() >= input.length()
  if ok {
    for i in 0..<input.length() {
      if input.at(i) != output.at(i) {
        ok = false
      }
    }
  }
  ok
}

///|
fn check_case(
  input : Bytes,
  noise_section_count : Int,
  noise_payload_bytes : Int,
  seed : Int,
) -> Unit {
  let out = @engine.obfuscate_core(
    input, noise_section_count, noise_payload_bytes, seed,
  )
  if out.length() < input.length() {
    panic()
  }
  if !prefix_preserved(input, out) {
    panic()
  }
}

///|
test "robustness boundary values for noise and payload" {
  let input = @obfuscator.fixture_minimal_wasm_add_i32()

  check_case(input, 0, 0, 0)
  check_case(input, -1, 10, 0)
  check_case(input, 1, -1, 0)
  check_case(input, 1, 0, 0)
  check_case(input, 1, 1, 0)
  check_case(input, 32, 4, 42)
  check_case(input, 4, 512, 42)
  check_case(input, 8, 1024, -1)
  check_case(input, 8, 1024, 2147483647)
  check_case(input, 8, 1024, -2147483648)
}

///|
test "robustness deterministic pseudo-fuzz matrix" {
  let input = @obfuscator.fixture_minimal_wasm_add_i32()
  let mut x = 0x5F3759DF

  for _ in 0..<5000 {
    x = x * 1664525 + 1013904223
    let noise_section_count = (x & 0x0F) - 4

    x = x * 1664525 + 1013904223
    let noise_payload_bytes = (x & 0xFF) - 32

    x = x * 1664525 + 1013904223
    let seed = x

    check_case(input, noise_section_count, noise_payload_bytes, seed)
  }
}
