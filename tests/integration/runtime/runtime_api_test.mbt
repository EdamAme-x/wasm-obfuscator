///|
fn is_budget_exceeded(error : @obfuscator.ObfuscationError) -> Bool {
  match error {
    @obfuscator.BudgetExceeded(_) => true
    _ => false
  }
}

///|
test "runtime run_i32_export evaluates fixture add" {
  let input = @obfuscator.fixture_minimal_wasm_add_i32()
  let value = try! @obfuscator.run_i32_export(input, "add", [10, -3])
  assert_eq(value, 7)
}

///|
test "runtime obfuscate returns valid metrics and equivalence report" {
  let input = @obfuscator.fixture_minimal_wasm_add_i32()
  let config = @obfuscator.strict_test_config()
  let result = try! @obfuscator.obfuscate(input, config)

  inspect(result.metrics.input_size == input.length(), content="true")
  inspect(result.metrics.output_size >= input.length(), content="true")

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
}

///|
test "runtime obfuscate_with_single_pass preserves fixture behavior" {
  let input = @obfuscator.fixture_minimal_wasm_add_i32()
  let config = @obfuscator.strict_test_config()
  let baseline = try! @obfuscator.run_i32_export(input, "add", [7, 11])

  let result = try! @obfuscator.obfuscate_with_single_pass(
    input,
    @obfuscator.RenameIdentifiers,
    config,
  )
  let after = try! @obfuscator.run_i32_export(result.obfuscated_wasm, "add", [
    7, 11,
  ])
  assert_eq(after, baseline)
}

///|
test "runtime all declared passes preserve add semantics" {
  let input = @obfuscator.fixture_minimal_wasm_add_i32()
  let config = @obfuscator.strict_test_config()
  let baseline = try! @obfuscator.run_i32_export(input, "add", [3, 9])

  let passes : Array[@obfuscator.ObfuscationPass] = [
    @obfuscator.RenameIdentifiers,
    @obfuscator.SplitBlocks,
    @obfuscator.FlattenControlFlow,
    @obfuscator.EncodeConstants,
    @obfuscator.InsertOpaquePredicates,
  ]

  for pass in passes {
    let result = try! @obfuscator.obfuscate_with_single_pass(
      input, pass, config,
    )
    let after = try! @obfuscator.run_i32_export(result.obfuscated_wasm, "add", [
      3, 9,
    ])
    assert_eq(after, baseline)
  }
}

///|
test "runtime each pass rewrites bytes while preserving execution" {
  let input = @obfuscator.fixture_minimal_wasm_add_i32()
  let config = @obfuscator.strict_test_config()
  let baseline = try! @obfuscator.run_i32_export(input, "add", [12, 30])

  let passes : Array[@obfuscator.ObfuscationPass] = [
    @obfuscator.RenameIdentifiers,
    @obfuscator.SplitBlocks,
    @obfuscator.FlattenControlFlow,
    @obfuscator.EncodeConstants,
    @obfuscator.InsertOpaquePredicates,
  ]

  for pass in passes {
    let result = try! @obfuscator.obfuscate_with_single_pass(
      input, pass, config,
    )
    inspect(result.obfuscated_wasm == input, content="false")
    let after = try! @obfuscator.run_i32_export(result.obfuscated_wasm, "add", [
      12, 30,
    ])
    assert_eq(after, baseline)
  }
}

///|
test "runtime verify_equivalence reports mismatched expected values" {
  let input = @obfuscator.fixture_minimal_wasm_add_i32()
  let obfuscated = try! @obfuscator.obfuscate(
    input,
    @obfuscator.silent_test_config(),
  )

  let cases : Array[@obfuscator.FunctionCase] = [
    { export_name: "add", params: [1, 1], expected_i32: 3 },
  ]
  let report = try! @obfuscator.verify_equivalence(
    input,
    obfuscated.obfuscated_wasm,
    cases,
  )
  inspect(report.all_passed, content="false")
  inspect(report.failed_cases, content="1")
  inspect(report.total_cases, content="1")
}

///|
test "runtime obfuscate_wat matches parsed-wasm obfuscation output" {
  let wat = @obfuscator.fixture_minimal_wat_add_i32()
  let wasm = try! @obfuscator.parse_wat_to_wasm(wat)
  let config = @obfuscator.silent_test_config()

  let from_wat = try! @obfuscator.obfuscate_wat(wat, config)
  let from_wasm = try! @obfuscator.obfuscate(wasm, config)
  inspect(from_wat.obfuscated_wasm == from_wasm.obfuscated_wasm, content="true")
}

///|
test "runtime budget overflow surfaces BudgetExceeded" {
  let input = @obfuscator.fixture_minimal_wasm_add_i32()
  let base = @obfuscator.strict_test_config()
  let strict_budget : @obfuscator.ObfuscationConfig = {
    ..base,
    passes: [@obfuscator.RenameIdentifiers],
    max_size_growth_percent: 0,
    max_runtime_slowdown_percent: 0,
  }

  let result : Result[
    @obfuscator.ObfuscationResult,
    @obfuscator.ObfuscationError,
  ] = try? @obfuscator.obfuscate(input, strict_budget)

  match result {
    Ok(_) => inspect(false, content="true")
    Err(error) => inspect(is_budget_exceeded(error), content="true")
  }
}
