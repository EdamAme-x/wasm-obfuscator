///|
test "performance benchmark light vs heavy noise" (b : @bench.T) {
  let input = @obfuscator.fixture_minimal_wasm_add_i32()
  let seed = @obfuscator.default_config().random_seed

  b.bench(name="obfuscate_light", fn() {
    b.keep(@engine.obfuscate_core(input, 1, 8, seed).length())
  })
  b.bench(name="obfuscate_heavy", fn() {
    b.keep(@engine.obfuscate_core(input, 8, 64, seed).length())
  })
}

///|
test "performance output growth is bounded for configured noise" {
  let input = @obfuscator.fixture_minimal_wasm_add_i32()
  let seed = @obfuscator.default_config().random_seed
  let section_count = 4
  let payload_bytes = 24

  let out = @engine.obfuscate_core(input, section_count, payload_bytes, seed)
  let growth = out.length() - input.length()
  let max_expected_growth = section_count * (payload_bytes + 32)

  inspect(growth > 0, content="true")
  inspect(growth <= max_expected_growth, content="true")
}
