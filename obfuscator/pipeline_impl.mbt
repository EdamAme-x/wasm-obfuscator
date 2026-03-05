///|
pub fn obfuscate(
  input_wasm : Bytes,
  config : ObfuscationConfig,
) -> ObfuscationResult raise ObfuscationError {
  validate_config(config)
  validate_wasm_binary(input_wasm)
  ensure_parsed_wasm(input_wasm)

  let spy_events : Array[SpyEvent] = []
  let mut slowdown = 0
  let mut output = input_wasm

  if config.emit_spy_trace {
    for i in 0..<config.passes.length() {
      let pass = config.passes[i]
      spy_events.push({
        pass,
        phase: "start",
        detail: "size_before=\{output.length()}",
      })

      let (next_output, cost_percent) = run_single_pass(
        output,
        pass,
        config.random_seed,
        i,
      )
      output = next_output
      slowdown += cost_percent

      spy_events.push({
        pass,
        phase: "end",
        detail: "size_after=\{output.length()}",
      })
    }
  } else {
    for i in 0..<config.passes.length() {
      let pass = config.passes[i]
      let (next_output, cost_percent) = run_single_pass(
        output,
        pass,
        config.random_seed,
        i,
      )
      output = next_output
      slowdown += cost_percent
    }
  }

  let metrics = build_metrics(input_wasm.length(), output.length(), slowdown)
  ensure_budget(config, metrics)

  { obfuscated_wasm: output, metrics, spy_events }
}

///|
pub fn obfuscate_with_single_pass(
  input_wasm : Bytes,
  pass : ObfuscationPass,
  config : ObfuscationConfig,
) -> ObfuscationResult raise ObfuscationError {
  validate_config(config)
  validate_wasm_binary(input_wasm)
  ensure_parsed_wasm(input_wasm)

  let (output, cost_percent) = run_single_pass(
    input_wasm,
    pass,
    config.random_seed,
    0,
  )
  let metrics = build_metrics(
    input_wasm.length(),
    output.length(),
    cost_percent,
  )
  ensure_budget(config, metrics)

  let spy_events : Array[SpyEvent] = if config.emit_spy_trace {
    [
      { pass, phase: "start", detail: "size_before=\{input_wasm.length()}" },
      { pass, phase: "end", detail: "size_after=\{output.length()}" },
    ]
  } else {
    []
  }

  { obfuscated_wasm: output, metrics, spy_events }
}

///|
fn run_single_pass(
  input_wasm : Bytes,
  pass : ObfuscationPass,
  random_seed : Int,
  step_index : Int,
) -> (Bytes, Int) {
  let plan = plan_for_pass(pass)
  let pass_seed = derive_pass_seed(random_seed, pass, step_index)
  let rewritten = match pass {
    RenameIdentifiers =>
      @rewriter.apply_rename_identifiers(input_wasm, pass_seed)
    SplitBlocks => @rewriter.apply_split_blocks(input_wasm, pass_seed)
    FlattenControlFlow =>
      @rewriter.apply_flatten_control_flow(input_wasm, pass_seed)
    EncodeConstants => @rewriter.apply_encode_constants(input_wasm, pass_seed)
    InsertOpaquePredicates =>
      @rewriter.apply_insert_opaque_predicates(input_wasm, pass_seed)
  }

  let output = @engine.obfuscate_core(
    rewritten,
    plan.noise_section_count,
    plan.noise_payload_bytes,
    pass_seed,
  )
  (output, plan.estimated_runtime_cost_percent)
}

///|
pub fn obfuscate_wat(
  input_wat : String,
  config : ObfuscationConfig,
) -> ObfuscationResult raise ObfuscationError {
  let wasm = parse_wat_to_wasm(input_wat)
  obfuscate(wasm, config)
}

///|
fn build_metrics(
  input_size : Int,
  output_size : Int,
  slowdown : Int,
) -> ObfuscationMetrics {
  let size_growth_percent = if input_size <= 0 {
    0
  } else {
    (output_size - input_size) * 100 / input_size
  }
  let estimated_runtime_slowdown_percent = if slowdown < 0 {
    0
  } else {
    slowdown
  }

  {
    input_size,
    output_size,
    size_growth_percent,
    estimated_runtime_slowdown_percent,
  }
}

///|
fn ensure_budget(
  config : ObfuscationConfig,
  metrics : ObfuscationMetrics,
) -> Unit raise ObfuscationError {
  if metrics.size_growth_percent > config.max_size_growth_percent {
    raise BudgetExceeded(
      "Size growth \{metrics.size_growth_percent}% exceeds budget \{config.max_size_growth_percent}%.",
    )
  }
  if metrics.estimated_runtime_slowdown_percent >
    config.max_runtime_slowdown_percent {
    raise BudgetExceeded(
      "Runtime slowdown \{metrics.estimated_runtime_slowdown_percent}% exceeds budget \{config.max_runtime_slowdown_percent}%.",
    )
  }
}
