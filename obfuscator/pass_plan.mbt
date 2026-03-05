///|
priv struct PassPlan {
  noise_section_count : Int
  noise_payload_bytes : Int
  estimated_runtime_cost_percent : Int
}

///|
fn plan_for_pass(pass : ObfuscationPass) -> PassPlan {
  match pass {
    RenameIdentifiers =>
      {
        noise_section_count: 1,
        noise_payload_bytes: 8,
        estimated_runtime_cost_percent: 1,
      }
    SplitBlocks =>
      {
        noise_section_count: 2,
        noise_payload_bytes: 12,
        estimated_runtime_cost_percent: 3,
      }
    FlattenControlFlow =>
      {
        noise_section_count: 3,
        noise_payload_bytes: 16,
        estimated_runtime_cost_percent: 6,
      }
    EncodeConstants =>
      {
        noise_section_count: 2,
        noise_payload_bytes: 10,
        estimated_runtime_cost_percent: 2,
      }
    InsertOpaquePredicates =>
      {
        noise_section_count: 4,
        noise_payload_bytes: 20,
        estimated_runtime_cost_percent: 9,
      }
  }
}

///|
fn pass_tag(pass : ObfuscationPass) -> Int {
  match pass {
    RenameIdentifiers => 101
    SplitBlocks => 211
    FlattenControlFlow => 307
    EncodeConstants => 401
    InsertOpaquePredicates => 509
  }
}

///|
fn derive_pass_seed(
  base_seed : Int,
  pass : ObfuscationPass,
  step_index : Int,
) -> Int {
  base_seed ^ pass_tag(pass) ^ ((step_index + 1) * 977)
}
