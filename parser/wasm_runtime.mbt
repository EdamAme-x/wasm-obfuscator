///|
pub fn run_i32_export(
  wasm : Bytes,
  export_name : String,
  params : Array[Int],
) -> Int raise ParseRuntimeError {
  let parsed_module = parse_module(wasm)
  let export_entry = find_export(parsed_module.exports, export_name)
  if export_entry.kind != b'\x00' {
    raise RuntimeError("Only function exports are supported.")
  }
  execute_i32_function(parsed_module, export_entry.index, params)
}

///|
pub fn run_i32_exports(
  wasm : Bytes,
  export_names : Array[String],
  params_list : Array[Array[Int]],
) -> Array[Int] raise ParseRuntimeError {
  if export_names.length() != params_list.length() {
    raise RuntimeError("export_names and params_list length mismatch.")
  }

  let parsed_module = parse_module(wasm)
  let results : Array[Int] = []
  for i in 0..<export_names.length() {
    let export_entry = find_export(parsed_module.exports, export_names[i])
    if export_entry.kind != b'\x00' {
      raise RuntimeError("Only function exports are supported.")
    }
    results.push(
      execute_i32_function(parsed_module, export_entry.index, params_list[i]),
    )
  }
  results
}

///|
fn find_export(
  exports : Array[ExportEntry],
  export_name : String,
) -> ExportEntry raise ParseRuntimeError {
  for entry in exports {
    if entry.name == export_name {
      return entry
    }
  }
  raise RuntimeError("Export not found: \{export_name}")
}

///|
fn execute_i32_function(
  parsed_module : ParsedModule,
  function_index : Int,
  params : Array[Int],
) -> Int raise ParseRuntimeError {
  if function_index < 0 ||
    function_index >= parsed_module.function_type_indices.length() {
    raise RuntimeError("Function index out of range.")
  }

  let type_index = parsed_module.function_type_indices[function_index]
  if type_index < 0 || type_index >= parsed_module.function_types.length() {
    raise RuntimeError("Function type index out of range.")
  }

  let function_type = parsed_module.function_types[type_index]
  if function_type.param_types.length() != params.length() {
    raise RuntimeError("Function parameter count mismatch.")
  }
  for param_type in function_type.param_types {
    if param_type != b'\x7F' {
      raise RuntimeError("Only i32 parameters are supported.")
    }
  }
  if function_type.result_types.length() != 1 ||
    function_type.result_types[0] != b'\x7F' {
    raise RuntimeError("Only single i32 return values are supported.")
  }

  let body = parsed_module.function_bodies[function_index]
  eval_i32_body(body, params)
}

///|
fn eval_i32_body(
  body : Bytes,
  params : Array[Int],
) -> Int raise ParseRuntimeError {
  let mut offset = 0
  let local_group_count_read = decode_u32_leb(body, offset)
  let local_group_count = local_group_count_read.value
  offset = local_group_count_read.next_offset

  let locals : Array[Int] = []
  for param in params {
    locals.push(param)
  }
  for _ in 0..<local_group_count {
    let count_read = decode_u32_leb(body, offset)
    let local_count = count_read.value
    offset = count_read.next_offset
    if offset >= body.length() {
      raise ParseError("Function body is truncated in local declarations.")
    }
    let local_type = body.at(offset)
    offset += 1
    if local_type != b'\x7F' {
      raise RuntimeError("Only i32 locals are supported.")
    }
    for _ in 0..<local_count {
      locals.push(0)
    }
  }

  let stack : Array[Int] = []
  let mut saw_end = false
  while offset < body.length() {
    let opcode = body.at(offset).to_int()
    offset += 1
    match opcode {
      0x01 => ()
      0x1A => pop_i32(stack) |> ignore
      0x20 => {
        let index_read = decode_u32_leb(body, offset)
        let local_index = index_read.value
        offset = index_read.next_offset
        if local_index < 0 || local_index >= locals.length() {
          raise RuntimeError("local.get index out of range.")
        }
        stack.push(locals[local_index])
      }
      0x21 => {
        let index_read = decode_u32_leb(body, offset)
        let local_index = index_read.value
        offset = index_read.next_offset
        if local_index < 0 || local_index >= locals.length() {
          raise RuntimeError("local.set index out of range.")
        }
        let value = pop_i32(stack)
        locals[local_index] = value
      }
      0x22 => {
        let index_read = decode_u32_leb(body, offset)
        let local_index = index_read.value
        offset = index_read.next_offset
        if local_index < 0 || local_index >= locals.length() {
          raise RuntimeError("local.tee index out of range.")
        }
        let value = pop_i32(stack)
        locals[local_index] = value
        stack.push(value)
      }
      0x41 => {
        let value_read = decode_i32_leb(body, offset)
        stack.push(value_read.value)
        offset = value_read.next_offset
      }
      0x6A => {
        let rhs = pop_i32(stack)
        let lhs = pop_i32(stack)
        stack.push(lhs + rhs)
      }
      0x6B => {
        let rhs = pop_i32(stack)
        let lhs = pop_i32(stack)
        stack.push(lhs - rhs)
      }
      0x6C => {
        let rhs = pop_i32(stack)
        let lhs = pop_i32(stack)
        stack.push(lhs * rhs)
      }
      0x73 => {
        let rhs = pop_i32(stack)
        let lhs = pop_i32(stack)
        stack.push(lhs ^ rhs)
      }
      0x45 => {
        let value = pop_i32(stack)
        if value == 0 {
          stack.push(1)
        } else {
          stack.push(0)
        }
      }
      0x46 => {
        let rhs = pop_i32(stack)
        let lhs = pop_i32(stack)
        if lhs == rhs {
          stack.push(1)
        } else {
          stack.push(0)
        }
      }
      0x0B => {
        saw_end = true
        break
      }
      _ => raise RuntimeError("Unsupported opcode: \{opcode}")
    }
  }

  if !saw_end {
    raise RuntimeError("Function body did not terminate with end opcode.")
  }
  if stack.length() == 0 {
    raise RuntimeError("Function did not produce an i32 result.")
  }
  pop_i32(stack)
}

///|
fn pop_i32(stack : Array[Int]) -> Int raise ParseRuntimeError {
  match stack.pop() {
    Some(v) => v
    None => raise RuntimeError("Stack underflow while evaluating expression.")
  }
}
