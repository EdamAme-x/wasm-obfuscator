///|
fn arithmetic_wat_fixture() -> String {
  "(module\n  (func (export \"add\") (param i32 i32) (result i32)\n    local.get 0\n    local.get 1\n    i32.add)\n  (func (export \"sub\") (param i32 i32) (result i32)\n    local.get 0\n    local.get 1\n    i32.sub)\n  (func (export \"mix\") (param i32 i32) (result i32) (local i32)\n    local.get 0\n    i32.const 7\n    i32.mul\n    local.get 1\n    i32.sub\n    local.get 2\n    i32.add)\n  (func (export \"logic\") (param i32 i32) (result i32) (local i32 i32)\n    local.get 0\n    local.set 2\n    local.get 1\n    local.tee 3\n    drop\n    local.get 2\n    local.get 3\n    i32.eq\n    drop\n    local.get 2\n    local.get 3\n    i32.xor\n    i32.eqz\n    drop\n    local.get 2\n    local.get 3\n    i32.add\n    nop)\n  (func (export \"line\\nadd\") (param i32 i32) (result i32)\n    local.get 0\n    local.get 1\n    i32.add))"
}

///|
fn lcg_step(state : Int) -> Int {
  state * 1664525 + 1013904223
}

///|
fn sample_operand(raw : Int) -> Int {
  (raw & 0x0003_FFFF) - 131072
}

///|
fn assert_module_semantics(wasm : Bytes, iterations : Int) -> Unit raise {
  let mut state = 0x1357_9BDF
  for _ in 0..<iterations {
    state = lcg_step(state)
    let a = sample_operand(state)

    state = lcg_step(state)
    let b = sample_operand(state)

    let add_value = try! @obfuscator.run_i32_export(wasm, "add", [a, b])
    let sub_value = try! @obfuscator.run_i32_export(wasm, "sub", [a, b])
    let mix_value = try! @obfuscator.run_i32_export(wasm, "mix", [a, b])
    let logic_value = try! @obfuscator.run_i32_export(wasm, "logic", [a, b])
    let escaped_name_value = try! @obfuscator.run_i32_export(
      wasm,
      "line\nadd",
      [a, b],
    )

    inspect(add_value == a + b, content="true")
    inspect(sub_value == a - b, content="true")
    inspect(mix_value == a * 7 - b, content="true")
    inspect(logic_value == a + b, content="true")
    inspect(escaped_name_value == a + b, content="true")
  }
}

///|
test "semantic matrix parser/runtime supports multi-export wat" {
  let wasm = try! @obfuscator.parse_wat_to_wasm(arithmetic_wat_fixture())
  try! assert_module_semantics(wasm, 1200)
}

///|
test "semantic matrix obfuscate(wasm) preserves semantics over seed sweep" {
  let wasm = try! @obfuscator.parse_wat_to_wasm(arithmetic_wat_fixture())
  let base_config = @obfuscator.silent_test_config()
  let seeds : Array[Int] = [0, 1, 2, 9, 42, 1337, -1, 2147483647, -2147483648]

  for seed in seeds {
    let config : @obfuscator.ObfuscationConfig = {
      ..base_config,
      random_seed: seed,
    }
    let out = try! @obfuscator.obfuscate(wasm, config).obfuscated_wasm
    try! assert_module_semantics(out, 500)
  }
}

///|
test "semantic matrix obfuscate_wat is deterministic and matches wasm path" {
  let wat = arithmetic_wat_fixture()
  let wasm = try! @obfuscator.parse_wat_to_wasm(wat)
  let base_config = @obfuscator.silent_test_config()

  for seed in [7, 8, 9, 10] {
    let config : @obfuscator.ObfuscationConfig = {
      ..base_config,
      random_seed: seed,
    }

    let from_wat = try! @obfuscator.obfuscate_wat(wat, config)
    let from_wat_again = try! @obfuscator.obfuscate_wat(wat, config)
    let from_wasm = try! @obfuscator.obfuscate(wasm, config)

    inspect(
      from_wat.obfuscated_wasm == from_wat_again.obfuscated_wasm,
      content="true",
    )
    inspect(
      from_wat.obfuscated_wasm == from_wasm.obfuscated_wasm,
      content="true",
    )

    try! assert_module_semantics(from_wat.obfuscated_wasm, 300)
    try! assert_module_semantics(from_wasm.obfuscated_wasm, 300)
  }
}
