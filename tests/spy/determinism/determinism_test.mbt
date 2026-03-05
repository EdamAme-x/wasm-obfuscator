///|
fn run_noise(seed : Int) -> Bytes {
  @engine.obfuscate_core(
    @obfuscator.fixture_minimal_wasm_add_i32(),
    2,
    12,
    seed,
  )
}

///|
test "spy determinism same seed gives identical output" {
  let seed = @obfuscator.strict_test_config().random_seed
  let out1 = run_noise(seed)
  let out2 = run_noise(seed)
  inspect(out1 == out2, content="true")
}

///|
test "spy variance different seed changes output" {
  let out1 = run_noise(7)
  let out2 = run_noise(9)
  inspect(out1 != out2, content="true")
}
