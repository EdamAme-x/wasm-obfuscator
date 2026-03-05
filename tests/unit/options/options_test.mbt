///|
test "unit default config includes all baseline passes" {
  let config = @obfuscator.default_config()
  inspect(config.passes.length(), content="5")
  inspect(config.max_size_growth_percent >= 0, content="true")
  inspect(config.max_runtime_slowdown_percent >= 0, content="true")
}

///|
test "unit strict test config enables spy and fixed seed" {
  let config = @obfuscator.strict_test_config()
  inspect(config.random_seed, content="1337")
  inspect(config.emit_spy_trace, content="true")
}

///|
test "unit silent test config disables spy while preserving seed" {
  let strict = @obfuscator.strict_test_config()
  let silent = @obfuscator.silent_test_config()
  inspect(silent.emit_spy_trace, content="false")
  inspect(silent.random_seed == strict.random_seed, content="true")
}
