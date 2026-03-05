///|
suberror CliError {
  CliError(String)
} derive(Show, Eq)

///|
priv enum InputKind {
  Wasm
  Wat
}

///|
priv struct CliOptions {
  input_path : String
  output_path : String
  random_seed : Int
  emit_spy_trace : Bool
  max_size_growth_percent : Int
  max_runtime_slowdown_percent : Int
}

///|
fn main {
  run_cli(normalize_user_args(@env.args())) catch {
    CliError(message) => {
      println("error: \{message}")
      panic()
    }
  }
}

///|
fn run_cli(args : Array[String]) -> Unit raise CliError {
  if args.length() == 0 {
    print_usage()
    return
  }
  if args[0] == "--help" || args[0] == "-h" {
    print_usage()
    return
  }

  let options = parse_cli_options(args)
  let config : @obfuscator.ObfuscationConfig = {
    passes: @obfuscator.default_config().passes,
    random_seed: options.random_seed,
    max_size_growth_percent: options.max_size_growth_percent,
    max_runtime_slowdown_percent: options.max_runtime_slowdown_percent,
    emit_spy_trace: options.emit_spy_trace,
  }

  let result = match detect_input_kind(options.input_path) {
    Wasm => {
      let input_wasm = read_wasm_file(options.input_path)
      @obfuscator.obfuscate(input_wasm, config) catch {
        error => raise map_obfuscation_error(error)
      }
    }
    Wat => {
      let input_wat = read_wat_file(options.input_path)
      @obfuscator.obfuscate_wat(input_wat, config) catch {
        error => raise map_obfuscation_error(error)
      }
    }
  }

  write_output_wasm(options.output_path, result.obfuscated_wasm)
  println("input: \{options.input_path}")
  println("output: \{options.output_path}")
  println("seed: \{options.random_seed}")
  println("size growth (%): \{result.metrics.size_growth_percent}")
  println(
    "runtime slowdown (%): \{result.metrics.estimated_runtime_slowdown_percent}",
  )
  println("spy events: \{result.spy_events.length()}")
}

///|
fn parse_cli_options(args : Array[String]) -> CliOptions raise CliError {
  let input_path = args[0]
  if !@fs.path_exists(input_path) {
    raise CliError("Input file not found: \{input_path}")
  }

  let defaults = @obfuscator.default_config()
  let mut output_path : String? = None
  let mut random_seed = defaults.random_seed
  let mut emit_spy_trace = defaults.emit_spy_trace
  let mut max_size_growth_percent = defaults.max_size_growth_percent
  let mut max_runtime_slowdown_percent = defaults.max_runtime_slowdown_percent

  let mut i = 1
  while i < args.length() {
    let flag = args[i]
    match flag {
      "--output" | "-o" => {
        if i + 1 >= args.length() {
          raise CliError("Missing value for \{flag}.")
        }
        output_path = Some(args[i + 1])
        i += 2
      }
      "--seed" => {
        if i + 1 >= args.length() {
          raise CliError("Missing value for --seed.")
        }
        random_seed = parse_int_option(args[i + 1], "--seed")
        i += 2
      }
      "--max-size-growth-percent" => {
        if i + 1 >= args.length() {
          raise CliError("Missing value for --max-size-growth-percent.")
        }
        max_size_growth_percent = parse_int_option(
          args[i + 1],
          "--max-size-growth-percent",
        )
        i += 2
      }
      "--max-runtime-slowdown-percent" => {
        if i + 1 >= args.length() {
          raise CliError("Missing value for --max-runtime-slowdown-percent.")
        }
        max_runtime_slowdown_percent = parse_int_option(
          args[i + 1],
          "--max-runtime-slowdown-percent",
        )
        i += 2
      }
      "--spy" => {
        emit_spy_trace = true
        i += 1
      }
      _ => raise CliError("Unknown option: \{flag}")
    }
  }

  let output_path = match output_path {
    Some(path) => path
    None => derive_output_path(input_path)
  }

  {
    input_path,
    output_path,
    random_seed,
    emit_spy_trace,
    max_size_growth_percent,
    max_runtime_slowdown_percent,
  }
}

///|
fn normalize_user_args(raw_args : Array[String]) -> Array[String] {
  let mut start = 1
  if raw_args.length() >= 3 && raw_args[1].has_suffix(".js") {
    start = 2
  }

  let normalized : Array[String] = []
  for i in start..<raw_args.length() {
    normalized.push(raw_args[i])
  }
  normalized
}

///|
fn parse_int_option(raw : String, flag : String) -> Int raise CliError {
  @strconv.parse_int(raw[:]) catch {
    _ => raise CliError("Invalid integer for \{flag}: \{raw}")
  }
}

///|
fn detect_input_kind(path : String) -> InputKind raise CliError {
  if path.has_suffix(".wasm") {
    Wasm
  } else if path.has_suffix(".wat") {
    Wat
  } else {
    raise CliError("Unsupported input format: \{path} (expected .wasm or .wat)")
  }
}

///|
fn derive_output_path(input_path : String) -> String {
  if input_path.has_suffix(".wasm") {
    let base = strip_suffix(input_path, ".wasm")
    "\{base}.obf.wasm"
  } else if input_path.has_suffix(".wat") {
    let base = strip_suffix(input_path, ".wat")
    "\{base}.obf.wasm"
  } else {
    "\{input_path}.obf.wasm"
  }
}

///|
fn strip_suffix(path : String, suffix : String) -> String {
  if !path.has_suffix(suffix) {
    return path
  }

  let prefix_len = path.length() - suffix.length()
  let prefix_view = path[0:prefix_len] catch {
      _ => return copy_prefix(path, prefix_len)
    }
  prefix_view.to_string()
}

///|
fn copy_prefix(path : String, prefix_len : Int) -> String {
  let out = StringBuilder::new(size_hint=prefix_len)
  for i in 0..<prefix_len {
    out.write_char(path.unsafe_get(i).to_int().unsafe_to_char())
  }
  out.to_string()
}

///|
fn read_wasm_file(path : String) -> Bytes raise CliError {
  @fs.read_file_to_bytes(path) catch {
    @fs.IOError(message) =>
      raise CliError("Failed to read wasm input \{path}: \{message}")
  }
}

///|
fn read_wat_file(path : String) -> String raise CliError {
  @fs.read_file_to_string(path) catch {
    @fs.IOError(message) =>
      raise CliError("Failed to read wat input \{path}: \{message}")
  }
}

///|
fn write_output_wasm(path : String, content : Bytes) -> Unit raise CliError {
  @fs.write_bytes_to_file(path, content) catch {
    @fs.IOError(message) =>
      raise CliError("Failed to write output \{path}: \{message}")
  }
}

///|
fn map_obfuscation_error(error : @obfuscator.ObfuscationError) -> CliError {
  match error {
    @obfuscator.InvalidWasmBinary(message) => CliError(message)
    @obfuscator.InvalidConfig(message) => CliError(message)
    @obfuscator.BudgetExceeded(message) => CliError(message)
    @obfuscator.UnsupportedFeature(message) => CliError(message)
  }
}

///|
fn print_usage() -> Unit {
  println("usage: wasm-obfuscator <input.(wasm|wat)> [options]")
  println("options:")
  println("  -o, --output <path>                       output wasm file path")
  println("  --seed <int>                              random seed override")
  println("  --spy                                     enable spy trace")
  println("  --max-size-growth-percent <int>           max output size growth")
  println(
    "  --max-runtime-slowdown-percent <int>      max runtime slowdown estimate",
  )
  println("  -h, --help                                show this help")
}
