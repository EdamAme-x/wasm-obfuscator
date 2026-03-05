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
test "integration engine pipeline preserves fixture prefix" {
  let input = @obfuscator.fixture_minimal_wasm_add_i32()
  let seed = @obfuscator.default_config().random_seed
  let out = @engine.obfuscate_core(input, 3, 16, seed)
  inspect(prefix_preserved(input, out), content="true")
  inspect(out.length() > input.length(), content="true")
}

///|
test "integration zero-noise mode is a no-op" {
  let input = @obfuscator.fixture_minimal_wasm_add_i32()
  let out = @engine.obfuscate_core(input, 0, 16, 42)
  inspect(out == input, content="true")
}

///|
test "integration obfuscate keeps exported add semantics" {
  let input = @obfuscator.fixture_minimal_wasm_add_i32()
  let before = try! @obfuscator.run_i32_export(input, "add", [7, 11])
  let result = try! @obfuscator.obfuscate(
    input,
    @obfuscator.strict_test_config(),
  )
  let after = try! @obfuscator.run_i32_export(result.obfuscated_wasm, "add", [
    7, 11,
  ])
  inspect(before == after, content="true")
}

///|
test "integration equivalence report succeeds on representative cases" {
  let input = @obfuscator.fixture_minimal_wasm_add_i32()
  let result = try! @obfuscator.obfuscate(
    input,
    @obfuscator.strict_test_config(),
  )
  let cases : Array[@obfuscator.FunctionCase] = [
    { export_name: "add", params: [0, 0], expected_i32: 0 },
    { export_name: "add", params: [1, 2], expected_i32: 3 },
    { export_name: "add", params: [-4, 9], expected_i32: 5 },
  ]
  let report = try! @obfuscator.verify_equivalence(
    input,
    result.obfuscated_wasm,
    cases,
  )
  inspect(report.all_passed, content="true")
  inspect(report.failed_cases, content="0")
  inspect(report.total_cases, content="3")
}
