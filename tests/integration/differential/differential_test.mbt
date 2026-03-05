///|
fn apply_single_passes(
  input : Bytes,
  config : @obfuscator.ObfuscationConfig,
) -> Bytes raise @obfuscator.ObfuscationError {
  let mut current = input
  for pass in config.passes {
    let pass_result = @obfuscator.obfuscate_with_single_pass(
      current, pass, config,
    )
    current = pass_result.obfuscated_wasm
  }
  current
}

///|
test "differential obfuscate_wasm wrapper matches obfuscate().bytes" {
  let input = @obfuscator.fixture_minimal_wasm_add_i32()
  let config = @obfuscator.silent_test_config()
  let wrapped = try! @obfuscator.obfuscate_wasm(input, config~)
  let detailed = try! @obfuscator.obfuscate(input, config)
  inspect(wrapped == detailed.obfuscated_wasm, content="true")
}

///|
test "differential full-pass and single-pass pipelines preserve semantics" {
  let input = @obfuscator.fixture_minimal_wasm_add_i32()
  let config = @obfuscator.silent_test_config()

  let full = try! @obfuscator.obfuscate(input, config).obfuscated_wasm
  let single = try! apply_single_passes(input, config)

  let full_value = try! @obfuscator.run_i32_export(full, "add", [21, 34])
  let single_value = try! @obfuscator.run_i32_export(single, "add", [21, 34])
  assert_eq(full_value, 55)
  assert_eq(single_value, 55)
}

///|
test "differential wat and wasm entrypoints are behavior-equivalent" {
  let wat = @obfuscator.fixture_minimal_wat_add_i32()
  let wasm = try! @obfuscator.parse_wat_to_wasm(wat)
  let config = @obfuscator.strict_test_config()

  let from_wat = try! @obfuscator.obfuscate_wat(wat, config).obfuscated_wasm
  let from_wasm = try! @obfuscator.obfuscate(wasm, config).obfuscated_wasm

  let a = try! @obfuscator.run_i32_export(from_wat, "add", [3, 4])
  let b = try! @obfuscator.run_i32_export(from_wasm, "add", [3, 4])
  assert_eq(a, 7)
  assert_eq(b, 7)
}
