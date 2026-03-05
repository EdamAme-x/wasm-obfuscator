///|
fn obfuscate_for_seed(input : Bytes, seed : Int) -> Bytes {
  let base = @obfuscator.silent_test_config()
  let config : @obfuscator.ObfuscationConfig = { ..base, random_seed: seed }
  try! @obfuscator.obfuscate(input, config).obfuscated_wasm
}

///|
fn assert_export_add_stable(wasm : Bytes) -> Unit {
  let cases : Array[@obfuscator.FunctionCase] = [
    { export_name: "add", params: [0, 0], expected_i32: 0 },
    { export_name: "add", params: [1, 2], expected_i32: 3 },
    { export_name: "add", params: [-40, 82], expected_i32: 42 },
    { export_name: "add", params: [1234, -234], expected_i32: 1000 },
  ]
  let report = try! @obfuscator.verify_equivalence(
    @obfuscator.fixture_minimal_wasm_add_i32(),
    wasm,
    cases,
  )
  if !report.all_passed {
    panic()
  }
}

///|
fn assert_all_outputs_are_distinct(outputs : Array[Bytes]) -> Unit {
  for i in 0..<outputs.length() {
    for j in (i + 1)..<outputs.length() {
      if outputs[i] == outputs[j] {
        panic()
      }
    }
  }
}

///|
test "randomization policy same seed remains deterministic on full pipeline" {
  let input = @obfuscator.fixture_minimal_wasm_add_i32()
  let seed = 20260305

  let out1 = obfuscate_for_seed(input, seed)
  let out2 = obfuscate_for_seed(input, seed)

  inspect(out1 == out2, content="true")
  assert_export_add_stable(out1)
}

///|
test "randomization policy different seeds change bytes but keep export behavior" {
  let input = @obfuscator.fixture_minimal_wasm_add_i32()
  let seeds : Array[Int] = [
    20260305, 20260306, 1337, -1, 2147483647, -2147483648,
  ]

  let outputs : Array[Bytes] = []
  for seed in seeds {
    let out = obfuscate_for_seed(input, seed)
    outputs.push(out)
    let value = try! @obfuscator.run_i32_export(out, "add", [17, 25])
    assert_eq(value, 42)
    assert_export_add_stable(out)
  }

  assert_all_outputs_are_distinct(outputs)
}

///|
test "randomization policy chained obfuscation does not break exported add" {
  let mut artifact = @obfuscator.fixture_minimal_wasm_add_i32()
  let mut seed = 501

  for i in 0..<32 {
    artifact = obfuscate_for_seed(artifact, seed)
    let value = try! @obfuscator.run_i32_export(artifact, "add", [i, 42 - i])
    assert_eq(value, 42)
    seed = seed * 1103515245 + 12345
  }
}
