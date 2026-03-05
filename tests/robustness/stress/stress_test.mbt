///|
test "stress repeated wat parsing remains deterministic" {
  let wat = @obfuscator.fixture_minimal_wat_add_i32()
  let expected = try! @obfuscator.parse_wat_to_wasm(wat)

  for _ in 0..<1000 {
    let parsed = try! @obfuscator.parse_wat_to_wasm(wat)
    inspect(parsed == expected, content="true")
  }
}

///|
test "stress repeated obfuscation preserves add semantics" {
  let mut artifact = @obfuscator.fixture_minimal_wasm_add_i32()
  let base_config = @obfuscator.silent_test_config()

  for i in 0..<300 {
    let config : @obfuscator.ObfuscationConfig = {
      ..base_config,
      random_seed: base_config.random_seed + i,
    }
    artifact = try! @obfuscator.obfuscate(artifact, config).obfuscated_wasm
    let value = try! @obfuscator.run_i32_export(artifact, "add", [i, 1])
    assert_eq(value, i + 1)
  }
}
