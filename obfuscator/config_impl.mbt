///|
fn all_passes() -> Array[ObfuscationPass] {
  [
    RenameIdentifiers,
    SplitBlocks,
    FlattenControlFlow,
    EncodeConstants,
    InsertOpaquePredicates,
  ]
}

///|
pub fn default_config() -> ObfuscationConfig {
  {
    passes: all_passes(),
    random_seed: 20260305,
    max_size_growth_percent: 5000,
    max_runtime_slowdown_percent: 200,
    emit_spy_trace: false,
  }
}

///|
pub fn strict_test_config() -> ObfuscationConfig {
  let config = default_config()
  { ..config, random_seed: 1337, emit_spy_trace: true }
}

///|
pub fn silent_test_config() -> ObfuscationConfig {
  let config = strict_test_config()
  { ..config, emit_spy_trace: false }
}
