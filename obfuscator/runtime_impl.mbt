///|
pub fn run_i32_export(
  input_wasm : Bytes,
  export_name : String,
  params : Array[Int],
) -> Int raise ObfuscationError {
  @parser.run_i32_export(input_wasm, export_name, params) catch {
    error => raise map_parser_error(error)
  }
}

///|
pub fn verify_equivalence(
  original_wasm : Bytes,
  obfuscated_wasm : Bytes,
  cases : Array[FunctionCase],
) -> EquivalenceReport raise ObfuscationError {
  let export_names : Array[String] = []
  let params_list : Array[Array[Int]] = []
  for case in cases {
    export_names.push(case.export_name)
    params_list.push(case.params)
  }

  let before_values = @parser.run_i32_exports(
    original_wasm, export_names, params_list,
  ) catch {
    error => raise map_parser_error(error)
  }
  let after_values = @parser.run_i32_exports(
    obfuscated_wasm, export_names, params_list,
  ) catch {
    error => raise map_parser_error(error)
  }

  let mut failed_cases = 0
  for i in 0..<cases.length() {
    let case = cases[i]
    let before = before_values[i]
    let after = after_values[i]
    if before != case.expected_i32 ||
      after != case.expected_i32 ||
      before != after {
      failed_cases += 1
    }
  }

  let total_cases = cases.length()
  { all_passed: failed_cases == 0, total_cases, failed_cases }
}
