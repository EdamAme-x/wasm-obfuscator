///|
/// Supported obfuscation passes.
pub(all) enum ObfuscationPass {
  RenameIdentifiers
  SplitBlocks
  FlattenControlFlow
  EncodeConstants
  InsertOpaquePredicates
} derive(Show, Eq)

///|
/// Configuration for a single obfuscation run.
pub(all) struct ObfuscationConfig {
  passes : Array[ObfuscationPass]
  random_seed : Int
  max_size_growth_percent : Int
  max_runtime_slowdown_percent : Int
  emit_spy_trace : Bool
} derive(Show, Eq)

///|
/// Event emitted by spy mode during a pass.
pub(all) struct SpyEvent {
  pass : ObfuscationPass
  phase : String
  detail : String
} derive(Show, Eq)

///|
/// Metrics collected during obfuscation.
pub(all) struct ObfuscationMetrics {
  input_size : Int
  output_size : Int
  size_growth_percent : Int
  estimated_runtime_slowdown_percent : Int
} derive(Show, Eq)

///|
/// Main obfuscation output.
pub(all) struct ObfuscationResult {
  obfuscated_wasm : Bytes
  metrics : ObfuscationMetrics
  spy_events : Array[SpyEvent]
} derive(Show, Eq)

///|
/// Single exported-function behavior case used by integration tests.
pub(all) struct FunctionCase {
  export_name : String
  params : Array[Int]
  expected_i32 : Int
} derive(Show, Eq)

///|
/// Equivalence summary for pre/post-obfuscation execution.
pub(all) struct EquivalenceReport {
  all_passed : Bool
  total_cases : Int
  failed_cases : Int
} derive(Show, Eq)

///|
/// Errors returned by validation and obfuscation pipeline.
pub(all) suberror ObfuscationError {
  InvalidWasmBinary(String)
  InvalidConfig(String)
  BudgetExceeded(String)
  UnsupportedFeature(String)
} derive(Show, Eq)

///|
/// Default configuration used in production.
#declaration_only
pub fn default_config() -> ObfuscationConfig {
  ...
}

///|
/// Stricter config tuned for tests; expected to emit spy events.
#declaration_only
pub fn strict_test_config() -> ObfuscationConfig {
  ...
}

///|
/// Lower-overhead config for tests that validate no-spy mode.
#declaration_only
pub fn silent_test_config() -> ObfuscationConfig {
  ...
}

///|
/// Small fixture module exporting `add(i32, i32) -> i32`.
#declaration_only
pub fn fixture_minimal_wasm_add_i32() -> Bytes {
  ...
}

///|
/// Invalid fixture used to validate parser/validator failures.
#declaration_only
pub fn fixture_invalid_wasm() -> Bytes {
  ...
}

///|
/// Small fixture module in WAT text format exporting `add(i32, i32) -> i32`.
#declaration_only
pub fn fixture_minimal_wat_add_i32() -> String {
  ...
}

///|
/// Invalid WAT fixture used to validate parser failures.
#declaration_only
pub fn fixture_invalid_wat() -> String {
  ...
}

///|
/// Parse textual WAT into wasm binary bytes.
#declaration_only
pub fn parse_wat_to_wasm(input_wat : String) -> Bytes raise ObfuscationError {
  ...
}

///|
/// Run full obfuscation pipeline.
#declaration_only
pub fn obfuscate(
  input_wasm : Bytes,
  config : ObfuscationConfig,
) -> ObfuscationResult raise ObfuscationError {
  ...
}

///|
/// Parse WAT and run obfuscation pipeline.
#declaration_only
pub fn obfuscate_wat(
  input_wat : String,
  config : ObfuscationConfig,
) -> ObfuscationResult raise ObfuscationError {
  ...
}

///|
/// Apply exactly one obfuscation pass.
#declaration_only
pub fn obfuscate_with_single_pass(
  input_wasm : Bytes,
  pass : ObfuscationPass,
  config : ObfuscationConfig,
) -> ObfuscationResult raise ObfuscationError {
  ...
}

///|
/// Execute one exported function with i32 params and i32 result.
#declaration_only
pub fn run_i32_export(
  input_wasm : Bytes,
  export_name : String,
  params : Array[Int],
) -> Int raise ObfuscationError {
  ...
}

///|
/// Verify behavior equivalence across representative exported calls.
#declaration_only
pub fn verify_equivalence(
  original_wasm : Bytes,
  obfuscated_wasm : Bytes,
  cases : Array[FunctionCase],
) -> EquivalenceReport raise ObfuscationError {
  ...
}
